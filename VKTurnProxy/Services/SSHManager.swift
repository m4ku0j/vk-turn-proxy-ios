import Foundation
import NMSSH

class SSHManager: ObservableObject {
    @Published var logs: [String] = []
    @Published var isConnected = false
    @Published var isInstalled = false
    @Published var isServerRunning = false

    private var session: NMSSHSession?

    // MARK: - Connect

    func connect(ip: String, port: Int, user: String, pass: String) {
        disconnect()
        addLog("[Система]: Подключение к \(user)@\(ip):\(port)...")

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let sess = NMSSHSession(host: ip, port: port, andUsername: user)
            sess?.connect()

            guard sess?.isConnected == true else {
                self.addLog("[Ошибка]: Не удалось подключиться")
                return
            }

            sess?.authenticate(byPassword: pass)

            guard sess?.isAuthorized == true else {
                self.addLog("[Ошибка]: Неверный пароль")
                sess?.disconnect()
                return
            }

            self.session = sess
            DispatchQueue.main.async { self.isConnected = true }
            self.addLog("[Система]: Подключено успешно!")
            self.checkServerState()
        }
    }

    // MARK: - Disconnect

    func disconnect() {
        session?.disconnect()
        session = nil
        DispatchQueue.main.async {
            self.isConnected = false
            self.isInstalled = false
            self.isServerRunning = false
        }
    }

    // MARK: - Install server binary

    func installServer() {
        execute("""
            mkdir -p /opt/vk-turn && cd /opt/vk-turn && \
            pkill -9 -f 'server-linux-' 2>/dev/null; \
            ARCH=$(uname -m); \
            if [ "$ARCH" = "x86_64" ]; then BIN="server-linux-amd64"; else BIN="server-linux-arm64"; fi; \
            wget -qO $BIN https://github.com/cacggghp/vk-turn-proxy/releases/latest/download/$BIN && \
            chmod +x $BIN && echo "Установка завершена!"
            """)
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.checkServerState()
        }
    }

    // MARK: - Start server proxy

    func startProxy(listen: String = "0.0.0.0:56000", connect: String = "127.0.0.1:51820") {
        execute("""
            cd /opt/vk-turn && \
            ARCH=$(uname -m); \
            if [ "$ARCH" = "x86_64" ]; then BIN="server-linux-amd64"; else BIN="server-linux-arm64"; fi; \
            nohup ./$BIN -listen \(listen) -connect \(connect) > server.log 2>&1 & \
            echo $! > proxy.pid && echo "Сервер запущен (PID: $(cat proxy.pid))"
            """)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.checkServerState()
        }
    }

    // MARK: - Stop server proxy

    func stopProxy() {
        execute("""
            cd /opt/vk-turn && \
            if [ -f proxy.pid ]; then kill -9 $(cat proxy.pid) 2>/dev/null; rm -f proxy.pid; fi; \
            pkill -9 -f 'server-linux-' 2>/dev/null; \
            echo "Остановлено."
            """)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.checkServerState()
        }
    }

    // MARK: - Execute custom command

    func sendCommand(_ cmd: String) {
        guard !cmd.isEmpty else { return }
        execute(cmd)
    }

    // MARK: - Check server state

    func checkServerState() {
        let checkCmd = """
            if ls /opt/vk-turn/server-linux-* >/dev/null 2>&1; then echo "INSTALLED:YES"; else echo "INSTALLED:NO"; fi
            if ps aux | grep -v grep | grep -q "server-linux-"; then echo "RUNNING:YES"; else echo "RUNNING:NO"; fi
            """
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self, let sess = self.session else { return }
            var error: NSError?
            let result = sess.channel.execute(checkCmd, error: &error) ?? ""
            DispatchQueue.main.async {
                self.isInstalled    = result.contains("INSTALLED:YES")
                self.isServerRunning = result.contains("RUNNING:YES")
                let status = self.isServerRunning ? "РАБОТАЕТ" : "ОСТАНОВЛЕН"
                let inst   = self.isInstalled    ? "УСТАНОВЛЕН" : "НЕ НАЙДЕН"
                self.addLog("[Статус]: vk-turn-proxy \(inst). Сервер: \(status).")
            }
        }
    }

    // MARK: - Private helpers

    private func execute(_ command: String) {
        guard let sess = session else {
            addLog("[Ошибка]: Нет SSH подключения")
            return
        }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var error: NSError?
            let result = sess.channel.execute(command, error: &error) ?? ""
            let lines = result.components(separatedBy: "\n").filter { !$0.isEmpty }
            for line in lines { self?.addLog(line) }
            if let err = error { self?.addLog("[Ошибка]: \(err.localizedDescription)") }
        }
    }

    private func addLog(_ msg: String) {
        DispatchQueue.main.async {
            if self.logs.count > 300 { self.logs.removeFirst(100) }
            self.logs.append(msg)
        }
    }
}
