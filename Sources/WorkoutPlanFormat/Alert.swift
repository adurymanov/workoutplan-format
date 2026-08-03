import Foundation

/// A live target shown on the watch during a step.
///
/// Encoded as a tagged union: `{"type": "heartRateZone", "zone": 4}`.
///
/// **A step carries at most one alert.** That is a WorkoutKit limitation, not a
/// limitation of this format: if both a heart-rate ceiling and a cadence target
/// matter on the same interval, pick the one that defines the session and put the
/// other in the step's `displayName`.
public enum Alert: Hashable, Sendable {
    case heartRateZone(Int)
    case heartRateRange(min: Double, max: Double)
    case cadenceRange(min: Double, max: Double)
    case cadenceThreshold(Double)
    case powerZone(Int)
    /// `metric` is optional: when omitted, WorkoutKit's own default for power
    /// alerts applies.
    case powerRange(min: Double, max: Double, unit: PowerUnit, metric: AlertMetric?)
    case powerThreshold(Double, unit: PowerUnit, metric: AlertMetric?)
    case speedRange(min: Double, max: Double, unit: SpeedUnit, metric: AlertMetric)
    case speedThreshold(Double, unit: SpeedUnit, metric: AlertMetric)

    /// The `type` tag as written to file.
    public var typeName: String {
        switch self {
        case .heartRateZone: "heartRateZone"
        case .heartRateRange: "heartRateRange"
        case .cadenceRange: "cadenceRange"
        case .cadenceThreshold: "cadenceThreshold"
        case .powerZone: "powerZone"
        case .powerRange: "powerRange"
        case .powerThreshold: "powerThreshold"
        case .speedRange: "speedRange"
        case .speedThreshold: "speedThreshold"
        }
    }

    /// Heart-rate zones on Apple Watch run from 1 to 5.
    public static let heartRateZoneRange = 1...5
}

extension Alert: Codable {
    private enum CodingKeys: String, CodingKey {
        case type, min, max, value, zone, unit, metric
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard let type = try container.decodeIfPresent(String.self, forKey: .type) else {
            throw FormatError.missingField("alert.type")
        }

        /// Ordered (min, max) pair; a reversed range is an authoring mistake worth
        /// reporting rather than silently swapping.
        func bounds() throws -> (Double, Double) {
            guard let low = try container.decodeIfPresent(Double.self, forKey: .min) else {
                throw FormatError.missingField("alert.min")
            }
            guard let high = try container.decodeIfPresent(Double.self, forKey: .max) else {
                throw FormatError.missingField("alert.max")
            }
            guard low <= high else {
                throw FormatError(
                    .invalidRange,
                    "Alert range is reversed: min (\(low)) must be less than or equal to max (\(high)).",
                    field: "alert")
            }
            return (low, high)
        }

        func threshold() throws -> Double {
            guard let value = try container.decodeIfPresent(Double.self, forKey: .value) else {
                throw FormatError.missingField("alert.value")
            }
            return value
        }

        func zone(limitedTo allowed: ClosedRange<Int>?) throws -> Int {
            guard let zone = try container.decodeIfPresent(Int.self, forKey: .zone) else {
                throw FormatError.missingField("alert.zone")
            }
            if let allowed, !allowed.contains(zone) {
                throw FormatError(
                    .invalidZone,
                    "Zone \(zone) is out of range; expected \(allowed.lowerBound) to \(allowed.upperBound).",
                    field: "alert.zone")
            }
            if allowed == nil && zone < 1 {
                throw FormatError(.invalidZone, "Zone must be 1 or greater.", field: "alert.zone")
            }
            return zone
        }

        func unit<Unit: FileVocabulary>(_ type: Unit.Type, default fallback: Unit) throws -> Unit {
            guard let raw = try container.decodeIfPresent(String.self, forKey: .unit) else {
                return fallback
            }
            return try Unit(fileValue: raw, field: "alert.unit")
        }

        func metric() throws -> AlertMetric? {
            guard let raw = try container.decodeIfPresent(String.self, forKey: .metric) else {
                return nil
            }
            return try AlertMetric(fileValue: raw, field: "alert.metric")
        }

        switch normalizeToken(type) {
        case "heartratezone":
            self = .heartRateZone(try zone(limitedTo: Alert.heartRateZoneRange))
        case "heartraterange":
            let (low, high) = try bounds()
            self = .heartRateRange(min: low, max: high)
        case "cadencerange":
            let (low, high) = try bounds()
            self = .cadenceRange(min: low, max: high)
        case "cadencethreshold":
            self = .cadenceThreshold(try threshold())
        case "powerzone":
            self = .powerZone(try zone(limitedTo: nil))
        case "powerrange":
            let (low, high) = try bounds()
            self = .powerRange(
                min: low, max: high,
                unit: try unit(PowerUnit.self, default: .watts),
                metric: try metric())
        case "powerthreshold":
            self = .powerThreshold(
                try threshold(),
                unit: try unit(PowerUnit.self, default: .watts),
                metric: try metric())
        case "speedrange":
            let (low, high) = try bounds()
            self = .speedRange(
                min: low, max: high,
                unit: try unit(SpeedUnit.self, default: .kilometersPerHour),
                metric: try metric() ?? .current)
        case "speedthreshold":
            self = .speedThreshold(
                try threshold(),
                unit: try unit(SpeedUnit.self, default: .kilometersPerHour),
                metric: try metric() ?? .current)
        default:
            throw FormatError(
                .unknownAlertType,
                "Unknown alert type '\(type)'.",
                field: "alert.type")
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(typeName, forKey: .type)
        switch self {
        case .heartRateZone(let zone), .powerZone(let zone):
            try container.encode(zone, forKey: .zone)
        case .heartRateRange(let low, let high), .cadenceRange(let low, let high):
            try container.encode(low, forKey: .min)
            try container.encode(high, forKey: .max)
        case .cadenceThreshold(let value):
            try container.encode(value, forKey: .value)
        case .powerRange(let low, let high, let unit, let metric):
            try container.encode(low, forKey: .min)
            try container.encode(high, forKey: .max)
            try container.encode(unit, forKey: .unit)
            try container.encodeIfPresent(metric, forKey: .metric)
        case .powerThreshold(let value, let unit, let metric):
            try container.encode(value, forKey: .value)
            try container.encode(unit, forKey: .unit)
            try container.encodeIfPresent(metric, forKey: .metric)
        case .speedRange(let low, let high, let unit, let metric):
            try container.encode(low, forKey: .min)
            try container.encode(high, forKey: .max)
            try container.encode(unit, forKey: .unit)
            try container.encode(metric, forKey: .metric)
        case .speedThreshold(let value, let unit, let metric):
            try container.encode(value, forKey: .value)
            try container.encode(unit, forKey: .unit)
            try container.encode(metric, forKey: .metric)
        }
    }
}
