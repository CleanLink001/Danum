"""
Danum Water Quality System - PC USB to MySQL Serial Gateway
----------------------------------------------------------
This script bridges the Arduino Mega (connected via USB) to the local XAMPP MySQL database.
It reads the serial output from the Mega, parses the pH and simulated values, POSTs them
to save_sensor_data.php, and writes back the target valve control commands to the Mega.

Dependencies:
    pip install pyserial requests

Usage:
    1. Ensure XAMPP (Apache and MySQL) is running.
    2. Upload the 'danum_mega_lcd.ino' sketch to your Arduino Mega.
    3. Keep the Arduino plugged into your PC via USB.
    4. Close the Arduino IDE Serial Monitor (only one program can open the COM port at a time).
    5. Run this script: python serial_gateway.py
"""

import sys
import json
import time
import glob

# Try importing dependencies and print friendly installation advice if missing
try:
    import serial
    import requests
except ImportError:
    print("\n[ERROR] Missing required Python libraries!")
    print("Please install them by running this command in your terminal/cmd:")
    print("    pip install pyserial requests\n")
    sys.exit(1)

# ==========================================
# 1. GATEWAY CONFIGURATION
# ==========================================
# Target API URL (Localhost XAMPP)
API_URL = "http://127.0.0.1/danum/api/save_sensor_data.php"

# Serial baud rate must match Mega's Serial.begin(115200)
BAUD_RATE = 115200

def list_ports():
    """Lists available serial ports on the system."""
    if sys.platform.startswith('win'):
        ports = ['COM%s' % (i + 1) for i in range(256)]
    elif sys.platform.startswith('linux') or sys.platform.startswith('cygwin'):
        ports = glob.glob('/dev/tty[A-Za-z]*')
    elif sys.platform.startswith('darwin'):
        ports = glob.glob('/dev/tty.*')
    else:
        raise EnvironmentError('Unsupported platform')

    results = []
    for port in ports:
        try:
            s = serial.Serial(port)
            s.close()
            results.append(port)
        except Exception:
            pass
    return results

def find_arduino_port():
    """Detects and returns the best candidate for the Arduino COM port."""
    ports = list_ports()
    if not ports:
        return None
    
    print("\nAvailable Serial COM Ports found:")
    for i, port in enumerate(ports):
        print(f" [{i}] {port}")
    
    # Return the first available port by default, or ask user if multiple
    return ports[0]

def main():
    print("=========================================================")
    print("        DANUM WATER MONITOR - USB SERIAL GATEWAY        ")
    print("=========================================================")
    
    arduino_port = find_arduino_port()
    if not arduino_port:
        print("\n[ERROR] No active COM ports found! Is the Arduino Mega plugged in?")
        print("Please check your USB cable connection and try again.")
        input("\nPress Enter to exit...")
        sys.exit(1)
        
    print(f"\n[INFO] Attempting connection on auto-detected port: {arduino_port}")
    print(f"[INFO] Backend API target URL: {API_URL}")
    print("[INFO] Press Ctrl+C at any time to stop this gateway.")
    print("---------------------------------------------------------")
    
    try:
        # Open serial connection (timeout 2s to prevent blocking indefinitely)
        ser = serial.Serial(port=arduino_port, baudrate=BAUD_RATE, timeout=2.0)
        time.sleep(2) # Wait 2 seconds for Arduino Mega to auto-reset after opening connection
        print("[SUCCESS] USB serial connection established. Listening for data...\n")
        
        while True:
            if ser.in_waiting > 0:
                try:
                    # Read line from Arduino
                    line = ser.readline().decode('utf-8', errors='ignore').strip()
                    
                    # Ensure it is a JSON line (starts with { and ends with })
                    if line.startswith('{') and line.endswith('}'):
                        print(f"<- [ARDUINO DATA]: {line}")
                        
                        # Validate JSON parsing
                        sensor_payload = json.loads(line)
                        
                        # POST the JSON data directly to our PHP API
                        headers = {'Content-Type': 'application/json'}
                        start_time = time.time()
                        response = requests.post(API_URL, json=sensor_payload, headers=headers, timeout=5.0)
                        latency = (time.time() - start_time) * 1000
                        
                        if response.status_code == 200:
                            api_response = response.json()
                            print(f"-> [PHP API SUCCESS] Code 200 | Latency: {latency:.1f}ms")
                            print(f"   [DB RESPONSE]: {response.text}")
                            
                            # Extract valve state target from PHP response
                            if "valve_state" in api_response:
                                target_state = api_response["valve_state"] # 1 or 0
                                
                                # Package serial command to send back to Arduino Mega
                                command = {"valve_state": target_state}
                                command_str = json.dumps(command) + "\n"
                                
                                # Send to Arduino Mega via USB
                                ser.write(command_str.encode('utf-8'))
                                print(f"-> [SENT TO ARDUINO]: {command_str.strip()}")
                        else:
                            print(f"[WARNING] API POST failed with HTTP Status: {response.status_code}")
                            
                        print("-" * 55)
                        
                except json.JSONDecodeError:
                    # Ignore lines that aren't valid JSON (e.g. boot debug messages)
                    pass
                except requests.exceptions.RequestException as req_err:
                    print(f"[API ERROR] Failed to connect to XAMPP server: {req_err}")
                    print("Make sure Apache and MySQL are running inside XAMPP panel!")
                    print("-" * 55)
                except Exception as loop_err:
                    print(f"[LOOP ERROR] {loop_err}")
                    print("-" * 55)
            
            time.sleep(0.05) # Prevent high CPU utilization
            
    except serial.SerialException as serial_err:
        print(f"\n[ERROR] Port serial error: {serial_err}")
        print("Is the Arduino IDE Serial Monitor open? If yes, close it so this gateway can take control.")
    except KeyboardInterrupt:
        print("\n[INFO] Serial Gateway stopped by user. Goodbye!")
    finally:
        if 'ser' in locals() and ser.is_open:
            ser.close()
            print("[INFO] Serial Port closed safely.")

if __name__ == "__main__":
    main()
