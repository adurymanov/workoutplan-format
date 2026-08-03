import Foundation

/// Every error the format layer (and the WorkoutKit mapping layer) can raise.
///
/// Errors carry a stable machine-readable `code` so that conformance suites and
/// non-Swift implementations can agree on *why* a file was rejected, plus an
/// English `message` meant for developers. Apps that show errors to end users
/// should localise them from the code, not from the message.
public struct FormatError: Error, Hashable, Sendable, CustomStringConvertible, LocalizedError {

    /// Stable identifiers, also used by the language-agnostic conformance suite.
    public enum Code: String, Codable, Hashable, Sendable, CaseIterable {
        // Structure
        case invalidJSON = "invalid_json"
        case emptyFile = "empty_file"
        case unsupportedVersion = "unsupported_version"
        case missingField = "missing_field"
        case unknownWorkoutType = "unknown_workout_type"

        // Vocabulary
        case unknownActivity = "unknown_activity"
        case unknownSport = "unknown_sport"
        case unknownLocation = "unknown_location"
        case unknownPurpose = "unknown_purpose"
        case unknownGoalType = "unknown_goal_type"
        case unknownAlertType = "unknown_alert_type"
        case unknownMetric = "unknown_metric"
        case unknownUnit = "unknown_unit"

        // Values
        case invalidZone = "invalid_zone"
        case invalidRange = "invalid_range"
        case invalidIterations = "invalid_iterations"
        case invalidValue = "invalid_value"
        case invalidDate = "invalid_date"
        case emptyLegs = "empty_legs"

        // Constraints that come from WorkoutKit itself
        case energyGoalInCustomWorkout = "energy_goal_in_custom_workout"
        case unsupportedActivity = "unsupported_activity"
        case unsupportedGoal = "unsupported_goal"
        case unsupportedAlert = "unsupported_alert"
        case unsupportedLegOrdering = "unsupported_leg_ordering"
    }

    public let code: Code
    public let message: String
    /// Dotted path to the offending value, e.g. `workouts[1].blocks[0].steps[2].goal`.
    public let field: String?

    public init(_ code: Code, _ message: String, field: String? = nil) {
        self.code = code
        self.message = message
        self.field = field
    }

    public var description: String {
        guard let field else { return message }
        return "\(message) (at \(field))"
    }

    public var errorDescription: String? { description }

    // MARK: - Common constructors

    static func missingField(_ name: String) -> FormatError {
        FormatError(.missingField, "Required field '\(name)' is missing.", field: name)
    }

    static func invalidValue(_ message: String, field: String? = nil) -> FormatError {
        FormatError(.invalidValue, message, field: field)
    }
}
