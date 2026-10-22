import SwiftUI
@preconcurrency import FamilyControls

/// Tab 1 — instant focus sessions ("Quick Block").
@MainActor
struct ThresholdView: View {
    @Environment(AppState.self) private var appState
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        @Bindable var model = appState.quickSession
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if appState.authorization.status == .simulatorPreview {
                        previewBanner
                    }
                    if model.state.isActive {
                        ActiveSessionCard(model: model)
                    } else {
                        selectionCard(model)
                        durationCard(model)
                        strictCard(model)
                        startButton(model)
                    }
                    activeRitualsNote
                }
                .padding(16)
            }
            .horosScreen()
            .navigationTitle("Threshold")
            .navigationBarTitleDisplayMode(.large)
            .familyActivityPicker(isPresented: $model.isPickerPresented, selection: $model.selection)
            .onReceive(ticker) { _ in model.tick() }
            .onAppear { model.refresh() }
            .alert(model.alert?.title ?? "HOROS", isPresented: $model.isAlertPresented) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(model.alert?.message ?? "")
            }
        }
    }

    // MARK: - Sections

    private var previewBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "eye")
                .foregroundStyle(HorosPalette.gold)
            Text("Simulator preview — shields are simulated, counters use sample data.")
                .font(.caption)
                .foregroundStyle(HorosPalette.textSecondary)
            Spacer(minLength: 0)
            Button("Exit") { appState.authorization.disablePreviewMode() }
                .font(.caption.weight(.semibold))
                .foregroundStyle(HorosPalette.gold)
        }
        .horosCard(padding: 12, elevated: true)
    }

    private func selectionCard(_ model: QuickSessionViewModel) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "What lies beyond", subtitle: "Apps, categories and websites to shield")
            SelectionSummaryView(selection: model.selection, emptyMessage: "Choose what to block")
            HStack(spacing: 10) {
                Button {
                    model.isPickerPresented = true
                } label: {
                    Label(model.hasSelection ? "Change selection" : "Choose apps", systemImage: "square.grid.2x2")
                }
                .buttonStyle(GhostButtonStyle())
                if model.hasSelection {
                    Button(role: .destructive) {
                        model.clearSelection()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.headline)
                            .frame(width: 52, height: 52)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(HorosPalette.textSecondary)
                    .background(HorosPalette.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(HorosPalette.border, lineWidth: 1))
                    .accessibilityLabel("Clear selection")
                }
            }
        }
        .horosCard()
    }

    private func durationCard(_ model: QuickSessionViewModel) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "How long", subtitle: durationSubtitle(model))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(QuickDuration.allCases) { option in
                        Button(option.title) { model.duration = option }
                            .buttonStyle(ChipButtonStyle(isSelected: model.duration == option))
                            .accessibilityLabel(option.accessibilityLabel)
                    }
                }
            }
            if model.duration == .custom {
                CustomDurationStepper(model: model)
            }
        }
        .horosCard()
    }

    private func durationSubtitle(_ model: QuickSessionViewModel) -> String {
        if let minutes = model.plannedMinutes {
            return "Shield for \(DurationFormatter.spoken(minutes: minutes))"
        }
        return "Shield until you end the session"
    }

    private func strictCard(_ viewModel: QuickSessionViewModel) -> some View {
        @Bindable var model = viewModel
        return VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: $model.isStrict) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Image(systemName: "lock.fill")
                            .foregroundStyle(HorosPalette.gold)
                        Text("Strict mode")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(HorosPalette.textPrimary)
                    }
                    Text(model.strictModeAvailable
                         ? "The Stop button stays locked until the timer runs out."
                         : "Strict mode needs a timer — pick a duration first.")
                        .font(.caption)
                        .foregroundStyle(HorosPalette.textSecondary)
                }
            }
            .toggleStyle(HorosToggleStyle())
            .disabled(!model.strictModeAvailable)
        }
        .horosCard()
    }

    private func startButton(_ model: QuickSessionViewModel) -> some View {
        Button {
            model.start()
        } label: {
            Label("Raise the shield", systemImage: "shield.lefthalf.filled")
        }
        .buttonStyle(GoldButtonStyle())
        .disabled(!model.canStart)
    }

    @ViewBuilder
    private var activeRitualsNote: some View {
        let active = appState.schedules.activeProfiles
        if !active.isEmpty {
            HStack(spacing: 10) {
                Image(systemName: "clock.badge.checkmark")
                    .foregroundStyle(HorosPalette.gold)
                Text(active.count == 1
                     ? "\(active[0].name) is active right now."
                     : "\(active.count) rituals are active right now.")
                    .font(.caption)
                    .foregroundStyle(HorosPalette.textSecondary)
                Spacer(minLength: 0)
                Button("Rituals") { appState.selectedTab = .rituals }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(HorosPalette.gold)
            }
            .horosCard(padding: 12)
        }
    }
}

// MARK: - Active session

@MainActor
struct ActiveSessionCard: View {
    let model: QuickSessionViewModel

    var body: some View {
        VStack(spacing: 18) {
            HStack {
                HorosBadge(text: model.state.isStrict ? "Strict session" : "Session active")
                Spacer()
                if model.state.isStrict {
                    Image(systemName: model.canStop ? "lock.open" : "lock.fill")
                        .foregroundStyle(HorosPalette.gold)
                }
            }

            ZStack {
                Circle()
                    .stroke(HorosPalette.border, lineWidth: 8)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(HorosPalette.gold, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: progress)
                VStack(spacing: 6) {
                    Text(model.countdownText)
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(HorosPalette.textPrimary)
                    Text(model.countdownCaption)
                        .font(.caption)
                        .foregroundStyle(HorosPalette.textSecondary)
                }
            }
            .frame(width: 220, height: 220)
            .padding(.vertical, 8)

            SelectionSummaryView(selection: model.state.selectedApps)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let note = model.monitoringNote {
                Text(note)
                    .font(.caption2)
                    .foregroundStyle(HorosPalette.textTertiary)
                    .multilineTextAlignment(.leading)
            }

            Button {
                model.stop()
            } label: {
                Label(model.canStop ? "End session" : "Locked until the timer ends", systemImage: model.canStop ? "stop.fill" : "lock.fill")
            }
            .buttonStyle(GhostButtonStyle(tint: model.canStop ? HorosPalette.danger : HorosPalette.textTertiary))
            .disabled(!model.canStop)
        }
        .horosCard(padding: 20)
    }

    private var progress: CGFloat {
        guard let start = model.state.startTime, let end = model.state.endTime else { return 1 }
        let total = end.timeIntervalSince(start)
        guard total > 0, let remaining = model.remaining else { return 1 }
        return CGFloat(max(0, min(1, remaining / total)))
    }
}

// MARK: - Custom duration

@MainActor
struct CustomDurationStepper: View {
    let model: QuickSessionViewModel

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(DurationFormatter.spoken(minutes: model.customMinutes))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(HorosPalette.textPrimary)
                    .monospacedDigit()
                Text("Custom duration")
                    .font(.caption)
                    .foregroundStyle(HorosPalette.textTertiary)
            }
            Spacer()
            HStack(spacing: 6) {
                stepButton("-15", -15)
                stepButton("-5", -5)
                stepButton("+5", 5)
                stepButton("+15", 15)
            }
        }
        .padding(.top, 4)
    }

    private func stepButton(_ title: String, _ delta: Int) -> some View {
        Button(title) { model.updateCustomMinutes(model.customMinutes + delta) }
            .buttonStyle(ChipButtonStyle(isSelected: false))
    }
}
