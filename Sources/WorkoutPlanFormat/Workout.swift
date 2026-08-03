import Foundation

/// One planned workout.
///
/// On the wire this is a flat object tagged by `type`; in Swift the fields that
/// only apply to one kind live inside ``Workout/Kind``.
public struct Workout: Hashable, Sendable {
    /// When the workout should appear on the watch. When absent, the consuming
    /// app decides (typically by asking the athlete).
    public var scheduledDate: ScheduledDate?
    /// Title shown on the watch.
    public var displayName: String?
    public var kind: Kind
    /// Reserved container for vendor data; round-trips untouched.
    public var extensions: JSONValue?

    public init(
        scheduledDate: ScheduledDate? = nil,
        displayName: String? = nil,
        kind: Kind,
        extensions: JSONValue? = nil
    ) {
        self.scheduledDate = scheduledDate
        self.displayName = displayName
        self.kind = kind
        self.extensions = extensions
    }

    /// The four workout shapes WorkoutKit can schedule.
    public enum Kind: Hashable, Sendable {
        /// Warmup + repeated interval blocks + cooldown.
        case custom(Custom)
        /// A single goal: run 5 km, ride 40 minutes, burn 400 kcal.
        case goal(SingleGoal)
        /// A distance to cover within a time (the watch paces you).
        case pacer(Pacer)
        /// Triathlon-style multisport, one leg per sport.
        case swimBikeRun(legs: [Leg])

        /// The `type` tag as written to file.
        public var typeName: String {
            switch self {
            case .custom: "custom"
            case .goal: "goal"
            case .pacer: "pacer"
            case .swimBikeRun: "swimBikeRun"
            }
        }
    }

    public struct Custom: Hashable, Sendable {
        public var activity: Activity
        public var location: Location
        public var warmup: Step?
        public var blocks: [Block]
        public var cooldown: Step?

        public init(
            activity: Activity,
            location: Location = .unknown,
            warmup: Step? = nil,
            blocks: [Block] = [],
            cooldown: Step? = nil
        ) {
            self.activity = activity
            self.location = location
            self.warmup = warmup
            self.blocks = blocks
            self.cooldown = cooldown
        }

        /// Warmup, every step of every block, then cooldown, in workout order
        /// and without expanding repetitions.
        public var allSteps: [Step] {
            (warmup.map { [$0] } ?? []) + blocks.flatMap(\.steps) + (cooldown.map { [$0] } ?? [])
        }
    }

    public struct SingleGoal: Hashable, Sendable {
        public var activity: Activity
        public var location: Location
        public var swimmingLocation: SwimmingLocation
        public var goal: Goal

        public init(
            activity: Activity,
            location: Location = .unknown,
            swimmingLocation: SwimmingLocation = .unknown,
            goal: Goal
        ) {
            self.activity = activity
            self.location = location
            self.swimmingLocation = swimmingLocation
            self.goal = goal
        }
    }

    public struct Pacer: Hashable, Sendable {
        public var activity: Activity
        public var location: Location
        public var distance: DistanceMeasure
        public var time: TimeMeasure

        public init(
            activity: Activity,
            location: Location = .unknown,
            distance: DistanceMeasure,
            time: TimeMeasure
        ) {
            self.activity = activity
            self.location = location
            self.distance = distance
            self.time = time
        }
    }

    /// One leg of a ``Workout/Kind/swimBikeRun(legs:)`` workout.
    public struct Leg: Hashable, Sendable, Codable {
        public var sport: LegSport
        /// Used by the cycling and running legs.
        public var location: Location
        /// Used by the swimming leg.
        public var swimmingLocation: SwimmingLocation

        public init(
            sport: LegSport,
            location: Location = .unknown,
            swimmingLocation: SwimmingLocation = .unknown
        ) {
            self.sport = sport
            self.location = location
            self.swimmingLocation = swimmingLocation
        }

        private enum CodingKeys: String, CodingKey { case sport, location, swimmingLocation }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            guard let sport = try container.decodeIfPresent(LegSport.self, forKey: .sport) else {
                throw FormatError.missingField("legs.sport")
            }
            self.sport = sport
            self.location = try container.decodeIfPresent(Location.self, forKey: .location)
                ?? .unknown
            self.swimmingLocation = try container.decodeIfPresent(
                SwimmingLocation.self, forKey: .swimmingLocation) ?? .unknown
        }

        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(sport, forKey: .sport)
            switch sport {
            case .swimming:
                try container.encode(swimmingLocation, forKey: .swimmingLocation)
            case .cycling, .running:
                try container.encode(location, forKey: .location)
            }
        }
    }
}

// MARK: - Convenience accessors

extension Workout {
    /// The activity, for the three single-activity kinds. `nil` for swim-bike-run.
    public var activity: Activity? {
        switch kind {
        case .custom(let workout): workout.activity
        case .goal(let workout): workout.activity
        case .pacer(let workout): workout.activity
        case .swimBikeRun: nil
        }
    }
}

// MARK: - Codable

extension Workout: Codable {
    private enum CodingKeys: String, CodingKey {
        case type, scheduledDate, displayName
        case activity, location
        case warmup, blocks, cooldown
        case goal, swimmingLocation
        case distance, time
        case legs
        case extensions
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        guard let type = try container.decodeIfPresent(String.self, forKey: .type) else {
            throw FormatError.missingField("type")
        }
        self.scheduledDate = try container.decodeIfPresent(
            ScheduledDate.self, forKey: .scheduledDate)
        self.displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        self.extensions = try container.decodeIfPresent(JSONValue.self, forKey: .extensions)

        func activity() throws -> Activity {
            guard let value = try container.decodeIfPresent(Activity.self, forKey: .activity) else {
                throw FormatError.missingField("activity")
            }
            return value
        }
        func location() throws -> Location {
            try container.decodeIfPresent(Location.self, forKey: .location) ?? .unknown
        }

        switch normalizeToken(type) {
        case "custom":
            self.kind = .custom(
                Custom(
                    activity: try activity(),
                    location: try location(),
                    warmup: try container.decodeIfPresent(Step.self, forKey: .warmup),
                    blocks: try container.decodeIfPresent([Block].self, forKey: .blocks) ?? [],
                    cooldown: try container.decodeIfPresent(Step.self, forKey: .cooldown)))

        case "goal":
            guard let goal = try container.decodeIfPresent(Goal.self, forKey: .goal) else {
                throw FormatError.missingField("goal")
            }
            self.kind = .goal(
                SingleGoal(
                    activity: try activity(),
                    location: try location(),
                    swimmingLocation: try container.decodeIfPresent(
                        SwimmingLocation.self, forKey: .swimmingLocation) ?? .unknown,
                    goal: goal))

        case "pacer":
            self.kind = .pacer(
                Pacer(
                    activity: try activity(),
                    location: try location(),
                    distance: try DistanceMeasure.decode(
                        from: container, key: .distance, field: "distance"),
                    time: try TimeMeasure.decode(from: container, key: .time, field: "time")))

        case "swimbikerun":
            guard let legs = try container.decodeIfPresent([Leg].self, forKey: .legs) else {
                throw FormatError.missingField("legs")
            }
            guard !legs.isEmpty else {
                throw FormatError(
                    .emptyLegs, "A swimBikeRun workout needs at least one leg.", field: "legs")
            }
            self.kind = .swimBikeRun(legs: legs)

        default:
            throw FormatError(
                .unknownWorkoutType,
                "Unknown workout type '\(type)'. Expected one of: custom, goal, pacer, swimBikeRun.",
                field: "type")
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind.typeName, forKey: .type)
        try container.encodeIfPresent(scheduledDate, forKey: .scheduledDate)
        try container.encodeIfPresent(displayName, forKey: .displayName)

        switch kind {
        case .custom(let workout):
            try container.encode(workout.activity, forKey: .activity)
            try container.encode(workout.location, forKey: .location)
            try container.encodeIfPresent(workout.warmup, forKey: .warmup)
            try container.encode(workout.blocks, forKey: .blocks)
            try container.encodeIfPresent(workout.cooldown, forKey: .cooldown)

        case .goal(let workout):
            try container.encode(workout.activity, forKey: .activity)
            try container.encode(workout.location, forKey: .location)
            if workout.activity == .swimming {
                try container.encode(workout.swimmingLocation, forKey: .swimmingLocation)
            }
            try container.encode(workout.goal, forKey: .goal)

        case .pacer(let workout):
            try container.encode(workout.activity, forKey: .activity)
            try container.encode(workout.location, forKey: .location)
            try container.encode(workout.distance, forKey: .distance)
            try container.encode(workout.time, forKey: .time)

        case .swimBikeRun(let legs):
            try container.encode(legs, forKey: .legs)
        }

        try container.encodeIfPresent(extensions, forKey: .extensions)
    }
}
