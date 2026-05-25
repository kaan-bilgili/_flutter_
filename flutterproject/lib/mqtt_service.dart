import 'dart:async';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class MQTTService {
  static final MQTTService _instance = MQTTService._internal();
  factory MQTTService() => _instance;
  MQTTService._internal();

  late MqttServerClient client;
  bool _isConnected = false;
  bool _isConnecting = false;

  Function(double)? onTemperatureChanged;

  bool get isConnected => _isConnected;

  // ─── Publish ──────────────────────────────────────────────────────────────

  void publishSetpoint(double value) {
    if (!_isConnected) {
      print("MQTT bağlı değil, setpoint gönderilemedi");
      return;
    }
    final builder = MqttClientPayloadBuilder();
    builder.addString(value.toStringAsFixed(0));
    client.publishMessage(
      "thermosmart/setpoint",
      MqttQos.atLeastOnce, // QoS 1 — daha güvenilir
      builder.payload!,
    );
    print("SETPOINT GÖNDERİLDİ: $value");
  }

  // ─── Connect ──────────────────────────────────────────────────────────────

  Future<void> connect() async {
    if (_isConnected || _isConnecting) return;
    _isConnecting = true;

    final clientId = 'flutter_${DateTime.now().millisecondsSinceEpoch}';

    client = MqttServerClient('192.168.1.100', clientId);
    client.port = 1883;
    client.keepAlivePeriod = 20;
    client.autoReconnect = true;
    client.resubscribeOnAutoReconnect = true;

    client.onDisconnected    = _onDisconnected;
    client.onConnected       = _onConnected;
    client.onAutoReconnected = _onAutoReconnected;

    final connMess = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .startClean();
    client.connectionMessage = connMess;

    try {
      await client.connect();
    } catch (e) {
      print("MQTT ERROR ❌: $e");
      _isConnected  = false;
      _isConnecting = false;
      client.disconnect();
      // 5 saniye sonra tekrar dene
      Future.delayed(const Duration(seconds: 5), connect);
      return;
    }

    if (client.connectionStatus?.state == MqttConnectionState.connected) {
      _isConnected  = true;
      _isConnecting = false;
      _subscribeAndListen();
    } else {
      print("MQTT bağlantı başarısız: ${client.connectionStatus}");
      _isConnected  = false;
      _isConnecting = false;
      Future.delayed(const Duration(seconds: 5), connect);
    }
  }

  // ─── Subscribe & Listen ───────────────────────────────────────────────────

  void _subscribeAndListen() {
    client.subscribe("thermosmart/temperature", MqttQos.atMostOnce);

    client.updates?.listen((List<MqttReceivedMessage<MqttMessage>> events) {
      for (final event in events) {
        final recMess = event.payload as MqttPublishMessage;
        final payload = MqttPublishPayload.bytesToStringAsString(
          recMess.payload.message,
        );
        print("TEMP GELDİ: $payload");
        final temp = double.tryParse(payload);
        if (temp != null) onTemperatureChanged?.call(temp);
      }
    });
  }

  // ─── Callbacks ────────────────────────────────────────────────────────────

  void _onConnected() {
    _isConnected  = true;
    _isConnecting = false;
    print("MQTT CONNECTED ✅");
  }

  void _onDisconnected() {
    _isConnected = false;
    print("MQTT DISCONNECTED ❌ — otomatik yeniden bağlanılacak");
  }

  void _onAutoReconnected() {
    _isConnected = true;
    print("MQTT YENİDEN BAĞLANDI ✅");
  }

  // ─── Disconnect ───────────────────────────────────────────────────────────

  void disconnect() {
    client.disconnect();
    _isConnected  = false;
    _isConnecting = false;
  }
}