import Foundation

/// High-precision astronomical calculator for the 24 Chinese Solar Terms (二十四节气).
/// Computes apparent solar ecliptic longitude (Jean Meeus algorithm) and solves for exact
/// Beijing Time (UTC+8) dates matching Purple Mountain Observatory conventions.
public struct SolarTerm: Identifiable, Hashable, Sendable {
    public let id: Int
    public let name: String
    public let longitude: Double
    public let date: Date
    public let year: Int
    public let month: Int
    public let day: Int

    public init(id: Int, name: String, longitude: Double, date: Date, year: Int, month: Int, day: Int) {
        self.id = id
        self.name = name
        self.longitude = longitude
        self.date = date
        self.year = year
        self.month = month
        self.day = day
    }
}

public final class SolarTermCalculator: @unchecked Sendable {
    public static let shared = SolarTermCalculator()

    /// Ordered by calendar year starting from 小寒 (285°).
    private static let termsSpec: [(name: String, longitude: Double, approxMonth: Int, approxDay: Int)] = [
        ("小寒", 285,  1,  5),
        ("大寒", 300,  1, 20),
        ("立春", 315,  2,  4),
        ("雨水", 330,  2, 19),
        ("惊蛰", 345,  3,  5),
        ("春分",   0,  3, 20),
        ("清明",  15,  4,  4),
        ("谷雨",  30,  4, 20),
        ("立夏",  45,  5,  5),
        ("小满",  60,  5, 21),
        ("芒种",  75,  6,  5),
        ("夏至",  90,  6, 21),
        ("小暑", 105,  7,  7),
        ("大暑", 120,  7, 22),
        ("立秋", 135,  8,  7),
        ("处暑", 150,  8, 23),
        ("白露", 165,  9,  7),
        ("秋分", 180,  9, 23),
        ("寒露", 195, 10,  8),
        ("霜降", 210, 10, 23),
        ("立冬", 225, 11,  7),
        ("小雪", 240, 11, 22),
        ("大雪", 255, 12,  7),
        ("冬至", 270, 12, 21)
    ]

    private let lock = NSLock()
    private var yearCache: [Int: [SolarTerm]] = [:]
    private var dateLookupCache: [Int: [Int: SolarTerm]] = [:] // year -> (month*100 + day -> SolarTerm)

    private static let beijingCalendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 8 * 3600)!
        return cal
    }()

    private init() {}

    /// Returns all 24 solar terms for the given Gregorian year.
    public func solarTerms(for year: Int) -> [SolarTerm] {
        lock.lock()
        if let cached = yearCache[year] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        var results: [SolarTerm] = []
        var lookup: [Int: SolarTerm] = [:]

        for (index, spec) in Self.termsSpec.enumerated() {
            let approxJD = julianDay(year: year, month: spec.approxMonth, day: Double(spec.approxDay))
            let exactJDE = solveSolarLongitude(targetDegrees: spec.longitude, initialJD: approxJD)
            // Convert JDE (TD) to UTC by subtracting approximate Delta-T (~69s for modern era)
            let jdUTC = exactJDE - 69.0 / 86400.0
            let exactDate = dateFromJulianDay(jdUTC)
            let comps = Self.beijingCalendar.dateComponents([.year, .month, .day], from: exactDate)
            let y = comps.year ?? year
            let m = comps.month ?? spec.approxMonth
            let d = comps.day ?? spec.approxDay

            let term = SolarTerm(
                id: index,
                name: spec.name,
                longitude: spec.longitude,
                date: exactDate,
                year: y,
                month: m,
                day: d
            )
            results.append(term)
            lookup[m * 100 + d] = term
        }

        lock.lock()
        yearCache[year] = results
        dateLookupCache[year] = lookup
        lock.unlock()

        return results
    }

    /// Returns the solar term falling on the given (year, month, day), if any.
    public func solarTerm(year: Int, month: Int, day: Int) -> SolarTerm? {
        lock.lock()
        let lookup = dateLookupCache[year]
        lock.unlock()

        if let lookup {
            return lookup[month * 100 + day]
        }
        _ = solarTerms(for: year)
        lock.lock()
        let populated = dateLookupCache[year]
        lock.unlock()
        return populated?[month * 100 + day]
    }

    /// Finds the next solar term strictly after (or on) the given local date.
    public func nextSolarTerm(from date: Date, calendar: Calendar = .current) -> (term: SolarTerm, daysUntil: Int)? {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        guard let y = comps.year, let m = comps.month, let d = comps.day,
              let startOfDay = calendar.date(from: DateComponents(year: y, month: m, day: d)) else {
            return nil
        }

        let candidates = solarTerms(for: y) + solarTerms(for: y + 1)
        for term in candidates {
            guard let termDay = calendar.date(from: DateComponents(year: term.year, month: term.month, day: term.day)) else {
                continue
            }
            let diff = calendar.dateComponents([.day], from: startOfDay, to: termDay).day ?? -1
            if diff > 0 {
                return (term, diff)
            }
        }
        return nil
    }

    // MARK: - Astronomical Math (Meeus Ch. 25)

    private func julianDay(year: Int, month: Int, day: Double) -> Double {
        var y = year
        var m = month
        if m <= 2 {
            y -= 1
            m += 12
        }
        let a = y / 100
        let b = 2 - a + a / 4
        return floor(365.25 * Double(y + 4716))
            + floor(30.6001 * Double(m + 1))
            + day + Double(b) - 1524.5
    }

    private func dateFromJulianDay(_ jd: Double) -> Date {
        // Unix epoch 1970-01-01 00:00:00 UTC is JD 2440587.5
        let unixSeconds = (jd - 2440587.5) * 86400.0
        return Date(timeIntervalSince1970: unixSeconds)
    }

    /// Apparent solar ecliptic longitude in degrees [0, 360).
    private func apparentSolarLongitude(jde: Double) -> Double {
        let t = (jde - 2451545.0) / 36525.0
        let t2 = t * t
        let t3 = t2 * t

        // Geometric mean longitude L0 (deg)
        let l0 = normalizeDegrees(280.46646 + 36000.76983 * t + 0.0003032 * t2)

        // Mean anomaly M (deg)
        let mDeg = normalizeDegrees(357.52911 + 35999.05029 * t - 0.0001537 * t2)
        let mRad = mDeg * .pi / 180.0

        // Sun's equation of center C (deg)
        let c = (1.914602 - 0.004817 * t - 0.000014 * t2) * sin(mRad)
              + (0.019993 - 0.000101 * t) * sin(2.0 * mRad)
              + 0.000289 * sin(3.0 * mRad)

        // True longitude
        let trueLong = l0 + c

        // Apparent longitude (nutation + aberration correction)
        let omega = (125.04 - 1934.136 * t) * .pi / 180.0
        let apparent = trueLong - 0.00569 - 0.00478 * sin(omega)

        _ = t3 // silence unused if needed
        return normalizeDegrees(apparent)
    }

    private func solveSolarLongitude(targetDegrees: Double, initialJD: Double) -> Double {
        var jd = initialJD
        for _ in 0..<12 {
            let current = apparentSolarLongitude(jde: jd)
            var diff = targetDegrees - current
            if diff > 180.0 { diff -= 360.0 }
            if diff < -180.0 { diff += 360.0 }

            // Sun moves ~0.985647 deg/day
            let deltaDays = diff / 0.98564736
            jd += deltaDays
            if abs(deltaDays) < 1e-6 {
                break
            }
        }
        return jd
    }

    private func normalizeDegrees(_ deg: Double) -> Double {
        var result = deg.truncatingRemainder(dividingBy: 360.0)
        if result < 0 { result += 360.0 }
        return result
    }
}
