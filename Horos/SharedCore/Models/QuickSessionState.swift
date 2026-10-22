import Foundation
@preconcurrency import FamilyControls

/// State of the one-off "Quick Block" focus session.
struct QuickSessionState: Codable, Equatable {
    var isActive: Bool
    var selectedApps: FamilyActivitySelection
    var startTime: Date?
    /// `nil` means the session runs until the user stops it.
    var endTime: Date?
    /// Strict sessions cannot be stopped before `endTime`.
    var isStrict: Bool
    /// True when a `DeviceActivitySchedule` was registered so the monitor
    /// extension can lift the shield even if the app is terminated.
    var monitoringRegistered: Bool

    init(
        isActive: Bool = false,
        selectedApps: FamilyActivitySelection = FamilyActivitySelection(),
        startTime: Date? = nil,
        endTime: Date? = nil,
        isStrict: Bool = false,
        monitoringRegistered: Bool = false
    ) {
        self.isActive = isActive
        self.selectedApps = selectedApps
        self.startTime = startTime
        self.endTime = endTime
        self.isStrict = isStrict
        self.monitoringRegistered = monitoringRegistered
    }

    /// Computed rather than stored so no global of a possibly non-Sendable type exists.
    static var idle: QuickSessionState { QuickSessionState() }

    var isIndefinite: Bool { endTime == nil }

    func hasExpired(at date: Date = Date()) -> Bool {
        guard isActive, let endTime else { return false }
        return date >= endTime
    }

    func remaining(at date: Date = Date()) -> TimeInterval? {
        guard isActive, let endTime else { return nil }
        return max(0, endTime.timeIntervalSince(date))
    }

    func elapsed(at date: Date = Date()) -> TimeInterval {
        guard isActive, let startTime else { return 0 }
        return max(0, date.timeIntervalSince(startTime))
    }

    /// Strict timed sessions are locked until they expire.
    func canBeStopped(at date: Date = Date()) -> Bool {
        guard isActive else { return true }
        if !isStrict { return true }
        return hasExpired(at: date)
    }

    // MARK: - Codable (selection wrapped in a plist blob)

    private enum CodingKeys: String, CodingKey {
        case isActive, selectedAppsData, startTime, endTime, isStrict, monitoringRegistered
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? false
        let blob = try container.decodeIfPresent(Data.self, forKey: .selectedAppsData) ?? Data()
        selectedApps = FamilyActivitySelectionCoder.decode(blob)
        startTime = try container.decodeIfPresent(Date.self, forKey: .startTime)
        endTime = try container.decodeIfPresent(Date.self, forKey: .endTime)
        isStrict = try container.decodeIfPresent(Bool.self, forKey: .isStrict) ?? false
        monitoringRegistered = try container.decodeIfPresent(Bool.self, forKey: .monitoringRegistered) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(isActive, forKey: .isActive)
        try container.encode(FamilyActivitySelectionCoder.encode(selectedApps), forKey: .selectedAppsData)
        try container.encodeIfPresent(startTime, forKey: .startTime)
        try container.encodeIfPresent(endTime, forKey: .endTime)
        try container.encode(isStrict, forKey: .isStrict)
        try container.encode(monitoringRegistered, forKey: .monitoringRegistered)
    }

    static func == (lhs: QuickSessionState, rhs: QuickSessionState) -> Bool {
        lhs.isActive == rhs.isActive
            && lhs.startTime == rhs.startTime
            && lhs.endTime == rhs.endTime
            && lhs.isStrict == rhs.isStrict
            && lhs.monitoringRegistered == rhs.monitoringRegistered
            && FamilyActivitySelectionCoder.isEqual(lhs.selectedApps, rhs.selectedApps)
    }
}
