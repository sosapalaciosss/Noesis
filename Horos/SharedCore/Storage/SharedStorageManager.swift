import Foundation

/// Thread-safe facade over the App Group `UserDefaults` suite shared by the
/// main app and all four extensions.
///
/// Every value is stored as JSON `Data` under a versioned key. Compound
/// read-modify-write operations are serialised with an `NSLock` so concurrent
/// callers inside one process can never lose updates; `UserDefaults` itself
/// guarantees atomic writes across processes.
final class SharedStorageManager: @unchecked Sendable {
    static let shared = SharedStorageManager()

    private let defaults: UserDefaults
    private let lock = NSLock()

    init(suiteName: String = HorosConstants.appGroupID) {
        // Falling back to `.standard` keeps the app functional (single-process)
        // if the App Group entitlement is missing, e.g. on a misconfigured team.
        defaults = UserDefaults(suiteName: suiteName) ?? .standard
    }

    // MARK: - Generic codable access

    func load<Value: Decodable>(_ type: Value.Type, forKey key: String) -> Value? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(Value.self, from: data)
    }

    func save<Value: Encodable>(_ value: Value, forKey key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
    }

    func remove(forKey key: String) {
        defaults.removeObject(forKey: key)
    }

    private func withLock<Result>(_ body: () throws -> Result) rethrows -> Result {
        lock.lock()
        defer { lock.unlock() }
        return try body()
    }

    // MARK: - Blocking profiles

    var profiles: [BlockingProfile] {
        withLock { load([BlockingProfile].self, forKey: HorosConstants.StorageKey.profiles) ?? [] }
    }

    func saveProfiles(_ profiles: [BlockingProfile]) {
        withLock { save(profiles, forKey: HorosConstants.StorageKey.profiles) }
    }

    func profile(id: UUID) -> BlockingProfile? {
        profiles.first { $0.id == id }
    }

    func upsertProfile(_ profile: BlockingProfile) {
        withLock {
            var list = load([BlockingProfile].self, forKey: HorosConstants.StorageKey.profiles) ?? []
            if let index = list.firstIndex(where: { $0.id == profile.id }) {
                list[index] = profile
            } else {
                list.append(profile)
            }
            list.sort { $0.createdAt < $1.createdAt }
            save(list, forKey: HorosConstants.StorageKey.profiles)
        }
    }

    @discardableResult
    func deleteProfile(id: UUID) -> BlockingProfile? {
        withLock { () -> BlockingProfile? in
            var list = load([BlockingProfile].self, forKey: HorosConstants.StorageKey.profiles) ?? []
            guard let index = list.firstIndex(where: { $0.id == id }) else { return nil }
            let removed = list.remove(at: index)
            save(list, forKey: HorosConstants.StorageKey.profiles)
            return removed
        }
    }

    // MARK: - Quick session

    var quickSession: QuickSessionState {
        withLock { load(QuickSessionState.self, forKey: HorosConstants.StorageKey.quickSession) ?? .idle }
    }

    func saveQuickSession(_ state: QuickSessionState) {
        withLock { save(state, forKey: HorosConstants.StorageKey.quickSession) }
    }

    // MARK: - Attempt tracker

    var attemptTracker: AttemptTracker {
        withLock { load(AttemptTracker.self, forKey: HorosConstants.StorageKey.attemptTracker) ?? .empty }
    }

    func saveAttemptTracker(_ tracker: AttemptTracker) {
        withLock { save(tracker, forKey: HorosConstants.StorageKey.attemptTracker) }
    }

    /// Atomically appends an attempt and returns the updated tracker.
    @discardableResult
    func recordAttempt(_ event: BlockAttemptEvent) -> AttemptTracker {
        withLock { () -> AttemptTracker in
            var tracker = load(AttemptTracker.self, forKey: HorosConstants.StorageKey.attemptTracker) ?? .empty
            tracker.record(event)
            tracker.prune(now: event.timestamp)
            save(tracker, forKey: HorosConstants.StorageKey.attemptTracker)
            return tracker
        }
    }

    func markProtectedDay(_ date: Date = Date()) {
        withLock {
            var tracker = load(AttemptTracker.self, forKey: HorosConstants.StorageKey.attemptTracker) ?? .empty
            let key = AttemptTracker.dayKey(for: date)
            guard !tracker.protectedDays.contains(key) else { return }
            tracker.markProtected(date)
            save(tracker, forKey: HorosConstants.StorageKey.attemptTracker)
        }
    }

    func resetAttemptTracker() {
        withLock { remove(forKey: HorosConstants.StorageKey.attemptTracker) }
    }

    // MARK: - Known ManagedSettingsStore names

    var knownStoreNames: Set<String> {
        withLock { load(Set<String>.self, forKey: HorosConstants.StorageKey.knownStores) ?? [] }
    }

    func registerStoreName(_ name: String) {
        withLock {
            var names = load(Set<String>.self, forKey: HorosConstants.StorageKey.knownStores) ?? []
            guard !names.contains(name) else { return }
            names.insert(name)
            save(names, forKey: HorosConstants.StorageKey.knownStores)
        }
    }

    func unregisterStoreName(_ name: String) {
        withLock {
            var names = load(Set<String>.self, forKey: HorosConstants.StorageKey.knownStores) ?? []
            guard names.contains(name) else { return }
            names.remove(name)
            save(names, forKey: HorosConstants.StorageKey.knownStores)
        }
    }

    // MARK: - Profile runtime state

    var profileRuntime: [String: ProfileRuntimeState] {
        withLock { load([String: ProfileRuntimeState].self, forKey: HorosConstants.StorageKey.profileRuntime) ?? [:] }
    }

    func runtimeState(for id: UUID) -> ProfileRuntimeState {
        profileRuntime[id.uuidString] ?? ProfileRuntimeState()
    }

    func updateRuntimeState(for id: UUID, _ mutate: (inout ProfileRuntimeState) -> Void) {
        withLock {
            var all = load([String: ProfileRuntimeState].self, forKey: HorosConstants.StorageKey.profileRuntime) ?? [:]
            var state = all[id.uuidString] ?? ProfileRuntimeState()
            mutate(&state)
            all[id.uuidString] = state
            save(all, forKey: HorosConstants.StorageKey.profileRuntime)
        }
    }

    func removeRuntimeState(for id: UUID) {
        withLock {
            var all = load([String: ProfileRuntimeState].self, forKey: HorosConstants.StorageKey.profileRuntime) ?? [:]
            all.removeValue(forKey: id.uuidString)
            save(all, forKey: HorosConstants.StorageKey.profileRuntime)
        }
    }

    // MARK: - Simulator preview flags

    var isPreviewModeEnabled: Bool {
        get { defaults.bool(forKey: HorosConstants.StorageKey.previewMode) }
        set { defaults.set(newValue, forKey: HorosConstants.StorageKey.previewMode) }
    }

    var isPreviewDataSeeded: Bool {
        get { defaults.bool(forKey: HorosConstants.StorageKey.previewSeeded) }
        set { defaults.set(newValue, forKey: HorosConstants.StorageKey.previewSeeded) }
    }
}
