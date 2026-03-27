import SwiftUI

@main
struct VKTurnProxyApp: App {
    @StateObject private var proxyService = ProxyService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(proxyService)
                .preferredColorScheme(.dark)
        }
    }
}
