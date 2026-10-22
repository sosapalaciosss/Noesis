import SwiftUI
@preconcurrency import FamilyControls

/// Shows what is currently selected for blocking: counts plus a strip of app
/// and category icons rendered through the privacy-preserving `Label(token)`.
@MainActor
struct SelectionSummaryView: View {
    let selection: FamilyActivitySelection
    var emptyMessage = "Nothing selected yet"

    private var isEmpty: Bool { FamilyActivitySelectionCoder.isEmpty(selection) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "app.dashed")
                        .foregroundStyle(HorosPalette.textTertiary)
                    Text(emptyMessage)
                        .font(.subheadline)
                        .foregroundStyle(HorosPalette.textSecondary)
                }
            } else {
                Text(FamilyActivitySelectionCoder.summary(selection))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(HorosPalette.textPrimary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(selection.applicationTokens.prefix(12)), id: \.self) { token in
                            Label(token)
                                .labelStyle(.iconOnly)
                                .frame(width: 36, height: 36)
                        }
                        ForEach(Array(selection.categoryTokens.prefix(8)), id: \.self) { token in
                            Label(token)
                                .labelStyle(.iconOnly)
                                .frame(width: 36, height: 36)
                        }
                        if selection.webDomainTokens.count > 0 {
                            Image(systemName: "globe")
                                .font(.title3)
                                .foregroundStyle(HorosPalette.gold)
                                .frame(width: 36, height: 36)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }
}
