import SwiftUI

@main
struct HorosApp: App {
    var body: some Scene {
        WindowGroup {
            AppRoot()
        }
    }
}

/// Owns the single `AppState`. Creating it inside a `@MainActor` view
/// initialiser keeps the construction main-actor isolated under both
/// Swift 5.9 (Xcode 15) and Swift 6 (Xcode 16).
@MainActor
struct AppRoot: View {
    @State private var appState: AppState

    init() {
        _appState = State(initialValue: AppState())
    }

    var body: some View {
        RootView()
            .environment(appState)
            .preferredColorScheme(.dark)
            .tint(HorosPalette.gold)
    }
}
