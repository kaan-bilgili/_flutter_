#include <WiFiManager.h>
#include <WiFi.h>
#include <PubSubClient.h>
#include <DHT.h>
#include <Preferences.h>

// ===== DHT =====
#define DHTPIN 4
#define DHTTYPE DHT11

// ===== LED =====
#define LED_PIN 5

// ===== RESET BUTTON =====
// Bu pine bağlı butona 3 saniye basılı tutulursa WiFi ayarları sıfırlanır
#define RESET_PIN 0  // ESP32 üzerindeki BOOT butonu

WiFiClient espClient;
PubSubClient client(espClient);
DHT dht(DHTPIN, DHTTYPE);
Preferences preferences;

char mqtt_server[40] = "192.168.1.100";
int setpoint = 22;

// MQTT callback
void callback(char *topic, byte *payload, unsigned int length)
{
  String message = "";
  for (int i = 0; i < length; i++)
  {
    message += (char)payload[i];
  }

  Serial.print("Yeni setpoint: ");
  Serial.println(message);

  int newSetpoint = message.toInt();
  if (newSetpoint > 0)
  {
    setpoint = newSetpoint;
  }
}

void connectWiFi()
{
  WiFiManager wifiManager;

  wifiManager.setConfigPortalTimeout(120);

  WiFiManagerParameter mqtt_param("mqtt", "MQTT Sunucu IP", mqtt_server, 40);
  wifiManager.addParameter(&mqtt_param);

  Serial.println("WiFi baglaniyor...");

  if (!wifiManager.autoConnect("ThermoSmart-Setup", "thermosetup"))
  {
    Serial.println("WiFi baglanti basarisiz, yeniden baslatiliyor...");
    delay(3000);
    ESP.restart();
  }

  strncpy(mqtt_server, mqtt_param.getValue(), 40);
  preferences.begin("thermosmart", false);
  preferences.putString("mqtt_ip", mqtt_server);
  preferences.end();

  Serial.println("WiFi BAGLANDI");
  Serial.print("ESP IP: ");
  Serial.println(WiFi.localIP());
  Serial.print("MQTT Sunucu: ");
  Serial.println(mqtt_server);
}

void reconnect()
{
  while (!client.connected())
  {
    Serial.println("MQTT connect deneniyor...");
    if (client.connect("ESP32TEST"))
    {
      Serial.println("MQTT CONNECT BASARILI");
      client.subscribe("thermosmart/setpoint");
      Serial.println("Subscribed OK");
    }
    else
    {
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

  if (digitalRead(RESET_PIN) == LOW)
  {
    unsigned long pressStart = millis();
    Serial.println("Reset butonu basili, 3 saniye bekle...");

    while (digitalRead(RESET_PIN) == LOW)
    {
      if (millis() - pressStart >= 3000)
      {
        Serial.println("WiFi ayarlari sifirlanıyor...");
        WiFiManager wifiManager;
        wifiManager.resetSettings();
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
  if (WiFi.status() != WL_CONNECTED)
  {
    connectWiFi();
  }

  if (!client.connected())
  {
    reconnect();
  }

  client.loop();

  float temperature = dht.readTemperature();

  if (isnan(temperature))
  {
    Serial.println("DHT okuma hatasi");
    delay(2000);
    return;
  }

  char tempString[8];
  dtostrf(temperature, 1, 2, tempString);

  client.publish("thermosmart/temperature", tempString);

  Serial.print("Temp: ");
  Serial.print(tempString);
  Serial.print(" | Setpoint: ");
  Serial.println(setpoint);

  if (temperature < setpoint - 1)
  {
    digitalWrite(LED_PIN, HIGH);
    Serial.println("Heating ON");
  }
  else if (temperature > setpoint + 1)
  {
    digitalWrite(LED_PIN, LOW);
    Serial.println("Heating OFF");
  }

  delay(3000);
}
