import Foundation
@preconcurrency import FamilyControls
@preconcurrency import ManagedSettings
@preconcurrency import DeviceActivity
import os

/// Centralises every call to `ManagedSettingsStore` and `DeviceActivityCenter`.
///
/// The main app and the extensions all route through this type, so there is a
/// single definition of "what does it mean to raise a shield for profile X" and
/// the processes can never disagree. Each shield source (the quick session and
/// every profile) writes to its own named store, which is what lets overlapping
/// schedules coexist without clobbering one another.
struct ShieldEngine: Sendable {
    static let shared = ShieldEngine()

    enum EngineError: LocalizedError, Equatable {
        case emptySelection
        case strictSessionLocked
        case scheduleTooShort
        case noDaysSelected
        case monitoringFailed(String)

        var errorDescription: String? {
            switch self {
            case .emptySelection:
                return "Choose at least one app, category or website first."
            case .strictSessionLocked:
                return "This is a strict session. The threshold stays closed until the timer runs out."
            case .scheduleTooShort:
                return "Schedules must last at least \(HorosConstants.minimumScheduleMinutes) minutes."
            case .noDaysSelected:
                return "Pick at least one day of the week."
            case .monitoringFailed(let reason):
                return "Screen Time refused the schedule: \(reason)"
            }
        }
    }

    private let storage: SharedStorageManager
    /// When true, every ManagedSettings / DeviceActivity call is skipped and
    /// only the persisted state changes. Used in the Simulator, where the
    /// Screen Time daemons do not exist and calling into them can block.
    let dryRun: Bool
    private let logger = Logger(subsystem: HorosConstants.logSubsystem, category: "ShieldEngine")

    init(storage: SharedStorageManager = .shared, dryRun: Bool = false) {
        self.storage = storage
        self.dryRun = dryRun
    }

    // MARK: - Quick session

    /// Raises the shield immediately and, for timed sessions long enough for
    /// DeviceActivity, registers a one-shot schedule so the monitor extension
    /// lifts the shield at the deadline even if the app has been terminated.
    @discardableResult
    func startQuickSession(
        selection: FamilyActivitySelection,
        duration: TimeInterval?,
        isStrict: Bool,
        now: Date = Date()
    ) throws -> QuickSessionState {
        guard !FamilyActivitySelectionCoder.isEmpty(selection) else {
            throw EngineError.emptySelection
        }

        let endTime = duration.map { now.addingTimeInterval($0) }
        var state = QuickSessionState(
            isActive: true,
            selectedApps: selection,
            startTime: now,
            endTime: endTime,
            isStrict: isStrict && endTime != nil,
            monitoringRegistered: false
        )

        apply(selection: selection, toStoreNamed: HorosConstants.Store.quickSession)

        if let endTime, endTime.timeIntervalSince(now) >= Double(HorosConstants.minimumScheduleMinutes * 60) {
            do {
                try registerQuickSessionMonitoring(start: now, end: endTime)
                state.monitoringRegistered = true
            } catch {
                // Non-fatal: the app reconciles expiry itself on every foreground.
                logger.error("Quick session monitoring not registered: \(error.localizedDescription, privacy: .public)")
            }
        }

        storage.saveQuickSession(state)
        storage.markProtectedDay(now)
        DarwinNotifier.post(HorosConstants.DarwinNotification.sessionDidChange)
        logger.info("Quick session started (strict: \(state.isStrict), timed: \(endTime != nil))")
        return state
    }

    /// Stops the session unless it is strict and still running.
    @discardableResult
    func stopQuickSession(force: Bool = false, now: Date = Date()) throws -> QuickSessionState {
        let state = storage.quickSession
        guard state.isActive else { return .idle }
        guard force || state.canBeStopped(at: now) else {
            throw EngineError.strictSessionLocked
        }
        return finishQuickSession()
    }

    /// Unconditionally tears the quick session down (used by the monitor
    /// extension when the interval ends and by the app once the timer expires).
    @discardableResult
    func finishQuickSession() -> QuickSessionState {
        clear(storeNamed: HorosConstants.Store.quickSession)
        if !dryRun {
            DeviceActivityCenter().stopMonitoring([DeviceActivityName(HorosConstants.Activity.quickSession)])
        }
        storage.saveQuickSession(.idle)
        DarwinNotifier.post(HorosConstants.DarwinNotification.sessionDidChange)
        logger.info("Quick session finished")
        return .idle
    }

    /// Brings persisted state and the live shield back into agreement:
    /// expired sessions are torn down, running ones are re-applied (idempotent).
    @discardableResult
    func reconcileQuickSession(now: Date = Date()) -> QuickSessionState {
        let state = storage.quickSession
        guard state.isActive else { return state }
        if state.hasExpired(at: now) {
            return finishQuickSession()
        }
        apply(selection: state.selectedApps, toStoreNamed: HorosConstants.Store.quickSession)
        return state
    }

    /// Called by the monitor extension at interval start.
    func applyQuickSessionShield() {
        let state = storage.quickSession
        guard state.isActive else { return }
        apply(selection: state.selectedApps, toStoreNamed: HorosConstants.Store.quickSession)
    }

    private func registerQuickSessionMonitoring(start: Date, end: Date) throws {
        guard !dryRun else { return }
        let calendar = Calendar.current
        let components: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
        let schedule = DeviceActivitySchedule(
            intervalStart: calendar.dateComponents(components, from: start),
            intervalEnd: calendar.dateComponents(components, from: end),
            repeats: false
        )
        let center = DeviceActivityCenter()
        let name = DeviceActivityName(HorosConstants.Activity.quickSession)
        center.stopMonitoring([name])
        try center.startMonitoring(name, during: schedule)
    }

    // MARK: - Scheduled profiles

    /// Registers a repeating `DeviceActivitySchedule` for every enabled, valid
    /// profile, stops monitoring for anything else, and then applies/removes
    /// shields for whatever should be active right now.
    /// Returns per-profile registration failures (empty on success).
    @discardableResult
    func syncSchedules(profiles: [BlockingProfile]? = nil, now: Date = Date()) -> [UUID: EngineError] {
        let allProfiles = profiles ?? storage.profiles
        if dryRun {
            reconcileProfileShields(profiles: allProfiles, now: now)
            return [:]
        }
        let center = DeviceActivityCenter()

        let desired = allProfiles.filter { $0.isEnabled && $0.hasSelection && $0.scheduleIsValid }
        let desiredNames = Set(desired.map { HorosConstants.Activity.profile($0.id) })

        let stale = center.activities.filter { activity in
            activity.rawValue.hasPrefix(HorosConstants.Activity.profilePrefix)
                && !desiredNames.contains(activity.rawValue)
        }
        if !stale.isEmpty {
            center.stopMonitoring(stale)
        }

        let registered = Set(center.activities.map(\.rawValue))
        var failures: [UUID: EngineError] = [:]
        for profile in desired {
            let activityName = HorosConstants.Activity.profile(profile.id)
            if registered.contains(activityName),
               storage.runtimeState(for: profile.id).registeredSignature == profile.scheduleSignature {
                continue
            }
            do {
                try register(profile, with: center)
            } catch let error as EngineError {
                failures[profile.id] = error
            } catch {
                failures[profile.id] = .monitoringFailed(error.localizedDescription)
            }
        }

        reconcileProfileShields(profiles: allProfiles, now: now)
        return failures
    }

    /// Validates the profile the way `syncSchedules` will, so the editor can
    /// surface problems before saving.
    func validate(_ profile: BlockingProfile) throws {
        guard profile.hasSelection else { throw EngineError.emptySelection }
        guard !profile.daysOfWeek.isEmpty else { throw EngineError.noDaysSelected }
        guard profile.durationMinutes >= HorosConstants.minimumScheduleMinutes else {
            throw EngineError.scheduleTooShort
        }
    }

    private func register(_ profile: BlockingProfile, with center: DeviceActivityCenter) throws {
        try validate(profile)

        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: profile.startTime.hour ?? 0, minute: profile.startTime.minute ?? 0),
            intervalEnd: DateComponents(hour: profile.endTime.hour ?? 0, minute: profile.endTime.minute ?? 0),
            repeats: true
        )

        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
        if let allowance = profile.dailyAllowanceMinutes, allowance > 0 {
            events[DeviceActivityEvent.Name(HorosConstants.Event.allowanceReached)] = DeviceActivityEvent(
                applications: profile.activitySelection.applicationTokens,
                categories: profile.activitySelection.categoryTokens,
                webDomains: profile.activitySelection.webDomainTokens,
                threshold: DateComponents(minute: allowance)
            )
        }

        let name = DeviceActivityName(HorosConstants.Activity.profile(profile.id))
        center.stopMonitoring([name])
        do {
            try center.startMonitoring(name, during: schedule, events: events)
        } catch {
            throw EngineError.monitoringFailed(error.localizedDescription)
        }
        storage.registerStoreName(HorosConstants.Store.profile(profile.id))
        storage.updateRuntimeState(for: profile.id) { $0.registeredSignature = profile.scheduleSignature }
        logger.info("Registered schedule for profile \(profile.name, privacy: .public)")
    }

    /// Applies shields for profiles whose window is open now and removes them
    /// for everything else. Allowance profiles only shield once the monitor
    /// extension has recorded that today's allowance is spent.
    func reconcileProfileShields(profiles: [BlockingProfile]? = nil, now: Date = Date()) {
        let todayKey = AttemptTracker.dayKey(for: now)
        for profile in profiles ?? storage.profiles {
            let shouldShield: Bool
            if profile.isActive(at: now) {
                if profile.hasAllowance {
                    shouldShield = storage.runtimeState(for: profile.id).allowanceReachedDayKey == todayKey
                } else {
                    shouldShield = true
                }
            } else {
                shouldShield = false
            }

            if shouldShield {
                applyShield(for: profile)
            } else {
                removeShield(forProfileID: profile.id)
            }
        }
    }

    func applyShield(for profile: BlockingProfile) {
        apply(selection: profile.activitySelection, toStoreNamed: HorosConstants.Store.profile(profile.id))
        storage.updateRuntimeState(for: profile.id) { $0.isShieldApplied = true }
        storage.markProtectedDay()
    }

    func removeShield(forProfileID id: UUID) {
        let name = HorosConstants.Store.profile(id)
        guard storage.knownStoreNames.contains(name) || storage.runtimeState(for: id).isShieldApplied else { return }
        clear(storeNamed: name)
        storage.updateRuntimeState(for: id) { $0.isShieldApplied = false }
    }

    /// Tears down everything that belongs to a deleted profile.
    func deleteProfileArtifacts(id: UUID) {
        if !dryRun {
            DeviceActivityCenter().stopMonitoring([DeviceActivityName(HorosConstants.Activity.profile(id))])
        }
        let name = HorosConstants.Store.profile(id)
        clear(storeNamed: name)
        storage.unregisterStoreName(name)
        storage.removeRuntimeState(for: id)
    }

    /// Emergency stop: clears every store HOROS has ever written to and stops
    /// all monitoring. Respects nothing — intended for the settings screen.
    func clearAllShields() {
        var names = storage.knownStoreNames
        names.insert(HorosConstants.Store.quickSession)
        for name in names {
            clear(storeNamed: name)
        }
        if !dryRun {
            DeviceActivityCenter().stopMonitoring()
        }
        storage.saveQuickSession(.idle)
        for profile in storage.profiles {
            storage.updateRuntimeState(for: profile.id) { $0.isShieldApplied = false }
        }
        DarwinNotifier.post(HorosConstants.DarwinNotification.sessionDidChange)
        logger.notice("All shields cleared")
    }

    // MARK: - Monitor extension entry points

    func handleIntervalDidStart(activityName rawValue: String, now: Date = Date()) {
        if rawValue == HorosConstants.Activity.quickSession {
            applyQuickSessionShield()
            return
        }
        guard let id = HorosConstants.Activity.profileID(from: rawValue),
              let profile = storage.profile(id: id) else {
            logger.warning("intervalDidStart for unknown activity \(rawValue, privacy: .public)")
            return
        }

        storage.updateRuntimeState(for: id) {
            $0.lastIntervalStart = now
            $0.allowanceReachedDayKey = nil
        }

        guard profile.isEnabled, profile.daysOfWeek.contains(Weekday.current(at: now)) else {
            removeShield(forProfileID: id)
            return
        }

        if profile.hasAllowance {
            // Allowance phase: apps stay open until `eventDidReachThreshold`.
            removeShield(forProfileID: id)
        } else {
            applyShield(for: profile)
        }
    }

    func handleIntervalDidEnd(activityName rawValue: String, now: Date = Date()) {
        if rawValue == HorosConstants.Activity.quickSession {
            finishQuickSession()
            return
        }
        guard let id = HorosConstants.Activity.profileID(from: rawValue) else { return }
        removeShield(forProfileID: id)
        storage.updateRuntimeState(for: id) { $0.lastIntervalEnd = now }
    }

    func handleEventDidReachThreshold(eventName: String, activityName rawValue: String, now: Date = Date()) {
        guard eventName == HorosConstants.Event.allowanceReached,
              let id = HorosConstants.Activity.profileID(from: rawValue),
              let profile = storage.profile(id: id),
              profile.isEnabled,
              profile.daysOfWeek.contains(Weekday.current(at: now)) else { return }

        storage.updateRuntimeState(for: id) { $0.allowanceReachedDayKey = AttemptTracker.dayKey(for: now) }
        applyShield(for: profile)
        logger.info("Allowance exhausted for profile \(profile.name, privacy: .public)")
    }

    // MARK: - Primitives

    private func apply(selection: FamilyActivitySelection, toStoreNamed name: String) {
        storage.registerStoreName(name)
        guard !dryRun else {
            logger.debug("dry run: would shield \(FamilyActivitySelectionCoder.count(selection)) targets in \(name, privacy: .public)")
            return
        }
        let store = ManagedSettingsStore(named: ManagedSettingsStore.Name(name))
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty
            ? nil
            : .specific(selection.categoryTokens, except: [])
        store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
        store.shield.webDomainCategories = selection.categoryTokens.isEmpty
            ? nil
            : .specific(selection.categoryTokens, except: [])
    }

    private func clear(storeNamed name: String) {
        guard !dryRun else { return }
        ManagedSettingsStore(named: ManagedSettingsStore.Name(name)).clearAllSettings()
    }
}
