@preconcurrency import DeviceActivity

/// The single report context shared by the main app (`DeviceActivityReport`)
/// and the report extension (`DeviceActivityReportScene`).
extension DeviceActivityReport.Context {
    static let horosTotalActivity = Self("HorosTotalActivity")
}
