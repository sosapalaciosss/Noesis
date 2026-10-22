import SwiftUI
import Charts

/// Rendered inside the host app's `DeviceActivityReport` frame. The sandbox
/// forbids network and persistence, so the view is purely presentational.
struct TotalActivityView: View {
    let summary: ActivityReportSummary

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                header
                if summary.hasData {
                    dailyChart
                    topApps
                    if !summary.categories.isEmpty {
                        categoryBreakdown
                    }
                } else {
                    emptyState
                }
            }
            .padding(16)
        }
        .background(HorosPalette.background)
        .preferredColorScheme(.dark)
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("SCREEN TIME · TODAY")
                .font(.caption.weight(.semibold))
                .tracking(1.4)
                .foregroundStyle(HorosPalette.textSecondary)

            Text(DurationFormatter.compact(summary.todayDuration))
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(HorosPalette.textPrimary)
                .monospacedDigit()

            HStack(spacing: 12) {
                trendBadge(title: "vs yesterday", change: summary.dayOverDayChange)
                trendBadge(title: "vs 7-day avg", change: summary.trendVersusAverage)
            }
        }
    }

    private func trendBadge(title: String, change: Double?) -> some View {
        HStack(spacing: 4) {
            if let change {
                let fewer = change < 0
                Image(systemName: fewer ? "arrow.down.right" : "arrow.up.right")
                    .font(.caption2.weight(.bold))
                Text("\(abs(Int((change * 100).rounded())))%")
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                Text(title)
                    .font(.caption)
                    .foregroundStyle(HorosPalette.textSecondary)
            } else {
                Text("No baseline \(title)")
                    .font(.caption)
                    .foregroundStyle(HorosPalette.textTertiary)
            }
        }
        .foregroundStyle(changeColor(change))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(HorosPalette.card, in: Capsule())
        .overlay(Capsule().stroke(HorosPalette.border, lineWidth: HorosPalette.borderWidth))
    }

    private func changeColor(_ change: Double?) -> Color {
        guard let change else { return HorosPalette.textTertiary }
        return change < 0 ? HorosPalette.success : HorosPalette.danger
    }

    private var dailyChart: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Last \(summary.days.count) days")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(HorosPalette.textPrimary)

            Chart(summary.days) { day in
                BarMark(
                    x: .value("Day", day.date, unit: .day),
                    y: .value("Minutes", day.duration / 60)
                )
                .foregroundStyle(day.isToday ? HorosPalette.gold : HorosPalette.gold.opacity(0.35))
                .cornerRadius(5)

                if summary.averageDuration > 0 {
                    RuleMark(y: .value("Average", summary.averageDuration / 60))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .foregroundStyle(HorosPalette.textTertiary)
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                        .foregroundStyle(HorosPalette.textSecondary)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine().foregroundStyle(HorosPalette.border)
                    if let minutes = value.as(Double.self) {
                        AxisValueLabel {
                            Text(DurationFormatter.compact(minutes * 60))
                                .font(.caption2)
                                .foregroundStyle(HorosPalette.textSecondary)
                        }
                    }
                }
            }
            .frame(height: 150)
        }
        .padding(14)
        .background(HorosPalette.card, in: RoundedRectangle(cornerRadius: HorosPalette.cardCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: HorosPalette.cardCornerRadius, style: .continuous)
                .stroke(HorosPalette.border, lineWidth: HorosPalette.borderWidth)
        )
    }

    private var topApps: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Where the time went")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(HorosPalette.textPrimary)

            ForEach(Array(summary.apps.prefix(6))) { app in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(app.name)
                            .font(.subheadline)
                            .foregroundStyle(HorosPalette.textPrimary)
                            .lineLimit(1)
                        Spacer()
                        Text(DurationFormatter.compact(app.duration))
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(HorosPalette.gold)
                    }
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(HorosPalette.border)
                            Capsule()
                                .fill(HorosPalette.gold)
                                .frame(width: max(4, proxy.size.width * app.share))
                        }
                    }
                    .frame(height: 5)
                    HStack(spacing: 10) {
                        Label("\(app.pickups) pickups", systemImage: "hand.tap")
                        Label("\(app.notifications) notifications", systemImage: "bell")
                    }
                    .font(.caption2)
                    .foregroundStyle(HorosPalette.textTertiary)
                }
            }
        }
        .padding(14)
        .background(HorosPalette.card, in: RoundedRectangle(cornerRadius: HorosPalette.cardCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: HorosPalette.cardCornerRadius, style: .continuous)
                .stroke(HorosPalette.border, lineWidth: HorosPalette.borderWidth)
        )
    }

    private var categoryBreakdown: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("By category")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(HorosPalette.textPrimary)

            Chart(Array(summary.categories.prefix(5))) { category in
                BarMark(
                    x: .value("Minutes", category.duration / 60),
                    y: .value("Category", category.name)
                )
                .foregroundStyle(HorosPalette.gold.opacity(0.75))
                .cornerRadius(4)
                .annotation(position: .trailing, alignment: .leading) {
                    Text(DurationFormatter.compact(category.duration))
                        .font(.caption2)
                        .foregroundStyle(HorosPalette.textSecondary)
                }
            }
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisValueLabel()
                        .foregroundStyle(HorosPalette.textSecondary)
                }
            }
            .frame(height: CGFloat(min(summary.categories.count, 5)) * 34 + 10)
        }
        .padding(14)
        .background(HorosPalette.card, in: RoundedRectangle(cornerRadius: HorosPalette.cardCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: HorosPalette.cardCornerRadius, style: .continuous)
                .stroke(HorosPalette.border, lineWidth: HorosPalette.borderWidth)
        )
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "hourglass")
                .font(.system(size: 28, weight: .thin))
                .foregroundStyle(HorosPalette.gold)
            Text("No Screen Time recorded yet")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(HorosPalette.textPrimary)
            Text("Usage for the selected apps will appear here once iOS has collected a day of activity.")
                .font(.caption)
                .foregroundStyle(HorosPalette.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(HorosPalette.card, in: RoundedRectangle(cornerRadius: HorosPalette.cardCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: HorosPalette.cardCornerRadius, style: .continuous)
                .stroke(HorosPalette.border, lineWidth: HorosPalette.borderWidth)
        )
    }
}
