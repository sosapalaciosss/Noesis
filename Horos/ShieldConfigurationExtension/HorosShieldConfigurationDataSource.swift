@preconcurrency import ManagedSettings
@preconcurrency import ManagedSettingsUI
import UIKit

/// Supplies the custom block screen iOS draws over a shielded app or site.
/// Every variant reads the live attempt counters from the App Group so the
/// copy reflects exactly how many times the user has pushed on the threshold today.
final class HorosShieldConfigurationDataSource: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        ShieldScreenBuilder.build(
            targetName: application.localizedDisplayName,
            tokenHash: application.token.map { TokenHasher.stableHash($0) },
            kind: .application
        )
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        ShieldScreenBuilder.build(
            targetName: application.localizedDisplayName ?? category.localizedDisplayName,
            tokenHash: application.token.map { TokenHasher.stableHash($0) }
                ?? category.token.map { TokenHasher.stableHash($0) },
            kind: .application
        )
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        ShieldScreenBuilder.build(
            targetName: webDomain.domain,
            tokenHash: webDomain.token.map { TokenHasher.stableHash($0) },
            kind: .webDomain
        )
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        ShieldScreenBuilder.build(
            targetName: webDomain.domain ?? category.localizedDisplayName,
            tokenHash: webDomain.token.map { TokenHasher.stableHash($0) }
                ?? category.token.map { TokenHasher.stableHash($0) },
            kind: .webDomain
        )
    }
}
