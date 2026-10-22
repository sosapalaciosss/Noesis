import SwiftUI

/// Permission gate shown until Family Controls is approved (or preview mode
/// is enabled in the Simulator).
struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openURL) private var openURL

    var body: some View {
        @Bindable var authorization = appState.authorization
        ScrollView {
            VStack(spacing: 28) {
                Spacer(minLength: 40)
                hero
                principles
                actions
                Spacer(minLength: 24)
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .background(HorosPalette.background.ignoresSafeArea())
        .alert(authorization.alert?.title ?? "HOROS", isPresented: $authorization.isAlertPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(authorization.alert?.message ?? "")
        }
    }

    private var hero: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(HorosPalette.gold.opacity(0.25), lineWidth: 1)
                    .frame(width: 132, height: 132)
                Circle()
                    .stroke(HorosPalette.border, lineWidth: 1)
                    .frame(width: 104, height: 104)
                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 48, weight: .thin))
                    .foregroundStyle(HorosPalette.gold)
            }
            .padding(.bottom, 6)

            Text("HOROS")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .tracking(6)
                .foregroundStyle(HorosPalette.textPrimary)

            Text("The boundary between you and the feed.")
                .font(.title3)
                .foregroundStyle(HorosPalette.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    private var principles: some View {
        VStack(spacing: 12) {
            principle(
                icon: "lock.shield",
                title: "On-device, private by design",
                detail: "HOROS uses Apple's Screen Time API. It never sees which apps you choose — only opaque tokens."
            )
            principle(
                icon: "timer",
                title: "Quick sessions and rituals",
                detail: "Block instantly, or schedule recurring windows that raise themselves even when the app is closed."
            )
            principle(
                icon: "chart.bar.xaxis",
                title: "Count every attempt",
                detail: "Each tap on the block screen is recorded, so you can watch the urge fade day by day."
            )
        }
    }

    private func principle(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(HorosPalette.gold)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(HorosPalette.textPrimary)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(HorosPalette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .horosCard(padding: 14)
    }

    @ViewBuilder
    private var actions: some View {
        let authorization = appState.authorization
        VStack(spacing: 12) {
            switch authorization.status {
            case .denied:
                Text("Screen Time access was declined. HOROS cannot raise a single shield without it.")
                    .font(.footnote)
                    .foregroundStyle(HorosPalette.danger)
                    .multilineTextAlignment(.center)
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                } label: {
                    Label("Open Settings", systemImage: "gear")
                }
                .buttonStyle(GoldButtonStyle())
                Button("Try again") {
                    Task { await authorization.requestAccess() }
                }
                .buttonStyle(GhostButtonStyle())

            default:
                Button {
                    Task { await authorization.requestAccess() }
                } label: {
                    HStack(spacing: 10) {
                        if authorization.isRequesting {
                            ProgressView()
                                .tint(HorosPalette.background)
                        }
                        Text(authorization.isRequesting ? "Waiting for Screen Time…" : "Grant Screen Time Access")
                    }
                }
                .buttonStyle(GoldButtonStyle())
                .disabled(authorization.isRequesting)
            }

            if AuthorizationViewModel.isSimulator {
                Button {
                    authorization.enablePreviewMode()
                } label: {
                    Label("Continue in Simulator preview mode", systemImage: "eye")
                }
                .buttonStyle(GhostButtonStyle(tint: HorosPalette.textSecondary))

                Text("Family Controls cannot be granted in the Simulator. Preview mode unlocks the full UI with sample analytics; shields only work on a physical device.")
                    .font(.caption2)
                    .foregroundStyle(HorosPalette.textTertiary)
                    .multilineTextAlignment(.center)
            }
        }
    }
}
