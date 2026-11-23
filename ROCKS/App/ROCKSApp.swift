import SwiftUI

@main
struct ROCKSApp: App {
    @State private var appState = AppState.production()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .task {
                    await appState.restoreSession()
                }
                .onOpenURL { url in
                    if PasswordRecoveryLink.matches(url) {
                        Task { await appState.openPasswordRecovery(url) }
                    } else if AuthCallbackLink.matches(url) {
                        Task { await appState.completeEmailConfirmation(url) }
                    } else {
                        appState.pendingDeepLink = DeepLinkRoute(url: url)
                    }
                }
                .onChange(of: scenePhase) { _, phase in
                    guard phase == .active else { return }
                    Task { await appState.validateSession() }
                }
        }
    }
}
