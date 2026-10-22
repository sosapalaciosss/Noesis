import Foundation

/// Cross-process signalling via Darwin notifications. Extensions post, the
/// main app observes and re-broadcasts through `NotificationCenter` so SwiftUI
/// views can refresh with `.onReceive`.
enum DarwinNotifier {
    static func post(_ name: String) {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(name as CFString),
            nil,
            nil,
            true
        )
    }

    /// Registers a process-wide observer. The C callback cannot capture
    /// context, so it simply forwards the Darwin name as a local notification.
    static func observe(_ name: String) {
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            nil,
            { _, _, cfName, _, _ in
                guard let cfName else { return }
                let localName = Notification.Name(cfName.rawValue as String)
                NotificationCenter.default.post(name: localName, object: nil)
            },
            name as CFString,
            nil,
            .deliverImmediately
        )
    }
}

extension Notification.Name {
    static let horosAttemptsDidChange = Notification.Name(HorosConstants.DarwinNotification.attemptsDidChange)
    static let horosSessionDidChange = Notification.Name(HorosConstants.DarwinNotification.sessionDidChange)
}
