# HOROS

A native iOS application blocker built on Apple's Screen Time API
(FamilyControls · ManagedSettings · DeviceActivity). SwiftUI, Swift Charts, iOS 17+. Written for Swift 6 strict concurrency; ships in Swift 5 language mode so it builds with Xcode 15.2 on macOS 13 (set `SWIFT_VERSION: "6.0"` in project.yml on Xcode 16+).

## Getting started (macOS)

```bash
cd Horos
./Scripts/bootstrap.sh        # installs XcodeGen if needed, generates, builds, opens Xcode
```

Or step by step:

```bash
brew install xcodegen
xcodegen generate
xcodebuild -project Horos.xcodeproj -scheme Horos \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
open Horos.xcodeproj
```

Before running on a device, set your **Development Team** on all five targets in
Xcode (Signing & Capabilities). Family Controls requires a paid developer
account; for App Store distribution request the *Family Controls (Distribution)*
entitlement from Apple. Shields never work in the Simulator — use **preview
mode** there to exercise the UI with sample analytics.

## Targets

| Target | Bundle ID | Role |
|---|---|---|
| `Horos` | `com.horos.app` | Main app: onboarding, quick sessions, rituals, analytics |
| `DeviceActivityMonitorExtension` | `com.horos.app.monitor` | `DeviceActivityMonitor` — raises/lowers shields at schedule boundaries and usage thresholds |
| `ShieldConfigurationExtension` | `com.horos.app.shieldconfiguration` | `ShieldConfigurationDataSource` — OLED block screen with the live attempt counter |
| `ShieldActionExtension` | `com.horos.app.shieldaction` | `ShieldActionDelegate` — counts and logs every attempt, closes the shield |
| `DeviceActivityReportExtension` | `com.horos.app.report` | `DeviceActivityReportExtension` — total/per-app Screen Time and day-over-day trends in Swift Charts |

All five share the App Group `group.com.horos.shared` and the
`com.apple.developer.family-controls` entitlement.

## Layout

```
Horos/
├── project.yml                     XcodeGen spec (5 targets, entitlements, scheme)
├── SharedCore/                     Compiled into every target
│   ├── Models/                     BlockingProfile, QuickSessionState, AttemptTracker, …
│   ├── Storage/SharedStorageManager.swift   thread-safe App Group store
│   ├── Services/ShieldEngine.swift          single owner of ManagedSettingsStore + DeviceActivityCenter
│   ├── Utilities/                  selection (plist) coder, token hasher, Darwin notifier
│   └── Theme/HorosPalette.swift    OLED palette shared with the shield extension
├── Horos/                          Main app (App, ViewModels, Views, Theme, Resources)
├── DeviceActivityMonitorExtension/
├── ShieldConfigurationExtension/
├── ShieldActionExtension/
├── DeviceActivityReportExtension/
└── Scripts/bootstrap.sh
```

## How the pieces talk

* **Quick session** → `ShieldEngine.startQuickSession` writes the selection to the
  `com.horos.store.quickSession` store and, for timed sessions ≥ 15 min, registers a
  one-shot `DeviceActivitySchedule` so the monitor extension lifts the shield even if
  the app is killed.
* **Rituals** → one repeating daily `DeviceActivitySchedule` per enabled profile.
  The monitor checks the profile's `daysOfWeek` at `intervalDidStart`, so a single
  activity covers any weekday pattern. Profiles with a usage allowance register a
  `DeviceActivityEvent`; the shield rises in `eventDidReachThreshold`.
* **Attempts** → every shield-button tap goes through `ShieldActionExtension`, which
  appends a `BlockAttemptEvent`, bumps the daily / per-target counters, posts a Darwin
  notification and closes the shield. The main app and the shield screen read the same
  `AttemptTracker` from the App Group.
* **Screen Time** → the app embeds `DeviceActivityReport(.horosTotalActivity, filter:)`;
  the report extension folds `DeviceActivityResults` into daily totals, per-app usage and
  day-over-day change, rendered with Swift Charts inside Apple's privacy sandbox.
