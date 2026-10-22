@preconcurrency import DeviceActivity
import SwiftUI

/// Folds the raw `DeviceActivityResults` stream into an `ActivityReportSummary`.
struct TotalActivityReport: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .horosTotalActivity
    let content: (ActivityReportSummary) -> TotalActivityView

    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> ActivityReportSummary {
        await ActivityReportBuilder.build(from: data)
    }
}

enum ActivityReportBuilder {
    static func build(
        from data: DeviceActivityResults<DeviceActivityData>,
        calendar: Calendar = .current,
        now: Date = Date()
    ) async -> ActivityReportSummary {
        var dayTotals: [Date: TimeInterval] = [:]
        var appTotals: [String: AppUsage] = [:]
        var categoryTotals: [String: CategoryUsage] = [:]

        for await datum in data {
            for await segment in datum.activitySegments {
                let dayStart = calendar.startOfDay(for: segment.dateInterval.start)
                dayTotals[dayStart, default: 0] += segment.totalActivityDuration

                for await categoryActivity in segment.categories {
                    let categoryName = categoryActivity.category.localizedDisplayName ?? "Other"
                    var category = categoryTotals[categoryName]
                        ?? CategoryUsage(id: categoryName, name: categoryName, duration: 0, share: 0)
                    category.duration += categoryActivity.totalActivityDuration
                    categoryTotals[categoryName] = category

                    for await applicationActivity in categoryActivity.applications {
                        let application = applicationActivity.application
                        let bundleID = application.bundleIdentifier
                        let name = application.localizedDisplayName ?? bundleID ?? "Unknown app"
                        let key = bundleID ?? name
                        var app = appTotals[key] ?? AppUsage(
                            id: key,
                            name: name,
                            bundleIdentifier: bundleID,
                            duration: 0,
                            pickups: 0,
                            notifications: 0,
                            share: 0
                        )
                        app.duration += applicationActivity.totalActivityDuration
                        app.pickups += applicationActivity.numberOfPickups
                        app.notifications += applicationActivity.numberOfNotifications
                        appTotals[key] = app
                    }
                }
            }
        }

        let total = dayTotals.values.reduce(0, +)
        let todayStart = calendar.startOfDay(for: now)
        let yesterdayStart = calendar.date(byAdding: .day, value: -1, to: todayStart) ?? todayStart

        let days = dayTotals
            .map { DailyUsage(date: $0.key, duration: $0.value, isToday: $0.key == todayStart) }
            .sorted { $0.date < $1.date }

        let todayDuration = dayTotals[todayStart] ?? 0
        let yesterdayDuration = dayTotals[yesterdayStart] ?? 0
        let previousDays = days.filter { $0.date < todayStart }
        let average = previousDays.isEmpty
            ? 0
            : previousDays.reduce(0) { $0 + $1.duration } / Double(previousDays.count)

        let apps = appTotals.values
            .map { app -> AppUsage in
                var copy = app
                copy.share = total > 0 ? app.duration / total : 0
                return copy
            }
            .sorted { $0.duration > $1.duration }

        let categories = categoryTotals.values
            .map { category -> CategoryUsage in
                var copy = category
                copy.share = total > 0 ? category.duration / total : 0
                return copy
            }
            .sorted { $0.duration > $1.duration }

        return ActivityReportSummary(
            days: days,
            apps: apps,
            categories: categories,
            totalDuration: total,
            todayDuration: todayDuration,
            yesterdayDuration: yesterdayDuration,
            averageDuration: average,
            dayOverDayChange: yesterdayDuration > 0 ? (todayDuration - yesterdayDuration) / yesterdayDuration : nil,
            trendVersusAverage: average > 0 ? (todayDuration - average) / average : nil,
            generatedAt: now
        )
    }
}
