import Foundation
import WidgetKit

public struct HolidayEntry: Codable, Hashable, Sendable {
    public let date: String      // "YYYY-MM-DD"
    public let name: String      // e.g. "春节", "国庆节"
    public let isOffDay: Bool    // true = 休, false = 班 (调休上班)

    public init(date: String, name: String, isOffDay: Bool) {
        self.date = date
        self.name = name
        self.isOffDay = isOffDay
    }
}

public struct HolidayDataset: Codable, Sendable {
    public let version: String
    public let region: String
    public let holidays: [HolidayEntry]
}

/// Format published by NateScarlet/holiday-cn per-year JSON files.
private struct HolidayCNYearPayload: Codable {
    let year: Int?
    let days: [HolidayEntry]
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

public extension Notification.Name {
    static let daydropHolidaysDidUpdate = Notification.Name("com.daydrop.holidaysDidUpdate")
}

public final class HolidayStore: @unchecked Sendable {
    public static let shared = HolidayStore()

    private static let cacheKey = "cachedRemoteHolidayEntriesV1"
    private static let sharedSuite = "com.daydrop.shared"

    private let lock = NSLock()
    private var entriesByDateKey: [String: HolidayEntry] = [:]
    private var sortedOffDayBlocks: [(name: String, startKey: String, startDate: Date, duration: Int)] = []

    private static let keyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private init() {
        reloadFromStorage()
    }

    public func reloadFromStorage() {
        var merged: [String: HolidayEntry] = [:]

        // 1. Built-in bundled baseline (2024–2027)
        if let data = Self.loadBundledJSONData(),
           let dataset = try? JSONDecoder().decode(HolidayDataset.self, from: data) {
            for item in dataset.holidays {
                merged[item.date] = item
            }
        }

        // 2. Overlay cached online updates from shared preferences (synced to both App & Widget)
        CFPreferencesAppSynchronize(Self.sharedSuite as CFString)
        let store = UserDefaults(suiteName: Self.sharedSuite) ?? .standard
        if let cachedData = store.data(forKey: Self.cacheKey),
           let cachedEntries = try? JSONDecoder().decode([HolidayEntry].self, from: cachedData) {
            for item in cachedEntries {
                merged[item.date] = item
            }
        }

        let blocks = Self.buildHolidayBlocks(from: merged)
        lock.lock()
        entriesByDateKey = merged
        sortedOffDayBlocks = blocks
        lock.unlock()
    }

    public var coveredYearsSummary: String {
        lock.lock()
        let keys = Array(entriesByDateKey.keys)
        lock.unlock()

        let years = Set(keys.compactMap { Int($0.prefix(4)) }).sorted()
        guard let first = years.first, let last = years.last else { return "—" }
        return first == last ? "\(first)" : "\(first)–\(last)"
    }

    public func status(year: Int, month: Int, day: Int) -> HolidayStatus? {
        let key = String(format: "%04d-%02d-%02d", year, month, day)
        lock.lock()
        let entry = entriesByDateKey[key]
        lock.unlock()
        guard let entry else { return nil }
        return entry.isOffDay ? .offDay(name: entry.name) : .workDay(name: entry.name)
    }

    public func nextHoliday(from date: Date, calendar: Calendar = .current) -> UpcomingHoliday? {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        guard let y = comps.year, let m = comps.month, let d = comps.day,
              let startOfDay = calendar.date(from: DateComponents(year: y, month: m, day: d)) else {
            return nil
        }

        lock.lock()
        let blocks = sortedOffDayBlocks
        lock.unlock()

        for block in blocks {
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

    // MARK: - Online Silent Sync (holiday-cn CDN with GitHub Raw fallback)

    /// Parses either NateScarlet/holiday-cn `{ "days": [...] }` or our own `{ "holidays": [...] }` format.
    public static func parseRemoteHolidayJSON(_ data: Data) -> [HolidayEntry]? {
        let decoder = JSONDecoder()
        if let cnPayload = try? decoder.decode(HolidayCNYearPayload.self, from: data), !cnPayload.days.isEmpty {
            return cnPayload.days
        }
        if let dataset = try? decoder.decode(HolidayDataset.self, from: data), !dataset.holidays.isEmpty {
            return dataset.holidays
        }
        return nil
    }

    /// Merges remote holiday entries into the shared cache and refreshes widgets.
    public func mergeAndPersistRemoteEntries(_ newEntries: [HolidayEntry]) {
        guard !newEntries.isEmpty else { return }

        let store = UserDefaults(suiteName: Self.sharedSuite) ?? .standard
        var existingCache: [String: HolidayEntry] = [:]
        if let cachedData = store.data(forKey: Self.cacheKey),
           let cachedEntries = try? JSONDecoder().decode([HolidayEntry].self, from: cachedData) {
            for item in cachedEntries {
                existingCache[item.date] = item
            }
        }
        for item in newEntries {
            existingCache[item.date] = item
        }

        let sortedCache = existingCache.values.sorted { $0.date < $1.date }
        if let encoded = try? JSONEncoder().encode(sortedCache) {
            store.set(encoded, forKey: Self.cacheKey)
            store.synchronize()
        }

        reloadFromStorage()
        AppPreferences.reloadAllWidgets()
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .daydropHolidaysDidUpdate, object: nil)
        }
    }

    /// Silently syncs current year and next year if more than 7 days have passed since last check.
    public func syncIfNeededOnLaunch() {
        let lastSync = AppPreferences.shared.lastHolidaySyncDate
        if let lastSync, Date().timeIntervalSince(lastSync) < 7 * 86400 {
            return
        }
        Task.detached(priority: .utility) {
            _ = await self.syncRemoteHolidays()
        }
    }

    /// Fetches official holiday schedules for currentYear and currentYear + 1 from static CDN mirrors.
    @discardableResult
    public func syncRemoteHolidays(targetYears: [Int]? = nil) async -> Bool {
        let cal = Calendar.current
        let currentYear = cal.component(.year, from: Date())
        let years = targetYears ?? [currentYear, currentYear + 1]

        var collected: [HolidayEntry] = []
        var anySucceeded = false

        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 8
        config.timeoutIntervalForResource = 12
        let session = URLSession(configuration: config)

        for year in years {
            let mirrors = [
                "https://fastly.jsdelivr.net/gh/NateScarlet/holiday-cn@master/\(year).json",
                "https://raw.githubusercontent.com/NateScarlet/holiday-cn/master/\(year).json"
            ]
            for urlString in mirrors {
                guard let url = URL(string: urlString) else { continue }
                do {
                    let (data, response) = try await session.data(from: url)
                    guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                        continue
                    }
                    if let parsed = Self.parseRemoteHolidayJSON(data) {
                        collected.append(contentsOf: parsed)
                        anySucceeded = true
                        break
                    }
                } catch {
                    continue
                }
            }
        }

        if anySucceeded {
            mergeAndPersistRemoteEntries(collected)
            await MainActor.run {
                AppPreferences.shared.lastHolidaySyncDate = Date()
            }
        }
        return anySucceeded
    }

    // MARK: - Helpers

    private static func loadBundledJSONData() -> Data? {
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
