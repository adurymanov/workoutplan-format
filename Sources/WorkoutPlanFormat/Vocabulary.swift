import Foundation

/// A closed set of string values in the file format.
///
/// Every conforming type has one **canonical** spelling (its `rawValue`, which is
/// what writers emit) and a set of accepted aliases. Reading is case- and
/// separator-insensitive: `"traditionalStrengthTraining"`, `"traditional_strength_training"`
/// and `"strength"` all decode to the same case; writing always produces the
/// canonical form.
public protocol FileVocabulary: RawRepresentable, CaseIterable, Codable, Hashable, Sendable
where RawValue == String {
    /// Human-readable name of this vocabulary, used in error messages.
    static var vocabularyName: String { get }
    /// Error code raised when a value is not part of the vocabulary.
    static var unknownValueCode: FormatError.Code { get }
    /// Extra accepted spellings, beyond the canonical `rawValue` of each case.
    static var extraAliases: [String: Self] { get }
}

/// Lower-cased, separator-free lookup key: `"Open Water"`, `"open_water"` and
/// `"openWater"` all normalise to `"openwater"`. Also used to compare the `type`
/// tags of the goal and alert unions.
func normalizeToken(_ raw: String) -> String {
    raw.lowercased().filter { !$0.isWhitespace && $0 != "_" && $0 != "-" }
}

extension FileVocabulary {
    public static var extraAliases: [String: Self] { [:] }

    /// See ``normalizeToken(_:)``.
    public static func normalize(_ raw: String) -> String { normalizeToken(raw) }

    static var aliasTable: [String: Self] {
        var table: [String: Self] = [:]
        for value in Self.allCases {
            table[normalize(value.rawValue)] = value
        }
        for (alias, value) in Self.extraAliases {
            table[normalize(alias)] = value
        }
        return table
    }

    /// Decodes a value from its file representation, accepting any known alias.
    public init(fileValue raw: String, field: String? = nil) throws {
        guard let value = Self.aliasTable[Self.normalize(raw)] else {
            throw FormatError(
                Self.unknownValueCode,
                "Unknown \(Self.vocabularyName) '\(raw)'.",
                field: field)
        }
        self = value
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        try self.init(fileValue: container.decode(String.self))
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

// MARK: - Activity

/// The workout activity, mirroring the subset of `HKWorkoutActivityType` that
/// WorkoutKit can schedule.
public enum Activity: String, FileVocabulary {
    case running, cycling, walking, swimming, hiking, rowing, elliptical
    case functionalStrengthTraining, traditionalStrengthTraining
    case highIntensityIntervalTraining, coreTraining
    case flexibility, yoga, pilates, jumpRope, stairClimbing, kickboxing
    case mixedCardio, cardioDance, cooldown, handCycling
    case downhillSkiing, crossCountrySkiing, paddleSports
    case wheelchairWalkPace, wheelchairRunPace

    public static let vocabularyName = "activity"
    public static let unknownValueCode = FormatError.Code.unknownActivity
    public static let extraAliases: [String: Activity] = [
        "run": .running, "jog": .running,
        "bike": .cycling, "biking": .cycling, "cycle": .cycling,
        "walk": .walking,
        "swim": .swimming,
        "hike": .hiking,
        "row": .rowing,
        "strength": .traditionalStrengthTraining,
        "strengthTraining": .traditionalStrengthTraining,
        "weights": .traditionalStrengthTraining,
        "functionalStrength": .functionalStrengthTraining,
        "hiit": .highIntensityIntervalTraining,
        "core": .coreTraining,
        "stretching": .flexibility,
        "stairs": .stairClimbing,
        "cardio": .mixedCardio,
        "dance": .cardioDance,
        "ski": .downhillSkiing, "skiing": .downhillSkiing,
        "paddle": .paddleSports,
    ]
}

// MARK: - Locations

/// Indoor / outdoor, mirroring `HKWorkoutSessionLocationType`.
public enum Location: String, FileVocabulary {
    case unknown, indoor, outdoor

    public static let vocabularyName = "location"
    public static let unknownValueCode = FormatError.Code.unknownLocation
}

/// Pool / open water, mirroring `HKWorkoutSwimmingLocationType`.
public enum SwimmingLocation: String, FileVocabulary {
    case unknown, pool, openWater

    public static let vocabularyName = "swimming location"
    public static let unknownValueCode = FormatError.Code.unknownLocation
    public static let extraAliases: [String: SwimmingLocation] = ["ow": .openWater]
}

// MARK: - Step purpose

/// Whether a step inside a block is work or recovery.
public enum StepPurpose: String, FileVocabulary {
    case work, recovery

    public static let vocabularyName = "step purpose"
    public static let unknownValueCode = FormatError.Code.unknownPurpose
    public static let extraAliases: [String: StepPurpose] = ["rest": .recovery, "rec": .recovery]
}

// MARK: - Alert metric

/// Whether an alert tracks the current or the average value of its metric.
public enum AlertMetric: String, FileVocabulary {
    case current, average

    public static let vocabularyName = "alert metric"
    public static let unknownValueCode = FormatError.Code.unknownMetric
    public static let extraAliases: [String: AlertMetric] = ["avg": .average]
}

// MARK: - Triathlon leg sport

/// One of the three sports a `swimBikeRun` workout is made of.
public enum LegSport: String, FileVocabulary {
    case swimming, cycling, running

    public static let vocabularyName = "swim-bike-run sport"
    public static let unknownValueCode = FormatError.Code.unknownSport
    public static let extraAliases: [String: LegSport] = [
        "swim": .swimming, "bike": .cycling, "cycle": .cycling, "run": .running,
    ]
}
