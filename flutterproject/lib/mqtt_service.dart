import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class MQTTService {
  late MqttServerClient client;

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

  Future<void> connect() async {
    client = MqttServerClient(
      '172.20.10.2', // RPI IP
      'flutter_client',
    );

    client.port = 1883;
    client.keepAlivePeriod = 20;

    final connMess = MqttConnectMessage()
        .withClientIdentifier('flutter_client')
        .startClean();

    client.connectionMessage = connMess;

    try {
      await client.connect();
      print("MQTT CONNECTED ✅");
    } catch (e) {
      print("MQTT ERROR ❌");
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

      if (onTemperatureChanged != null) {
        onTemperatureChanged!(double.parse(payload));
      }
    });
  }
}
