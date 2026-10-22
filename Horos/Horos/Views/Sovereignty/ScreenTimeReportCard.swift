import SwiftUI
import Charts
@preconcurrency import DeviceActivity

/// Hosts the sandboxed `DeviceActivityReport` (rendered by the report
/// extension) or, in the Simulator, a representative placeholder.
@MainActor
struct ScreenTimeReportCard: View {
    let filter: DeviceActivityFilter
    let selectionSummary: String
    let isPreview: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Screen time", subtitle: "Real usage for \(selectionSummary.lowercased()) · last 7 days")
            if isPreview {
                PreviewScreenTimeView()
            } else {
                DeviceActivityReport(.horosTotalActivity, filter: filter)
                    .frame(height: 560)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .horosCard()
    }
}

/// Simulator stand-in for the report extension (which only runs on device).
@MainActor
struct PreviewScreenTimeView: View {
    private struct Sample: Identifiable {
        let day: Date
        let minutes: Double
        var id: Date { day }
    }

    private var samples: [Sample] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let pattern: [Double] = [212, 198, 176, 151, 143, 118, 96]
        return pattern.enumerated().compactMap { index, minutes in
            guard let day = calendar.date(byAdding: .day, value: index - (pattern.count - 1), to: today) else { return nil }
            return Sample(day: day, minutes: minutes)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("1h 36m")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(HorosPalette.textPrimary)
                Text("today · 19% less than yesterday")
                    .font(.caption)
                    .foregroundStyle(HorosPalette.success)
            }
            Chart(samples) { sample in
                BarMark(
                    x: .value("Day", sample.day, unit: .day),
                    y: .value("Minutes", sample.minutes)
                )
                .foregroundStyle(Calendar.current.isDateInToday(sample.day) ? HorosPalette.gold : HorosPalette.gold.opacity(0.35))
                .cornerRadius(5)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisValueLabel(format: .dateTime.weekday(.abbreviated), centered: true)
                        .foregroundStyle(HorosPalette.textSecondary)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine().foregroundStyle(HorosPalette.border)
                    AxisValueLabel().foregroundStyle(HorosPalette.textTertiary)
                }
            }
            .frame(height: 150)
            Text("Sample data. On a device this card embeds the DeviceActivityReport extension with your real Screen Time.")
                .font(.caption2)
                .foregroundStyle(HorosPalette.textTertiary)
        }
    }
}
