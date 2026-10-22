import SwiftUI
import Observation
@preconcurrency import FamilyControls
@preconcurrency import DeviceActivity

/// Feeds the Sovereignty tab: attempt counters, 7-day history, streaks and
/// the filter for the embedded `DeviceActivityReport`.
@MainActor
@Observable
final class AnalyticsViewModel {
    private(set) var tracker: AttemptTracker = .empty
    private(set) var series: [DailyAttemptCount] = []
    private(set) var recentEvents: [BlockAttemptEvent] = []
    private(set) var reportFilter: DeviceActivityFilter
    private(set) var reportSelectionSummary: String = "All apps"
    private(set) var lastRefresh = Date()

    private let storage: SharedStorageManager

    init(storage: SharedStorageManager) {
        self.storage = storage
        self.reportFilter = Self.makeFilter(selection: FamilyActivitySelection())
        refresh(previewMode: false)
    }

    var attemptsToday: Int { tracker.attemptsToday }
    var attemptsThisWeek: Int { tracker.attempts(inLast: 7) }
    var streak: Int { tracker.currentStreak() }
    var dayOverDayChange: Double? { tracker.dayOverDayChange() }
    var peakDay: DailyAttemptCount? { series.max { $0.count < $1.count } }

    func refresh(previewMode: Bool = false) {
        if previewMode {
            seedPreviewDataIfNeeded()
        }
        tracker = storage.attemptTracker
        series = tracker.dailySeries(days: 7)
        recentEvents = Array(tracker.events(on: Date()).prefix(12))
        rebuildReportFilter()
        lastRefresh = Date()
    }

    func resetHistory() {
        storage.resetAttemptTracker()
        storage.isPreviewDataSeeded = false
        refresh()
    }

    // MARK: - Report filter

    private func rebuildReportFilter() {
        let profileSelections = storage.profiles.filter { $0.isEnabled }.map { $0.activitySelection }
        let session = storage.quickSession
        let union = FamilyActivitySelectionCoder.union(
            profileSelections + (session.isActive ? [session.selectedApps] : [])
        )
        reportFilter = Self.makeFilter(selection: union)
        reportSelectionSummary = FamilyActivitySelectionCoder.isEmpty(union)
            ? "All apps"
            : FamilyActivitySelectionCoder.summary(union)
    }

    private static func makeFilter(selection: FamilyActivitySelection, calendar: Calendar = .current) -> DeviceActivityFilter {
        let now = Date()
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
        let start = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now)) ?? now
        return DeviceActivityFilter(
            segment: .daily(during: DateInterval(start: start, end: end)),
            users: .all,
            devices: .init([.iPhone, .iPad]),
            applications: selection.applicationTokens,
            categories: selection.categoryTokens,
            webDomains: selection.webDomainTokens
        )
    }

    // MARK: - Simulator preview data

    /// Populates a believable week of attempts the first time the app runs in
    /// preview mode, so charts and counters are not empty in the Simulator.
    private func seedPreviewDataIfNeeded() {
        guard !storage.isPreviewDataSeeded else { return }
        var seeded = AttemptTracker.empty
        let calendar = Calendar.current
        let now = Date()
        let pattern = [9, 7, 8, 5, 4, 3, 2]
        let targets = ["preview-social", "preview-video", "preview-games"]

        for (offset, count) in pattern.enumerated() {
            let daysAgo = pattern.count - 1 - offset
            guard let day = calendar.date(byAdding: .day, value: -daysAgo, to: calendar.startOfDay(for: now)) else { continue }
            seeded.markProtected(day)
            for index in 0..<count {
                let hour = 8 + (index * 2) % 14
                let minute = (index * 17) % 60
                guard let timestamp = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day),
                      timestamp <= now else { continue }
                seeded.record(BlockAttemptEvent(
                    timestamp: timestamp,
                    tokenHash: targets[index % targets.count],
                    kind: index % 4 == 3 ? .webDomain : .application,
                    button: index % 3 == 0 ? .secondary : .primary
                ))
            }
        }
        storage.saveAttemptTracker(seeded)
        storage.isPreviewDataSeeded = true
    }
}
