import SwiftUI
import Observation

/// CRUD and registration for `BlockingProfile` rituals.
@MainActor
@Observable
final class SchedulesViewModel {
    private(set) var profiles: [BlockingProfile] = []
    private(set) var registrationFailures: [UUID: String] = [:]
    var alert: AlertState?
    var editingProfile: BlockingProfile?
    var isCreatingProfile = false

    private let storage: SharedStorageManager
    private let engine: ShieldEngine

    init(storage: SharedStorageManager, engine: ShieldEngine) {
        self.storage = storage
        self.engine = engine
        load()
    }

    var isAlertPresented: Bool {
        get { alert != nil }
        set { if !newValue { alert = nil } }
    }

    var activeProfiles: [BlockingProfile] {
        profiles.filter { $0.isActive() }
    }

    func load() {
        profiles = storage.profiles
    }

    func failureMessage(for profile: BlockingProfile) -> String? {
        registrationFailures[profile.id]
    }

    func isLockedByStrictMode(_ profile: BlockingProfile) -> Bool {
        profile.isStrict && profile.isActive()
    }

    // MARK: - Mutations

    func save(_ profile: BlockingProfile) {
        var normalized = profile
        normalized.name = profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.name.isEmpty { normalized.name = "Untitled ritual" }

        do {
            try engine.validate(normalized)
        } catch {
            alert = AlertState(title: "Cannot save ritual", message: error.localizedDescription)
            return
        }

        if let existing = storage.profile(id: normalized.id), isLockedByStrictMode(existing),
           existing != normalized {
            alert = AlertState(
                title: "Strict ritual",
                message: "\(existing.name) is strict and currently active. It can be edited once its window closes."
            )
            return
        }

        storage.upsertProfile(normalized)
        sync()
    }

    func toggle(_ profile: BlockingProfile) {
        guard var current = storage.profile(id: profile.id) else { return }
        if current.isEnabled, isLockedByStrictMode(current) {
            alert = AlertState(
                title: "Strict ritual",
                message: "\(current.name) is strict and currently active. It cannot be paused until \(BlockingProfile.format(current.endTime))."
            )
            load()
            return
        }
        current.isEnabled.toggle()
        storage.upsertProfile(current)
        sync()
    }

    func delete(_ profile: BlockingProfile) {
        guard let current = storage.profile(id: profile.id) else { return }
        if isLockedByStrictMode(current) {
            alert = AlertState(
                title: "Strict ritual",
                message: "\(current.name) is strict and currently active. Delete it once its window closes."
            )
            return
        }
        storage.deleteProfile(id: profile.id)
        engine.deleteProfileArtifacts(id: profile.id)
        registrationFailures.removeValue(forKey: profile.id)
        sync()
    }

    func delete(at offsets: IndexSet) {
        for index in offsets {
            guard profiles.indices.contains(index) else { continue }
            delete(profiles[index])
        }
    }

    func beginCreating() {
        editingProfile = nil
        isCreatingProfile = true
    }

    func beginEditing(_ profile: BlockingProfile) {
        editingProfile = profile
    }

    private func sync() {
        let failures = engine.syncSchedules()
        registrationFailures = failures.reduce(into: [:]) { result, entry in
            result[entry.key] = entry.value.localizedDescription
        }
        load()
        if let first = failures.first {
            let name = profiles.first { $0.id == first.key }?.name ?? "A ritual"
            alert = AlertState(
                title: "Schedule not registered",
                message: "\(name): \(first.value.localizedDescription)"
            )
        }
    }
}
