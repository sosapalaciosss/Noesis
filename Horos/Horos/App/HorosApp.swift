import SwiftUI

@main
struct HorosApp: App {
    // `App` initialisers run on the main thread, but Swift 5.9 does not treat
    // stored-property default values as main-actor isolated, so state it.
    @State private var appState = MainActor.assumeIsolated { AppState() }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .preferredColorScheme(.dark)
                .tint(HorosPalette.gold)
        }
    }
}
