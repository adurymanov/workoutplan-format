import Foundation

// MARK: - Unit vocabularies

/// Distance units. Canonical spellings are the short symbols.
public enum LengthUnit: String, FileVocabulary {
    case meters = "m"
    case kilometers = "km"
    case miles = "mi"
    case yards = "yd"
    case feet = "ft"

    public static let vocabularyName = "distance unit"
    public static let unknownValueCode = FormatError.Code.unknownUnit
    public static let extraAliases: [String: LengthUnit] = [
        "meter": .meters, "meters": .meters, "metre": .meters, "metres": .meters,
        "kilometer": .kilometers, "kilometers": .kilometers,
        "kilometre": .kilometers, "kilometres": .kilometers,
        "mile": .miles, "miles": .miles,
        "yard": .yards, "yards": .yards,
        "foot": .feet, "feet": .feet,
    ]
}

/// Duration units.
public enum TimeUnit: String, FileVocabulary {
    case seconds = "s"
    case minutes = "min"
    case hours = "h"

    public static let vocabularyName = "time unit"
    public static let unknownValueCode = FormatError.Code.unknownUnit
    public static let extraAliases: [String: TimeUnit] = [
        "sec": .seconds, "secs": .seconds, "second": .seconds, "seconds": .seconds,
        "mins": .minutes, "minute": .minutes, "minutes": .minutes,
        "hr": .hours, "hrs": .hours, "hour": .hours, "hours": .hours,
    ]
}

/// Energy units.
public enum EnergyUnit: String, FileVocabulary {
    case kilocalories = "kcal"
    case kilojoules = "kJ"
    case joules = "J"

    public static let vocabularyName = "energy unit"
    public static let unknownValueCode = FormatError.Code.unknownUnit
    public static let extraAliases: [String: EnergyUnit] = [
        "cal": .kilocalories, "kilocalorie": .kilocalories, "kilocalories": .kilocalories,
        "kilojoule": .kilojoules, "kilojoules": .kilojoules,
        "joule": .joules, "joules": .joules,
    ]
}

/// Power units.
public enum PowerUnit: String, FileVocabulary {
    case watts = "W"
    case kilowatts = "kW"

    public static let vocabularyName = "power unit"
    public static let unknownValueCode = FormatError.Code.unknownUnit
    public static let extraAliases: [String: PowerUnit] = [
        "watt": .watts, "watts": .watts, "kilowatt": .kilowatts, "kilowatts": .kilowatts,
    ]
}

/// Speed units. Note that the format expresses speed, never pace (min/km).
public enum SpeedUnit: String, FileVocabulary {
    case kilometersPerHour = "kmh"
    case milesPerHour = "mph"
    case metersPerSecond = "mps"

    public static let vocabularyName = "speed unit"
    public static let unknownValueCode = FormatError.Code.unknownUnit
    public static let extraAliases: [String: SpeedUnit] = [
        "km/h": .kilometersPerHour, "kph": .kilometersPerHour,
        "kilometersperhour": .kilometersPerHour,
        "mi/h": .milesPerHour, "milesperhour": .milesPerHour,
        "m/s": .metersPerSecond, "meterspersecond": .metersPerSecond,
    ]
}

// MARK: - Measure

/// A magnitude plus a unit, e.g. `{"value": 5, "unit": "km"}`.
public struct Measure<Unit: FileVocabulary>: Hashable, Sendable, Codable {
    public var value: Double
    public var unit: Unit

    public init(_ value: Double, _ unit: Unit) {
        self.value = value
        self.unit = unit
    }
}

public typealias DistanceMeasure = Measure<LengthUnit>
public typealias TimeMeasure = Measure<TimeUnit>
public typealias EnergyMeasure = Measure<EnergyUnit>

extension Measure {
    /// Decodes a measure from a keyed container, producing precise errors for the
    /// enclosing field rather than a generic "key not found".
    static func decode<Key: CodingKey>(
        from container: KeyedDecodingContainer<Key>, key: Key, field: String
    ) throws -> Measure<Unit> {
        guard container.contains(key) else { throw FormatError.missingField(field) }
        let nested = try container.nestedContainer(keyedBy: MeasureKeys.self, forKey: key)
        guard let value = try nested.decodeIfPresent(Double.self, forKey: .value) else {
            throw FormatError.missingField("\(field).value")
        }
        guard let rawUnit = try nested.decodeIfPresent(String.self, forKey: .unit) else {
            throw FormatError.missingField("\(field).unit")
        }
        return Measure(value, try Unit(fileValue: rawUnit, field: "\(field).unit"))
    }

    private enum MeasureKeys: String, CodingKey { case value, unit }
}
