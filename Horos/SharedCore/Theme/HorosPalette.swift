import SwiftUI
import UIKit

/// OLED-black foundation palette shared by every target (the shield extension
/// needs `UIColor`, everything else uses SwiftUI `Color`).
enum HorosPalette {
    enum Hex {
        static let background: UInt32 = 0x000000
        static let card: UInt32 = 0x0D0D0F
        static let cardElevated: UInt32 = 0x141417
        static let border: UInt32 = 0x1F1F24
        static let gold: UInt32 = 0xD4AF37
        static let goldDeep: UInt32 = 0x9C7F22
        static let textPrimary: UInt32 = 0xFFFFFF
        static let textSecondary: UInt32 = 0x9A9AA3
        static let textTertiary: UInt32 = 0x5C5C66
        static let danger: UInt32 = 0xE5484D
        static let success: UInt32 = 0x3DD68C
    }

    static let background = Color(hex: Hex.background)
    static let card = Color(hex: Hex.card)
    static let cardElevated = Color(hex: Hex.cardElevated)
    static let border = Color(hex: Hex.border)
    static let gold = Color(hex: Hex.gold)
    static let goldDeep = Color(hex: Hex.goldDeep)
    static let textPrimary = Color(hex: Hex.textPrimary)
    static let textSecondary = Color(hex: Hex.textSecondary)
    static let textTertiary = Color(hex: Hex.textTertiary)
    static let danger = Color(hex: Hex.danger)
    static let success = Color(hex: Hex.success)

    static let cardCornerRadius: CGFloat = 18
    static let borderWidth: CGFloat = 1
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}

/// Human-friendly duration strings shared by the app and the report extension.
enum DurationFormatter {
    /// "1h 24m", "45m", "0m"
    static func compact(_ interval: TimeInterval) -> String {
        let totalMinutes = Int(interval.rounded()) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }

    /// "00:14:59" style countdown.
    static func clock(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval.rounded()))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    /// "1 hr 30 min", "45 min"
    static func spoken(minutes: Int) -> String {
        let hours = minutes / 60
        let rest = minutes % 60
        switch (hours, rest) {
        case (0, _): return "\(rest) min"
        case (_, 0): return "\(hours) hr"
        default: return "\(hours) hr \(rest) min"
        }
    }
}
