import Foundation
import Testing

@testable import WorkoutPlanFormat

@Suite("Scheduled dates")
struct ScheduledDateTests {

    private let moscow = TimeZone(identifier: "Europe/Moscow")!
    private let berlin = TimeZone(identifier: "Europe/Berlin")!

    @Test("A wall-clock date means the same clock time in every zone")
    func wallClockFollowsTheAthlete() throws {
        let date = try ScheduledDate(rawValue: "2026-09-08T07:30:00")
        guard case .wallClock(let clock) = date.representation else {
            Issue.record("expected a wall-clock date")
            return
        }
        #expect((clock.year, clock.month, clock.day) == (2026, 9, 8))
        #expect((clock.hour, clock.minute, clock.second) == (7, 30, 0))

        // 07:30 in Moscow and 07:30 in Berlin are different instants, which is the
        // whole point of a wall-clock date.
        let inMoscow = date.date(in: moscow)
        let inBerlin = date.date(in: berlin)
        #expect(inMoscow != inBerlin)
        #expect(inMoscow! < inBerlin!)
    }

    @Test("An absolute date is one instant, whoever reads it")
    func absoluteIsAbsolute() throws {
        let date = try ScheduledDate(rawValue: "2026-09-08T04:30:00Z")
        guard case .absolute = date.representation else {
            Issue.record("expected an absolute date")
            return
        }
        #expect(date.date(in: moscow) == date.date(in: berlin))
        // 04:30 UTC is 07:30 in Moscow (UTC+3).
        let components = date.schedulingComponents(in: moscow)
        #expect(components.hour == 7)
        #expect(components.minute == 30)
    }

    @Test("Offsets other than Z are absolute too")
    func numericOffset() throws {
        let date = try ScheduledDate(rawValue: "2026-09-08T07:30:00+03:00")
        guard case .absolute = date.representation else {
            Issue.record("expected an absolute date")
            return
        }
        #expect(date.date() == (try ScheduledDate(rawValue: "2026-09-08T04:30:00Z").date()))
    }

    @Test("Scheduling components carry an explicit calendar and time zone")
    func schedulingComponentsAreExplicit() throws {
        let date = try ScheduledDate(rawValue: "2026-09-08T07:30:00")
        let components = date.schedulingComponents(in: berlin)
        #expect(components.timeZone == berlin)
        #expect(components.calendar != nil)
        #expect(components.year == 2026)
        #expect(components.hour == 7)
    }

    @Test("Accepted spellings", arguments: [
        "2026-09-08",
        "2026-09-08T07:30",
        "2026-09-08T07:30:00",
        "2026-09-08 07:30:00",
        "2026-09-08T07:30:00Z",
        "2026-09-08T07:30:00+03:00",
    ])
    func accepted(_ raw: String) throws {
        #expect(throws: Never.self) { try ScheduledDate(rawValue: raw) }
    }

    @Test("Rejected spellings", arguments: [
        "next monday",
        "08.09.2026",
        "2026-9-8",
        "2026-13-01T07:30:00",
        "2026-09-08T25:00:00",
        "",
    ])
    func rejected(_ raw: String) throws {
        #expect(throws: FormatError.self) { try ScheduledDate(rawValue: raw) }
    }

    @Test("A date written by hand round-trips through the raw string")
    func rawValueIsPreserved() throws {
        let date = ScheduledDate(
            ScheduledDate.WallClock(year: 2026, month: 9, day: 8, hour: 7, minute: 5))
        #expect(date.rawValue == "2026-09-08T07:05:00")
        #expect(try ScheduledDate(rawValue: date.rawValue) == date)
    }
}
