import SwiftUI
import Observation

/// Composition root for the main app. Owns the shared storage/engine handles,
/// the per-tab view models, and wires cross-process notifications so the UI
/// refreshes the moment an extension writes to the App Group.
@MainActor
@Observable
final class AppState {
    let storage: SharedStorageManager
    let engine: ShieldEngine

    let authorization: AuthorizationViewModel
    let quickSession: QuickSessionViewModel
    let schedules: SchedulesViewModel
    let analytics: AnalyticsViewModel

    var selectedTab: HorosTab = .threshold

    init(storage: SharedStorageManager = .shared, engine: ShieldEngine = .shared) {
        self.storage = storage
        self.engine = engine
        self.authorization = AuthorizationViewModel(storage: storage)
        self.quickSession = QuickSessionViewModel(storage: storage, engine: engine)
        self.schedules = SchedulesViewModel(storage: storage, engine: engine)
        self.analytics = AnalyticsViewModel(storage: storage)

        DarwinNotifier.observe(HorosConstants.DarwinNotification.attemptsDidChange)
        DarwinNotifier.observe(HorosConstants.DarwinNotification.sessionDidChange)
    }

    /// Full reconciliation: authorization, live shields vs persisted state,
    /// schedule registration and analytics. Cheap enough to run on every
    /// foreground transition.
    func refreshAll() {
        authorization.refresh()
        guard authorization.isGranted else { return }

        if authorization.status == .approved {
            engine.reconcileQuickSession()
            engine.syncSchedules()
        }
        quickSession.refresh()
        schedules.load()
        analytics.refresh(previewMode: authorization.status == .simulatorPreview)
    }

    func handleScenePhase(_ phase: ScenePhase) {
        if phase == .active {
            refreshAll()
        }
    }
}

enum HorosTab: Hashable {
    case threshold
    case rituals
    case sovereignty
}
