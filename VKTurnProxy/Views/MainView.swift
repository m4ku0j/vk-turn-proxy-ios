import SwiftUI

struct MainView: View {
    @EnvironmentObject var proxyService: ProxyService
    @StateObject private var settings = ProxySettings()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // --- Форма настроек ---
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {

                        // Raw mode toggle
                        Toggle("Режим Raw команды", isOn: $settings.rawMode)
                            .toggleStyle(SwitchToggleStyle(tint: .blue))
                            .foregroundColor(.white)
                            .padding(.top, 8)

                        if settings.rawMode {
                            TextEditor(text: $settings.rawCmd)
                                .frame(height: 80)
                                .font(.system(.body, design: .monospaced))
                                .background(Color(white: 0.12))
                                .foregroundColor(.white)
                                .cornerRadius(6)
                                .overlay(
                                    Group {
                                        if settings.rawCmd.isEmpty {
                                            Text("./client -n 8 -udp -peer IP:56000 ...")
                                                .foregroundColor(.gray)
                                                .padding(8)
                                        }
                                    }, alignment: .topLeading
                                )
                        } else {
                            // Peer
                            fieldLabel("Peer (IP:Port сервера)")
                            TextField("192.145.28.186:56000", text: $settings.peer)
                                .textFieldStyle(DarkTextFieldStyle())
                                .autocapitalization(.none)
                                .keyboardType(.URL)

                            // VK Link
                            fieldLabel("Ссылка VK Calls")
                            TextField("https://vk.com/call/join/...", text: $settings.vkLink)
                                .textFieldStyle(DarkTextFieldStyle())
                                .autocapitalization(.none)
                                .keyboardType(.URL)

                            // Threads
                            HStack {
                                fieldLabel("Потоки (-n): \(settings.threads)")
                                Spacer()
                                Stepper("", value: $settings.threads, in: 1...16)
                                    .labelsHidden()
                            }

                            // Toggles
                            Toggle("Использовать UDP (-udp)", isOn: $settings.useUDP)
                                .toggleStyle(SwitchToggleStyle(tint: .green))
                                .foregroundColor(.white)

                            Toggle("Без обфускации (-no-dtls)", isOn: $settings.noDtls)
                                .toggleStyle(SwitchToggleStyle(tint: .orange))
                                .foregroundColor(.white)

                            // Local port
                            fieldLabel("Локальный порт")
                            TextField("127.0.0.1:9000", text: $settings.localPort)
                                .textFieldStyle(DarkTextFieldStyle())
                                .autocapitalization(.none)
                                .keyboardType(.URL)
                        }

                        // --- Кнопка СТАРТ/СТОП ---
                        Button(action: toggleProxy) {
                            Text(proxyService.isRunning ? "ОСТАНОВИТЬ ПРОКСИ" : "ЗАПУСТИТЬ ПРОКСИ")
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .font(.headline)
                                .foregroundColor(.white)
                                .background(proxyService.isRunning ? Color.red.opacity(0.85) : Color.green.opacity(0.8))
                                .cornerRadius(10)
                        }
                        .padding(.top, 8)
                    }
                    .padding()
                }

                // --- Лог консоль ---
                LogConsoleView(logs: proxyService.logs,
                               onCopy: copyLogs,
                               onClear: proxyService.clearLogs)
                    .frame(height: 220)
            }
        }
    }

    // MARK: - Actions

    private func toggleProxy() {
        if proxyService.isRunning {
            proxyService.stop()
        } else {
            if settings.rawMode {
                // TODO: raw mode parsing
                proxyService.addLog("Raw режим: \(settings.rawCmd)")
            } else {
                proxyService.start(
                    peer: settings.peer,
                    vkLink: settings.vkLink,
                    threads: settings.threads,
                    useUDP: settings.useUDP,
                    noDtls: settings.noDtls,
                    localPort: settings.localPort
                )
            }
        }
    }

    private func copyLogs() {
        UIPasteboard.general.string = proxyService.logs.joined(separator: "\n")
    }

    // MARK: - Helpers

    @ViewBuilder
    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption.bold())
            .foregroundColor(Color(white: 0.7))
    }
}

// MARK: - Dark TextField Style

struct DarkTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(10)
            .background(Color(white: 0.12))
            .foregroundColor(.white)
            .cornerRadius(6)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(white: 0.27), lineWidth: 1))
    }
}
