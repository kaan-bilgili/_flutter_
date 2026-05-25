import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class MQTTService {
  static final MQTTService _instance = MQTTService._internal();
  factory MQTTService() => _instance;
  MQTTService._internal();

  late MqttServerClient client;
  bool _isConnected = false;

  Function(double)? onTemperatureChanged;

  void publishSetpoint(double value) {
  final builder = MqttClientPayloadBuilder();
  builder.addString(value.toString());

  client.publishMessage(
    "thermosmart/setpoint",
    MqttQos.atMostOnce,
    builder.payload!,
  );

  print("SETPOINT GÖNDERİLDİ: $value");
}

  Function(double)? onTemperatureChanged;
<<<<<<< Updated upstream

=======
/*
  void publishSetpoint(double value) {
    if (!_isConnected) return;
    final builder = MqttClientPayloadBuilder();
    builder.addString(value.toString());
    client.publishMessage(
      "thermosmart/setpoint",
      MqttQos.atMostOnce,
      builder.payload!,
    );
    print("SETPOINT GÖNDERİLDİ: $value");
  }
*/
>>>>>>> Stashed changes
  Future<void> connect() async {
    if (_isConnected) return;

    client = MqttServerClient('192.168.1.100', 'flutter_client');
    client.port = 1883;
    client.keepAlivePeriod = 20;

    final connMess = MqttConnectMessage()
        .withClientIdentifier('flutter_client')
        .startClean();
    client.connectionMessage = connMess;

    try {
      await client.connect();
      _isConnected = true;
      print("MQTT CONNECTED ✅");
    } catch (e) {
      print("MQTT ERROR ❌: $e");
      client.disconnect();
      return;
    }

    client.subscribe("thermosmart/temperature", MqttQos.atMostOnce);

    client.updates!.listen((event) {
      final recMess = event[0].payload as MqttPublishMessage;
      final payload = MqttPublishPayload.bytesToStringAsString(
        recMess.payload.message,
      );
      print("TEMP GELDİ: $payload");
      onTemperatureChanged?.call(double.parse(payload));
    });
  }
}