import SwiftUI

/// Seven round toggles in locale order.
@MainActor
struct WeekdayPicker: View {
    @Binding var selection: Set<Weekday>

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                ForEach(Weekday.localeOrdered()) { day in
                    let isOn = selection.contains(day)
                    Button {
                        if isOn { selection.remove(day) } else { selection.insert(day) }
                    } label: {
                        Text(day.veryShortSymbol())
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(isOn ? HorosPalette.background : HorosPalette.textSecondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .background(isOn ? HorosPalette.gold : HorosPalette.cardElevated, in: Circle())
                            .overlay(Circle().stroke(isOn ? HorosPalette.gold : HorosPalette.border, lineWidth: HorosPalette.borderWidth))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(day.fullSymbol())
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                }
            }

            HStack(spacing: 8) {
                presetButton("Every day", Weekday.everyDay)
                presetButton("Weekdays", Weekday.workdays)
                presetButton("Weekends", Weekday.weekend)
            }
        }
    }

    private func presetButton(_ title: String, _ preset: Set<Weekday>) -> some View {
        Button(title) { selection = preset }
            .buttonStyle(ChipButtonStyle(isSelected: selection == preset))
    }
}
