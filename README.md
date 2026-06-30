# Core Motion ESP32 Controller (WatchOS + ESP32)

This repository contains a WatchOS application and an ESP32 firmware project designed to control an ESP32-connected LED via wrist gestures or a manual testing user interface using UDP packages over a local network.

---

## 📁 Repository Structure

* **`core-motion-test Watch App/`**: WatchOS app built with SwiftUI and Swift Network framework.
  * Contains the music player UI and gesture helper routines.
  * Includes a dedicated **ESP32 Test Panel** tab for manual verification.
* **`hardware/`**: Contains the Arduino/C++ source code (`core-motion-test.ino`) for the ESP32.
  * Listens on UDP Port `8080` for incoming commands and blinks the onboard LED on GPIO 2.

---

## ⚡ Gesture / Command Mapping

When a gesture is triggered or a button is pressed in the Test Panel, a corresponding UDP string command is sent to the ESP32:

| Gesture / Trigger | UDP Command | LED Pattern | Description |
|---|---|---|---|
| **Single Pinch** | `NEXT` | 1 Quick Blink | Switches to the next song |
| **Double Pinch** | `PREV` | 2 Quick Blinks | Switches to the previous song |
| **Clench** (Fist) | `PLAY` / `PAUSE` | 1 Long Blink (600ms) | Play/pause toggle |
| **Roll Right** | `VOL:<N>` (Volume Increase) | 3 Rapid Blinks | Increases system volume |
| **Roll Left** | `VOL:<N>` (Volume Decrease) | 3 Slow Blinks | Decreases system volume |
| **Test Panel Button** | `LED_ON` | Persistent ON | Turns on the onboard LED |
| **Test Panel Button** | `LED_OFF` | Persistent OFF | Turns off the onboard LED |

---

## 🛠️ Setup Instructions

### 1. ESP32 (Hardware Setup)
1. Open `hardware/core-motion-test.ino` in the Arduino IDE.
2. Ensure you have the **ESP32** board package installed.
3. Modify the WiFi credentials configuration section:
   ```cpp
   const char* WIFI_SSID     = "Mobile";
   const char* WIFI_PASSWORD = "00000000";
   ```
4. Flash the sketch to your ESP32.
5. Open the Serial Monitor at `115200` baud.
6. Copy the **IP Address** printed on the serial output (e.g., `192.168.233.10`).

### 2. WatchOS App Setup
1. Open the Xcode project `core-motion-test.xcodeproj`.
2. Open `core-motion-test Watch App/ESPController.swift`.
3. Update the target IP address to match your ESP32's IP:
   ```swift
   private let espHost = "192.168.233.10" // <-- Update with ESP32 IP
   ```
4. Build and run the app on your Apple Watch or Watch Simulator.
5. Swipe down from the Player interface to open the **ESP32 Test Panel** to check network logs and test LED toggles.

---

## ⚠️ Current Challenges & Troubleshooting

During testing and development, several OS-level and networking hurdles were identified:

### 1. Local Network Permission (WatchOS 10+)
* **Symptom:** UDP packages fail silently without any console errors.
* **Resolution:** Apple requires `NSLocalNetworkUsageDescription` in the App's build configuration. Without this description, the OS refuses socket connections to private subnets. We configured Xcode to inject this key into the generated target's plist.

### 2. Apple Watch Network Routing (NECP Policy / Bluetooth Proxy)
* **Symptom:** The simulator transmits UDP packets successfully (showing `✅ Network OK | Eth`), but the real Apple Watch errors out with `Path was denied by NECP policy` or `Network is down` (showing `❌ No network | Other`).
* **Root Cause:** By default, watchOS routes all outbound internet requests through the paired iPhone via a Bluetooth bridge (`ipsec1` tunnel) to conserve battery. Because this tunnel isolates local subnets, private UDP packets to your ESP32 IP are blocked.
* **Resolution:** 
  1. The Watch must directly connect to the local WiFi interface.
  2. In your watch's settings, turn on **Wi-Fi** and connect directly to the hotspot/router WiFi (e.g., `Mobile`).
  3. If routing issues persist, temporarily disable Bluetooth on the paired iPhone to force the Apple Watch to use its dedicated WiFi radio.

### 3. ESP32 Wi-Fi Compatibility
* **Symptom:** ESP32 fails to connect to the network.
* **Root Cause:** The ESP32's network chip only supports **2.4 GHz** Wi-Fi bands. It cannot discover or connect to 5 GHz bands.
* **Resolution:** Ensure your router or mobile hotspot is operating on the **2.4 GHz band** with **WPA2** security enabled.
