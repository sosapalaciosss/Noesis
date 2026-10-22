import SwiftUI
@preconcurrency import FamilyControls

/// Permission gate → main tabs. Also the single place where cross-process
/// signals and scene phase changes are turned into model refreshes.
struct RootView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if appState.authorization.isGranted {
                MainTabView()
                    .transition(.opacity)
            } else {
                OnboardingView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: appState.authorization.isGranted)
        .background(HorosPalette.background.ignoresSafeArea())
        .onAppear { appState.refreshAll() }
        .onChange(of: scenePhase) { _, phase in
            appState.handleScenePhase(phase)
        }
        .onReceive(AuthorizationCenter.shared.$authorizationStatus.receive(on: DispatchQueue.main)) { status in
            appState.authorization.apply(status)
        }
        .onReceive(NotificationCenter.default.publisher(for: .horosAttemptsDidChange).receive(on: DispatchQueue.main)) { _ in
            appState.analytics.refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: .horosSessionDidChange).receive(on: DispatchQueue.main)) { _ in
            appState.quickSession.refresh()
            appState.analytics.refresh()
        }
    }
}
