import Foundation
import HealthKit
import WorkoutKit
import WorkoutPlanFormat

// Value-by-value bridges from the file format's vocabulary to HealthKit and
// WorkoutKit. Everything here is total: no lookups can fail, because the format
// layer already rejected values outside the vocabulary.

extension Activity {
    public var healthKitActivityType: HKWorkoutActivityType {
        switch self {
        case .running: .running
        case .cycling: .cycling
        case .walking: .walking
        case .swimming: .swimming
        case .hiking: .hiking
        case .rowing: .rowing
        case .elliptical: .elliptical
        case .functionalStrengthTraining: .functionalStrengthTraining
        case .traditionalStrengthTraining: .traditionalStrengthTraining
        case .highIntensityIntervalTraining: .highIntensityIntervalTraining
        case .coreTraining: .coreTraining
        case .flexibility: .flexibility
        case .yoga: .yoga
        case .pilates: .pilates
        case .jumpRope: .jumpRope
        case .stairClimbing: .stairClimbing
        case .kickboxing: .kickboxing
        case .mixedCardio: .mixedCardio
        case .cardioDance: .cardioDance
        case .cooldown: .cooldown
        case .handCycling: .handCycling
        case .downhillSkiing: .downhillSkiing
        case .crossCountrySkiing: .crossCountrySkiing
        case .paddleSports: .paddleSports
        case .wheelchairWalkPace: .wheelchairWalkPace
        case .wheelchairRunPace: .wheelchairRunPace
        }
    }
}

extension Location {
    public var healthKitLocation: HKWorkoutSessionLocationType {
        switch self {
        case .unknown: .unknown
        case .indoor: .indoor
        case .outdoor: .outdoor
        }
    }
}

extension SwimmingLocation {
    public var healthKitSwimmingLocation: HKWorkoutSwimmingLocationType {
        switch self {
        case .unknown: .unknown
        case .pool: .pool
        case .openWater: .openWater
        }
    }
}

extension StepPurpose {
    public var workoutKitPurpose: IntervalStep.Purpose {
        switch self {
        case .work: .work
        case .recovery: .recovery
        }
    }
}

extension AlertMetric {
    public var workoutKitMetric: WorkoutAlertMetric {
        switch self {
        case .current: .current
        case .average: .average
        }
    }
}

// MARK: - Units

extension LengthUnit {
    public var foundationUnit: UnitLength {
        switch self {
        case .meters: .meters
        case .kilometers: .kilometers
        case .miles: .miles
        case .yards: .yards
        case .feet: .feet
        }
    }
}

extension TimeUnit {
    public var foundationUnit: UnitDuration {
        switch self {
        case .seconds: .seconds
        case .minutes: .minutes
        case .hours: .hours
        }
    }
}

extension EnergyUnit {
    public var foundationUnit: UnitEnergy {
        switch self {
        case .kilocalories: .kilocalories
        case .kilojoules: .kilojoules
        case .joules: .joules
        }
    }
}

extension PowerUnit {
    public var foundationUnit: UnitPower {
        switch self {
        case .watts: .watts
        case .kilowatts: .kilowatts
        }
    }
}

extension SpeedUnit {
    public var foundationUnit: UnitSpeed {
        switch self {
        case .kilometersPerHour: .kilometersPerHour
        case .milesPerHour: .milesPerHour
        case .metersPerSecond: .metersPerSecond
        }
    }
}

extension Measure where Unit == LengthUnit {
    public var measurement: Measurement<UnitLength> {
        Measurement(value: value, unit: unit.foundationUnit)
    }
}

extension Measure where Unit == TimeUnit {
    public var measurement: Measurement<UnitDuration> {
        Measurement(value: value, unit: unit.foundationUnit)
    }
}

// MARK: - Goal and alert

extension Goal {
    public var workoutKitGoal: WorkoutGoal {
        switch self {
        case .open:
            .open
        case .distance(let measure):
            .distance(measure.value, measure.unit.foundationUnit)
        case .time(let measure):
            .time(measure.value, measure.unit.foundationUnit)
        case .energy(let measure):
            .energy(measure.value, measure.unit.foundationUnit)
        case .poolSwimDistanceWithTime(let distance, let time):
            .poolSwimDistanceWithTime(distance.measurement, time.measurement)
        }
    }
}

extension Alert {
    public var workoutKitAlert: any WorkoutAlert {
        /// Heart rate and cadence are both "counts per minute" as far as
        /// WorkoutKit is concerned.
        func perMinute(_ value: Double) -> Measurement<UnitFrequency> {
            Measurement(value: value, unit: WorkoutAlertMetric.countPerMinute)
        }

        switch self {
        case .heartRateZone(let zone):
            return HeartRateZoneAlert(zone: zone)
        case .heartRateRange(let low, let high):
            return HeartRateRangeAlert(target: perMinute(low)...perMinute(high))
        case .cadenceRange(let low, let high):
            return CadenceRangeAlert(target: perMinute(low)...perMinute(high))
        case .cadenceThreshold(let value):
            return CadenceThresholdAlert(target: perMinute(value))
        case .powerZone(let zone):
            return PowerZoneAlert(zone: zone)
        case .powerRange(let low, let high, let unit, let metric):
            let lower = Measurement(value: low, unit: unit.foundationUnit)
            let upper = Measurement(value: high, unit: unit.foundationUnit)
            let target = lower...upper
            // The metric-less initialiser is not the same as passing `.current`:
            // it leaves WorkoutKit's own default in place, which is what a file
            // that omits `metric` is asking for.
            guard let metric else { return PowerRangeAlert(target: target) }
            return PowerRangeAlert(target: target, metric: metric.workoutKitMetric)
        case .powerThreshold(let value, let unit, let metric):
            let target = Measurement(value: value, unit: unit.foundationUnit)
            guard let metric else { return PowerThresholdAlert(target: target) }
            return PowerThresholdAlert(target: target, metric: metric.workoutKitMetric)
        case .speedRange(let low, let high, let unit, let metric):
            let lower = Measurement(value: low, unit: unit.foundationUnit)
            let upper = Measurement(value: high, unit: unit.foundationUnit)
            let target = lower...upper
            return SpeedRangeAlert(target: target, metric: metric.workoutKitMetric)
        case .speedThreshold(let value, let unit, let metric):
            return SpeedThresholdAlert(
                target: Measurement(value: value, unit: unit.foundationUnit),
                metric: metric.workoutKitMetric)
        }
    }
}

extension Workout.Leg {
    public var workoutKitActivity: SwimBikeRunWorkout.Activity {
        switch sport {
        case .swimming: .swimming(swimmingLocation.healthKitSwimmingLocation)
        case .cycling: .cycling(location.healthKitLocation)
        case .running: .running(location.healthKitLocation)
        }
    }
}
