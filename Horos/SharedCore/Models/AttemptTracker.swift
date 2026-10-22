import Foundation

/// What kind of shielded target the user tried to open.
enum BlockedTargetKind: String, Codable, Hashable, Sendable {
    case application
    case category
    case webDomain

    var label: String {
        switch self {
        case .application: return "App"
        case .category: return "Category"
        case .webDomain: return "Website"
        }
    }
}

/// Which shield button was tapped.
enum ShieldButtonKind: String, Codable, Hashable, Sendable {
    case primary
    case secondary
}

/// One intercepted attempt to cross a shield, logged by `ShieldActionExtension`.
struct BlockAttemptEvent: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let timestamp: Date
    /// Stable hash of the token (see `TokenHasher`) — never the bundle identifier.
    let tokenHash: String
    let kind: BlockedTargetKind
    let button: ShieldButtonKind
    /// `yyyy-MM-dd` in the local calendar, precomputed for cheap grouping.
    let dayKey: String

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        tokenHash: String,
        kind: BlockedTargetKind,
        button: ShieldButtonKind,
        calendar: Calendar = .current
    ) {
        self.id = id
        self.timestamp = timestamp
        self.tokenHash = tokenHash
        self.kind = kind
        self.button = button
        self.dayKey = AttemptTracker.dayKey(for: timestamp, calendar: calendar)
    }
}

/// Attempts for one calendar day — feeds the 7-day Swift Chart.
struct DailyAttemptCount: Identifiable, Hashable, Sendable {
    let date: Date
    let count: Int
    let isToday: Bool
    var id: Date { date }
}

/// Aggregated log of every blocked attempt, grouped by day and by token hash,
/// plus the set of days on which HOROS was protecting the user (for streaks).
struct AttemptTracker: Codable, Equatable, Sendable {
    var events: [BlockAttemptEvent]
    /// dayKey → total attempts that day.
    var dailyCounts: [String: Int]
    /// dayKey → (tokenHash → attempts).
    var perTargetDailyCounts: [String: [String: Int]]
    /// Days (dayKey) on which at least one shield was raised.
    var protectedDays: Set<String>

    init(
        events: [BlockAttemptEvent] = [],
        dailyCounts: [String: Int] = [:],
        perTargetDailyCounts: [String: [String: Int]] = [:],
        protectedDays: Set<String> = []
    ) {
        self.events = events
        self.dailyCounts = dailyCounts
        self.perTargetDailyCounts = perTargetDailyCounts
        self.protectedDays = protectedDays
    }

    static let empty = AttemptTracker()

    // MARK: - Day keys

    static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }

    static func date(fromDayKey key: String, calendar: Calendar = .current) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    // MARK: - Mutation

    mutating func record(_ event: BlockAttemptEvent) {
        events.append(event)
        dailyCounts[event.dayKey, default: 0] += 1
        perTargetDailyCounts[event.dayKey, default: [:]][event.tokenHash, default: 0] += 1
        protectedDays.insert(event.dayKey)
    }

    mutating func markProtected(_ date: Date, calendar: Calendar = .current) {
        protectedDays.insert(Self.dayKey(for: date, calendar: calendar))
    }

    /// Drops events older than the retention window and caps the event array.
    mutating func prune(
        now: Date = Date(),
        retentionDays: Int = HorosConstants.attemptRetentionDays,
        maxEvents: Int = HorosConstants.maxStoredAttemptEvents,
        calendar: Calendar = .current
    ) {
        guard let cutoff = calendar.date(byAdding: .day, value: -retentionDays, to: calendar.startOfDay(for: now)) else { return }
        let cutoffKey = Self.dayKey(for: cutoff, calendar: calendar)
        events.removeAll { $0.timestamp < cutoff }
        if events.count > maxEvents {
            events.removeFirst(events.count - maxEvents)
        }
        dailyCounts = dailyCounts.filter { $0.key >= cutoffKey }
        perTargetDailyCounts = perTargetDailyCounts.filter { $0.key >= cutoffKey }
        protectedDays = protectedDays.filter { $0 >= cutoffKey }
    }

    // MARK: - Queries

    func attempts(on date: Date, calendar: Calendar = .current) -> Int {
        dailyCounts[Self.dayKey(for: date, calendar: calendar)] ?? 0
    }

    var attemptsToday: Int { attempts(on: Date()) }

    func attempts(forTarget tokenHash: String, on date: Date = Date(), calendar: Calendar = .current) -> Int {
        perTargetDailyCounts[Self.dayKey(for: date, calendar: calendar)]?[tokenHash] ?? 0
    }

    func events(on date: Date, calendar: Calendar = .current) -> [BlockAttemptEvent] {
        let key = Self.dayKey(for: date, calendar: calendar)
        return events.filter { $0.dayKey == key }.sorted { $0.timestamp > $1.timestamp }
    }

    var totalAttempts: Int { dailyCounts.values.reduce(0, +) }

    /// Attempts for the last `days` days, oldest first, with zero-filled gaps.
    func dailySeries(days: Int = 7, endingAt end: Date = Date(), calendar: Calendar = .current) -> [DailyAttemptCount] {
        let todayStart = calendar.startOfDay(for: end)
        return (0..<days).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: todayStart) else { return nil }
            return DailyAttemptCount(
                date: day,
                count: attempts(on: day, calendar: calendar),
                isToday: offset == 0
            )
        }
    }

    func attempts(inLast days: Int, endingAt end: Date = Date(), calendar: Calendar = .current) -> Int {
        dailySeries(days: days, endingAt: end, calendar: calendar).reduce(0) { $0 + $1.count }
    }

    /// Consecutive protected days ending today (or yesterday, so an early-morning
    /// check doesn't zero the streak before the first shield of the day).
    func currentStreak(asOf date: Date = Date(), calendar: Calendar = .current) -> Int {
        let todayStart = calendar.startOfDay(for: date)
        var cursor = todayStart
        if !protectedDays.contains(Self.dayKey(for: cursor, calendar: calendar)) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor) else { return 0 }
            cursor = yesterday
        }
        var streak = 0
        while protectedDays.contains(Self.dayKey(for: cursor, calendar: calendar)) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }

    /// Today's attempts compared with yesterday, as a signed fraction (−0.25 = 25 % fewer).
    func dayOverDayChange(asOf date: Date = Date(), calendar: Calendar = .current) -> Double? {
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: date) else { return nil }
        let previous = attempts(on: yesterday, calendar: calendar)
        guard previous > 0 else { return nil }
        return Double(attempts(on: date, calendar: calendar) - previous) / Double(previous)
    }
}
