@preconcurrency import DeviceActivity
import SwiftUI

/// Entry point of the Screen Time analytics sandbox. iOS renders this
/// extension's scene inside the main app's `DeviceActivityReport` view.
@main
struct HorosReportExtension: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        TotalActivityReport { summary in
            TotalActivityView(summary: summary)
        }
    }
}
