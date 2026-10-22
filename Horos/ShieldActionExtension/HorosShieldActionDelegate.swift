@preconcurrency import ManagedSettings
@preconcurrency import FamilyControls
import os

/// Intercepts every tap on the shield. Each tap — primary or secondary — is an
/// attempt to cross the boundary: it is counted, logged for analytics, the
/// main app is woken through a Darwin notification, and the shield closes.
final class HorosShieldActionDelegate: ShieldActionDelegate {
    private let interceptor = AttemptInterceptor()

    override func handle(
        action: ShieldAction,
        for application: ApplicationToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        completionHandler(interceptor.intercept(action: action, token: application, kind: .application))
    }

    override func handle(
        action: ShieldAction,
        for webDomain: WebDomainToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        completionHandler(interceptor.intercept(action: action, token: webDomain, kind: .webDomain))
    }

    override func handle(
        action: ShieldAction,
        for category: ActivityCategoryToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        completionHandler(interceptor.intercept(action: action, token: category, kind: .category))
    }
}
