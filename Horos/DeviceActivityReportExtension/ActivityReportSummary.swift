import Foundation

/// Screen time for one calendar day.
struct DailyUsage: Identifiable, Hashable, Sendable {
    let date: Date
    let duration: TimeInterval
    let isToday: Bool
    var id: Date { date }
}

/// Aggregated usage of one application across the reporting window.
struct AppUsage: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let bundleIdentifier: String?
    var duration: TimeInterval
    var pickups: Int
    var notifications: Int
    /// Fraction of total screen time (0…1).
    var share: Double
}

/// Aggregated usage of one activity category.
struct CategoryUsage: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    var duration: TimeInterval
    var share: Double
}

/// Everything the report view needs, computed once in `makeConfiguration`.
struct ActivityReportSummary: Hashable, Sendable {
    var days: [DailyUsage]
    var apps: [AppUsage]
    var categories: [CategoryUsage]
    var totalDuration: TimeInterval
    var todayDuration: TimeInterval
    var yesterdayDuration: TimeInterval
    var averageDuration: TimeInterval
    /// Today vs yesterday as a signed fraction (−0.30 = 30 % less than yesterday).
    var dayOverDayChange: Double?
    /// Today vs the average of the preceding days in the window.
    var trendVersusAverage: Double?
    var generatedAt: Date

    static let empty = ActivityReportSummary(
        days: [],
        apps: [],
        categories: [],
        totalDuration: 0,
        todayDuration: 0,
        yesterdayDuration: 0,
        averageDuration: 0,
        dayOverDayChange: nil,
        trendVersusAverage: nil,
        generatedAt: Date()
    )

    var hasData: Bool { totalDuration > 0 }
}
