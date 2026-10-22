import Foundation

/// Per-profile bookkeeping written by the monitor extension and read by the
/// app so both agree on whether a shield is currently raised.
struct ProfileRuntimeState: Codable, Equatable, Sendable {
    /// dayKey on which the usage allowance was exhausted (nil = not yet today).
    var allowanceReachedDayKey: String?
    var lastIntervalStart: Date?
    var lastIntervalEnd: Date?
    var isShieldApplied: Bool
    /// Fingerprint of the schedule last handed to `DeviceActivityCenter`, so
    /// unchanged profiles are not re-registered (which would reset allowance
    /// accounting) on every foreground.
    var registeredSignature: String?

    init(
        allowanceReachedDayKey: String? = nil,
        lastIntervalStart: Date? = nil,
        lastIntervalEnd: Date? = nil,
        isShieldApplied: Bool = false,
        registeredSignature: String? = nil
    ) {
        self.allowanceReachedDayKey = allowanceReachedDayKey
        self.lastIntervalStart = lastIntervalStart
        self.lastIntervalEnd = lastIntervalEnd
        self.isShieldApplied = isShieldApplied
        self.registeredSignature = registeredSignature
    }
}
