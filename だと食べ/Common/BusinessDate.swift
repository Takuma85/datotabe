import Foundation

struct BusinessDatePolicy: Hashable, Codable {
    var dayBoundaryHour: Int

    static let `default` = BusinessDatePolicy(dayBoundaryHour: 5)

    var normalized: BusinessDatePolicy {
        BusinessDatePolicy(dayBoundaryHour: min(max(dayBoundaryHour, 0), 23))
    }
}

enum BusinessDate {
    static func businessDate(
        for date: Date,
        calendar: Calendar = .current,
        policy: BusinessDatePolicy = .default
    ) -> Date {
        let hour = policy.normalized.dayBoundaryHour
        let shifted = calendar.date(byAdding: .hour, value: -hour, to: date) ?? date
        return calendar.startOfDay(for: shifted)
    }

    static func startOfDay(_ date: Date, calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: date)
    }

    static func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
        dateFormatter(calendar: calendar).string(from: calendar.startOfDay(for: date))
    }

    static func monthKey(_ date: Date, calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.calendar = calendar
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: date)
    }

    static func monthRange(for date: Date, calendar: Calendar = .current) -> (start: Date, end: Date)? {
        let comps = calendar.dateComponents([.year, .month], from: date)
        guard let start = calendar.date(from: DateComponents(year: comps.year, month: comps.month, day: 1)),
              let end = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: start) else {
            return nil
        }
        return (calendar.startOfDay(for: start), calendar.startOfDay(for: end))
    }

    static func daysInRange(from start: Date, to end: Date, calendar: Calendar = .current) -> [Date] {
        var days: [Date] = []
        var current = calendar.startOfDay(for: start)
        let last = calendar.startOfDay(for: end)

        while current <= last {
            days.append(current)
            guard let next = calendar.date(byAdding: .day, value: 1, to: current), next > current else {
                break
            }
            current = next
        }
        return days
    }

    static func isDate(_ date: Date, between start: Date, and end: Date, calendar: Calendar = .current) -> Bool {
        let day = calendar.startOfDay(for: date)
        return day >= calendar.startOfDay(for: start) && day <= calendar.startOfDay(for: end)
    }

    private static func dateFormatter(calendar: Calendar) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.calendar = calendar
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }
}
