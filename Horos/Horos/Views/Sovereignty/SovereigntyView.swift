import SwiftUI
@preconcurrency import DeviceActivity

/// Tab 3 — blocked-attempt analytics and real Screen Time usage.
@MainActor
struct SovereigntyView: View {
    @Environment(AppState.self) private var appState
    @State private var showResetConfirmation = false

    var body: some View {
        let model = appState.analytics
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    statGrid(model)
                    AttemptsChartView(series: model.series, peak: model.peakDay)
                    ScreenTimeReportCard(
                        filter: model.reportFilter,
                        selectionSummary: model.reportSelectionSummary,
                        isPreview: appState.authorization.status == .simulatorPreview
                    )
                    RecentAttemptsList(events: model.recentEvents)
                }
                .padding(16)
            }
            .refreshable { await MainActor.run { model.refresh() } }
            .horosScreen()
            .navigationTitle("Sovereignty")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(role: .destructive) {
                            showResetConfirmation = true
                        } label: {
                            Label("Reset attempt history", systemImage: "trash")
                        }
                        Button(role: .destructive) {
                            appState.engine.clearAllShields()
                            appState.refreshAll()
                        } label: {
                            Label("Lift every shield now", systemImage: "shield.slash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.headline)
                    }
                    .accessibilityLabel("More")
                }
            }
            .confirmationDialog("Reset attempt history?", isPresented: $showResetConfirmation, titleVisibility: .visible) {
                Button("Reset", role: .destructive) { model.resetHistory() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Counters, the 7-day chart and your streak start again from zero.")
            }
            .onAppear { model.refresh(previewMode: appState.authorization.status == .simulatorPreview) }
        }
    }

    private func statGrid(_ model: AnalyticsViewModel) -> some View {
        VStack(spacing: 12) {
            StatTile(
                title: "Blocked attempts today",
                value: "\(model.attemptsToday)",
                caption: changeCaption(model.dayOverDayChange),
                systemImage: "hand.raised.fill"
            )
            HStack(spacing: 12) {
                StatTile(
                    title: "Streak",
                    value: "\(model.streak)d",
                    caption: model.streak == 0 ? "Raise a shield to begin" : "consecutive protected days",
                    systemImage: "flame.fill"
                )
                StatTile(
                    title: "This week",
                    value: "\(model.attemptsThisWeek)",
                    caption: "attempts in 7 days",
                    systemImage: "calendar"
                )
            }
        }
    }

    private func changeCaption(_ change: Double?) -> String {
        guard let change else { return "No attempts yesterday to compare with" }
        let percent = abs(Int((change * 100).rounded()))
        if change < 0 { return "\(percent)% fewer than yesterday" }
        if change > 0 { return "\(percent)% more than yesterday" }
        return "Same as yesterday"
    }
}

// MARK: - Attempts chart

@MainActor
struct AttemptsChartView: View {
    let series: [DailyAttemptCount]
    let peak: DailyAttemptCount?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: "Last 7 days",
                subtitle: peak.map { "Peak \($0.count) on \($0.date.formatted(.dateTime.weekday(.wide)))" } ?? "Blocked attempts per day"
            )
            AttemptsBarChart(series: series)
                .frame(height: 170)
        }
        .horosCard()
    }
}

// MARK: - Recent attempts

@MainActor
struct RecentAttemptsList: View {
    let events: [BlockAttemptEvent]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Today's attempts", subtitle: events.isEmpty ? "Nothing intercepted yet" : "Most recent first")
            if events.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.seal")
                        .foregroundStyle(HorosPalette.success)
                    Text("The threshold has held all day.")
                        .font(.subheadline)
                        .foregroundStyle(HorosPalette.textSecondary)
                }
            } else {
                ForEach(events) { event in
                    HStack(spacing: 12) {
                        Image(systemName: icon(for: event.kind))
                            .foregroundStyle(HorosPalette.gold)
                            .frame(width: 22)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(event.kind.label) · \(event.button == .primary ? "held the line" : "returned")")
                                .font(.subheadline)
                                .foregroundStyle(HorosPalette.textPrimary)
                            Text("Target \(String(event.tokenHash.prefix(8)))")
                                .font(.caption2)
                                .foregroundStyle(HorosPalette.textTertiary)
                                .monospaced()
                        }
                        Spacer()
                        Text(event.timestamp.formatted(date: .omitted, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(HorosPalette.textSecondary)
                            .monospacedDigit()
                    }
                    .padding(.vertical, 2)
                    if event.id != events.last?.id {
                        Divider().overlay(HorosPalette.border)
                    }
                }
            }
        }
        .horosCard()
    }

    private func icon(for kind: BlockedTargetKind) -> String {
        switch kind {
        case .application: return "app.badge"
        case .category: return "square.grid.2x2"
        case .webDomain: return "globe"
        }
    }
}
