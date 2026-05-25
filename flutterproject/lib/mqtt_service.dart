import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class MQTTService {
  static final MQTTService _instance = MQTTService._internal();
  factory MQTTService() => _instance;
  MQTTService._internal();

  late MqttServerClient client;
  bool _isConnected = false;
  bool _isConnecting = false;

  // Callbacks
  Function(double)? onTemperatureChanged;
  Function(double)? onHumidityChanged;
  Function(String)? onHeatingStateChanged;
  Function(bool)?   onConnectionChanged;

  bool get isConnected => _isConnected;

  // ─── Connect ──────────────────────────────────────────────────────────────

  Future<void> connect() async {
    if (_isConnected || _isConnecting) return;
    _isConnecting = true;

    // Benzersiz client ID — aynı ağda çakışmayı önler
    final clientId = 'flutter_${DateTime.now().millisecondsSinceEpoch}';

    client = MqttServerClient('192.168.1.100', clientId);
    client.port = 1883;
    client.keepAlivePeriod = 20;
    client.autoReconnect = true;
    client.resubscribeOnAutoReconnect = true;

    client.onDisconnected   = _onDisconnected;
    client.onConnected      = _onConnected;
    client.onAutoReconnected = _onAutoReconnected;

    final connMess = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .withWillQos(MqttQos.atMostOnce)
        .startClean();
    client.connectionMessage = connMess;

    try {
      await client.connect();
    } catch (e) {
      print('[MQTT] Bağlantı hatası: $e');
      client.disconnect();
      _isConnected  = false;
      _isConnecting = false;
      onConnectionChanged?.call(false);
      return;
    }

    if (client.connectionStatus?.state == MqttConnectionState.connected) {
      _isConnected  = true;
      _isConnecting = false;
      _subscribeToTopics();
      _listenToMessages();
      onConnectionChanged?.call(true);
      print('[MQTT] BAĞLANDI ✅');
    } else {
      print('[MQTT] Bağlantı başarısız: ${client.connectionStatus}');
      _isConnected  = false;
      _isConnecting = false;
      onConnectionChanged?.call(false);
    }
  }

  // ─── Subscribe ────────────────────────────────────────────────────────────

  void _subscribeToTopics() {
    client.subscribe('thermosmart/temperature', MqttQos.atMostOnce);
    client.subscribe('thermosmart/humidity',    MqttQos.atMostOnce);
    client.subscribe('thermosmart/heating',     MqttQos.atMostOnce);
    print('[MQTT] Subscribe tamamlandı');
  }

  // ─── Listen ───────────────────────────────────────────────────────────────

  void _listenToMessages() {
    client.updates?.listen((List<MqttReceivedMessage<MqttMessage>> events) {
      for (final event in events) {
        final recMess = event.payload as MqttPublishMessage;
        final payload = MqttPublishPayload.bytesToStringAsString(
          recMess.payload.message,
        );
        final topic = event.topic;
        print('[MQTT] $topic → $payload');

        switch (topic) {
          case 'thermosmart/temperature':
            final temp = double.tryParse(payload);
            if (temp != null) onTemperatureChanged?.call(temp);
            break;
          case 'thermosmart/humidity':
            final hum = double.tryParse(payload);
            if (hum != null) onHumidityChanged?.call(hum);
            break;
          case 'thermosmart/heating':
            onHeatingStateChanged?.call(payload); // "ON" veya "OFF"
            break;
        }
      }
    });
  }

  // ─── Publish ──────────────────────────────────────────────────────────────

  void publishSetpoint(double value) {
    if (!_isConnected) {
      print('[MQTT] Bağlı değil, setpoint gönderilemedi');
      return;
    }
    final builder = MqttClientPayloadBuilder();
    builder.addString(value.toStringAsFixed(0)); // "22" formatında
    client.publishMessage(
      'thermosmart/setpoint',
      MqttQos.atLeastOnce, // QoS 1 — daha güvenilir
      builder.payload!,
    );
    print('[MQTT] Setpoint gönderildi: $value');
  }

  void publishCommand(String command) {
    if (!_isConnected) return;
    final builder = MqttClientPayloadBuilder();
    builder.addString(command);
    client.publishMessage(
      'thermosmart/command',
      MqttQos.atLeastOnce,
      builder.payload!,
    );
    print('[MQTT] Komut gönderildi: $command');
  }

  // ─── Callbacks ────────────────────────────────────────────────────────────

  void _onConnected() {
    _isConnected = true;
    onConnectionChanged?.call(true);
    print('[MQTT] onConnected');
  }

  void _onDisconnected() {
    _isConnected = false;
    onConnectionChanged?.call(false);
    print('[MQTT] Bağlantı koptu');
  }

  void _onAutoReconnected() {
    _isConnected = true;
    onConnectionChanged?.call(true);
    print('[MQTT] Otomatik yeniden bağlandı');
  }

  // ─── Disconnect ───────────────────────────────────────────────────────────

  void disconnect() {
    client.disconnect();
    _isConnected  = false;
    _isConnecting = false;
  }
}