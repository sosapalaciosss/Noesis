import Foundation
@preconcurrency import FamilyControls

/// Serialises `FamilyActivitySelection` through `PropertyListEncoder` so the
/// opaque tokens survive the trip through the App Group untouched, and offers
/// a handful of set-algebra helpers the engine and UI share.
enum FamilyActivitySelectionCoder {
    static func encode(_ selection: FamilyActivitySelection) -> Data {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        return (try? encoder.encode(selection)) ?? Data()
    }

    static func decode(_ data: Data) -> FamilyActivitySelection {
        guard !data.isEmpty else { return FamilyActivitySelection() }
        return (try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: data))
            ?? FamilyActivitySelection()
    }

    static func isEqual(_ lhs: FamilyActivitySelection, _ rhs: FamilyActivitySelection) -> Bool {
        lhs.applicationTokens == rhs.applicationTokens
            && lhs.categoryTokens == rhs.categoryTokens
            && lhs.webDomainTokens == rhs.webDomainTokens
    }

    static func isEmpty(_ selection: FamilyActivitySelection) -> Bool {
        selection.applicationTokens.isEmpty
            && selection.categoryTokens.isEmpty
            && selection.webDomainTokens.isEmpty
    }

    static func count(_ selection: FamilyActivitySelection) -> Int {
        selection.applicationTokens.count
            + selection.categoryTokens.count
            + selection.webDomainTokens.count
    }

    static func union(_ selections: [FamilyActivitySelection]) -> FamilyActivitySelection {
        var result = FamilyActivitySelection()
        for selection in selections {
            result.applicationTokens.formUnion(selection.applicationTokens)
            result.categoryTokens.formUnion(selection.categoryTokens)
            result.webDomainTokens.formUnion(selection.webDomainTokens)
        }
        return result
    }

    /// Short description such as "4 apps · 2 categories".
    static func summary(_ selection: FamilyActivitySelection) -> String {
        var parts: [String] = []
        let apps = selection.applicationTokens.count
        let categories = selection.categoryTokens.count
        let domains = selection.webDomainTokens.count
        if apps > 0 { parts.append("\(apps) app\(apps == 1 ? "" : "s")") }
        if categories > 0 { parts.append("\(categories) categor\(categories == 1 ? "y" : "ies")") }
        if domains > 0 { parts.append("\(domains) site\(domains == 1 ? "" : "s")") }
        return parts.isEmpty ? "Nothing selected" : parts.joined(separator: " · ")
    }
}
