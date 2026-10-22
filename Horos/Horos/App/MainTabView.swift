import SwiftUI

@MainActor
struct MainTabView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState
        TabView(selection: $appState.selectedTab) {
            ThresholdView()
                .tabItem { Label("Threshold", systemImage: "shield.lefthalf.filled") }
                .tag(HorosTab.threshold)

            RitualsView()
                .tabItem { Label("Rituals", systemImage: "clock.badge.checkmark") }
                .tag(HorosTab.rituals)

            SovereigntyView()
                .tabItem { Label("Sovereignty", systemImage: "chart.bar.xaxis") }
                .tag(HorosTab.sovereignty)
        }
        .tint(HorosPalette.gold)
    }
}
