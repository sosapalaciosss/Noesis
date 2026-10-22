import SwiftUI
@preconcurrency import DeviceActivity

/// `DeviceActivityReport` lives in the DeviceActivity ⨯ SwiftUI cross-import
/// overlay, so both modules must be imported for the type to be visible.
///
/// The single report context shared by the main app (`DeviceActivityReport`)
/// and the report extension (`DeviceActivityReportScene`).
extension DeviceActivityReport.Context {
    static let horosTotalActivity = Self("HorosTotalActivity")
}
