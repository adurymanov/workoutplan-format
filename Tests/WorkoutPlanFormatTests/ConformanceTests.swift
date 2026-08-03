import Foundation
import Testing

@testable import WorkoutPlanFormat

/// Locates the repository's shared, language-agnostic test data.
enum Repository {
    static let root = URL(filePath: #filePath)
        .deletingLastPathComponent()  // WorkoutPlanFormatTests
        .deletingLastPathComponent()  // Tests
        .deletingLastPathComponent()  // repository root

    static var examples: [URL] {
        get throws {
            try FileManager.default
                .contentsOfDirectory(at: root.appending(path: "examples"), includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "workoutplan" }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
        }
    }

    struct Manifest: Decodable {
        struct ValidCase: Decodable {
            let file: String
            let description: String
        }
        struct InvalidCase: Decodable {
            let file: String
            let error: FormatError.Code
            let description: String
        }
        let valid: [ValidCase]
        let invalid: [InvalidCase]
    }

    static var manifest: Manifest {
        get throws {
            let url = root.appending(path: "conformance/manifest.json")
            return try JSONDecoder().decode(Manifest.self, from: try Data(contentsOf: url))
        }
    }

    static func conformanceFile(_ path: String) throws -> Data {
        try Data(contentsOf: root.appending(path: "conformance").appending(path: path))
    }
}

@Suite("Conformance suite")
struct ConformanceTests {

    @Test("Every file under conformance/valid loads")
    func validFixturesLoad() throws {
        for testCase in try Repository.manifest.valid {
            let data = try Repository.conformanceFile(testCase.file)
            #expect(throws: Never.self, "\(testCase.file): \(testCase.description)") {
                try WorkoutPlanFile(data: data)
            }
        }
    }

    @Test("Every file under conformance/invalid is rejected with the documented code")
    func invalidFixturesAreRejected() throws {
        for testCase in try Repository.manifest.invalid {
            let data = try Repository.conformanceFile(testCase.file)
            do {
                _ = try WorkoutPlanFile(data: data)
                Issue.record("\(testCase.file) was accepted but should fail with '\(testCase.error.rawValue)'")
            } catch let error as FormatError {
                #expect(
                    error.code == testCase.error,
                    "\(testCase.file): expected '\(testCase.error.rawValue)', got '\(error.code.rawValue)': \(error.description)")
            }
        }
    }

    @Test("Every shipped example loads")
    func examplesLoad() throws {
        let examples = try Repository.examples
        #expect(!examples.isEmpty)
        for url in examples {
            #expect(throws: Never.self, "\(url.lastPathComponent)") {
                try WorkoutPlanFile(contentsOf: url)
            }
        }
    }

    @Test("Examples and valid fixtures survive a decode → encode → decode round-trip")
    func roundTrip() throws {
        var urls = try Repository.examples
        urls += try Repository.manifest.valid.map {
            Repository.root.appending(path: "conformance").appending(path: $0.file)
        }

        for url in urls {
            let original = try WorkoutPlanFile(contentsOf: url)
            let reread = try WorkoutPlanFile(data: try original.encoded())
            #expect(original == reread, "\(url.lastPathComponent) changed when rewritten")
        }
    }

    @Test("Rewriting a file twice is byte-identical")
    func encodingIsStable() throws {
        for url in try Repository.examples {
            let file = try WorkoutPlanFile(contentsOf: url)
            #expect(try file.encoded() == (try file.encoded()))
        }
    }
}
