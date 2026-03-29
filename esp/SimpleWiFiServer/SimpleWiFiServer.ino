#include <WiFi.h>
#include <WiFiManager.h>
#include <PubSubClient.h>

#define LED_PIN 2   // D4 = GPIO2

const char* mqtt_server = "192.168.43.120"; // Raspberry Pi IP

WiFiClient espClient;
PubSubClient client(espClient);

int setpoint = 22;

void callback(char* topic, byte* payload, unsigned int length) {
  String message;

  for (int i = 0; i < length; i++) {
    message += (char)payload[i];
  }

  Serial.print("Setpoint received: ");
  Serial.println(message);

  setpoint = message.toInt();
}

void reconnect() {
  while (!client.connected()) {
    Serial.print("Connecting MQTT...");

    if (client.connect("ESP32Thermostat")) {
      Serial.println("connected");
      client.subscribe("thermosmart/setpoint");
    } else {
      Serial.print("failed ");
      Serial.println(client.state());
      delay(2000);
    }
  }
}

void setup() {
  Serial.begin(115200);

 
  WiFiManager wm;
  wm.autoConnect("Thermostat-Setup");

  Serial.println("WiFi Connected!");

  client.setServer(mqtt_server, 1883);
  client.setCallback(callback);

  pinMode(LED_PIN, OUTPUT);
}

void loop() {
  if (!client.connected()) {
    reconnect();
  }

  client.loop();


  float temperature = random(20, 30);

  char tempString[8];
  dtostrf(temperature, 1, 2, tempString);

  client.publish("thermosmart/temperature", tempString);

  Serial.print("Temperature sent: ");
  Serial.println(tempString);


  if (temperature < setpoint - 1) {
    digitalWrite(LED_PIN, HIGH);  // LED ON
    Serial.println("Heating ON");
  }
  else if (temperature > setpoint + 1) {
    digitalWrite(LED_PIN, LOW);   // LED OFF
    Serial.println("Heating OFF");
  }

  delay(3000);
}