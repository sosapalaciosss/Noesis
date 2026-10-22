import SwiftUI

// MARK: - Card

struct HorosCardModifier: ViewModifier {
    var padding: CGFloat = 16
    var elevated = false

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                elevated ? HorosPalette.cardElevated : HorosPalette.card,
                in: RoundedRectangle(cornerRadius: HorosPalette.cardCornerRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: HorosPalette.cardCornerRadius, style: .continuous)
                    .stroke(HorosPalette.border, lineWidth: HorosPalette.borderWidth)
            )
    }
}

extension View {
    func horosCard(padding: CGFloat = 16, elevated: Bool = false) -> some View {
        modifier(HorosCardModifier(padding: padding, elevated: elevated))
    }

    /// Standard screen chrome: OLED background, dark bars, gold tint.
    func horosScreen() -> some View {
        self
            .background(HorosPalette.background.ignoresSafeArea())
            .toolbarBackground(HorosPalette.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(HorosPalette.background, for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .scrollContentBackground(.hidden)
    }
}

// MARK: - Buttons

struct GoldButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .foregroundStyle(HorosPalette.background)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                (isEnabled ? HorosPalette.gold : HorosPalette.goldDeep.opacity(0.45)),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .opacity(configuration.isPressed ? 0.82 : 1)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct GhostButtonStyle: ButtonStyle {
    var tint: Color = HorosPalette.textPrimary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.medium))
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(HorosPalette.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(HorosPalette.border, lineWidth: HorosPalette.borderWidth)
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct ChipButtonStyle: ButtonStyle {
    var isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(isSelected ? HorosPalette.background : HorosPalette.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                isSelected ? HorosPalette.gold : HorosPalette.cardElevated,
                in: Capsule()
            )
            .overlay(
                Capsule().stroke(isSelected ? HorosPalette.gold : HorosPalette.border, lineWidth: HorosPalette.borderWidth)
            )
            .opacity(configuration.isPressed ? 0.75 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Typography helpers

struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .tracking(1.4)
                .foregroundStyle(HorosPalette.textSecondary)
            if let subtitle {
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(HorosPalette.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct StatTile: View {
    let title: String
    let value: String
    var caption: String? = nil
    var accent: Color = HorosPalette.gold
    var systemImage: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(accent)
                }
                Text(title.uppercased())
                    .font(.caption2.weight(.semibold))
                    .tracking(1.2)
                    .foregroundStyle(HorosPalette.textSecondary)
            }
            Text(value)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(HorosPalette.textPrimary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if let caption {
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(HorosPalette.textTertiary)
                    .lineLimit(2)
            }
        }
        .horosCard(padding: 14)
    }
}

struct HorosToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Toggle(isOn: configuration.$isOn) {
            configuration.label
        }
        .toggleStyle(.switch)
        .tint(HorosPalette.gold)
    }
}

struct HorosBadge: View {
    let text: String
    var color: Color = HorosPalette.gold

    var body: some View {
        Text(text.uppercased())
            .font(.caption2.weight(.bold))
            .tracking(1)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12), in: Capsule())
            .overlay(Capsule().stroke(color.opacity(0.4), lineWidth: HorosPalette.borderWidth))
    }
}
