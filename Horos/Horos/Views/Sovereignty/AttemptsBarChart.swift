import SwiftUI
import Charts

/// Swift Charts bar chart of blocked attempts, today highlighted in gold.
@MainActor
struct AttemptsBarChart: View {
    let series: [DailyAttemptCount]

    private var maxCount: Int { series.map(\.count).max() ?? 0 }

    var body: some View {
        Chart(series) { day in
            BarMark(
                x: .value("Day", day.date, unit: .day),
                y: .value("Attempts", day.count)
            )
            .foregroundStyle(day.isToday ? HorosPalette.gold : HorosPalette.gold.opacity(0.35))
            .cornerRadius(6)
            .annotation(position: .top, alignment: .center) {
                if day.count > 0 {
                    Text("\(day.count)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(day.isToday ? HorosPalette.gold : HorosPalette.textSecondary)
                        .monospacedDigit()
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { _ in
                AxisValueLabel(format: .dateTime.weekday(.abbreviated), centered: true)
                    .foregroundStyle(HorosPalette.textSecondary)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine().foregroundStyle(HorosPalette.border)
                AxisValueLabel().foregroundStyle(HorosPalette.textTertiary)
            }
        }
        .chartYScale(domain: 0...Double(max(4, maxCount + 1)))
    }
}
