import SwiftUI

struct ContentView: View {
    @EnvironmentObject var proxyService: ProxyService
    @State private var showSettings = false

    var body: some View {
        NavigationView {
            MainView()
                .navigationTitle("VK Turn Proxy")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("SETTINGS") {
                            showSettings = true
                        }
                        .foregroundColor(.cyan)
                        .font(.caption.bold())
                    }
                }
                .sheet(isPresented: $showSettings) {
                    SettingsView()
                }
        }
        .navigationViewStyle(.stack)
    }
}
