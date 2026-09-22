// ======================================================
// Danum Water Quality Monitoring System (ESP32)
// 3 Calibrated Sensors + Firebase RTDB Sync + Buzzer Alert
// Supports Firebase Authentication (Option A Secure Rules)
// ======================================================

#include <EEPROM.h>
#include <WiFi.h>
#include <Firebase_ESP_Client.h>

// Firebase Helper Addons
#include <addons/RTDBHelper.h>

// ==================== Sensor Pins ====================
#define PH_PIN          34
#define TDS_PIN         35
#define TURBIDITY_PIN   32

// ==================== Output Pins ====================
#define SOLENOID_PIN       25    // Relay signal pin for Solenoid Valve
#define RELAY_ACTIVE_LOW   true  // Set to true for Active-LOW 5V relay modules (signal LOW = Relay ON)
#define BUZZER_PIN         26    // Signal pin for Active Piezo Buzzer (Red wire -> GPIO 26, Black wire -> GND)

// Helper function to drive relay correctly based on Active-LOW / Active-HIGH architecture
void writeSolenoidState(bool open) {
    if (RELAY_ACTIVE_LOW) {
        digitalWrite(SOLENOID_PIN, open ? LOW : HIGH);
    } else {
        digitalWrite(SOLENOID_PIN, open ? HIGH : LOW);
    }
}

// ================= ADC Configuration =================
#define ADC_MAX 4095.0
#define VREF    3.3

// ================= Network & Firebase Config =================
#define WIFI_SSID         "Danum_WiFi"
#define WIFI_PASSWORD     "123456789"

// Firebase Web API Key (Found in Firebase Console -> Project Settings -> General)
#define FIREBASE_API_KEY  "AIzaSyCy4r4PjVx9bNTa7Vfk7u7NQ7BouyOqeJY"

// Firebase Realtime Database URL (asia-southeast1)
#define FIREBASE_URL      "https://danum-3bbe4-default-rtdb.asia-southeast1.firebasedatabase.app"

// Auth Mode: 1 = Firebase Anonymous Auth (Matches Option A Rules), 2 = Database Secret
#define USE_FIREBASE_AUTH 1

#define FIREBASE_DB_SECRET "7axJWjsIFLY0hTqJ760SiUiywyUYLSa6v2zhBFQz"

// ================= Calibration Values =================
float phSlope  = -5.70;
float phOffset = 20.28; // Calibrated offset adjusted to match 7.10 pH tester baseline

float tdsScale   = 1.0;
float tdsOffset  = 0;

float turbScale  = 1.0;
float turbOffset = 0;

// ============== Moving Average Filter ==============
const int PH_WINDOW = 10;
float phBuf[PH_WINDOW];
int phIdx = 0;
bool phFull = false;

// ============== Buzzer Alarm Configuration ==============
const unsigned long BUZZER_INTERVAL_MS     = 3000; // Buzz cycle interval (3 seconds)
const unsigned long BUZZER_BEEP_DURATION_MS = 300;  // Beep pulse duration (300 ms)
unsigned long lastBuzzerCycleTime          = 0;
bool isBuzzerBeeping                        = false;

// ============== Firebase Objects & Timers ==============
FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;

unsigned long lastFirebaseLogTime = 0;
unsigned long lastSerialLogTime = 0;
unsigned long syncIntervalMs = 10000; // Dynamic, fetched from Firebase /controls/sync_interval
bool currentValveState = true;         // Track solenoid valve state

// ======================================================
// Read Voltage (Averaged 30 samples)
// ======================================================
float readVoltage(int pin)
{
    long s = 0;
    for (int i = 0; i < 30; i++) {
        s += analogRead(pin);
        delay(2);
    }
    return (s / 30.0) * (VREF / ADC_MAX);
}

// ======================================================
// Read pH Voltage (Outlier-Rejecting Median Filter)
// Filters out motor EMI noise and pump turbulence spikes
// ======================================================
float readPHVoltage()
{
    float samples[15];
    for (int i = 0; i < 15; i++) {
        samples[i] = readVoltage(PH_PIN);
        delay(3);
    }

    // Sort samples ascending to isolate noise spikes
    for (int i = 0; i < 14; i++) {
        for (int j = i + 1; j < 15; j++) {
            if (samples[i] > samples[j]) {
                float temp = samples[i];
                samples[i] = samples[j];
                samples[j] = temp;
            }
        }
    }

    // Average middle 7 median samples (discarding top & bottom 4 noise outliers)
    float medianSum = 0;
    for (int i = 4; i <= 10; i++) {
        medianSum += samples[i];
    }
    return medianSum / 7.0;
}

// ======================================================
// Wi-Fi Connection Helper
// ======================================================
void connectWiFi() {
    Serial.print("Connecting Wi-Fi: ");
    Serial.println(WIFI_SSID);
    WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

    int attempts = 0;
    while (WiFi.status() != WL_CONNECTED && attempts < 30) {
        delay(500);
        Serial.print(".");
        attempts++;
    }

    if (WiFi.status() == WL_CONNECTED) {
        Serial.println("\nWi-Fi Connected!");
        Serial.print("IP: ");
        Serial.println(WiFi.localIP());
    } else {
        Serial.println("\nWi-Fi Failed! Offline mode.");
    }
}

// ======================================================
// Setup
// ======================================================
void setup()
{
    Serial.begin(115200);
    delay(1000);

    Serial.println("\n==================================");
    Serial.println("      DANUM SYSTEM STARTING       ");
    Serial.println("==================================");

    // Initialize Solenoid Relay Pin (Default OPEN on boot)
    pinMode(SOLENOID_PIN, OUTPUT);
    writeSolenoidState(true);

    // Initialize Active Buzzer Pin (Default OFF on boot)
    pinMode(BUZZER_PIN, OUTPUT);
    digitalWrite(BUZZER_PIN, LOW);

    EEPROM.begin(64);

    analogReadResolution(12);
    analogSetPinAttenuation(PH_PIN, ADC_11db);
    analogSetPinAttenuation(TDS_PIN, ADC_11db);
    analogSetPinAttenuation(TURBIDITY_PIN, ADC_11db);

    connectWiFi();

    // ================= Firebase Setup =================
    Serial.println("Initializing Firebase...");
    config.database_url = FIREBASE_URL;

#if USE_FIREBASE_AUTH == 1
    // Method 1: Firebase Anonymous Authentication (Option A Secure Rules)
    config.api_key = FIREBASE_API_KEY;
    Serial.println("Authenticating anonymously with Firebase...");
    if (Firebase.signUp(&config, &auth, "", "")) {
        Serial.println("Firebase Auth: Anonymous Sign-In Successful!");
    } else {
        Serial.printf("Firebase Auth Warning: %s (Will retry on reconnect)\n", config.signer.signupError.message.c_str());
    }
#else
    // Method 2: Legacy Database Secret (Admin fallback)
    config.signer.tokens.legacy_token = FIREBASE_DB_SECRET;
#endif

    Firebase.reconnectWiFi(true);
    Firebase.begin(&config, &auth);

    Serial.println("Firebase ready!");
    Serial.println("Sensors Active. Solenoid Relay: OK. Buzzer: OK.");
    Serial.println("Starting Monitor...\n");
}

// ======================================================
// Main Loop
// ======================================================
void loop()
{
    // 1. Read Analog Sensor Voltages & Compute Calibrated Values
    float phV = readPHVoltage();
    float ph = constrain(phV * phSlope + phOffset, 0, 14);

    float tdsV = readVoltage(TDS_PIN);
    float rawTDS = (133.42 * pow(tdsV, 3) - 255.86 * sq(tdsV) + 857.39 * tdsV) * 0.5;
    float tds = max(0.0f, rawTDS * tdsScale + tdsOffset);

    float turbV = readVoltage(TURBIDITY_PIN);
    const float CLEAR_VOLTAGE = 3.30;
    const float MUDDY_VOLTAGE = 2.65;
    float ntu = (CLEAR_VOLTAGE - turbV) * (400.0 / (CLEAR_VOLTAGE - MUDDY_VOLTAGE));
    ntu = constrain(ntu, 0.0, 400.0);

    // 2. Fetch Control Parameters & Dynamic Sync Rate from Firebase (/controls)
    int manualOverride = 0;
    int appValveState = 1;
    int remoteSyncSec = 10;

    if (Firebase.ready()) {
        if (Firebase.RTDB.getInt(&fbdo, "/controls/manual_valve_override")) {
            manualOverride = fbdo.intData();
        }
        if (Firebase.RTDB.getInt(&fbdo, "/controls/valve_state")) {
            appValveState = fbdo.intData();
        }
        if (Firebase.RTDB.getInt(&fbdo, "/controls/sync_interval")) {
            remoteSyncSec = fbdo.intData();
            if (remoteSyncSec >= 5 && remoteSyncSec <= 300) {
                syncIntervalMs = remoteSyncSec * 1000;
            }
        }
    }

    // 3. Automatic Water Safety Evaluation
    // WHO/DOH Safe Limits: pH 6.5 - 8.5, TDS <= 600 ppm, Turbidity <= 5.0 NTU
    bool isWaterSafe = (ph >= 6.5 && ph <= 8.5) && (tds <= 600.0) && (ntu <= 5.0);

    if (manualOverride == 1) {
        // App Manual Override Active
        currentValveState = (appValveState == 1);
    } else {
        // AUTOMATIC MODE: Auto shut-off when unsafe, OPEN when safe
        currentValveState = isWaterSafe;

        // Sync automatic decision back to Firebase /controls/valve_state
        if (Firebase.ready()) {
            Firebase.RTDB.setInt(&fbdo, "/controls/valve_state", currentValveState ? 1 : 0);
        }
    }

    // Drive Relay Output Pin (using Active-LOW / Active-HIGH hardware helper)
    writeSolenoidState(currentValveState);

    // ======================================================
    // 3.5 Buzzer Unsafe Water Alarm Control
    // ======================================================
    // When water is dirty & unsafe to drink (!isWaterSafe), buzz every 3 seconds until safe again
    if (!isWaterSafe) {
        unsigned long currentMillis = millis();
        if (!isBuzzerBeeping && (currentMillis - lastBuzzerCycleTime >= BUZZER_INTERVAL_MS || lastBuzzerCycleTime == 0)) {
            lastBuzzerCycleTime = currentMillis;
            isBuzzerBeeping = true;
            digitalWrite(BUZZER_PIN, HIGH); // Active buzzer ON (Sound alarm)
        } else if (isBuzzerBeeping && (currentMillis - lastBuzzerCycleTime >= BUZZER_BEEP_DURATION_MS)) {
            isBuzzerBeeping = false;
            digitalWrite(BUZZER_PIN, LOW);  // Active buzzer OFF
        }
    } else {
        // Water is SAFE: silence buzzer and reset alarm cycle timer
        digitalWrite(BUZZER_PIN, LOW);
        isBuzzerBeeping = false;
        lastBuzzerCycleTime = 0;
    }

    // 4. Serial Diagnostics Display (every 1 sec)
    if (millis() - lastSerialLogTime > 1000) {
        lastSerialLogTime = millis();

        Serial.print("PH="); Serial.print(ph, 2);
        Serial.print(" | TDS="); Serial.print(tds, 1);
        Serial.print(" ppm | NTU="); Serial.print(ntu, 1);
        Serial.print(" | VALVE="); Serial.print(currentValveState ? "OPEN" : "CLOSED");
        Serial.print(" | BUZZER="); Serial.print(!isWaterSafe ? "ALARM(3s)" : "OFF");
        Serial.print(" | SYNC="); Serial.print(syncIntervalMs / 1000); Serial.println("s");
    }

    // 5. Firebase Telemetry Upload (Dynamic sync rate)
    if (Firebase.ready() && (millis() - lastFirebaseLogTime > syncIntervalMs || lastFirebaseLogTime == 0)) {
        lastFirebaseLogTime = millis();

        Serial.println("\n---> PUSHING SENSOR DATA TO FIREBASE <---");

        FirebaseJson json;
        json.set("ph", ph);
        json.set("tds", tds);
        json.set("turbidity", ntu);
        json.set("valve_open", currentValveState ? 1 : 0);
        json.set("timestamp/.sv", "timestamp"); // Firebase Server Timestamp (UTC millis)

        if (Firebase.RTDB.setJSON(&fbdo, "/live/metrics", &json)) {
            Serial.println("SUCCESS: /live/metrics updated!");
        } else {
            Serial.print("Firebase Error: ");
            Serial.println(fbdo.errorReason());
        }

        if (Firebase.RTDB.pushJSON(&fbdo, "/history/logs", &json)) {
            Serial.println("SUCCESS: Log pushed to /history/logs!");
        }
    }
}