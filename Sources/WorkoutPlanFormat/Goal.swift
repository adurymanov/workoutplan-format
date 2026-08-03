import Foundation

/// What ends a step or a single-goal workout.
///
/// Encoded as a tagged union: `{"type": "time", "value": 5, "unit": "min"}`.
public enum Goal: Hashable, Sendable {
    /// Untimed. The athlete taps to advance.
    case open
    case distance(DistanceMeasure)
    case time(TimeMeasure)
    /// Active energy burned. **Only valid in a `goal` workout**, never inside a
    /// `custom` workout's steps, which is a WorkoutKit restriction.
    case energy(EnergyMeasure)
    /// Swim a distance within a time; pool swimming only.
    case poolSwimDistanceWithTime(distance: DistanceMeasure, time: TimeMeasure)

    /// The `type` tag as written to file.
    public var typeName: String {
        switch self {
        case .open: "open"
        case .distance: "distance"
        case .time: "time"
        case .energy: "energy"
        case .poolSwimDistanceWithTime: "poolSwimDistanceWithTime"
        }
    }
}

extension Goal: Codable {
    private enum CodingKeys: String, CodingKey {
        case type, value, unit, distance, time
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard let type = try container.decodeIfPresent(String.self, forKey: .type) else {
            throw FormatError.missingField("goal.type")
        }

        func measure<Unit: FileVocabulary>(_ unitType: Unit.Type) throws -> Measure<Unit> {
            guard let value = try container.decodeIfPresent(Double.self, forKey: .value) else {
                throw FormatError.missingField("goal.value")
            }
            guard let rawUnit = try container.decodeIfPresent(String.self, forKey: .unit) else {
                throw FormatError.missingField("goal.unit")
            }
            return Measure(value, try Unit(fileValue: rawUnit, field: "goal.unit"))
        }

        switch normalizeToken(type) {
        case "open":
            self = .open
        case "distance":
            self = .distance(try measure(LengthUnit.self))
        case "time":
            self = .time(try measure(TimeUnit.self))
        case "energy":
            self = .energy(try measure(EnergyUnit.self))
        case "poolswimdistancewithtime":
            self = .poolSwimDistanceWithTime(
                distance: try DistanceMeasure.decode(
                    from: container, key: .distance, field: "goal.distance"),
                time: try TimeMeasure.decode(
                    from: container, key: .time, field: "goal.time"))
        default:
            throw FormatError(
                .unknownGoalType,
                "Unknown goal type '\(type)'. Expected one of: open, distance, time, energy, poolSwimDistanceWithTime.",
                field: "goal.type")
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(typeName, forKey: .type)
        switch self {
        case .open:
            break
        case .distance(let measure):
            try container.encode(measure.value, forKey: .value)
            try container.encode(measure.unit, forKey: .unit)
        case .time(let measure):
            try container.encode(measure.value, forKey: .value)
            try container.encode(measure.unit, forKey: .unit)
        case .energy(let measure):
            try container.encode(measure.value, forKey: .value)
            try container.encode(measure.unit, forKey: .unit)
        case .poolSwimDistanceWithTime(let distance, let time):
            try container.encode(distance, forKey: .distance)
            try container.encode(time, forKey: .time)
        }
    }
}
