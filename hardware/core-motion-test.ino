/*
  esp32_led_blink.ino
  ───────────────────
  Receives UDP commands from the WatchOS app and blinks
  the onboard LED in a distinct pattern for each gesture.

  Gesture → Command → LED pattern
  ────────────────────────────────
  Pinch          NEXT    1 quick blink
  Double pinch   PREV    2 quick blinks
  Clench         PLAY    1 long blink
  Clench         PAUSE   1 long blink (same, toggle on watch side)
  Roll right     VOL:N   3 rapid blinks
  Roll left      VOL:N   3 slow blinks
  LED_ON / LED_OFF       Persistent on/off

  Wiring
  ──────
  Most ESP32 devboards have an onboard LED on GPIO 2.
  If yours is different, change LED_PIN below.
  No extra wiring needed.

  Setup
  ─────
  1. Set your WiFi credentials in WIFI_SSID / WIFI_PASSWORD.
  2. Flash to ESP32 via Arduino IDE (board: "ESP32 Dev Module").
  3. Open Serial Monitor at 115200 baud.
  4. Note the IP address printed on boot — put it in ContentView.swift:
       private let espHost = "<that IP>"
  5. Run the WatchOS app and trigger gestures. Watch the LED.
*/

#include <WiFi.h>
#include <WiFiUdp.h>

// ── Config ──────────────────────────────────────────────
const char* WIFI_SSID     = "Mobile";
const char* WIFI_PASSWORD = "00000000";
const uint16_t UDP_PORT   = 8080;
const uint8_t  LED_PIN    = 2;   // onboard LED; change if needed
// ────────────────────────────────────────────────────────

WiFiUDP udp;
char packetBuf[64];

// Track last known volume to detect roll direction
int lastVolume = 65;

// Uptime & packet counters for debugging
unsigned long packetCount = 0;
unsigned long lastHeartbeat = 0;
const unsigned long HEARTBEAT_INTERVAL = 5000; // print status every 5s

void setup() {
  Serial.begin(115200);
  delay(500); // give serial monitor time to connect
  
  Serial.println();
  Serial.println("════════════════════════════════════════");
  Serial.println("  ESP32 LED Controller — DEBUG MODE");
  Serial.println("════════════════════════════════════════");
  
  // LED pin setup
  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, LOW);
  Serial.printf("[BOOT] LED_PIN = GPIO %d, set to OUTPUT, initial LOW\n", LED_PIN);

  // ── WiFi Connection ───────────────────────────────────
  Serial.printf("[WIFI] Connecting to SSID: \"%s\" ...\n", WIFI_SSID);
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    attempts++;
    Serial.printf("[WIFI] Attempt %d ... (status: %d)\n", attempts, WiFi.status());
    
    if (attempts > 30) { // 15 seconds timeout
      Serial.println("[WIFI] ❌ FAILED to connect after 15 seconds!");
      Serial.println("[WIFI] Check SSID/password. Restarting in 5s...");
      delay(5000);
      ESP.restart();
    }
  }
  
  Serial.println("[WIFI] ✅ Connected!");
  Serial.printf("[WIFI] IP Address : %s\n", WiFi.localIP().toString().c_str());
  Serial.printf("[WIFI] Subnet Mask: %s\n", WiFi.subnetMask().toString().c_str());
  Serial.printf("[WIFI] Gateway    : %s\n", WiFi.gatewayIP().toString().c_str());
  Serial.printf("[WIFI] MAC Address: %s\n", WiFi.macAddress().c_str());
  Serial.printf("[WIFI] RSSI       : %d dBm\n", WiFi.RSSI());

  // ── UDP Setup ─────────────────────────────────────────
  udp.begin(UDP_PORT);
  Serial.printf("[UDP]  ✅ Listening on port %d\n", UDP_PORT);
  
  Serial.println();
  Serial.println("────────────────────────────────────────");
  Serial.printf("  READY — Send UDP to %s:%d\n", WiFi.localIP().toString().c_str(), UDP_PORT);
  Serial.println("────────────────────────────────────────");
  Serial.println("[BOOT] Blinking 3x to confirm boot...");
  Serial.println();

  // Boot confirmation: 3 fast blinks
  blinkN(3, 80, 80);
  
  lastHeartbeat = millis();
}

void loop() {
  // ── Heartbeat: print alive status every 5 seconds ─────
  if (millis() - lastHeartbeat >= HEARTBEAT_INTERVAL) {
    lastHeartbeat = millis();
    Serial.printf("[HEARTBEAT] Uptime: %lus | Packets received: %lu | WiFi RSSI: %d dBm | WiFi status: %s\n",
                  millis() / 1000,
                  packetCount,
                  WiFi.RSSI(),
                  WiFi.status() == WL_CONNECTED ? "CONNECTED" : "DISCONNECTED");
    
    // Auto-reconnect if WiFi dropped
    if (WiFi.status() != WL_CONNECTED) {
      Serial.println("[WIFI] ⚠️  WiFi disconnected! Reconnecting...");
      WiFi.disconnect();
      WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
      int retries = 0;
      while (WiFi.status() != WL_CONNECTED && retries < 20) {
        delay(500);
        retries++;
        Serial.printf("[WIFI] Reconnect attempt %d...\n", retries);
      }
      if (WiFi.status() == WL_CONNECTED) {
        Serial.printf("[WIFI] ✅ Reconnected! IP: %s\n", WiFi.localIP().toString().c_str());
        udp.begin(UDP_PORT);
      } else {
        Serial.println("[WIFI] ❌ Reconnect failed. Will retry next heartbeat.");
      }
    }
  }
  
  // ── Check for incoming UDP packets ────────────────────
  int packetSize = udp.parsePacket();
  if (packetSize > 0) {
    packetCount++;
    
    // Log sender info
    IPAddress remoteIP = udp.remoteIP();
    uint16_t remotePort = udp.remotePort();
    
    Serial.println("┌──────────────────────────────────────");
    Serial.printf("│ [UDP RX] Packet #%lu\n", packetCount);
    Serial.printf("│ [UDP RX] From: %s:%d\n", remoteIP.toString().c_str(), remotePort);
    Serial.printf("│ [UDP RX] Size: %d bytes\n", packetSize);
    
    int len = udp.read(packetBuf, sizeof(packetBuf) - 1);
    if (len > 0) {
      packetBuf[len] = '\0';
      String cmd = String(packetBuf);
      cmd.trim();
      
      // Print raw bytes for debugging encoding issues
      Serial.printf("│ [UDP RX] Raw bytes: ");
      for (int i = 0; i < len; i++) {
        Serial.printf("0x%02X ", (uint8_t)packetBuf[i]);
      }
      Serial.println();
      Serial.printf("│ [UDP RX] Command: \"%s\" (len=%d)\n", cmd.c_str(), cmd.length());
      Serial.println("└──────────────────────────────────────");
      
      handleCommand(cmd);
    } else {
      Serial.println("│ [UDP RX] ⚠️  Read returned 0 bytes!");
      Serial.println("└──────────────────────────────────────");
    }
  }
}

// ── Command dispatcher ───────────────────────────────────

void handleCommand(const String& cmd) {
  unsigned long startMs = millis();
  
  if (cmd == "NEXT") {
    Serial.println("[CMD] ▶ NEXT — 1 quick blink (120ms on)");
    blinkN(1, 120, 0);

  } else if (cmd == "PREV") {
    Serial.println("[CMD] ◀ PREV — 2 quick blinks (120ms on, 100ms gap)");
    blinkN(2, 120, 100);

  } else if (cmd == "PLAY") {
    Serial.println("[CMD] ▶ PLAY — 1 long blink (600ms)");
    blinkLong(600);

  } else if (cmd == "PAUSE") {
    Serial.println("[CMD] ⏸ PAUSE — 1 long blink (600ms)");
    blinkLong(600);

  } else if (cmd.startsWith("VOL:")) {
    int newVol = cmd.substring(4).toInt();
    bool rolledRight = newVol > lastVolume;
    Serial.printf("[CMD] 🔊 VOL — %d%% → %d%% (%s)\n", lastVolume, newVol, rolledRight ? "UP/right" : "DOWN/left");
    lastVolume = newVol;
    if (rolledRight) {
      Serial.println("[CMD]   Pattern: 3 rapid blinks (60ms on, 60ms gap)");
      blinkN(3, 60, 60);    // rapid: roll right
    } else {
      Serial.println("[CMD]   Pattern: 3 slow blinks (60ms on, 220ms gap)");
      blinkN(3, 60, 220);   // slow gap: roll left
    }

  } else if (cmd == "LED_ON") {
    Serial.println("[CMD] 💡 LED_ON — Setting GPIO HIGH (persistent)");
    digitalWrite(LED_PIN, HIGH);
    Serial.printf("[CMD]   LED state: %s\n", digitalRead(LED_PIN) ? "ON ✅" : "OFF ❌ (PROBLEM!)");

  } else if (cmd == "LED_OFF") {
    Serial.println("[CMD] 🔲 LED_OFF — Setting GPIO LOW");
    digitalWrite(LED_PIN, LOW);
    Serial.printf("[CMD]   LED state: %s\n", digitalRead(LED_PIN) ? "ON ❌ (PROBLEM!)" : "OFF ✅");

  } else {
    Serial.printf("[CMD] ❓ UNKNOWN command: \"%s\"\n", cmd.c_str());
    Serial.printf("[CMD]   Hex dump: ");
    for (unsigned int i = 0; i < cmd.length(); i++) {
      Serial.printf("0x%02X ", (uint8_t)cmd[i]);
    }
    Serial.println();
  }
  
  unsigned long elapsed = millis() - startMs;
  Serial.printf("[CMD] ⏱ Command processed in %lums\n\n", elapsed);
}

// ── LED helpers ──────────────────────────────────────────

// Blink n times with onMs on-time and offMs gap between blinks
void blinkN(int n, int onMs, int offMs) {
  Serial.printf("[LED] Blinking %dx (on=%dms, off=%dms)\n", n, onMs, offMs);
  for (int i = 0; i < n; i++) {
    Serial.printf("[LED]   Blink %d/%d — HIGH\n", i + 1, n);
    digitalWrite(LED_PIN, HIGH);
    delay(onMs);
    digitalWrite(LED_PIN, LOW);
    if (i < n - 1) delay(offMs);
  }
  Serial.println("[LED]   Done — LOW");
}

// Single long blink
void blinkLong(int durationMs) {
  Serial.printf("[LED] Long blink (%dms) — HIGH\n", durationMs);
  digitalWrite(LED_PIN, HIGH);
  delay(durationMs);
  digitalWrite(LED_PIN, LOW);
  Serial.println("[LED]   Done — LOW");
}
