import SwiftUI

struct LogConsoleView: View {
    let logs: [String]
    let onCopy: () -> Void
    let onClear: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text("ТЕРМИНАЛ ЛОГОВ:")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color(white: 0.8))
                Spacer()
                Button("COPY") { onCopy() }
                    .buttonStyle(SmallButtonStyle(color: Color(white: 0.27)))
                Button("CLEAR") { onClear() }
                    .buttonStyle(SmallButtonStyle(color: Color(white: 0.27)))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(white: 0.15))

            // Log scroll
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(logs.enumerated()), id: \.offset) { index, line in
                            Text(line)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(.green)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id(index)
                        }
                    }
                    .padding(10)
                }
                .background(Color.black)
                .onChange(of: logs.count) { _ in
                    withAnimation {
                        proxy.scrollTo(logs.count - 1, anchor: .bottom)
                    }
                }
            }
        }
    }
}

// MARK: - Small Button Style

struct SmallButtonStyle: ButtonStyle {
    let color: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color)
            .cornerRadius(4)
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
