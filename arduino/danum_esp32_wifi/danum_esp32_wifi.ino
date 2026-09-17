/*
 * Danum Water Monitor System - ESP32 Firmware (MySQL Backend Version)
 * 
 * This firmware reads water quality sensors and transmits findings to the XAMPP MySQL backend via the PHP API.
 * It also fetches the target state of the solenoid valve (open/close) in the same request round-trip.
 * 
 * Hardware Connections:
 * 1. Analog pH Sensor         -> GPIO 34 (ADC1_CH6)
 * 2. Analog TDS Sensor        -> GPIO 35 (ADC1_CH7)
 * 3. Analog Turbidity Sensor  -> GPIO 32 (ADC1_CH4)
 * 4. Solar Voltage Divider    -> GPIO 33 (ADC1_CH5) [R1=100k, R2=10k for up to 36V measurement]
 * 5. Solenoid Valve Relay Pin -> GPIO 25 (Digital Output)
 * 
 * Dependencies:
 * - ArduinoJson Library (Install via Arduino IDE Library Manager)
 */

#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>

// ==========================================
// 1. NETWORK & API CONFIGURATION
// ==========================================
const char* ssid     = "YOUR_WIFI_SSID";         // Replace with your community Wi-Fi SSID
const char* password = "YOUR_WIFI_PASSWORD";     // Replace with your Wi-Fi password

// Your XAMPP computer's IP address (e.g. 192.168.1.100 or 10.0.3.2 if running local tools)
const char* serverIp = "192.168.1.100"; 
const int serverPort = 80;                       // Apache port, usually 80

// Solenoid Relay and Status LED Pins
#define SOLENOID_PIN    25 
#define STATUS_LED_PIN   2   // ESP32 onboard LED for status blinking

// Sensor Pin Definitions
#define PH_PIN          34
#define TDS_PIN         35
#define TURBIDITY_PIN   32
#define SOLAR_VOLT_PIN  33

// ==========================================
// 2. CONFIGURATION VARIABLES
// ==========================================
int syncIntervalSeconds   = 30;    // Default sync rate, will be updated by response
float localFilterHealth   = 100.0; // Simulated filter health starting at 100%
unsigned long lastLogTime = 0;

void setup() {
  Serial.begin(115200);
  
  pinMode(SOLENOID_PIN, OUTPUT);
  pinMode(STATUS_LED_PIN, OUTPUT);
  
  // Default valve state: open (energized or de-energized depending on active-low/high relay)
  digitalWrite(SOLENOID_PIN, HIGH); 
  
  connectWiFi();
}

void loop() {
  if (WiFi.status() != WL_CONNECTED) {
    connectWiFi();
  }

  // 1. Read values from physical analog sensors
  float phVal = readPhSensor();
  float tdsVal = readTdsSensor();
  float turbidityVal = readTurbiditySensor();
  float solarVoltage = readSolarVoltage();
  
  // Simulated filter decay: drops 0.01% every transmission
  localFilterHealth -= 0.01;
  if (localFilterHealth < 0) localFilterHealth = 0.0;

  // Print diagnostics to Serial Monitor
  Serial.println("\n--- SENSOR READINGS ---");
  Serial.print("pH Level: "); Serial.println(phVal);
  Serial.print("TDS (ppm): "); Serial.println(tdsVal);
  Serial.print("Turbidity (NTU): "); Serial.println(turbidityVal);
  Serial.print("Solar Voltage (V): "); Serial.println(solarVoltage);
  Serial.print("Filter Health (%): "); Serial.println(localFilterHealth);

  // 2. Sync with MySQL DB via PHP POST
  syncSensorData(phVal, tdsVal, turbidityVal, solarVoltage, localFilterHealth);

  // 3. Blink status LED to signal successful round-trip
  blinkLED(2, 200);

  // 4. Delay until next sync cycle (can be swapped for Deep Sleep to save battery)
  Serial.print("Sleeping for "); Serial.print(syncIntervalSeconds); Serial.println(" seconds...");
  delay(syncIntervalSeconds * 1000);
}

// ==========================================
// 3. SENSOR CALIBRATION FUNCTIONS
// ==========================================
float readPhSensor() {
  float samples[15];
  for (int i = 0; i < 15; i++) {
    int rawValue = analogRead(PH_PIN);
    samples[i] = rawValue * (3.3 / 4095.0);
    delay(2);
  }
  
  // Sort samples ascending to isolate motor spikes
  for (int i = 0; i < 14; i++) {
    for (int j = i + 1; j < 15; j++) {
      if (samples[i] > samples[j]) {
        float temp = samples[i];
        samples[i] = samples[j];
        samples[j] = temp;
      }
    }
  }

  // Average middle 7 median samples
  float voltage = 0;
  for (int i = 4; i <= 10; i++) {
    voltage += samples[i];
  }
  voltage /= 7.0;
  
  float phValue = 3.5 * voltage + 0.2; 
  return clamp(phValue, 0.0, 14.0);
}

float readTdsSensor() {
  int rawValue = analogRead(TDS_PIN);
  float voltage = rawValue * (3.3 / 4095.0);
  
  // Gravity TDS Calibration conversion equation:
  float compensationCoefficient = 1.0 + 0.02 * (25.0 - 25.0); // Temperature compensation (default 25C)
  float compensatedVoltage = voltage / compensationCoefficient;
  
  float tdsValue = (133.42 * compensatedVoltage * compensatedVoltage * compensatedVoltage 
                    - 255.86 * compensatedVoltage * compensatedVoltage 
                    + 857.39 * compensatedVoltage) * 0.5; // Scale calibration factor
  return clamp(tdsValue, 0.0, 1000.0);
}

float readTurbiditySensor() {
  int rawValue = analogRead(TURBIDITY_PIN);
  float voltage = rawValue * (3.3 / 4095.0);
  
  // Typical turbidity formula: NTU = -1120.4 * (Voltage^2) + 5742.3 * Voltage - 4352.9
  // If voltage is very high, NTU is very clean (0). If voltage drops, NTU goes high.
  float ntu = 0;
  if (voltage < 2.5) {
    ntu = 3000.0;
  } else {
    ntu = -1120.4 * (voltage * voltage) + 5742.3 * voltage - 4352.9;
  }
  return clamp(ntu, 0.0, 100.0);
}

float readSolarVoltage() {
  int rawValue = analogRead(SOLAR_VOLT_PIN);
  float adcVoltage = rawValue * (3.3 / 4095.0);
  
  // Voltage divider formula to scale up to actual battery/solar output
  // R1 = 100k ohm, R2 = 10k ohm
  // Factor = (R1 + R2) / R2 = 110k / 10k = 11
  float actualVoltage = adcVoltage * 11.0;
  return clamp(actualVoltage, 0.0, 36.0);
}

// ==========================================
// 4. API TRANSMISSION & COMMAND PARSING
// ==========================================
void syncSensorData(float ph, float tds, float turb, float solar, float filter) {
  if (WiFi.status() != WL_CONNECTED) return;

  HTTPClient http;
  String url = "http://" + String(serverIp) + ":" + String(serverPort) + "/danum/api/save_sensor_data.php";
  
  Serial.print("Connecting to backend: "); Serial.println(url);
  http.begin(url);
  http.addHeader("Content-Type", "application/json");

  // Create JSON Document to upload
  StaticJsonDocument<256> doc;
  doc["ph"] = ph;
  doc["tds"] = tds;
  doc["turbidity"] = turb;
  doc["solar_voltage"] = solar;
  doc["filter_health"] = filter;
  
  // Upload current solenoid valve state
  doc["valve_open"] = (digitalRead(SOLENOID_PIN) == HIGH) ? 1 : 0;

  String requestBody;
  serializeJson(doc, requestBody);

  int httpResponseCode = http.POST(requestBody);

  if (httpResponseCode > 0) {
    String response = http.getString();
    Serial.print("HTTP Response: "); Serial.println(httpResponseCode);
    Serial.println(response);

    StaticJsonDocument<256> responseDoc;
    DeserializationError error = deserializeJson(responseDoc, response);

    if (!error) {
      bool success = responseDoc["success"];
      if (success) {
        // Parse valve target commands from PHP response
        int targetValveState = responseDoc["valve_state"]; // 0 = close, 1 = open
        int remoteSyncInterval = responseDoc["sync_interval"];
        
        // Apply Solenoid valve toggle
        if (targetValveState == 1) {
          digitalWrite(SOLENOID_PIN, HIGH); // Open
          Serial.println("Action: VALVE OPENED (Solenoid Energized)");
        } else {
          digitalWrite(SOLENOID_PIN, LOW);  // Close
          Serial.println("Action: VALVE CLOSED (Solenoid Shutoff)");
        }

        // Apply dynamic sync rate
        if (remoteSyncInterval >= 5 && remoteSyncInterval <= 300) {
          syncIntervalSeconds = remoteSyncInterval;
        }
      }
    } else {
      Serial.print("JSON parse failed: "); Serial.println(error.c_str());
    }
  } else {
    Serial.print("Error sending POST request: "); Serial.println(httpResponseCode);
  }
  
  http.end();
}

// ==========================================
// 5. WI-FI & DIAGNOSTIC UTILITIES
// ==========================================
void connectWiFi() {
  Serial.print("Connecting to Wi-Fi: "); Serial.println(ssid);
  WiFi.begin(ssid, password);
  
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 20) {
    delay(500);
    Serial.print(".");
    attempts++;
  }
  
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\nWi-Fi Connected successfully!");
    Serial.print("ESP32 IP: "); Serial.println(WiFi.localIP());
  } else {
    Serial.println("\nWi-Fi connection failed. Will retry next loop.");
  }
}

void blinkLED(int count, int delayMs) {
  for (int i = 0; i < count; i++) {
    digitalWrite(STATUS_LED_PIN, HIGH);
    delay(delayMs);
    digitalWrite(STATUS_LED_PIN, LOW);
    delay(delayMs);
  }
}

float clamp(float value, float minVal, float maxVal) {
  if (value < minVal) return minVal;
  if (value > maxVal) return maxVal;
  return value;
}
