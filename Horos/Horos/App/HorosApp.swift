import SwiftUI

@main
struct HorosApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .preferredColorScheme(.dark)
                .tint(HorosPalette.gold)
        }
    }
}
