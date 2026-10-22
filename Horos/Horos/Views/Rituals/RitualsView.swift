import SwiftUI

/// Tab 2 — recurring blocking schedules.
struct RitualsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var model = appState.schedules
        NavigationStack {
            Group {
                if model.profiles.isEmpty {
                    emptyState(model)
                } else {
                    List {
                        ForEach(model.profiles) { profile in
                            ProfileRowView(
                                profile: profile,
                                failure: model.failureMessage(for: profile),
                                isLocked: model.isLockedByStrictMode(profile),
                                onToggle: { model.toggle(profile) }
                            )
                            .contentShape(Rectangle())
                            .onTapGesture { model.beginEditing(profile) }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    model.delete(profile)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                Button {
                                    model.beginEditing(profile)
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(HorosPalette.goldDeep)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .horosScreen()
            .navigationTitle("Rituals")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        model.beginCreating()
                    } label: {
                        Image(systemName: "plus")
                            .font(.headline)
                    }
                    .accessibilityLabel("New ritual")
                }
            }
            .sheet(isPresented: $model.isCreatingProfile) {
                ProfileEditorView(profile: nil) { draft in
                    model.save(draft)
                }
            }
            .sheet(item: $model.editingProfile) { profile in
                ProfileEditorView(profile: profile, onSave: { draft in
                    model.save(draft)
                }, onDelete: {
                    model.delete(profile)
                })
            }
            .onAppear { model.load() }
            .alert(model.alert?.title ?? "HOROS", isPresented: $model.isAlertPresented) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(model.alert?.message ?? "")
            }
        }
    }

    private func emptyState(_ model: SchedulesViewModel) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.badge.checkmark")
                .font(.system(size: 44, weight: .thin))
                .foregroundStyle(HorosPalette.gold)
            Text("No rituals yet")
                .font(.title3.weight(.semibold))
                .foregroundStyle(HorosPalette.textPrimary)
            Text("A ritual is a recurring window — evenings, mornings, work hours — during which the shield raises itself. iOS enforces it even when HOROS is closed.")
                .font(.footnote)
                .foregroundStyle(HorosPalette.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Button {
                model.beginCreating()
            } label: {
                Label("Create your first ritual", systemImage: "plus")
            }
            .buttonStyle(GoldButtonStyle())
            .padding(.horizontal, 32)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

struct ProfileRowView: View {
    let profile: BlockingProfile
    let failure: String?
    let isLocked: Bool
    let onToggle: () -> Void

    private var isActiveNow: Bool { profile.isActive() }
    private var isEnabled: Bool { profile.isEnabled }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(profile.name)
                            .font(.headline)
                            .foregroundStyle(profile.isEnabled ? HorosPalette.textPrimary : HorosPalette.textSecondary)
                        if isActiveNow {
                            HorosBadge(text: "Active")
                        }
                        if profile.isStrict {
                            Image(systemName: isLocked ? "lock.fill" : "lock")
                                .font(.caption)
                                .foregroundStyle(HorosPalette.gold)
                        }
                    }
                    Text("\(profile.formattedWindow()) · \(profile.daysOfWeek.summary)")
                        .font(.subheadline)
                        .foregroundStyle(HorosPalette.textSecondary)
                    Text(detailLine)
                        .font(.caption)
                        .foregroundStyle(HorosPalette.textTertiary)
                }
                Spacer(minLength: 8)
                Toggle("", isOn: Binding(get: { isEnabled }, set: { _ in onToggle() }))
                    .labelsHidden()
                    .toggleStyle(HorosToggleStyle())
            }

            if let failure {
                Label(failure, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(HorosPalette.danger)
            }
        }
        .horosCard(padding: 14)
        .opacity(profile.isEnabled ? 1 : 0.7)
    }

    private var detailLine: String {
        var parts = [FamilyActivitySelectionCoder.summary(profile.activitySelection)]
        if let allowance = profile.dailyAllowanceMinutes, allowance > 0 {
            parts.append("\(DurationFormatter.spoken(minutes: allowance)) allowance")
        }
        if !isActiveNow, let next = profile.nextStart() {
            parts.append("next \(next.formatted(.dateTime.weekday(.abbreviated).hour().minute()))")
        }
        return parts.joined(separator: " · ")
    }
}
