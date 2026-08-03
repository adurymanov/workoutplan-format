import Foundation

/// One step of a custom workout: a goal, an optional alert, an optional label.
///
/// The same shape is used for the warmup, the cooldown and the steps inside a
/// block; `purpose` is meaningful only inside a block.
public struct Step: Hashable, Sendable {
    /// `work` or `recovery`. Ignored for warmup and cooldown steps.
    public var purpose: StepPurpose?
    /// Defaults to ``Goal/open`` when the file omits it.
    public var goal: Goal
    /// At most one alert per step. See ``Alert``.
    public var alert: Alert?
    /// Free text shown on the watch. For strength work this is also where reps and
    /// load go (`"Bench press 10 x 60 kg"`), because WorkoutKit has no field for them.
    public var displayName: String?
    /// Reserved container for vendor data; round-trips untouched.
    public var extensions: JSONValue?

    public init(
        purpose: StepPurpose? = nil,
        goal: Goal = .open,
        alert: Alert? = nil,
        displayName: String? = nil,
        extensions: JSONValue? = nil
    ) {
        self.purpose = purpose
        self.goal = goal
        self.alert = alert
        self.displayName = displayName
        self.extensions = extensions
    }
}

extension Step: Codable {
    private enum CodingKeys: String, CodingKey {
        case purpose, goal, alert, displayName, extensions
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.purpose = try container.decodeIfPresent(StepPurpose.self, forKey: .purpose)
        self.goal = try container.decodeIfPresent(Goal.self, forKey: .goal) ?? .open
        self.alert = try container.decodeIfPresent(Alert.self, forKey: .alert)
        self.displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        self.extensions = try container.decodeIfPresent(JSONValue.self, forKey: .extensions)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(purpose, forKey: .purpose)
        try container.encode(goal, forKey: .goal)
        try container.encodeIfPresent(alert, forKey: .alert)
        try container.encodeIfPresent(displayName, forKey: .displayName)
        try container.encodeIfPresent(extensions, forKey: .extensions)
    }
}

/// A repeated group of steps.
public struct Block: Hashable, Sendable, Codable {
    /// How many times the group repeats. Must be at least 1.
    public var iterations: Int
    public var steps: [Step]
    /// Reserved container for vendor data; round-trips untouched.
    public var extensions: JSONValue?

    public init(iterations: Int = 1, steps: [Step], extensions: JSONValue? = nil) {
        self.iterations = iterations
        self.steps = steps
        self.extensions = extensions
    }

    private enum CodingKeys: String, CodingKey { case iterations, steps, extensions }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let iterations = try container.decodeIfPresent(Int.self, forKey: .iterations) ?? 1
        guard iterations >= 1 else {
            throw FormatError(
                .invalidIterations,
                "A block must repeat at least once; got \(iterations).",
                field: "blocks.iterations")
        }
        self.iterations = iterations
        self.steps = try container.decodeIfPresent([Step].self, forKey: .steps) ?? []
        self.extensions = try container.decodeIfPresent(JSONValue.self, forKey: .extensions)
    }
}
