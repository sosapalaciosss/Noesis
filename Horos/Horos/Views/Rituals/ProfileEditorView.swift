import SwiftUI
@preconcurrency import FamilyControls

/// Create / edit sheet for a `BlockingProfile`.
@MainActor
struct ProfileEditorView: View {
    @Environment(\.dismiss) private var dismiss

    private let isNew: Bool
    private let onSave: (BlockingProfile) -> Void
    private let onDelete: (() -> Void)?

    @State private var draft: BlockingProfile
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var allowanceEnabled: Bool
    @State private var allowanceMinutes: Int
    @State private var isPickerPresented = false
    @State private var showDeleteConfirmation = false

    init(profile: BlockingProfile?, onSave: @escaping (BlockingProfile) -> Void, onDelete: (() -> Void)? = nil) {
        let initial = profile ?? BlockingProfile(name: "")
        self.isNew = profile == nil
        self.onSave = onSave
        self.onDelete = onDelete
        _draft = State(initialValue: initial)
        _startDate = State(initialValue: Self.date(from: initial.startTime))
        _endDate = State(initialValue: Self.date(from: initial.endTime))
        _allowanceEnabled = State(initialValue: initial.hasAllowance)
        _allowanceMinutes = State(initialValue: initial.dailyAllowanceMinutes ?? 30)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    nameCard
                    selectionCard
                    windowCard
                    daysCard
                    allowanceCard
                    strictCard
                    if !isNew, onDelete != nil {
                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Label("Delete ritual", systemImage: "trash")
                        }
                        .buttonStyle(GhostButtonStyle(tint: HorosPalette.danger))
                    }
                }
                .padding(16)
            }
            .horosScreen()
            .navigationTitle(isNew ? "New ritual" : "Edit ritual")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(HorosPalette.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(composedProfile)
                        dismiss()
                    }
                    .font(.headline)
                    .foregroundStyle(canSave ? HorosPalette.gold : HorosPalette.textTertiary)
                    .disabled(!canSave)
                }
            }
            .familyActivityPicker(isPresented: $isPickerPresented, selection: $draft.activitySelection)
            .confirmationDialog("Delete this ritual?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    onDelete?()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
        .presentationBackground(HorosPalette.background)
        .preferredColorScheme(.dark)
    }

    // MARK: - Derived

    private var composedProfile: BlockingProfile {
        var profile = draft
        profile.startTime = Self.components(from: startDate)
        profile.endTime = Self.components(from: endDate)
        profile.dailyAllowanceMinutes = allowanceEnabled ? max(1, allowanceMinutes) : nil
        return profile
    }

    private var validationMessage: String? {
        let profile = composedProfile
        if !profile.hasSelection { return "Choose at least one app, category or website." }
        if profile.daysOfWeek.isEmpty { return "Pick at least one day." }
        if profile.durationMinutes < HorosConstants.minimumScheduleMinutes {
            return "The window must last at least \(HorosConstants.minimumScheduleMinutes) minutes."
        }
        if allowanceEnabled, allowanceMinutes >= profile.durationMinutes {
            return "The allowance must be shorter than the window."
        }
        return nil
    }

    private var canSave: Bool { validationMessage == nil }

    // MARK: - Cards

    private var nameCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Name")
            TextField("Evening stillness", text: $draft.name)
                .font(.title3.weight(.semibold))
                .foregroundStyle(HorosPalette.textPrimary)
                .textInputAutocapitalization(.words)
                .submitLabel(.done)
        }
        .horosCard()
    }

    private var selectionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "What lies beyond")
            SelectionSummaryView(selection: draft.activitySelection, emptyMessage: "Choose what to block")
            Button {
                isPickerPresented = true
            } label: {
                Label(draft.hasSelection ? "Change selection" : "Choose apps", systemImage: "square.grid.2x2")
            }
            .buttonStyle(GhostButtonStyle())
        }
        .horosCard()
    }

    private var windowCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Window", subtitle: windowSubtitle)
            HStack {
                timePicker("From", $startDate)
                Spacer()
                Image(systemName: "arrow.right")
                    .foregroundStyle(HorosPalette.textTertiary)
                Spacer()
                timePicker("Until", $endDate)
            }
            if let validationMessage, validationMessage.contains("window") {
                Text(validationMessage)
                    .font(.caption)
                    .foregroundStyle(HorosPalette.danger)
            }
        }
        .horosCard()
    }

    private var windowSubtitle: String {
        let profile = composedProfile
        let duration = DurationFormatter.spoken(minutes: profile.durationMinutes)
        return profile.spansMidnight ? "\(duration), overnight" : duration
    }

    private func timePicker(_ title: String, _ binding: Binding<Date>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .tracking(1)
                .foregroundStyle(HorosPalette.textTertiary)
            DatePicker("", selection: binding, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .datePickerStyle(.compact)
                .tint(HorosPalette.gold)
        }
    }

    private var daysCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Days", subtitle: draft.daysOfWeek.summary)
            WeekdayPicker(selection: $draft.daysOfWeek)
        }
        .horosCard()
    }

    private var allowanceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $allowanceEnabled) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Image(systemName: "hourglass")
                            .foregroundStyle(HorosPalette.gold)
                        Text("Usage allowance")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(HorosPalette.textPrimary)
                    }
                    Text("Let the apps run for a limited time inside the window; the shield rises once the allowance is spent.")
                        .font(.caption)
                        .foregroundStyle(HorosPalette.textSecondary)
                }
            }
            .toggleStyle(HorosToggleStyle())

            if allowanceEnabled {
                Stepper(value: $allowanceMinutes, in: 5...(24 * 60), step: 5) {
                    Text("\(DurationFormatter.spoken(minutes: allowanceMinutes)) per window")
                        .font(.subheadline)
                        .foregroundStyle(HorosPalette.textPrimary)
                        .monospacedDigit()
                }
                .tint(HorosPalette.gold)
                if let validationMessage, validationMessage.contains("allowance") {
                    Text(validationMessage)
                        .font(.caption)
                        .foregroundStyle(HorosPalette.danger)
                }
            }
        }
        .horosCard()
    }

    private var strictCard: some View {
        Toggle(isOn: $draft.isStrict) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(HorosPalette.gold)
                    Text("Strict ritual")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(HorosPalette.textPrimary)
                }
                Text("Cannot be paused, edited or deleted while its window is active.")
                    .font(.caption)
                    .foregroundStyle(HorosPalette.textSecondary)
            }
        }
        .toggleStyle(HorosToggleStyle())
        .horosCard()
    }

    // MARK: - Date helpers

    private static func date(from components: DateComponents, calendar: Calendar = .current) -> Date {
        var anchor = calendar.dateComponents([.year, .month, .day], from: Date())
        anchor.hour = components.hour ?? 0
        anchor.minute = components.minute ?? 0
        anchor.second = 0
        return calendar.date(from: anchor) ?? Date()
    }

    private static func components(from date: Date, calendar: Calendar = .current) -> DateComponents {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return DateComponents(hour: parts.hour ?? 0, minute: parts.minute ?? 0)
    }
}
