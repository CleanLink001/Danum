# ESP32 Water Quality Monitor - System Schematic & Wiring Guide

This guide details the complete system design, hardware pinouts, and electrical schematics when upgrading your project from the Arduino Mega to the **ESP32** microcontroller.

---

## 1. System Schematic (Block Diagram)

```mermaid
graph TD
    %% Microcontroller
    ESP[ESP32 Development Board]
    
    %% Power Source
    USB[USB Power / 5V USB] -->|Provides 5V| ESP
    
    %% Power Rails
    V5_Rail[5V Power Rail]
    GND_Rail[GND Rail]
    
    ESP -->|VIN Pin| V5_Rail
    ESP -->|GND Pin| GND_Rail
    
    %% Analog Sensors
    subgraph Sensors  
        PH[pH Sensor Module]
        TDS[TDS Sensor Module]
        TURB[Turbidity Sensor Module]
    end
    
    V5_Rail -.->|5V Power| PH
    V5_Rail -.->|5V Power| TDS
    V5_Rail -.->|5V Power| TURB
    
    GND_Rail -.->|GND| PH
    GND_Rail -.->|GND| TDS
    GND_Rail -.->|GND| TURB
    
    %% Voltage Dividers (Level Shifting 5V -> 3.3V)
    subgraph Voltage Dividers
        VD1[pH Voltage Divider]
        VD2[TDS Voltage Divider]
        VD3[Turbidity Divider]
    end
    
    PH -->|5V Analog Out| VD1
    TDS -->|5V Analog Out| VD2
    TURB -->|5V Analog Out| VD3
    
    VD1 -->|Safe 0-3.3V Out| ESP34[ESP32 GPIO 34 - ADC1_CH6]
    VD2 -->|Safe 0-3.3V Out| ESP35[ESP32 GPIO 35 - ADC1_CH7]
    VD3 -->|Safe 0-3.3V Out| ESP32[ESP32 GPIO 32 - ADC1_CH4]
    
    %% Actuators & Indicators
    subgraph Outputs
        SOL[Solenoid Valve Relay]
        BUZZ[Active Buzzer (3-24V DC)]
        R_LED[Status LED]
    end
    
    ESP -->|GPIO 25| SOL
    ESP -->|GPIO 26| BUZZ
    ESP -->|GPIO 27| R_LED
    GND_Rail -.->|GND| SOL
    GND_Rail -.->|GND| BUZZ
    GND_Rail -.->|GND via Resistor| R_LED
```

---

## 2. Master Pin Mapping Table

| Component | Pin Label | ESP32 GPIO Pin | Mode | Description / Notes |
| :--- | :--- | :--- | :--- | :--- |
| **pH Sensor** | **Analog Out** | **GPIO 34** | Analog Input | **ADC1_CH6** (Input Only pin, highly stable) |
| **TDS Sensor** | **Analog Out** | **GPIO 35** | Analog Input | **ADC1_CH7** (Input Only pin, highly stable) |
| **Turbidity Sensor** | **Analog Out** | **GPIO 32** | Analog Input | **ADC1_CH4** (ADC1 Pin) |
| | | | | |
| **Solenoid Valve Relay** | **IN / SIG** | **GPIO 25** | Digital Output | Control water inflow (Active LOW relay: LOW = Open, HIGH = Close) |
| **Active Piezo Buzzer** | **RED (+) Wire** | **GPIO 26** | Digital Output | Sound alarm every 3 seconds when water is dirty/unsafe |
| **Active Piezo Buzzer** | **BLACK (-) Wire**| **GND** | Ground | Common system ground |
| **Status LED** | **Anode (+)** | **GPIO 27** | Digital Output | Optional status LED (with 220Ω resistor) |

---

## 3. Crucial Hardware Notes & Warnings

> [!WARNING]
> ### 1. The 5V Sensor to 3.3V ESP32 Pin Danger (Must Read!)
> Most analog water sensors (pH, TDS, Turbidity) run on **5.0V** and output a **0V to 5V** signal.
> The ESP32 is a **3.3V microcontroller**. Connecting a 5V signal directly to an ESP32 pin **will permanently fry that pin or the entire chip!**
> 
> **Solution: Use a simple Resistor Voltage Divider** for each analog sensor:
> ```text
> Sensor Analog Output (0V - 5.0V)
>          │
>      ┌───┴───┐
>      │ 10k Ω │  (R1 Resistor)
>      └───┬───┘
>          ├───────────────> To ESP32 Pin (Max 3.3V)
>      ┌───┴───┐
>      │ 20k Ω │  (R2 Resistor)
>      └───┬───┘
>          │
>      Common GND
> ```
> *Note: This scales a 5.0V output down to precisely 3.33V ($5V \times \frac{20k}{10k+20k}$), which is perfectly safe for the ESP32.*

> [!IMPORTANT]
> ### 2. The Wi-Fi and ADC2 Conflict
> The ESP32 has two Analog-to-Digital Converter modules: **ADC1** and **ADC2**.
> * **ADC2 pins CANNOT be used when Wi-Fi is active** (the ESP32's Wi-Fi controller overrides ADC2 internally).
> * If you plug your sensors into ADC2 pins, the sensors will stop reading the moment the ESP32 connects to your Wi-Fi network!
> * **Our Solution**: We have selected **GPIO 34, 35, and 32** because they belong to **ADC1**, meaning they will work perfectly even when transmitting data over Wi-Fi.

### 3. LED Current Limiting Resistors
* Never connect the LEDs directly between the ESP32 GPIOs and GND. Always place a **220 Ohm (or 330 Ohm) resistor** in series with the LED to prevent burning out the ESP32 output pins.
