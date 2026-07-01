// ESPController.swift
// Drop this file into your WatchOS app target.

import Foundation
import Network
import Combine

class ESPController: ObservableObject {
    static let shared = ESPController()

    // ── Set this to your ESP32's IP after it boots ──
    private let espHost = "192.168.233.10"   // <-- change me
    private let espPort: UInt16 = 8080
    // ────────────────────────────────────────────────

    @Published var lastStatus: String = "Ready"
    @Published var sendCount: Int = 0
    @Published var networkInfo: String = "Checking..."

    private var pathMonitor: NWPathMonitor?
    private let queue = DispatchQueue(label: "com.yoram.core-motion-test.networkQueue")

    private init() {
        startNetworkMonitor()
    }

    // ── Network Monitor: shows what interfaces are available ──
    private func startNetworkMonitor() {
        pathMonitor = NWPathMonitor()
        pathMonitor?.pathUpdateHandler = { [weak self] path in
            var info = ""

            switch path.status {
            case .satisfied:
                info += "✅ Network OK"
            case .unsatisfied:
                info += "❌ No network"
            case .requiresConnection:
                info += "⏳ Needs connection"
            @unknown default:
                info += "❓ Unknown"
            }

            // Show available interfaces
            var ifaces: [String] = []
            if path.usesInterfaceType(.wifi) { ifaces.append("WiFi") }
            if path.usesInterfaceType(.cellular) { ifaces.append("Cell") }
            if path.usesInterfaceType(.wiredEthernet) { ifaces.append("Eth") }
            if path.usesInterfaceType(.loopback) { ifaces.append("Loop") }
            if path.usesInterfaceType(.other) { ifaces.append("Other") }

            if ifaces.isEmpty {
                info += " | No interfaces!"
            } else {
                info += " | \(ifaces.joined(separator: ", "))"
            }

            if path.isExpensive { info += " | 💰Expensive" }
            if path.isConstrained { info += " | 🔒Constrained" }

            print("[NET] Path update: \(info)")
            DispatchQueue.main.async { self?.networkInfo = info }
        }
        pathMonitor?.start(queue: queue)
    }

    private func send(command: String) {
        guard let data = command.data(using: .utf8) else {
            print("[ESP] ❌ Failed to encode command: \(command)")
            DispatchQueue.main.async { self.lastStatus = "❌ Encode error" }
            return
        }

        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(espHost),
            port: NWEndpoint.Port(rawValue: espPort)!
        )

        // Use default UDP — let the system pick the best path.
        // Don't force WiFi since the watch may not have WiFi active.
        let params = NWParameters.udp
        params.prohibitExpensivePaths = false
        params.prohibitConstrainedPaths = false

        let conn = NWConnection(to: endpoint, using: params)

        print("[ESP] 📡 Connecting to \(espHost):\(espPort) for command: \(command)")
        DispatchQueue.main.async { self.lastStatus = "📡 Sending \(command)..." }

        conn.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                print("[ESP] ✅ Connection ready, sending: \(command)")
                conn.send(content: data, completion: .contentProcessed { error in
                    if let error {
                        print("[ESP] ❌ Send error: \(error)")
                        DispatchQueue.main.async {
                            self?.lastStatus = "❌ \(error.localizedDescription)"
                        }
                    } else {
                        print("[ESP] → \(command) sent successfully")
                        DispatchQueue.main.async {
                            self?.lastStatus = "✅ \(command) sent"
                            self?.sendCount += 1
                        }
                    }
                    conn.cancel()
                })
            case .failed(let error):
                print("[ESP] ❌ Connection failed: \(error)")
                DispatchQueue.main.async {
                    self?.lastStatus = "❌ Failed: \(error.localizedDescription)"
                }
                conn.cancel()
            case .waiting(let error):
                print("[ESP] ⏳ Waiting: \(error)")
                DispatchQueue.main.async {
                    self?.lastStatus = "⏳ \(error.localizedDescription)"
                }
            case .cancelled:
                print("[ESP] 🔌 Connection cancelled")
            default:
                break
            }
        }
        conn.start(queue: queue)
    }

    func nextSong()                    { send(command: "NEXT") }
    func previousSong()                { send(command: "PREV") }
    func setPlayback(playing: Bool)    { send(command: playing ? "PLAY" : "PAUSE") }
    func setVolume(_ level: Int)       { send(command: "VOL:\(level)") }
    func sendRaw(_ command: String)    { send(command: command) }
}
