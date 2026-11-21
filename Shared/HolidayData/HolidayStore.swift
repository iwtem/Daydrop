import Foundation

public struct HolidayEntry: Codable, Hashable, Sendable {
    public let date: String      // "YYYY-MM-DD"
    public let name: String      // e.g. "春节", "国庆节"
    public let isOffDay: Bool    // true = 休, false = 班 (调休上班)
}

public struct HolidayDataset: Codable, Sendable {
    public let version: String
    public let region: String
    public let holidays: [HolidayEntry]
}

public enum HolidayStatus: Hashable, Sendable {
    case offDay(name: String)      // 休
    case workDay(name: String)     // 班
}

public struct UpcomingHoliday: Hashable, Sendable {
    public let name: String
    public let startDate: Date
    public let daysUntil: Int
    public let durationDays: Int
}

public final class HolidayStore: @unchecked Sendable {
    public static let shared = HolidayStore()

    private let entriesByDateKey: [String: HolidayEntry]
    private let sortedOffDayBlocks: [(name: String, startKey: String, startDate: Date, duration: Int)]

    private static let keyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private init() {
        var map: [String: HolidayEntry] = [:]
        if let data = Self.loadJSONData(),
           let dataset = try? JSONDecoder().decode(HolidayDataset.self, from: data) {
            for item in dataset.holidays {
                map[item.date] = item
            }
        }
        self.entriesByDateKey = map
        self.sortedOffDayBlocks = Self.buildHolidayBlocks(from: map)
    }

    public func status(year: Int, month: Int, day: Int) -> HolidayStatus? {
        let key = String(format: "%04d-%02d-%02d", year, month, day)
        guard let entry = entriesByDateKey[key] else { return nil }
        return entry.isOffDay ? .offDay(name: entry.name) : .workDay(name: entry.name)
    }

    public func nextHoliday(from date: Date, calendar: Calendar = .current) -> UpcomingHoliday? {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        guard let y = comps.year, let m = comps.month, let d = comps.day,
              let startOfDay = calendar.date(from: DateComponents(year: y, month: m, day: d)) else {
            return nil
        }

        for block in sortedOffDayBlocks {
            let diff = calendar.dateComponents([.day], from: startOfDay, to: block.startDate).day ?? -1
            if diff > 0 {
                return UpcomingHoliday(
                    name: block.name,
                    startDate: block.startDate,
                    daysUntil: diff,
                    durationDays: block.duration
                )
            }
        }
        return nil
    }

    private static func loadJSONData() -> Data? {
        // 1. Check optional user override in shared App Group container
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.daydrop.shared") {
            let overrideURL = containerURL.appendingPathComponent("holidays_cn_override.json")
            if let data = try? Data(contentsOf: overrideURL) {
                return data
            }
        }
        // 2. Load bundled JSON from current target bundle
        let bundles = [Bundle.main, Bundle(for: HolidayStore.self)]
        for bundle in bundles {
            if let url = bundle.url(forResource: "holidays_cn", withExtension: "json"),
               let data = try? Data(contentsOf: url) {
                return data
            }
        }
        return nil
    }

    private static func buildHolidayBlocks(from map: [String: HolidayEntry]) -> [(name: String, startKey: String, startDate: Date, duration: Int)] {
        let offEntries = map.values
            .filter { $0.isOffDay }
            .sorted { $0.date < $1.date }

        let cal = Calendar(identifier: .gregorian)
        var blocks: [(name: String, startKey: String, startDate: Date, duration: Int)] = []

        var currentStartKey: String?
        var currentStartDate: Date?
        var currentLastDate: Date?
        var currentName: String?
        var currentCount = 0

        for entry in offEntries {
            guard let entryDate = keyFormatter.date(from: entry.date) else { continue }
            if let last = currentLastDate,
               let diff = cal.dateComponents([.day], from: last, to: entryDate).day,
               diff == 1 {
                currentLastDate = entryDate
                currentCount += 1
            } else {
                if let sk = currentStartKey, let sd = currentStartDate, let nm = currentName {
                    blocks.append((name: nm, startKey: sk, startDate: sd, duration: currentCount))
                }
                currentStartKey = entry.date
                currentStartDate = entryDate
                currentLastDate = entryDate
                currentName = entry.name
                currentCount = 1
            }
        }

        if let sk = currentStartKey, let sd = currentStartDate, let nm = currentName {
            blocks.append((name: nm, startKey: sk, startDate: sd, duration: currentCount))
        }

        return blocks
    }
}
