import Foundation

/// Calendar-compatible weekday (1 = Sunday … 7 = Saturday).
enum Weekday: Int, Codable, CaseIterable, Hashable, Sendable, Identifiable {
    case sunday = 1
    case monday
    case tuesday
    case wednesday
    case thursday
    case friday
    case saturday

    var id: Int { rawValue }

    static var everyDay: Set<Weekday> { Set(allCases) }
    static var workdays: Set<Weekday> { [.monday, .tuesday, .wednesday, .thursday, .friday] }
    static var weekend: Set<Weekday> { [.saturday, .sunday] }

    /// Days ordered according to the user's locale (e.g. Monday-first in most of Europe).
    static func localeOrdered(_ calendar: Calendar = .current) -> [Weekday] {
        let first = calendar.firstWeekday
        return (0..<7).compactMap { offset in
            Weekday(rawValue: ((first - 1 + offset) % 7) + 1)
        }
    }

    static func current(at date: Date = Date(), calendar: Calendar = .current) -> Weekday {
        Weekday(rawValue: calendar.component(.weekday, from: date)) ?? .sunday
    }

    var next: Weekday {
        Weekday(rawValue: (rawValue % 7) + 1) ?? .sunday
    }

    var previous: Weekday {
        Weekday(rawValue: rawValue == 1 ? 7 : rawValue - 1) ?? .saturday
    }

    func shortSymbol(_ calendar: Calendar = .current) -> String {
        calendar.shortWeekdaySymbols[rawValue - 1]
    }

    func veryShortSymbol(_ calendar: Calendar = .current) -> String {
        calendar.veryShortWeekdaySymbols[rawValue - 1]
    }

    func fullSymbol(_ calendar: Calendar = .current) -> String {
        calendar.weekdaySymbols[rawValue - 1]
    }
}

extension Set where Element == Weekday {
    /// Human readable summary such as "Every day", "Weekdays", "Mon, Wed, Fri".
    var summary: String {
        if self == Weekday.everyDay { return "Every day" }
        if self == Weekday.workdays { return "Weekdays" }
        if self == Weekday.weekend { return "Weekends" }
        if isEmpty { return "No days" }
        return Weekday.localeOrdered()
            .filter { contains($0) }
            .map { $0.shortSymbol() }
            .joined(separator: ", ")
    }
}
