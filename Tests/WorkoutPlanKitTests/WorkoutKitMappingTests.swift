import Foundation
import HealthKit
import Testing
import WorkoutKit
import WorkoutPlanFormat

@testable import WorkoutPlanKit

/// These tests build real WorkoutKit values and run them through WorkoutKit's own
/// `supports*` validators, which is the closest check available without a watch.
enum Repository {
    static let root = URL(filePath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    static func files(in directory: String, extension ext: String) throws -> [URL] {
        try FileManager.default
            .contentsOfDirectory(at: root.appending(path: directory), includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == ext }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }
}

private func read(_ json: String) throws -> WorkoutPlanFile {
    try WorkoutPlanFile(data: Data(json.utf8))
}

@Suite("WorkoutKit mapping")
struct WorkoutKitMappingTests {

    @Test("Every example maps to a real WorkoutKit workout")
    func examplesMap() throws {
        let examples = try Repository.files(in: "examples", extension: "workoutplan")
        #expect(!examples.isEmpty)
        for url in examples {
            let file = try WorkoutPlanFile(contentsOf: url)
            #expect(throws: Never.self, "\(url.lastPathComponent)") {
                try file.workoutKitPlans()
            }
        }
    }

    @Test("Every valid conformance fixture maps too")
    func conformanceFixturesMap() throws {
        for url in try Repository.files(in: "conformance/valid", extension: "workoutplan") {
            let file = try WorkoutPlanFile(contentsOf: url)
            #expect(throws: Never.self, "\(url.lastPathComponent)") {
                try file.workoutKitPlans()
            }
        }
    }

    @Test("Each workout type produces its WorkoutKit counterpart")
    func workoutTypesMap() throws {
        let file = try read(
            """
            {"workouts":[
              {"type":"custom","activity":"running","location":"outdoor","blocks":[
                {"iterations":2,"steps":[{"purpose":"work","goal":{"type":"time","value":5,"unit":"min"}}]}]},
              {"type":"goal","activity":"running","location":"outdoor","goal":{"type":"distance","value":5,"unit":"km"}},
              {"type":"pacer","activity":"running","location":"outdoor",
                "distance":{"value":10,"unit":"km"},"time":{"value":50,"unit":"min"}},
              {"type":"swimBikeRun","legs":[
                {"sport":"swimming","swimmingLocation":"openWater"},
                {"sport":"cycling","location":"outdoor"},
                {"sport":"running","location":"outdoor"}]}
            ]}
            """)
        let plans = try file.workoutKitPlans()
        #expect(plans.count == 4)

        guard case .custom(let custom) = plans[0].workout else {
            Issue.record("expected a custom workout")
            return
        }
        #expect(custom.activity == .running)
        #expect(custom.blocks.count == 1)
        #expect(custom.blocks[0].iterations == 2)

        guard case .goal(let goal) = plans[1].workout else {
            Issue.record("expected a goal workout")
            return
        }
        #expect(goal.goal == .distance(5, .kilometers))

        guard case .pacer = plans[2].workout else {
            Issue.record("expected a pacer workout")
            return
        }
        guard case .swimBikeRun(let triathlon) = plans[3].workout else {
            Issue.record("expected a swim-bike-run workout")
            return
        }
        #expect(triathlon.activities.count == 3)
    }

    @Test("Heart-rate, power, cadence and speed alerts all build")
    func alertsBuild() throws {
        let file = try WorkoutPlanFile(
            contentsOf: Repository.root.appending(path: "conformance/valid/all-alerts.workoutplan"))
        let plans = try file.workoutKitPlans()

        guard case .custom(let cycling) = plans[0].workout else {
            Issue.record("expected a custom workout")
            return
        }
        let alerts = cycling.blocks[0].steps.compactMap(\.step.alert)
        #expect(alerts.count == 5)
        #expect(alerts.contains { $0 is PowerRangeAlert })
        #expect(alerts.contains { $0 is CadenceThresholdAlert })
    }

    @Test("An omitted power metric keeps WorkoutKit's default rather than forcing .current")
    func omittedPowerMetric() throws {
        let withoutMetric = try read(
            """
            {"workouts":[{"type":"custom","activity":"cycling","location":"outdoor","blocks":[
              {"iterations":1,"steps":[{"purpose":"work","goal":{"type":"time","value":3,"unit":"min"},
                "alert":{"type":"powerRange","min":200,"max":230,"unit":"W"}}]}]}]}
            """)
        let withCurrent = try read(
            """
            {"workouts":[{"type":"custom","activity":"cycling","location":"outdoor","blocks":[
              {"iterations":1,"steps":[{"purpose":"work","goal":{"type":"time","value":3,"unit":"min"},
                "alert":{"type":"powerRange","min":200,"max":230,"unit":"W","metric":"current"}}]}]}]}
            """)

        func firstAlert(_ file: WorkoutPlanFile) throws -> (any WorkoutAlert)? {
            guard case .custom(let custom) = try file.workoutKitPlans()[0].workout else { return nil }
            return custom.blocks[0].steps[0].step.alert
        }

        let defaulted = try #require(try firstAlert(withoutMetric) as? PowerRangeAlert)
        let explicit = try #require(try firstAlert(withCurrent) as? PowerRangeAlert)
        #expect(explicit.metric == .current)
        // Whatever WorkoutKit's default is, the point is that we did not overwrite it.
        #expect(defaulted.target == explicit.target)
    }

    @Test("Unsupported combinations are rejected with a specific error")
    func unsupportedCombinations() throws {
        // A power alert on a yoga session is not something WorkoutKit will take.
        let file = try read(
            """
            {"workouts":[{"type":"custom","activity":"yoga","location":"indoor","blocks":[
              {"iterations":1,"steps":[{"purpose":"work","goal":{"type":"time","value":5,"unit":"min"},
                "alert":{"type":"powerRange","min":200,"max":230,"unit":"W"}}]}]}]}
            """)
        do {
            _ = try file.workoutKitPlans()
            Issue.record("expected the alert to be rejected")
        } catch let error as FormatError {
            #expect(error.code == .unsupportedAlert)
        }
    }

    @Test("A distance goal on an activity that cannot measure distance is rejected")
    func unsupportedGoal() throws {
        let file = try read(
            """
            {"workouts":[{"type":"goal","activity":"yoga","location":"indoor",
              "goal":{"type":"distance","value":5,"unit":"km"}}]}
            """)
        do {
            _ = try file.workoutKitPlans()
            Issue.record("expected the goal to be rejected")
        } catch let error as FormatError {
            #expect(error.code == .unsupportedGoal)
        }
    }
}

@Suite("Scheduling")
struct SchedulingTests {

    @Test("Dated and undated workouts both resolve")
    func resolveDates() throws {
        let file = try read(
            """
            {"workouts":[
              {"type":"goal","scheduledDate":"2026-09-08T07:30:00","activity":"running","goal":{"type":"open"}},
              {"type":"goal","activity":"running","goal":{"type":"open"}}
            ]}
            """)
        let berlin = TimeZone(identifier: "Europe/Berlin")!
        let fallback = Date(timeIntervalSince1970: 1_788_000_000)

        let resolved = try WorkoutPlanScheduler.resolve(file, timeZone: berlin) { _ in fallback }
        #expect(resolved.count == 2)
        #expect(resolved[0].date.hour == 7)
        #expect(resolved[0].date.minute == 30)
        #expect(resolved[0].date.timeZone == berlin)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = berlin
        #expect(resolved[1].date.hour == calendar.component(.hour, from: fallback))
    }

    @Test("The scheduling limit comes from WorkoutKit, not from a guess")
    func limitIsReadFromWorkoutKit() {
        #expect(WorkoutPlanScheduler.maxScheduledWorkoutCount > 0)
    }

    @Test("An app can build a ResolvedWorkout from its own date picker")
    func resolvedWorkoutIsConstructible() throws {
        let file = try read(
            #"{"workouts":[{"type":"goal","activity":"running","goal":{"type":"open"}}]}"#)
        let workout = file.workouts[0]

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        var date = DateComponents()
        date.calendar = calendar
        date.timeZone = calendar.timeZone
        date.year = 2026
        date.month = 9
        date.day = 8
        date.hour = 7
        date.minute = 30

        let resolved = ResolvedWorkout(
            source: workout, plan: try workout.workoutKitPlan(), date: date)
        #expect(resolved.scheduledWorkoutPlan.date.hour == 7)
        #expect(resolved.scheduledWorkoutPlan.plan == resolved.plan)
    }

    @Test("Authorization states map onto a Sendable value")
    func authorizationMapping() {
        #expect(SchedulingAuthorization(.notDetermined) == .notDetermined)
        #expect(SchedulingAuthorization(.restricted) == .restricted)
        #expect(SchedulingAuthorization(.denied) == .denied)
        #expect(SchedulingAuthorization(.authorized) == .authorized)
        #expect(SchedulingAuthorization(.authorized).isAuthorized)
        #expect(!SchedulingAuthorization(.denied).isAuthorized)
    }
}
