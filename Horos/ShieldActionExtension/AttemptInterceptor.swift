@preconcurrency import ManagedSettings
import Foundation
import os

/// Records a blocked attempt in the App Group and decides the shield response.
struct AttemptInterceptor: Sendable {
    private let storage: SharedStorageManager
    private let logger = Logger(subsystem: HorosConstants.logSubsystem, category: "ShieldAction")

    init(storage: SharedStorageManager = .shared) {
        self.storage = storage
    }

    func intercept<Token: Encodable>(action: ShieldAction, token: Token, kind: BlockedTargetKind) -> ShieldActionResponse {
        let button: ShieldButtonKind
        switch action {
        case .primaryButtonPressed:
            button = .primary
        case .secondaryButtonPressed:
            button = .secondary
        @unknown default:
            button = .primary
        }

        let event = BlockAttemptEvent(
            tokenHash: TokenHasher.stableHash(token),
            kind: kind,
            button: button
        )
        let tracker = storage.recordAttempt(event)
        DarwinNotifier.post(HorosConstants.DarwinNotification.attemptsDidChange)
        logger.info("Blocked attempt #\(tracker.attemptsToday) today (\(kind.rawValue, privacy: .public), \(button.rawValue, privacy: .public))")

        // Both buttons close the shield; the attempt itself is the signal.
        return .close
    }
}
