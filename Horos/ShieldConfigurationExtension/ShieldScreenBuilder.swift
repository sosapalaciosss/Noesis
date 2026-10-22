@preconcurrency import ManagedSettingsUI
import UIKit

/// Composes the pitch-black HOROS shield from live counters.
enum ShieldScreenBuilder {
    private static let storage = SharedStorageManager.shared

    static func build(targetName: String?, tokenHash: String?, kind: BlockedTargetKind) -> ShieldConfiguration {
        let tracker = storage.attemptTracker
        let now = Date()
        let attemptsToday = tracker.attempts(on: now)
        let attemptsForTarget = tokenHash.map { tracker.attempts(forTarget: $0, on: now) } ?? 0
        let streak = tracker.currentStreak(asOf: now)
        let session = storage.quickSession

        let gold = UIColor(hex: HorosPalette.Hex.gold)
        let white = UIColor(hex: HorosPalette.Hex.textPrimary)
        let secondary = UIColor(hex: HorosPalette.Hex.textSecondary)
        let black = UIColor(hex: HorosPalette.Hex.background)

        let symbolConfiguration = UIImage.SymbolConfiguration(pointSize: 72, weight: .thin)
        let icon = UIImage(systemName: "shield.lefthalf.filled", withConfiguration: symbolConfiguration)?
            .withTintColor(gold, renderingMode: .alwaysOriginal)

        let title = ShieldConfiguration.Label(text: "HOROS", color: gold)
        let subtitle = ShieldConfiguration.Label(
            text: subtitleText(
                targetName: targetName,
                kind: kind,
                attemptsToday: attemptsToday,
                attemptsForTarget: attemptsForTarget,
                streak: streak,
                session: session,
                now: now
            ),
            color: secondary
        )

        return ShieldConfiguration(
            backgroundBlurStyle: .systemThickMaterialDark,
            backgroundColor: black.withAlphaComponent(0.96),
            icon: icon,
            title: title,
            subtitle: subtitle,
            primaryButtonLabel: ShieldConfiguration.Label(text: "Hold the line", color: black),
            primaryButtonBackgroundColor: gold,
            secondaryButtonLabel: ShieldConfiguration.Label(text: "Return to stillness", color: white)
        )
    }

    private static func subtitleText(
        targetName: String?,
        kind: BlockedTargetKind,
        attemptsToday: Int,
        attemptsForTarget: Int,
        streak: Int,
        session: QuickSessionState,
        now: Date
    ) -> String {
        let fallback = kind == .webDomain ? "This site" : "This app"
        let name: String
        if let targetName, !targetName.isEmpty {
            name = targetName
        } else {
            name = fallback
        }
        var lines: [String] = []
        lines.append("\(name) lies beyond the threshold.")

        switch attemptsToday {
        case 0:
            lines.append("This is your first attempt to cross this boundary today.")
        case 1:
            lines.append("You have tried to cross this boundary 1 time today.")
        default:
            lines.append("You have tried to cross this boundary \(attemptsToday) times today.")
        }

        if attemptsForTarget > 0, attemptsForTarget != attemptsToday {
            lines.append("\(attemptsForTarget) of them were for \(name).")
        }

        if session.isActive, let remaining = session.remaining(at: now) {
            lines.append("Quick session ends in \(DurationFormatter.compact(remaining)).")
        } else if session.isActive, session.isIndefinite {
            lines.append("A quick session is running until you end it.")
        }

        if streak > 1 {
            lines.append("Streak: \(streak) days of sovereignty.")
        }

        return lines.joined(separator: "\n")
    }
}
