import Foundation

/// Identifiers shared by the main app and all four App Extensions.
/// Every string that crosses a process boundary (App Group keys, store names,
/// DeviceActivity names, Darwin notifications) lives here so the five targets
/// can never drift apart.
enum HorosConstants {
    static let appGroupID = "group.com.horos.shared"
    static let mainBundleID = "com.horos.app"
    static let logSubsystem = "com.horos.app"

    /// Named `ManagedSettingsStore`s. Each shield source owns its own store so
    /// overlapping sessions never clobber each other's settings.
    enum Store {
        static let quickSession = "com.horos.store.quickSession"
        static let profilePrefix = "com.horos.store.profile."

        static func profile(_ id: UUID) -> String {
            profilePrefix + id.uuidString
        }
    }

    /// `DeviceActivityName` raw values registered with `DeviceActivityCenter`.
    enum Activity {
        static let quickSession = "horos.activity.quickSession"
        static let profilePrefix = "horos.activity.profile."

        static func profile(_ id: UUID) -> String {
            profilePrefix + id.uuidString
        }

        static func profileID(from rawValue: String) -> UUID? {
            guard rawValue.hasPrefix(profilePrefix) else { return nil }
            return UUID(uuidString: String(rawValue.dropFirst(profilePrefix.count)))
        }
    }

    /// `DeviceActivityEvent.Name` raw values.
    enum Event {
        static let allowanceReached = "horos.event.allowanceReached"
    }

    /// Keys inside the App Group `UserDefaults` suite.
    enum StorageKey {
        static let profiles = "horos.profiles.v1"
        static let quickSession = "horos.quickSession.v1"
        static let attemptTracker = "horos.attemptTracker.v1"
        static let knownStores = "horos.knownStores.v1"
        static let profileRuntime = "horos.profileRuntime.v1"
        static let previewMode = "horos.previewMode.v1"
        static let previewSeeded = "horos.previewSeeded.v1"
    }

    /// Darwin notification names used to wake the main app when an extension
    /// mutates shared state.
    enum DarwinNotification {
        static let attemptsDidChange = "com.horos.darwin.attemptsDidChange"
        static let sessionDidChange = "com.horos.darwin.sessionDidChange"
    }

    /// DeviceActivity refuses schedules shorter than 15 minutes.
    static let minimumScheduleMinutes = 15
    static let attemptRetentionDays = 30
    static let maxStoredAttemptEvents = 5_000
}
