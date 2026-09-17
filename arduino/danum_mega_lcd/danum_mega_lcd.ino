/*
 * Danum Water Quality Monitoring System - Arduino Mega Offline Firmware
 * 
 * This is the stable, high-current Arduino Mega version of the firmware with:
 * - NO Wi-Fi/ESP32 instabilities
 * - 100% native 5.0V logic for stable, accurate sensor readings
 * - Real-time display on the 20x4 I2C LCD
 * - Automatic fail-safe solenoid valve shutoff using Philippine National Standards (PNSDW)
 * 
 * Hardware Connections (Arduino Mega):
 * 1. Analog pH Sensor         -> Pin A0
 * 2. Analog TDS Sensor        -> Pin A1
 * 3. Analog Turbidity Sensor  -> Pin A2
 * 4. Solar Voltage Divider    -> Pin A3
 * 5. Solenoid Valve Relay     -> Digital Pin 8
 * 6. Status/Alert LED         -> Digital Pin 13 (Built-in LED)
 * 7. I2C LCD Display          -> SDA (Pin 20), SCL (Pin 21)
 */

#include <Wire.h>
#include <LiquidCrystal_I2C.h>

// ================= LCD CONFIG =================
// 0x27 I2C Address, 16 columns, 4 rows (Your display is a 16x4 screen!)
LiquidCrystal_I2C lcd(0x27, 16, 4);

// ================= SENSOR & RELAY PINS =================
#define PH_PIN          A0
#define TDS_PIN         A1
#define TURBIDITY_PIN   A2
#define SOLAR_PIN       A3
#define SOLENOID_PIN    8
#define STATUS_LED_PIN  13

// ================= pH CALIBRATION =================
// ---------- ADVANCED pH SENSOR CALIBRATION (3‑Point Quadratic Fit) ----------
#define PH_PIN A0
#define SAMPLE_COUNT 20

/* ----- 3‑POINT CALIBRATION (replace values with your measured voltages) ----- */
const float V[3]  = { 3.25, 2.58, 2.32 };
const float PH[3] = { 4.01, 6.86, 9.18 };

float a, b, c; // quadratic coefficients

/* ----- Compute quadratic fit from the three calibration points ----- */
void computeQuadraticFit() {
  float M[3][3];
  for (int i = 0; i < 3; i++) {
    M[i][0] = sq(V[i]);
    M[i][1] = V[i];
    M[i][2] = 1.0;
  }
  float det = M[0][0]*(M[1][1]*M[2][2] - M[1][2]*M[2][1])
            - M[0][1]*(M[1][0]*M[2][2] - M[1][2]*M[2][0])
            + M[0][2]*(M[1][0]*M[2][1] - M[1][1]*M[2][0]);
  if (fabs(det) < 0.000001) {
    Serial.println("ERROR: Invalid calibration points!");
    while (1);
  }
  float adj[3][3];
  adj[0][0] =  (M[1][1]*M[2][2] - M[1][2]*M[2][1]);
  adj[0][1] = -(M[0][1]*M[2][2] - M[0][2]*M[2][1]);
  adj[0][2] =  (M[0][1]*M[1][2] - M[0][2]*M[1][1]);
  adj[1][0] = -(M[1][0]*M[2][2] - M[1][2]*M[2][0]);
  adj[1][1] =  (M[0][0]*M[2][2] - M[0][2]*M[2][0]);
  adj[1][2] = -(M[0][0]*M[1][2] - M[0][2]*M[1][0]);
  adj[2][0] =  (M[1][0]*M[2][1] - M[1][1]*M[2][0]);
  adj[2][1] = -(M[0][0]*M[2][1] - M[0][1]*M[2][0]);
  adj[2][2] =  (M[0][0]*M[1][1] - M[0][1]*M[1][0]);
  float inv[3][3];
  for (int i = 0; i < 3; i++) {
    for (int j = 0; j < 3; j++) {
      inv[i][j] = adj[i][j] / det;
    }
  }
  a = inv[0][0]*PH[0] + inv[0][1]*PH[1] + inv[0][2]*PH[2];
  b = inv[1][0]*PH[0] + inv[1][1]*PH[1] + inv[1][2]*PH[2];
  c = inv[2][0]*PH[0] + inv[2][1]*PH[1] + inv[2][2]*PH[2];
}

/* ----- Read averaged voltage from the pH probe ----- */
float readVoltage() {
  long total = 0;
  for (int i = 0; i < SAMPLE_COUNT; i++) {
    total += analogRead(PH_PIN);
    delay(10);
  }
  float avgRaw = total / (float)SAMPLE_COUNT;
  // Convert ADC reading (5V reference) to voltage
  return avgRaw * (5.0 / 1023.0);
}

/* ----- Convert voltage to pH using quadratic coefficients ----- */
float voltageToPH(float voltage) {
  return a * sq(voltage) + b * voltage + c;
}

// In setup we will call computeQuadraticFit() (already added below).


// ================= VARIABLES =================
float phValue;
float tdsValue;
float turbidityValue;
float solarVoltage;
float filterHealth = 100.0;

void setup() {
  Serial.begin(9600);
  computeQuadraticFit();

  pinMode(SOLENOID_PIN, OUTPUT);
  pinMode(STATUS_LED_PIN, OUTPUT);

  // Default valve state: open
  digitalWrite(SOLENOID_PIN, HIGH);

  // Initialize I2C LCD Screen
  lcd.init();
  lcd.backlight();
  lcd.clear();

  lcd.setCursor(0, 0);
  lcd.print(" DANUM MONITOR  ");
  lcd.setCursor(0, 1);
  lcd.print("  ARDUINO MEGA  ");
  lcd.setCursor(0, 2);
  lcd.print("Initializing....");
  
  delay(2000);
  lcd.clear();
}

void loop() {
  // ===== READ pH SENSOR (Mega is 10-bit ADC / 5.0V reference) =====
  // Read pH using the new calibration routine
  float voltage = readVoltage();
  phValue = voltageToPH(voltage);
  // Clamp pH to realistic range
  if (phValue < 0.0) phValue = 0.0;
  if (phValue > 14.0) phValue = 14.0;

  // ===== READ TDS SENSOR =====
  int tdsRaw = analogRead(TDS_PIN);
  float voltageTDS = tdsRaw * (5.0 / 1023.0);
  tdsValue = (133.42 * voltageTDS * voltageTDS * voltageTDS
             - 255.86 * voltageTDS * voltageTDS
             + 857.39 * voltageTDS) * 0.5;
  if (tdsValue < 0.0) tdsValue = 0.0;

  // ===== READ TURBIDITY SENSOR =====
  int turbidityRaw = analogRead(TURBIDITY_PIN);
  float voltageTurbidity = turbidityRaw * (5.0 / 1023.0);
  turbidityValue = map(turbidityRaw, 0, 750, 3000, 0);
  if (turbidityValue < 0) turbidityValue = 0;

  // ===== READ SOLAR VOLTAGE =====
  int solarRaw = analogRead(SOLAR_PIN);
  float adcVoltage = solarRaw * (5.0 / 1023.0);
  solarVoltage = adcVoltage * 11.0; // Restores 100k/10k divider calculation
  if (solarVoltage < 0.1) solarVoltage = 13.4; // Simulation fallback if disconnected

  // ===== FILTER HEALTH DECAY =====
  filterHealth -= 0.002;
  if (filterHealth < 0) filterHealth = 0.0;

  // ===== SAFETY CONTROL (PNSDW Standards) =====
  // Safe thresholds: pH [6.5 - 8.5], TDS <= 600 ppm, Turbidity <= 5 NTU
  bool isSafe = (phValue >= 6.5 && phValue <= 8.5) && (tdsValue <= 600.0) && (turbidityValue <= 5.0);
  
  if (!isSafe) {
    digitalWrite(SOLENOID_PIN, LOW); // Safe Shutoff: Close solenoid valve
    digitalWrite(STATUS_LED_PIN, LOW);
  } else {
    digitalWrite(SOLENOID_PIN, HIGH); // Open solenoid valve
    digitalWrite(STATUS_LED_PIN, HIGH);
  }

  // ===== SERIAL MONITOR =====
  Serial.print("pH: ");
  Serial.print(phValue, 2);
  Serial.print(" | TDS: ");
  Serial.print(tdsValue, 0);
  Serial.print(" ppm");
  Serial.print(" | Turbidity: ");
  Serial.print(turbidityValue, 0);
  Serial.print(" NTU | Valve: ");
  Serial.println(isSafe ? "OPEN (SAFE)" : "CLOSED (DANGER)");

  // ===== LCD DISPLAY (16x4 Dashboard) =====
  // Line 0: pH and TDS (exactly 16 chars)
  lcd.setCursor(0, 0);
  lcd.print("pH:");
  lcd.print(phValue, 2);
  lcd.print("  TDS:");
  lcd.print((int)tdsValue);
  lcd.print("    "); // Overwrites old digits

  // Line 1: Turbidity (exactly 16 chars)
  lcd.setCursor(0, 1);
  lcd.print("TURB:");
  lcd.print((int)turbidityValue);
  lcd.print(" NTU      ");

  // Line 2: Solar Power & Filter (exactly 16 chars)
  lcd.setCursor(0, 2);
  lcd.print("SOLR:");
  lcd.print(solarVoltage, 1);
  lcd.print("V F:");
  lcd.print((int)filterHealth);
  lcd.print("%   ");

  // Line 3: Solenoid and Safety Status (exactly 16 chars)
  lcd.setCursor(0, 3);
  lcd.print("VLV:");
  lcd.print(isSafe ? "OPEN" : "CLSD");
  lcd.print(" SYS:");
  lcd.print(isSafe ? "SAFE  " : "DANG  ");

  delay(1000);
}