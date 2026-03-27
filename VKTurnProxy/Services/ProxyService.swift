import Foundation
import Network

// MARK: - ProxyService
//
// ⚠️  iOS ОГРАНИЧЕНИЕ: Process() (NSTask) — macOS-only API.
//     На iPhone запустить внешний бинарник через sandbox невозможно.
//
// РЕШЕНИЕ: Этот сервис управляет vk-turn-proxy через TCP-управляющий сокет
//          к Linux-машине, где запущен vk-turn-proxy client.
//
//          Схема:
//  iPhone (WireGuard) ──UDP──► Linux :9000 (vk-turn-proxy client)
//                                    ──► VK TURN ──► VPS WireGuard
//
//  Этот класс (ProxyService) через Control API:
//  - Запускает/останавливает vk-turn-proxy на Linux
//  - Читает логи с Linux в реальном времени (TCP поток)
//
// АЛЬТЕРНАТИВА (если нет Linux под рукой):
//  - iOS → прямой WireGuard к VPS 192.145.28.186:51820 (без TURN)

class ProxyService: ObservableObject {
    @Published var isRunning = false
    @Published var logs: [String] = ["Ожидание запуска...\n⚠️ iOS не может запускать внешние процессы.\nИспользуй Linux как ретранслятор (см. README)."]

    // Адрес Control-сервера на Linux (см. control-server.py)
    var controlHost = "192.168.1.42"
    var controlPort: UInt16 = 9001

    private var connection: NWConnection?
    private var queue = DispatchQueue(label: "proxy.control", qos: .userInitiated)

    // MARK: - Start (через Linux control server)
    func start(peer: String, vkLink: String, threads: Int, useUDP: Bool, noDtls: Bool, localPort: String) {
        let cmd = buildCommand(peer: peer, vkLink: vkLink, threads: threads,
                               useUDP: useUDP, noDtls: noDtls, localPort: localPort)
        addLog("→ Отправка команды на Linux: \(controlHost):\(controlPort)")
        sendControlCommand("START:\(cmd)")
    }

    func stop() {
        sendControlCommand("STOP")
        DispatchQueue.main.async { self.isRunning = false }
        addLog("→ Команда STOP отправлена")
    }

    // MARK: - Direct mode (прямое подключение к VPS без TURN)
    func startDirect() {
        addLog("""
        ╔══════════════════════════════════════════╗
        ║  ПРЯМОЕ ПОДКЛЮЧЕНИЕ (без TURN)           ║
        ╠══════════════════════════════════════════╣
        ║  Настрой WireGuard на iPhone:            ║
        ║  Endpoint: 192.145.28.186:51820          ║
        ║  PrivateKey: iJAjkFaOTe0K9FAtdA...      ║
        ║  PublicKey:  ZuBkD79x3bXkJWP0y8...      ║
        ║  Address:    10.66.66.2/24               ║
        ║  DNS:        8.8.8.8                     ║
        ╚══════════════════════════════════════════╝
        """)
    }

    // MARK: - Linux relay mode info
    func showLinuxRelayInfo(linuxIP: String) {
        addLog("""
        ╔══════════════════════════════════════════╗
        ║  РЕЖИМ ЧЕРЕЗ LINUX РЕТРАНСЛЯТОР          ║
        ╠══════════════════════════════════════════╣
        ║  1. На Linux запусти:                    ║
        ║     ./client-linux-amd64 \\              ║
        ║       -peer 192.145.28.186:56000 \\      ║
        ║       -vk-link "https://vk.com/..." \\  ║
        ║       -listen 0.0.0.0:9000 -udp         ║
        ║                                          ║
        ║  2. WireGuard на iPhone:                 ║
        ║     Endpoint: \(linuxIP.padding(toLength: 14, withPad: " ", startingAt: 0)):9000        ║
        ║     PrivateKey: iJAjkFaOTe0K9F...       ║
        ║     PublicKey:  ZuBkD79x3bXkJW...       ║
        ║     Address:    10.66.66.2/24            ║
        ╚══════════════════════════════════════════╝
        """)
    }

    // MARK: - Control connection

    private func sendControlCommand(_ command: String) {
        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(controlHost),
            port: NWEndpoint.Port(rawValue: controlPort)!
        )
        let conn = NWConnection(to: endpoint, using: .tcp)
        connection = conn

        conn.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                let data = (command + "\n").data(using: .utf8)!
                conn.send(content: data, completion: .contentProcessed({ _ in }))
                self?.receiveLoop(conn)
                DispatchQueue.main.async { self?.isRunning = command.hasPrefix("START") }
            case .failed(let err):
                self?.addLog("❌ Ошибка подключения к Linux: \(err)")
                self?.addLog("   Проверь что control-server.py запущен на \(self?.controlHost ?? "?")")
            default: break
            }
        }
        conn.start(queue: queue)
    }

    private func receiveLoop(_ conn: NWConnection) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] data, _, isComplete, error in
            if let data = data, let text = String(data: data, encoding: .utf8) {
                let lines = text.components(separatedBy: "\n").filter { !$0.isEmpty }
                lines.forEach { self?.addLog($0) }
            }
            if !isComplete && error == nil {
                self?.receiveLoop(conn)
            }
        }
    }

    // MARK: - Helpers

    private func buildCommand(peer: String, vkLink: String, threads: Int, useUDP: Bool, noDtls: Bool, localPort: String) -> String {
        var args = "-peer \(peer) -vk-link \"\(vkLink)\" -listen \(localPort) -n \(threads)"
        if useUDP  { args += " -udp" }
        if noDtls  { args += " -no-dtls" }
        return args
    }

    func addLog(_ msg: String) {
        DispatchQueue.main.async {
            if self.logs.count > 300 { self.logs.removeFirst(100) }
            let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
            self.logs.append("[\(timestamp)] \(msg)")
        }
    }

    func clearLogs() { logs = ["Консоль очищена."] }
}
