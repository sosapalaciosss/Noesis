import Foundation
@preconcurrency import FamilyControls

/// A scheduled blocking ritual: which apps are shielded, on which days and
/// between which times. Persisted as JSON in the App Group; the embedded
/// `FamilyActivitySelection` is wrapped in a property-list blob so the opaque
/// tokens round-trip safely between processes.
struct BlockingProfile: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var activitySelection: FamilyActivitySelection
    var daysOfWeek: Set<Weekday>
    /// Hour/minute the shield rises.
    var startTime: DateComponents
    /// Hour/minute the shield falls. If earlier than `startTime` the window spans midnight.
    var endTime: DateComponents
    /// Strict profiles cannot be disabled or deleted while their window is active.
    var isStrict: Bool
    var isEnabled: Bool
    /// Optional usage allowance (minutes). When set, the apps stay open until
    /// the allowance is consumed inside the window, then the shield rises.
    var dailyAllowanceMinutes: Int?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        activitySelection: FamilyActivitySelection = FamilyActivitySelection(),
        daysOfWeek: Set<Weekday> = Weekday.everyDay,
        startTime: DateComponents = DateComponents(hour: 21, minute: 0),
        endTime: DateComponents = DateComponents(hour: 7, minute: 0),
        isStrict: Bool = false,
        isEnabled: Bool = true,
        dailyAllowanceMinutes: Int? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.activitySelection = activitySelection
        self.daysOfWeek = daysOfWeek
        self.startTime = startTime
        self.endTime = endTime
        self.isStrict = isStrict
        self.isEnabled = isEnabled
        self.dailyAllowanceMinutes = dailyAllowanceMinutes
        self.createdAt = createdAt
    }

    // MARK: - Codable (selection wrapped in a plist blob)

    private enum CodingKeys: String, CodingKey {
        case id, name, activitySelectionData, daysOfWeek, startTime, endTime
        case isStrict, isEnabled, dailyAllowanceMinutes, createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        let blob = try container.decodeIfPresent(Data.self, forKey: .activitySelectionData) ?? Data()
        activitySelection = FamilyActivitySelectionCoder.decode(blob)
        daysOfWeek = try container.decodeIfPresent(Set<Weekday>.self, forKey: .daysOfWeek) ?? Weekday.everyDay
        startTime = try container.decode(DateComponents.self, forKey: .startTime)
        endTime = try container.decode(DateComponents.self, forKey: .endTime)
        isStrict = try container.decodeIfPresent(Bool.self, forKey: .isStrict) ?? false
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        dailyAllowanceMinutes = try container.decodeIfPresent(Int.self, forKey: .dailyAllowanceMinutes)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(FamilyActivitySelectionCoder.encode(activitySelection), forKey: .activitySelectionData)
        try container.encode(daysOfWeek, forKey: .daysOfWeek)
        try container.encode(startTime, forKey: .startTime)
        try container.encode(endTime, forKey: .endTime)
        try container.encode(isStrict, forKey: .isStrict)
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encodeIfPresent(dailyAllowanceMinutes, forKey: .dailyAllowanceMinutes)
        try container.encode(createdAt, forKey: .createdAt)
    }

    // MARK: - Hashable

    static func == (lhs: BlockingProfile, rhs: BlockingProfile) -> Bool {
        lhs.id == rhs.id
            && lhs.name == rhs.name
            && lhs.daysOfWeek == rhs.daysOfWeek
            && lhs.startTime == rhs.startTime
            && lhs.endTime == rhs.endTime
            && lhs.isStrict == rhs.isStrict
            && lhs.isEnabled == rhs.isEnabled
            && lhs.dailyAllowanceMinutes == rhs.dailyAllowanceMinutes
            && lhs.createdAt == rhs.createdAt
            && FamilyActivitySelectionCoder.isEqual(lhs.activitySelection, rhs.activitySelection)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    // MARK: - Schedule arithmetic

    var startMinutes: Int { (startTime.hour ?? 0) * 60 + (startTime.minute ?? 0) }
    var endMinutes: Int { (endTime.hour ?? 0) * 60 + (endTime.minute ?? 0) }
    var spansMidnight: Bool { endMinutes <= startMinutes }

    var durationMinutes: Int {
        spansMidnight ? (24 * 60 - startMinutes + endMinutes) : (endMinutes - startMinutes)
    }

    var hasSelection: Bool { !FamilyActivitySelectionCoder.isEmpty(activitySelection) }
    var hasAllowance: Bool { (dailyAllowanceMinutes ?? 0) > 0 }

    /// Changes whenever anything that affects the registered schedule changes.
    var scheduleSignature: String {
        let selectionHash = TokenHasher.fnv1a(FamilyActivitySelectionCoder.encode(activitySelection))
        return "\(startMinutes)-\(endMinutes)-\(dailyAllowanceMinutes ?? 0)-\(selectionHash)"
    }

    var scheduleIsValid: Bool {
        durationMinutes >= HorosConstants.minimumScheduleMinutes && !daysOfWeek.isEmpty
    }

    /// Whether the profile's window covers `date`, honouring the day-of-week
    /// filter and overnight windows (a window that started yesterday night is
    /// still active this morning if yesterday was a selected day).
    func isWindowActive(at date: Date, calendar: Calendar = .current) -> Bool {
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        let nowMinutes = hour * 60 + minute
        let today = Weekday.current(at: date, calendar: calendar)

        if spansMidnight {
            if nowMinutes >= startMinutes {
                return daysOfWeek.contains(today)
            }
            if nowMinutes < endMinutes {
                return daysOfWeek.contains(today.previous)
            }
            return false
        }
        return nowMinutes >= startMinutes && nowMinutes < endMinutes && daysOfWeek.contains(today)
    }

    /// Active = enabled, valid and inside its window right now.
    func isActive(at date: Date = Date(), calendar: Calendar = .current) -> Bool {
        isEnabled && scheduleIsValid && hasSelection && isWindowActive(at: date, calendar: calendar)
    }

    /// Next moment the window opens, used for the schedule list subtitle.
    func nextStart(after date: Date = Date(), calendar: Calendar = .current) -> Date? {
        guard isEnabled, !daysOfWeek.isEmpty else { return nil }
        for offset in 0...7 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: date),
                  let candidate = calendar.date(
                    bySettingHour: startTime.hour ?? 0,
                    minute: startTime.minute ?? 0,
                    second: 0,
                    of: day
                  ) else { continue }
            if candidate > date && daysOfWeek.contains(Weekday.current(at: candidate, calendar: calendar)) {
                return candidate
            }
        }
        return nil
    }

    func formattedWindow(calendar: Calendar = .current) -> String {
        "\(Self.format(startTime, calendar: calendar)) – \(Self.format(endTime, calendar: calendar))"
    }

    static func format(_ components: DateComponents, calendar: Calendar = .current) -> String {
        var anchor = calendar.dateComponents([.year, .month, .day], from: Date())
        anchor.hour = components.hour ?? 0
        anchor.minute = components.minute ?? 0
        guard let date = calendar.date(from: anchor) else { return "--:--" }
        return date.formatted(date: .omitted, time: .shortened)
    }
}
