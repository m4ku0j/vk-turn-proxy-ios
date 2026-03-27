import SwiftUI

struct SettingsView: View {
    @StateObject private var ssh    = SSHManager()
    @StateObject private var settings = ProxySettings()
    @Environment(\.dismiss) private var dismiss

    @State private var customCmd = ""

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    // --- SSH настройки ---
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {

                            sectionTitle("SSH ПОДКЛЮЧЕНИЕ")

                            HStack(spacing: 8) {
                                VStack(alignment: .leading) {
                                    fieldLabel("IP адрес")
                                    TextField("192.145.28.186", text: $settings.sshIP)
                                        .textFieldStyle(DarkTextFieldStyle())
                                        .autocapitalization(.none)
                                        .keyboardType(.URL)
                                }
                                VStack(alignment: .leading) {
                                    fieldLabel("Порт")
                                    TextField("1194", text: $settings.sshPort)
                                        .textFieldStyle(DarkTextFieldStyle())
                                        .keyboardType(.numberPad)
                                        .frame(width: 70)
                                }
                            }

                            fieldLabel("Пользователь")
                            TextField("m4ku0j", text: $settings.sshUser)
                                .textFieldStyle(DarkTextFieldStyle())
                                .autocapitalization(.none)

                            fieldLabel("Пароль")
                            SecureField("пароль", text: $settings.sshPass)
                                .textFieldStyle(DarkTextFieldStyle())

                            Button("ПОДКЛЮЧИТЬСЯ") {
                                ssh.connect(
                                    ip:   settings.sshIP,
                                    port: Int(settings.sshPort) ?? 22,
                                    user: settings.sshUser,
                                    pass: settings.sshPass
                                )
                            }
                            .buttonStyle(BigButtonStyle(color: .blue))

                            Divider().background(Color.gray.opacity(0.3))

                            sectionTitle("УПРАВЛЕНИЕ СЕРВЕРОМ")

                            HStack(spacing: 8) {
                                VStack(alignment: .leading) {
                                    fieldLabel("Listen")
                                    TextField("0.0.0.0:56000", text: $settings.sshProxyListen)
                                        .textFieldStyle(DarkTextFieldStyle())
                                        .autocapitalization(.none)
                                        .keyboardType(.URL)
                                }
                                VStack(alignment: .leading) {
                                    fieldLabel("Connect")
                                    TextField("127.0.0.1:51820", text: $settings.sshProxyConnect)
                                        .textFieldStyle(DarkTextFieldStyle())
                                        .autocapitalization(.none)
                                        .keyboardType(.URL)
                                }
                            }

                            HStack(spacing: 8) {
                                Button("УСТАНОВИТЬ") { ssh.installServer() }
                                    .buttonStyle(BigButtonStyle(color: Color(white: 0.25)))
                                    .disabled(!ssh.isConnected)

                                Button("ЗАПУСТИТЬ") {
                                    ssh.startProxy(listen: settings.sshProxyListen,
                                                   connect: settings.sshProxyConnect)
                                }
                                .buttonStyle(BigButtonStyle(color: .green.opacity(0.8)))
                                .disabled(!ssh.isConnected || !ssh.isInstalled || ssh.isServerRunning)

                                Button("СТОП") { ssh.stopProxy() }
                                    .buttonStyle(BigButtonStyle(color: .red.opacity(0.8)))
                                    .disabled(!ssh.isConnected || !ssh.isServerRunning)
                            }

                            Divider().background(Color.gray.opacity(0.3))

                            sectionTitle("ТЕРМИНАЛ")

                            HStack {
                                TextField("команда...", text: $customCmd)
                                    .textFieldStyle(DarkTextFieldStyle())
                                    .autocapitalization(.none)

                                Button("▶") {
                                    ssh.sendCommand(customCmd)
                                    customCmd = ""
                                }
                                .buttonStyle(BigButtonStyle(color: .teal))
                                .disabled(!ssh.isConnected)
                            }
                        }
                        .padding()
                    }

                    // --- SSH лог ---
                    LogConsoleView(
                        logs: ssh.logs,
                        onCopy: {
                            UIPasteboard.general.string = ssh.logs.joined(separator: "\n")
                        },
                        onClear: { ssh.logs = [] }
                    )
                    .frame(height: 200)
                }
            }
            .navigationTitle("Настройки")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("← Назад") { dismiss() }
                        .foregroundColor(.cyan)
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(.cyan)
            .padding(.top, 4)
    }

    @ViewBuilder
    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption.bold())
            .foregroundColor(Color(white: 0.7))
    }
}

// MARK: - Big Button Style

struct BigButtonStyle: ButtonStyle {
    let color: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .bold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(color)
            .cornerRadius(8)
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
