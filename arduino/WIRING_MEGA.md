# Arduino Mega - Water Quality Monitor Wiring & Calibration Guide

This guide details how to wire your **Arduino Mega**, **Analog pH Sensor**, **LCD Screen (I2C or Parallel)**, and **Breadboard** together. 

---

## 1. Wiring the pH Sensor Module

Most analog pH sensor boards (like the Gravity pH meter module or generic BNC-to-Analog modules) have 3 pins on their adapter board:

| pH Board Pin | Arduino Mega Pin | Description | Wire Color (Rec.) |
| :--- | :--- | :--- | :--- |
| **VCC / +** | **5V** | Power supply (5V) | Red |
| **GND / -** | **GND** | Ground reference | Black |
| **AOUT / A / S** | **A0** | Analog output signal | Blue or Yellow |

### Breadboard Setup:
1. Connect the Arduino Mega **5V** pin to the **positive (+) power rail** of your breadboard.
2. Connect the Arduino Mega **GND** pin to the **negative (-) ground rail** of your breadboard.
3. Connect the pH sensor board **VCC** pin to the breadboard positive rail.
4. Connect the pH sensor board **GND** pin to the breadboard negative rail.
5. Connect the pH sensor board **AOUT (Signal)** pin directly to the Arduino Mega **A0** pin.

---

## 2. Wiring the LCD Screen (Choose Your Screen Type)

### Option A: I2C LCD Display (Highly Recommended - Only 4 Wires)
If your LCD has a black backpack board attached to the back (with only 4 pins: GND, VCC, SDA, SCL), follow these connections:

| I2C LCD Pin | Arduino Mega Pin | Wire Color (Rec.) |
| :--- | :--- | :--- |
| **GND** | **GND** (Breadboard Negative Rail) | Black |
| **VCC** | **5V** (Breadboard Positive Rail) | Red |
| **SDA** | **Digital Pin 20 (SDA)** | Green or Orange |
| **SCL** | **Digital Pin 21 (SCL)** | Yellow |

*Note: On the Arduino Mega 2560, hardware I2C pins are strictly Digital 20 (SDA) and Digital 21 (SCL). Do not connect them to A4/A5 (which is for Uno).*

---

### Option B: Standard Parallel 16x2 LCD Display (16 Pins)
If your LCD does not have an I2C backpack and has a row of 16 pins, wire it using your breadboard and a 10K Ohm Potentiometer (for screen contrast control) as follows:

| LCD Pin | Label | Connection |
| :--- | :--- | :--- |
| **Pin 1** | VSS | Connect to **GND** (Negative Rail) |
| **Pin 2** | VDD | Connect to **5V** (Positive Rail) |
| **Pin 3** | V0 | Connect to the **Center pin** of the 10K Potentiometer |
| **Pin 4** | RS | Connect to Arduino Mega **Digital Pin 12** |
| **Pin 5** | R/W | Connect to **GND** (Negative Rail) |
| **Pin 6** | E | Connect to Arduino Mega **Digital Pin 11** |
| **Pins 7-10** | D0-D3 | Leave Disconnected |
| **Pin 11** | D4 | Connect to Arduino Mega **Digital Pin 5** |
| **Pin 12** | D5 | Connect to Arduino Mega **Digital Pin 4** |
| **Pin 13** | D6 | Connect to Arduino Mega **Digital Pin 3** |
| **Pin 14** | D7 | Connect to Arduino Mega **Digital Pin 2** |
| **Pin 15** | A (Anode) | Connect to **5V** (Positive Rail) *via a 220-ohm resistor* |
| **Pin 16** | K (Cathode) | Connect to **GND** (Negative Rail) |

#### Potentiometer Wiring (for Option B Contrast):
- **Left Pin**: Connect to **5V** (Positive Rail)
- **Right Pin**: Connect to **GND** (Negative Rail)
- **Center Pin**: Connect to **V0 (Pin 3)** of the LCD. (Turn this knob to adjust character visibility!)

---

## 3. Wiring a Solenoid Valve Control Relay (Optional)

If you have a Relay Module to control your water valve, connect it like this:

| Relay Module Pin | Arduino Mega Pin | Description |
| :--- | :--- | :--- |
| **VCC** | **5V** (Positive Rail) | Power |
| **GND** | **GND** (Negative Rail) | Ground |
| **IN / SIG** | **Digital Pin 8** | Control signal from Arduino |

---

## 4. pH Calibration Procedure

For accurate readings, you should calibrate the probe:

1. **Upload the Code**: First, upload the provided sketch to your Arduino Mega.
2. **Open Serial Monitor**: Open the Arduino IDE Serial Monitor (set to `115200` baud rate).
3. **Rinse the Probe**: Rinse the pH electrode with distilled water and dry it gently with a clean tissue.
4. **pH 7.00 Calibration (Offset)**:
   - Submerge the probe in a **pH 7.00 buffer solution**.
   - Let the temperature and voltage stabilize for 1-2 minutes.
   - Note the voltage printed on the Serial Monitor (e.g., `2.50V`).
   - If the voltage is not exactly `2.50V`, adjust the potentiometer on the pH module using a small screwdriver until the analog voltage reads close to `2.50V` (or adjust the `OFFSET` value in the Arduino sketch).
5. **pH 4.01 Calibration (Slope)**:
   - Rinse the probe with distilled water again.
   - Submerge it in a **pH 4.01 buffer solution**.
   - Note the stabilized voltage (e.g., `3.05V`).
   - The default slope equation maps the voltage difference to pH. If you want high precision, you can update the math in the sketch:
     $$\text{Slope} = \frac{7.00 - 4.01}{\text{Voltage at pH 7} - \text{Voltage at pH 4}}$$
