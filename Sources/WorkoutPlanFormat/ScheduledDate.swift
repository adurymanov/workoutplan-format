import Foundation

/// When a workout should show up on the watch.
///
/// Two spellings are allowed, and the difference matters:
///
/// - **Local wall-clock**, such as `"2026-07-28T07:30:00"`, with no time-zone
///   suffix. It means "half past seven in the morning, wherever the athlete is".
///   A plan written for a training camp abroad still starts at 07:30 local.
/// - **Absolute**, such as `"2026-07-28T07:30:00Z"` or `"2026-07-28T07:30:00+03:00"`.
///   A fixed instant, converted into the athlete's time zone for display.
///
/// Wall-clock is the default a plan generator should emit; it is resolved against
/// a time zone only at scheduling time, never at parse time.
public struct ScheduledDate: Hashable, Sendable {

    public enum Representation: Hashable, Sendable {
        /// Year, month, day, hour, minute and second, with no time zone.
        case wallClock(WallClock)
        /// A fixed point in time.
        case absolute(Date)
    }

    /// A date and time with no time zone attached.
    public struct WallClock: Hashable, Sendable {
        public var year: Int
        public var month: Int
        public var day: Int
        public var hour: Int
        public var minute: Int
        public var second: Int

        public init(
            year: Int, month: Int, day: Int, hour: Int = 0, minute: Int = 0, second: Int = 0
        ) {
            self.year = year
            self.month = month
            self.day = day
            self.hour = hour
            self.minute = minute
            self.second = second
        }
    }

    /// Exactly the string that was read from (or will be written to) the file.
    public let rawValue: String
    public let representation: Representation

    // MARK: - Parsing

    public init(rawValue: String) throws {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw FormatError(.invalidDate, "scheduledDate is empty.", field: "scheduledDate")
        }

        if let date = Self.parseAbsolute(trimmed) {
            self.rawValue = trimmed
            self.representation = .absolute(date)
            return
        }
        if let wallClock = Self.parseWallClock(trimmed) {
            self.rawValue = trimmed
            self.representation = .wallClock(wallClock)
            return
        }
        throw FormatError(
            .invalidDate,
            "'\(rawValue)' is not a valid date. Use \"YYYY-MM-DDThh:mm:ss\" for local time, or an ISO-8601 timestamp with an offset.",
            field: "scheduledDate")
    }

    public init(_ wallClock: WallClock) {
        self.representation = .wallClock(wallClock)
        self.rawValue = String(
            format: "%04d-%02d-%02dT%02d:%02d:%02d",
            wallClock.year, wallClock.month, wallClock.day,
            wallClock.hour, wallClock.minute, wallClock.second)
    }

    /// ISO-8601 with an explicit offset or `Z`.
    private static func parseAbsolute(_ string: String) -> Date? {
        guard string.hasSuffix("Z") || string.hasSuffix("z")
            || Self.hasNumericOffset(string) else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: string) { return date }
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: string)
    }

    /// Detects a trailing `+hh:mm` / `-hhmm` offset without tripping over the
    /// hyphens in the date part.
    private static func hasNumericOffset(_ string: String) -> Bool {
        guard let timeStart = string.firstIndex(where: { $0 == "T" || $0 == "t" || $0 == " " })
        else { return false }
        let timePart = string[string.index(after: timeStart)...]
        return timePart.contains("+") || timePart.contains("-")
    }

    /// `YYYY-MM-DD`, optionally followed by `T`/space and `hh:mm[:ss]`. Parsed by
    /// hand so that no locale, calendar or time zone can influence the result.
    private static func parseWallClock(_ string: String) -> WallClock? {
        let parts = string.split(whereSeparator: { $0 == "T" || $0 == "t" || $0 == " " })
        guard parts.count == 1 || parts.count == 2 else { return nil }

        let dateFields = parts[0].split(separator: "-", omittingEmptySubsequences: false)
        guard dateFields.count == 3,
            let year = Int(dateFields[0]), dateFields[0].count == 4,
            let month = Int(dateFields[1]), dateFields[1].count == 2,
            let day = Int(dateFields[2]), dateFields[2].count == 2,
            (1...12).contains(month), (1...31).contains(day)
        else { return nil }

        var hour = 0, minute = 0, second = 0
        if parts.count == 2 {
            let timeFields = parts[1].split(separator: ":", omittingEmptySubsequences: false)
            guard timeFields.count == 2 || timeFields.count == 3 else { return nil }
            guard let h = Int(timeFields[0]), let m = Int(timeFields[1]),
                (0...23).contains(h), (0...59).contains(m)
            else { return nil }
            hour = h
            minute = m
            if timeFields.count == 3 {
                guard let s = Int(timeFields[2]), (0...60).contains(s) else { return nil }
                second = s
            }
        }
        return WallClock(
            year: year, month: month, day: day, hour: hour, minute: minute, second: second)
    }

    // MARK: - Resolving

    /// The instant this date refers to, resolved in the given time zone.
    ///
    /// Returns `nil` only for a wall-clock date that does not exist in that time
    /// zone (for example 02:30 on a spring-forward night).
    public func date(
        in timeZone: TimeZone = .autoupdatingCurrent,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> Date? {
        switch representation {
        case .absolute(let date):
            return date
        case .wallClock(let wallClock):
            var calendar = calendar
            calendar.timeZone = timeZone
            return calendar.date(from: components(of: wallClock, in: calendar, timeZone: timeZone))
        }
    }

    /// `DateComponents` ready to hand to `WorkoutScheduler`, with an explicit
    /// calendar and time zone so the watch schedules the intended instant.
    public func schedulingComponents(
        in timeZone: TimeZone = .autoupdatingCurrent,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> DateComponents {
        var calendar = calendar
        calendar.timeZone = timeZone
        switch representation {
        case .wallClock(let wallClock):
            return components(of: wallClock, in: calendar, timeZone: timeZone)
        case .absolute(let date):
            var components = calendar.dateComponents(
                [.year, .month, .day, .hour, .minute], from: date)
            components.calendar = calendar
            components.timeZone = timeZone
            return components
        }
    }

    private func components(
        of wallClock: WallClock, in calendar: Calendar, timeZone: TimeZone
    ) -> DateComponents {
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = timeZone
        components.year = wallClock.year
        components.month = wallClock.month
        components.day = wallClock.day
        components.hour = wallClock.hour
        components.minute = wallClock.minute
        return components
    }
}

extension ScheduledDate: Codable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        try self.init(rawValue: container.decode(String.self))
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

extension ScheduledDate: CustomStringConvertible {
    public var description: String { rawValue }
}
