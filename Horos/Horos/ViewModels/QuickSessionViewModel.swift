import SwiftUI
import Observation
@preconcurrency import FamilyControls

/// Preset countdown options for a quick session.
enum QuickDuration: Hashable, Identifiable, CaseIterable {
    case fifteenMinutes
    case thirtyMinutes
    case oneHour
    case custom
    case indefinite

    var id: Self { self }

    var title: String {
        switch self {
        case .fifteenMinutes: return "15m"
        case .thirtyMinutes: return "30m"
        case .oneHour: return "1h"
        case .custom: return "Custom"
        case .indefinite: return "∞"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .fifteenMinutes: return "Fifteen minutes"
        case .thirtyMinutes: return "Thirty minutes"
        case .oneHour: return "One hour"
        case .custom: return "Custom duration"
        case .indefinite: return "Until I stop it"
        }
    }

    func minutes(custom: Int) -> Int? {
        switch self {
        case .fifteenMinutes: return 15
        case .thirtyMinutes: return 30
        case .oneHour: return 60
        case .custom: return max(1, custom)
        case .indefinite: return nil
        }
    }
}

/// State and actions for the Threshold tab.
@MainActor
@Observable
final class QuickSessionViewModel {
    var selection = FamilyActivitySelection()
    var duration: QuickDuration = .thirtyMinutes
    var customMinutes: Int = 45
    var isStrict = false
    var isPickerPresented = false
    var alert: AlertState?

    private(set) var state: QuickSessionState = .idle
    private(set) var now = Date()

    private let storage: SharedStorageManager
    private let engine: ShieldEngine

    init(storage: SharedStorageManager, engine: ShieldEngine) {
        self.storage = storage
        self.engine = engine
        refresh()
    }

    // MARK: - Derived

    var isAlertPresented: Bool {
        get { alert != nil }
        set { if !newValue { alert = nil } }
    }

    var hasSelection: Bool { !FamilyActivitySelectionCoder.isEmpty(selection) }
    var selectionSummary: String { FamilyActivitySelectionCoder.summary(selection) }

    var plannedMinutes: Int? { duration.minutes(custom: customMinutes) }

    /// Strict mode needs a deadline, otherwise the user could never leave.
    var strictModeAvailable: Bool { plannedMinutes != nil }

    var canStart: Bool { hasSelection && (plannedMinutes ?? 1) > 0 }

    var remaining: TimeInterval? { state.remaining(at: now) }
    var elapsed: TimeInterval { state.elapsed(at: now) }
    var canStop: Bool { state.canBeStopped(at: now) }

    var countdownText: String {
        if let remaining { return DurationFormatter.clock(remaining) }
        return DurationFormatter.clock(elapsed)
    }

    var countdownCaption: String {
        if state.isIndefinite { return "elapsed · until you end it" }
        if let end = state.endTime {
            return "ends at \(end.formatted(date: .omitted, time: .shortened))"
        }
        return ""
    }

    var monitoringNote: String? {
        guard state.isActive, !state.isIndefinite, !state.monitoringRegistered else { return nil }
        return "Sessions under \(HorosConstants.minimumScheduleMinutes) minutes are released when you reopen HOROS after the timer ends."
    }

    // MARK: - Actions

    func refresh() {
        now = Date()
        state = storage.quickSession
        if state.isActive {
            selection = state.selectedApps
        }
    }

    /// Called once per second while the tab is visible.
    func tick() {
        now = Date()
        guard state.isActive, state.hasExpired(at: now) else { return }
        state = engine.finishQuickSession()
    }

    func start() {
        let minutes = plannedMinutes
        let durationInterval: TimeInterval? = minutes.map { TimeInterval($0 * 60) }
        do {
            state = try engine.startQuickSession(
                selection: selection,
                duration: durationInterval,
                isStrict: isStrict && strictModeAvailable
            )
            now = Date()
        } catch {
            alert = AlertState(error: error)
        }
    }

    func stop() {
        do {
            state = try engine.stopQuickSession()
            now = Date()
        } catch {
            alert = AlertState(title: "Strict session", message: error.localizedDescription)
        }
    }

    func clearSelection() {
        selection = FamilyActivitySelection()
    }

    func updateCustomMinutes(_ value: Int) {
        customMinutes = min(max(value, 1), 24 * 60)
    }
}
