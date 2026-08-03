import Foundation

/// The root of a `.workoutplan` file.
///
/// ```swift
/// let file = try WorkoutPlanFile(data: Data(contentsOf: url))
/// for workout in file.workouts { … }
/// ```
///
/// ``init(data:)`` decodes *and* validates. Decoding through `JSONDecoder`
/// directly skips the whole-file checks in ``validate()``.
public struct WorkoutPlanFile: Hashable, Sendable {

    /// The format version this library reads and writes.
    public static let currentVersion = 1

    /// File-name extension, without the dot.
    public static let fileExtension = "workoutplan"

    /// Uniform Type Identifier exported by conforming apps.
    public static let uniformTypeIdentifier = "io.github.adurymanov.workoutplan"

    /// Media type for HTTP and mail attachments.
    public static let mediaType = "application/vnd.workoutplan+json"

    public var version: Int
    public var workouts: [Workout]
    /// Reserved container for vendor data; round-trips untouched.
    public var extensions: JSONValue?

    public init(
        version: Int = WorkoutPlanFile.currentVersion,
        workouts: [Workout],
        extensions: JSONValue? = nil
    ) {
        self.version = version
        self.workouts = workouts
        self.extensions = extensions
    }

    // MARK: - Reading

    /// Decodes and validates a `.workoutplan` file.
    ///
    /// - Throws: ``FormatError`` for anything this format defines as invalid, and
    ///   a `FormatError` with code `invalid_json` if the bytes are not JSON.
    public init(data: Data) throws {
        do {
            self = try JSONDecoder().decode(WorkoutPlanFile.self, from: data)
        } catch let error as FormatError {
            throw error
        } catch let error as DecodingError {
            throw FormatError(.invalidJSON, Self.describe(error))
        }
        try validate()
    }

    /// Convenience for reading straight off disk.
    public init(contentsOf url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    // MARK: - Writing

    /// Serialises the file. Keys are sorted so that output is reproducible.
    public func encoded(prettyPrinted: Bool = true) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting =
            prettyPrinted ? [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes] : [.sortedKeys]
        return try encoder.encode(self)
    }

    // MARK: - Validation

    /// Checks the rules that cannot be expressed by decoding a single value.
    ///
    /// Constraints that depend on WorkoutKit's own `supports*` tables (which
    /// activity accepts which alert, for instance) are checked by `WorkoutPlanKit`
    /// when a workout is converted, not here.
    public func validate() throws {
        guard version >= 1 else {
            throw FormatError(
                .unsupportedVersion, "Version must be 1 or greater; got \(version).",
                field: "version")
        }
        guard version <= Self.currentVersion else {
            throw FormatError(
                .unsupportedVersion,
                "This file declares version \(version); this library reads version \(Self.currentVersion).",
                field: "version")
        }
        guard !workouts.isEmpty else {
            throw FormatError(.emptyFile, "The file contains no workouts.", field: "workouts")
        }

        for (index, workout) in workouts.enumerated() {
            guard case .custom(let custom) = workout.kind else { continue }
            for step in custom.allSteps {
                if case .energy = step.goal {
                    throw FormatError(
                        .energyGoalInCustomWorkout,
                        "An energy goal cannot be used inside a custom workout. Use a 'goal' workout, or a time or distance goal.",
                        field: "workouts[\(index)]")
                }
            }
        }
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey { case version, workouts, extensions }

    private static func describe(_ error: DecodingError) -> String {
        switch error {
        case .dataCorrupted(let context) where context.codingPath.isEmpty:
            return "The file is not valid JSON. \(context.debugDescription)"
        case .typeMismatch(_, let context), .valueNotFound(_, let context),
            .keyNotFound(_, let context), .dataCorrupted(let context):
            let path = context.codingPath.map(\.stringValue).joined(separator: ".")
            return path.isEmpty
                ? context.debugDescription : "\(context.debugDescription) (at \(path))"
        @unknown default:
            return "The file could not be decoded."
        }
    }
}

extension WorkoutPlanFile: Codable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.version =
            try container.decodeIfPresent(Int.self, forKey: .version) ?? Self.currentVersion
        // Reject a future major version before trying to decode workouts written
        // in a shape this reader does not know.
        guard version <= Self.currentVersion else {
            throw FormatError(
                .unsupportedVersion,
                "This file declares version \(version); this library reads version \(Self.currentVersion).",
                field: "version")
        }
        self.workouts = try container.decodeIfPresent([Workout].self, forKey: .workouts) ?? []
        self.extensions = try container.decodeIfPresent(JSONValue.self, forKey: .extensions)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(version, forKey: .version)
        try container.encode(workouts, forKey: .workouts)
        try container.encodeIfPresent(extensions, forKey: .extensions)
    }
}
