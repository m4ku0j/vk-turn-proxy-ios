import Foundation
import Combine

class ProxyService: ObservableObject {
    @Published var isRunning = false
    @Published var logs: [String] = ["Ожидание запуска..."]

    private var process: Process?
    private var outputPipe: Pipe?

    // MARK: - Start

    func start(peer: String, vkLink: String, threads: Int, useUDP: Bool, noDtls: Bool, localPort: String) {
        guard !peer.isEmpty, !vkLink.isEmpty else {
            addLog("ОШИБКА: Укажите Peer и ссылку VK Calls")
            return
        }

        // Ищем бинарник в bundle приложения
        guard let binaryPath = Bundle.main.path(forResource: "vkturn-client", ofType: nil) else {
            addLog("ОШИБКА: Бинарник vkturn-client не найден в bundle")
            addLog("Поместите client-ios-arm64 в Resources/ и переименуйте в vkturn-client")
            return
        }

        // Даём права на выполнение
        let attrs: [FileAttributeKey: Any] = [.posixPermissions: NSNumber(value: 0o755)]
        try? FileManager.default.setAttributes(attrs, ofItemAtPath: binaryPath)

        // Формируем аргументы
        var args: [String] = [
            "-peer", peer,
            "-vk-link", vkLink,
            "-listen", localPort.isEmpty ? "127.0.0.1:9000" : localPort,
            "-n", "\(max(1, min(16, threads)))"
        ]
        if useUDP  { args.append("-udp") }
        if noDtls  { args.append("-no-dtls") }

        addLog("=== ЗАПУСК ПРОКСИ ===")
        addLog("Команда: vkturn-client \(args.joined(separator: " "))")

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: binaryPath)
        proc.arguments = args

        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError  = pipe
        outputPipe = pipe

        // Читаем вывод в реальном времени
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty,
                  let text = String(data: data, encoding: .utf8) else { return }
            let lines = text.components(separatedBy: "\n").filter { !$0.isEmpty }
            for line in lines { self?.addLog(line) }
        }

        proc.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async {
                self?.isRunning = false
                self?.addLog("=== ПРОЦЕСС ОСТАНОВЛЕН (Код: \(proc.terminationStatus)) ===")
            }
        }

        do {
            try proc.run()
            process = proc
            DispatchQueue.main.async { self.isRunning = true }
        } catch {
            addLog("КРИТИЧЕСКАЯ ОШИБКА: \(error.localizedDescription)")
        }
    }

    // MARK: - Stop

    func stop() {
        process?.terminate()
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        process = nil
        outputPipe = nil
        DispatchQueue.main.async {
            self.isRunning = false
            self.addLog("=== ОСТАНОВКА ИЗ ИНТЕРФЕЙСА ===")
        }
    }

    // MARK: - Log

    func addLog(_ msg: String) {
        DispatchQueue.main.async {
            if self.logs.count > 300 { self.logs.removeFirst(100) }
            self.logs.append(msg)
        }
    }

    func clearLogs() {
        logs = ["Консоль очищена."]
    }
}
