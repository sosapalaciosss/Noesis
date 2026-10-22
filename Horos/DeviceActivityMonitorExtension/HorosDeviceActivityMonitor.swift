@preconcurrency import DeviceActivity
@preconcurrency import ManagedSettings
@preconcurrency import FamilyControls
import os

/// Background scheduler. iOS launches this extension at the boundaries of every
/// `DeviceActivitySchedule` HOROS registered and whenever a usage-threshold
/// event fires, even if the main app is not running. All decisions are
/// delegated to `ShieldEngine` so the app and this process share one brain.
final class HorosDeviceActivityMonitor: DeviceActivityMonitor {
    private let engine = ShieldEngine.shared
    private let logger = Logger(subsystem: HorosConstants.logSubsystem, category: "Monitor")

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        logger.info("intervalDidStart \(activity.rawValue, privacy: .public)")
        engine.handleIntervalDidStart(activityName: activity.rawValue)
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        logger.info("intervalDidEnd \(activity.rawValue, privacy: .public)")
        engine.handleIntervalDidEnd(activityName: activity.rawValue)
    }

    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        logger.info("eventDidReachThreshold \(event.rawValue, privacy: .public) in \(activity.rawValue, privacy: .public)")
        engine.handleEventDidReachThreshold(eventName: event.rawValue, activityName: activity.rawValue)
    }

    override func intervalWillStartWarning(for activity: DeviceActivityName) {
        super.intervalWillStartWarning(for: activity)
        logger.debug("intervalWillStartWarning \(activity.rawValue, privacy: .public)")
    }

    override func intervalWillEndWarning(for activity: DeviceActivityName) {
        super.intervalWillEndWarning(for: activity)
        logger.debug("intervalWillEndWarning \(activity.rawValue, privacy: .public)")
    }

    override func eventWillReachThresholdWarning(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventWillReachThresholdWarning(event, activity: activity)
        logger.debug("eventWillReachThresholdWarning \(event.rawValue, privacy: .public)")
    }
}
