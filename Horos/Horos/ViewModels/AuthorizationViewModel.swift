import SwiftUI
import Observation
@preconcurrency import FamilyControls

/// Drives the permission gate. Mirrors `AuthorizationCenter` and adds a
/// Simulator preview mode so the whole UI can be exercised where Family
/// Controls is unavailable.
@MainActor
@Observable
final class AuthorizationViewModel {
    enum Status: Equatable {
        case notDetermined
        case approved
        case denied
        case simulatorPreview
    }

    private(set) var status: Status = .notDetermined
    private(set) var isRequesting = false
    var alert: AlertState?

    private let storage: SharedStorageManager

    init(storage: SharedStorageManager) {
        self.storage = storage
        refresh()
    }

    static var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    var isGranted: Bool {
        status == .approved || status == .simulatorPreview
    }

    var isAlertPresented: Bool {
        get { alert != nil }
        set { if !newValue { alert = nil } }
    }

    func refresh() {
        // Family Controls has no backing service in the Simulator and querying
        // it can block the main thread indefinitely, so never touch it there.
        if Self.isSimulator {
            status = storage.isPreviewModeEnabled ? .simulatorPreview : .notDetermined
            return
        }
        apply(AuthorizationCenter.shared.authorizationStatus)
    }

    func apply(_ raw: AuthorizationStatus) {
        let previewFallback = Self.isSimulator && storage.isPreviewModeEnabled
        switch raw {
        case .approved:
            status = .approved
        case .denied:
            status = previewFallback ? .simulatorPreview : .denied
        case .notDetermined:
            status = previewFallback ? .simulatorPreview : .notDetermined
        @unknown default:
            status = previewFallback ? .simulatorPreview : .notDetermined
        }
    }

    func requestAccess() async {
        guard !isRequesting else { return }
        if Self.isSimulator {
            // Family Controls cannot be granted in the Simulator (the request
            // never returns); preview mode is the only meaningful outcome.
            enablePreviewMode()
            return
        }
        isRequesting = true
        defer { isRequesting = false }

        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            refresh()
        } catch {
            refresh()
            if status != .approved {
                alert = AlertState(
                    title: "Screen Time access needed",
                    message: error.localizedDescription
                )
            }
        }
    }

    func enablePreviewMode() {
        storage.isPreviewModeEnabled = true
        status = .simulatorPreview
    }

    func disablePreviewMode() {
        storage.isPreviewModeEnabled = false
        refresh()
    }
}
