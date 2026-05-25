#include <WiFiManager.h>
#include <WiFi.h>
#include <PubSubClient.h>
#include <DHT.h>
#include <Preferences.h>

#define DHTPIN    4
#define DHTTYPE   DHT11
#define LED_PIN   5
#define RESET_PIN 0

WiFiClient   espClient;
PubSubClient client(espClient);
DHT          dht(DHTPIN, DHTTYPE);
Preferences  preferences;

char mqtt_server[40] = "192.168.1.100";
int  setpoint = 22;

unsigned long lastReadTime = 0;
#define READ_INTERVAL 3000

void callback(char *topic, byte *payload, unsigned int length)
{
  String message = "";
  for (unsigned int i = 0; i < length; i++)
    message += (char)payload[i];

  int newSetpoint = message.toInt();
  if (newSetpoint >= 15 && newSetpoint <= 35) {
    setpoint = newSetpoint;
    Serial.print("Yeni setpoint: ");
    Serial.println(setpoint);
  }
}

void connectWiFi()
{
  WiFiManager wifiManager;
  wifiManager.setConfigPortalTimeout(120);

  WiFiManagerParameter mqtt_param("mqtt", "MQTT Sunucu IP", mqtt_server, 40);
  wifiManager.addParameter(&mqtt_param);

  Serial.println("WiFi baglaniyor...");
  if (!wifiManager.autoConnect("ThermoSmart-Setup", "thermosetup")) {
    Serial.println("WiFi basarisiz, yeniden baslatiliyor...");
    delay(3000);
    ESP.restart();
  }

  strncpy(mqtt_server, mqtt_param.getValue(), 40);
  preferences.begin("thermosmart", false);
  preferences.putString("mqtt_ip", mqtt_server);
  preferences.end();

  Serial.print("WiFi BAGLANDI - IP: ");
  Serial.println(WiFi.localIP());
}

void reconnect()
{
  while (!client.connected()) {
    Serial.println("MQTT connect deneniyor...");
    if (client.connect("ESP32_ThermoSmart")) {
      Serial.println("MQTT BAGLANDI");
      client.subscribe("thermosmart/setpoint");
    } else {
      Serial.print("MQTT FAIL: ");
      Serial.println(client.state());
      delay(3000);
    }
  }
}

void checkResetButton()
{
  pinMode(RESET_PIN, INPUT_PULLUP);
  delay(100);
  if (digitalRead(RESET_PIN) == LOW) {
    unsigned long pressStart = millis();
    Serial.println("Reset butonu basili...");
    while (digitalRead(RESET_PIN) == LOW) {
      if (millis() - pressStart >= 3000) {
        Serial.println("Sifirlanıyor...");
        WiFiManager wm;
        wm.resetSettings();
        preferences.begin("thermosmart", false);
        preferences.clear();
        preferences.end();
        delay(1000);
        ESP.restart();
      }
    }
  }
}

void setup()
{
  Serial.begin(115200);
  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, LOW);

  preferences.begin("thermosmart", true);
  String saved_mqtt = preferences.getString("mqtt_ip", "192.168.1.100");
  preferences.end();
  saved_mqtt.toCharArray(mqtt_server, 40);

  checkResetButton();
  dht.begin();
  delay(2000);
  connectWiFi();

  client.setServer(mqtt_server, 1883);
  client.setCallback(callback);
}

void loop()
{
  if (WiFi.status() != WL_CONNECTED) connectWiFi();
  if (!client.connected()) reconnect();
  client.loop();

  unsigned long now = millis();
  if (now - lastReadTime >= READ_INTERVAL) {
    lastReadTime = now;

    float temperature = dht.readTemperature();
    float humidity    = dht.readHumidity();

    if (isnan(temperature) || isnan(humidity)) {
      Serial.println("DHT okuma hatasi");
      return;
    }

    char tempStr[8], humStr[8];
    dtostrf(temperature, 1, 2, tempStr);
    dtostrf(humidity,    1, 2, humStr);

    // Her ikisini de publish et
    client.publish("thermosmart/temperature", tempStr);
    client.publish("thermosmart/humidity",    humStr);

    Serial.print("Temp: "); Serial.print(tempStr);
    Serial.print(" | Hum: "); Serial.print(humStr);
    Serial.print(" | Setpoint: "); Serial.println(setpoint);

    if (temperature < setpoint - 1) {
      digitalWrite(LED_PIN, HIGH);
      client.publish("thermosmart/heating", "ON");
      Serial.println("Heating ON");
    } else if (temperature > setpoint + 1) {
      digitalWrite(LED_PIN, LOW);
      client.publish("thermosmart/heating", "OFF");
      Serial.println("Heating OFF");
    }
  }
}
