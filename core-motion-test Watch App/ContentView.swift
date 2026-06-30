import SwiftUI
import WatchKit
import CoreMotion
import Combine

// MARK: - ESP Speaker Controller via BLE/WiFi
// Replace ESPController with your actual transport (BLE, UDP, MQTT, etc.)

struct ContentView: View {
    @StateObject private var playerState = PlayerState()
    @StateObject private var gestureHandler = GestureHandler()
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // ━━━ Tab 1: Player UI ━━━━━━━━━━━━━━━━━━━━━━━━━━━━
            playerView
                .tag(0)

            // ━━━ Tab 2: Test Panel ━━━━━━━━━━━━━━━━━━━━━━━━━━━
            testPanelView
                .tag(1)
        }
        .tabViewStyle(.verticalPage)
        .onAppear {
            gestureHandler.startDetection()
        }
        .onDisappear {
            gestureHandler.stopDetection()
        }
    }

    // MARK: - Player View (original UI)

    private var playerView: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 8) {
                // Gesture feedback badge
                if !gestureHandler.feedbackLabel.isEmpty {
                    Text(gestureHandler.feedbackLabel)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.white.opacity(0.12), in: Capsule())
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.85).combined(with: .opacity),
                            removal: .opacity
                        ))
                }

                // Album art placeholder
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(white: 0.12))
                    .frame(width: 76, height: 76)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: 28))
                            .foregroundColor(.white.opacity(0.5))
                    )

                // Song info
                VStack(spacing: 2) {
                    Text(playerState.currentSong)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(playerState.currentArtist)
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.2)).frame(height: 3)
                        Capsule()
                            .fill(Color.white)
                            .frame(width: geo.size.width * playerState.progress, height: 3)
                    }
                }
                .frame(height: 3)

                // Volume row
                HStack(spacing: 6) {
                    Image(systemName: "speaker.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.2)).frame(height: 2)
                            Capsule()
                                .fill(Color.white)
                                .frame(width: geo.size.width * playerState.volume, height: 2)
                        }
                    }
                    .frame(height: 2)
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }

                // Swipe hint
                HStack(spacing: 4) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8))
                    Text("Swipe down for test panel")
                        .font(.system(size: 9))
                }
                .foregroundColor(.white.opacity(0.3))
                .padding(.top, 2)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        // ─── Gesture Recognizers ───────────────────────────────
        .handGestureShortcut(.primaryAction)
        .onReceive(gestureHandler.$detectedGesture) { gesture in
            handleGesture(gesture)
        }
        .focusable()
        .digitalCrownRotation(
            $playerState.crownValue,
            from: 0.0,
            through: 1.0,
            by: 0.05,
            sensitivity: .medium,
            isContinuous: false,
            isHapticFeedbackEnabled: true
        )
        .onChange(of: playerState.crownValue) { _, newValue in
            handleCrownChange(newValue)
        }
    }

    // MARK: - Test Panel View

    private var testPanelView: some View {
        ScrollView {
            VStack(spacing: 6) {
                // Header
                HStack(spacing: 4) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 12))
                        .foregroundColor(.cyan)
                    Text("ESP32 Test Panel")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(.bottom, 2)

                // ── Connection Status ─────────────────────────
                VStack(spacing: 3) {
                    Text("Target: 192.168.233.10:8080")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                    Text(ESPController.shared.networkInfo)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.cyan.opacity(0.8))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                    Text(ESPController.shared.lastStatus)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                    Text("Sent: \(ESPController.shared.sendCount)")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.3))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .background(Color.white.opacity(0.06))
                .cornerRadius(8)
                .padding(.bottom, 4)

                // ── Playback Controls ──────────────────────────
                Text("PLAYBACK")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.cyan.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Play / Pause row
                HStack(spacing: 6) {
                    testButton(icon: "play.fill", label: "Play", color: .green) {
                        ESPController.shared.setPlayback(playing: true)
                        playerState.isPlaying = true
                        gestureHandler.showFeedback("▶ Play")
                    }
                    testButton(icon: "pause.fill", label: "Pause", color: .orange) {
                        ESPController.shared.setPlayback(playing: false)
                        playerState.isPlaying = false
                        gestureHandler.showFeedback("⏸ Pause")
                    }
                }

                // ── Track Controls ────────────────────────────
                Text("TRACKS")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.cyan.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 2)

                HStack(spacing: 6) {
                    testButton(icon: "backward.fill", label: "Prev", color: .purple) {
                        ESPController.shared.previousSong()
                        playerState.previousSong()
                        gestureHandler.showFeedback("⏮ Previous")
                    }
                    testButton(icon: "forward.fill", label: "Next", color: .blue) {
                        ESPController.shared.nextSong()
                        playerState.nextSong()
                        gestureHandler.showFeedback("⏭ Next")
                    }
                }

                // ── Volume Controls ───────────────────────────
                Text("VOLUME")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.cyan.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 2)

                HStack(spacing: 6) {
                    testButton(icon: "speaker.minus.fill", label: "Vol −", color: .pink) {
                        playerState.volume = max(0, playerState.volume - 0.1)
                        playerState.crownValue = playerState.volume
                        let vol = Int(playerState.volume * 100)
                        ESPController.shared.setVolume(vol)
                        gestureHandler.showFeedback("🔉 Vol \(vol)%")
                    }
                    testButton(icon: "speaker.plus.fill", label: "Vol +", color: .mint) {
                        playerState.volume = min(1, playerState.volume + 0.1)
                        playerState.crownValue = playerState.volume
                        let vol = Int(playerState.volume * 100)
                        ESPController.shared.setVolume(vol)
                        gestureHandler.showFeedback("🔊 Vol \(vol)%")
                    }
                }

                // Volume percentage display
                Text("Volume: \(Int(playerState.volume * 100))%")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.5))

                // ── Direct LED Control ────────────────────────
                Text("LED TOGGLE")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.yellow.opacity(0.8))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 2)

                HStack(spacing: 6) {
                    testButton(icon: "lightbulb.fill", label: "LED On", color: .yellow) {
                        ESPController.shared.sendRaw("LED_ON")
                        gestureHandler.showFeedback("💡 LED On")
                    }
                    testButton(icon: "lightbulb.slash", label: "LED Off", color: .gray) {
                        ESPController.shared.sendRaw("LED_OFF")
                        gestureHandler.showFeedback("🔲 LED Off")
                    }
                }

                // ── Gesture Feedback ──────────────────────────
                if !gestureHandler.feedbackLabel.isEmpty {
                    Text(gestureHandler.feedbackLabel)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.cyan.opacity(0.2), in: Capsule())
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .background(Color.black)
    }

    // MARK: - Test Button Builder

    private func testButton(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: {
            action()
            WKInterfaceDevice.current().play(.click)
        }) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text(label)
                    .font(.system(size: 9, weight: .medium))
            }
            .foregroundColor(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(color.opacity(0.15))
            .cornerRadius(10)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Gesture Handling

    private func handleGesture(_ gesture: WatchGesture) {
        guard gesture != .none else { return }

        withAnimation(.spring(response: 0.3)) {
            switch gesture {
            case .pinch:
                // Single pinch → next song
                ESPController.shared.nextSong()
                playerState.nextSong()
                gestureHandler.showFeedback("⏭ Next")

            case .doublePinch:
                // Double pinch → previous song
                ESPController.shared.previousSong()
                playerState.previousSong()
                gestureHandler.showFeedback("⏮ Previous")

            case .clench:
                // Clench fist → play / pause
                playerState.isPlaying.toggle()
                ESPController.shared.setPlayback(playing: playerState.isPlaying)
                gestureHandler.showFeedback(playerState.isPlaying ? "▶ Playing" : "⏸ Paused")

            case .none:
                break
            }
        }
        WKInterfaceDevice.current().play(.click)
    }

    private func handleCrownChange(_ newValue: Double) {
        // Digital Crown → volume
        let vol = Int(newValue * 100)
        ESPController.shared.setVolume(vol)
        playerState.volume = newValue
        gestureHandler.showFeedback(newValue > playerState.lastCrownValue
            ? "🔊 Vol \(vol)%"
            : "🔉 Vol \(vol)%")
        playerState.lastCrownValue = newValue
    }
}

// MARK: - Player State

class PlayerState: ObservableObject {
    @Published var currentSong = "Blinding Lights"
    @Published var currentArtist = "The Weeknd"
    @Published var isPlaying = true
    @Published var progress: Double = 0.38
    @Published var volume: Double = 0.65
    @Published var crownValue: Double = 0.65
    var lastCrownValue: Double = 0.65

    private let playlist: [(song: String, artist: String)] = [
        ("Blinding Lights", "The Weeknd"),
        ("As It Was", "Harry Styles"),
        ("Golden Hour", "JVKE"),
        ("Unholy", "Sam Smith"),
        ("Cruel Summer", "Taylor Swift"),
    ]
    private var currentIndex = 0

    func nextSong() {
        currentIndex = (currentIndex + 1) % playlist.count
        updateSongInfo()
    }

    func previousSong() {
        currentIndex = (currentIndex - 1 + playlist.count) % playlist.count
        updateSongInfo()
    }

    private func updateSongInfo() {
        currentSong = playlist[currentIndex].song
        currentArtist = playlist[currentIndex].artist
        progress = 0.0
    }
}

// MARK: - Gesture Detection
// Uses WatchOS 9+ Hand Gesture API (WKExtendedRuntimeSession + CMHandPose / WKGestureRecognizer)

enum WatchGesture: Equatable {
    case none, pinch, doublePinch, clench
}

class GestureHandler: ObservableObject {
    @Published var detectedGesture: WatchGesture = .none
    @Published var feedbackLabel: String = ""

    private var feedbackTimer: Timer?
    private var lastPinchTime: Date?
    private let doublePinchInterval: TimeInterval = 0.5

    // WatchOS 9+ gesture session
    private var gestureSession: WKExtendedRuntimeSession?
    private let motionManager = CMMotionManager()

    func startDetection() {
        // --- Option A: WatchOS 9+ Native Gesture API ---
        // The system delivers .pinch / .doublePinch / .clench events
        // automatically when Hand Gesture Detection is enabled in
        // WatchConnectivity / WKApplication entitlement.
        // Register via Info.plist key: NSSupportsIndirectInputEvents = YES
        // and entitlement: com.apple.developer.hand-gesture-detection

        gestureSession = WKExtendedRuntimeSession()
        gestureSession?.delegate = self as? WKExtendedRuntimeSessionDelegate

        // --- Option B: CMMotionManager heuristics (fallback) ---
        // Uses accelerometer + gyroscope patterns to detect gestures.
        if motionManager.isAccelerometerAvailable {
            motionManager.accelerometerUpdateInterval = 0.05
            motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
                guard let self, let data else { return }
                self.analyzeMotion(data.acceleration)
            }
        }
    }

    func stopDetection() {
        gestureSession?.invalidate()
        motionManager.stopAccelerometerUpdates()
    }

    // MARK: Motion heuristic (fallback for Option B)

    private var motionBuffer: [CMAcceleration] = []
    private var lastGestureTime: Date = .distantPast

    private func analyzeMotion(_ acc: CMAcceleration) {
        let magnitude = sqrt(acc.x*acc.x + acc.y*acc.y + acc.z*acc.z)
        motionBuffer.append(acc)
        if motionBuffer.count > 20 { motionBuffer.removeFirst() }

        guard Date().timeIntervalSince(lastGestureTime) > 0.8 else { return }

        // Clench: sharp spike across all axes
        if magnitude > 3.0 {
            let variance = motionBuffer.map { sqrt($0.x*$0.x + $0.y*$0.y + $0.z*$0.z) }
                .reduce(0, +) / Double(motionBuffer.count)
            if variance > 1.8 {
                fire(.clench)
                return
            }
        }

        // Pinch: smaller, sharper wrist flick
        if magnitude > 1.8 && magnitude < 2.8 {
            let now = Date()
            if let last = lastPinchTime, now.timeIntervalSince(last) < doublePinchInterval {
                fire(.doublePinch)
                lastPinchTime = nil
            } else {
                lastPinchTime = now
                // Wait to see if a second pinch arrives before confirming single
                DispatchQueue.main.asyncAfter(deadline: .now() + doublePinchInterval + 0.05) { [weak self] in
                    guard let self else { return }
                    if self.lastPinchTime == now {
                        self.fire(.pinch)
                        self.lastPinchTime = nil
                    }
                }
            }
        }
    }

    private func fire(_ gesture: WatchGesture) {
        lastGestureTime = Date()
        DispatchQueue.main.async {
            self.detectedGesture = gesture
            // Reset so next same gesture fires again
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.detectedGesture = .none
            }
        }
    }

    func showFeedback(_ text: String) {
        feedbackTimer?.invalidate()
        withAnimation { feedbackLabel = text }
        feedbackTimer = Timer.scheduledTimer(withTimeInterval: 1.4, repeats: false) { [weak self] _ in
            withAnimation { self?.feedbackLabel = "" }
        }
    }
}

// MARK: - ESP Speaker Controller
// Replace the body of each method with your actual BLE / UDP / MQTT / HTTP calls.

//class ESPController {
//    static let shared = ESPController()
//    private init() {}
//
//    // Example: send a UDP command to ESP32 on local network
//    // Replace host/port with your ESP's IP and port.
//    private let espHost = "192.168.1.100"
//    private let espPort: UInt16 = 8080
//
//    func nextSong() {
//        send(command: "NEXT")
//    }
//
//    func previousSong() {
//        send(command: "PREV")
//    }
//
//    func setPlayback(playing: Bool) {
//        send(command: playing ? "PLAY" : "PAUSE")
//    }
//
//    func setVolume(_ level: Int) {
//        send(command: "VOL:\(level)")
//    }
//
//    // Generic send — swap this for BLE characteristic write, MQTT publish, etc.
//    private func send(command: String) {
//        guard let data = command.data(using: .utf8) else { return }
//        // UDP example (requires Network framework):
//        //   let connection = NWConnection(host: NWEndpoint.Host(espHost),
//        //                                 port: NWEndpoint.Port(rawValue: espPort)!,
//        //                                 using: .udp)
//        //   connection.send(content: data, completion: .idempotent)
//        print("[ESP] → \(command)")   // replace with real transport
//    }
//}
