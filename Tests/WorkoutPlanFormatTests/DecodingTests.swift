import Foundation
import Testing

@testable import WorkoutPlanFormat

private func read(_ json: String) throws -> WorkoutPlanFile {
    try WorkoutPlanFile(data: Data(json.utf8))
}

@Suite("Decoding")
struct DecodingTests {

    @Test("A step without a goal is an open step")
    func stepGoalDefaultsToOpen() throws {
        let file = try read(
            """
            {"workouts":[{"type":"custom","activity":"running","blocks":[
              {"iterations":1,"steps":[{"purpose":"work"}]}]}]}
            """)
        guard case .custom(let custom) = file.workouts[0].kind else {
            Issue.record("expected a custom workout")
            return
        }
        #expect(custom.blocks[0].steps[0].goal == .open)
    }

    @Test("Aliases and casing are accepted, and canonical spellings are written back")
    func aliasesNormalise() throws {
        let file = try read(
            """
            {"workouts":[{"type":"CUSTOM","activity":"run","location":"Outdoor","blocks":[
              {"iterations":1,"steps":[
                {"purpose":"rest","goal":{"type":"time","value":90,"unit":"seconds"}}]}]}]}
            """)
        guard case .custom(let custom) = file.workouts[0].kind else {
            Issue.record("expected a custom workout")
            return
        }
        #expect(custom.activity == .running)
        #expect(custom.location == .outdoor)
        #expect(custom.blocks[0].steps[0].purpose == .recovery)
        #expect(custom.blocks[0].steps[0].goal == .time(TimeMeasure(90, .seconds)))

        let rewritten = String(decoding: try file.encoded(), as: UTF8.self)
        #expect(rewritten.contains("\"activity\" : \"running\""))
        #expect(rewritten.contains("\"unit\" : \"s\""))
    }

    @Test("A missing version means version 1")
    func versionDefaults() throws {
        let file = try read(#"{"workouts":[{"type":"goal","activity":"running","goal":{"type":"open"}}]}"#)
        #expect(file.version == 1)
    }

    @Test("Unknown keys are ignored, but `extensions` round-trips")
    func extensionsSurviveUnknownKeys() throws {
        let file = try read(
            """
            {"workouts":[{"type":"goal","activity":"running","goal":{"type":"open"},
              "somethingWeInvented":42,
              "extensions":{"com.example":{"tss":65}}}]}
            """)
        let reread = try WorkoutPlanFile(data: try file.encoded())
        #expect(
            reread.workouts[0].extensions
                == .object(["com.example": .object(["tss": .number(65)])]))
    }

    @Test("An omitted power metric stays omitted")
    func powerMetricStaysOptional() throws {
        let file = try read(
            """
            {"workouts":[{"type":"custom","activity":"cycling","blocks":[
              {"iterations":1,"steps":[{"purpose":"work",
                "alert":{"type":"powerRange","min":200,"max":230,"unit":"W"}}]}]}]}
            """)
        guard case .custom(let custom) = file.workouts[0].kind,
            case .powerRange(_, _, _, let metric) = custom.blocks[0].steps[0].alert
        else {
            Issue.record("expected a power range alert")
            return
        }
        #expect(metric == nil)
        #expect(!String(decoding: try file.encoded(), as: UTF8.self).contains("metric"))
    }

    @Test("Errors point at the field that caused them")
    func errorsCarryAField() throws {
        do {
            _ = try read(
                #"{"workouts":[{"type":"pacer","activity":"running","distance":{"value":10,"unit":"km"}}]}"#)
            Issue.record("expected the missing time to be rejected")
        } catch let error as FormatError {
            #expect(error.code == .missingField)
            #expect(error.field == "time")
        }
    }

    @Test("A file that is not JSON reports invalid_json, not a decoding crash")
    func notJSON() throws {
        do {
            _ = try read("this is not json")
            Issue.record("expected a parse failure")
        } catch let error as FormatError {
            #expect(error.code == .invalidJSON)
        }
    }
}
