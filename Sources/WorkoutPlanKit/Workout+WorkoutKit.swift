import Foundation
import HealthKit
import WorkoutKit
import WorkoutPlanFormat

extension Workout {

    /// Builds the WorkoutKit workout this planned workout describes.
    ///
    /// Every combination is checked against WorkoutKit's own `supports*` tables
    /// first, so an unschedulable workout fails here with a specific error
    /// instead of being silently rejected by the watch later.
    ///
    /// - Throws: ``FormatError`` with an `unsupported_*` code.
    public func workoutKitPlan() throws -> WorkoutKit.WorkoutPlan {
        switch kind {
        case .custom(let custom):
            return WorkoutKit.WorkoutPlan(.custom(try customWorkout(custom)))
        case .goal(let goal):
            return WorkoutKit.WorkoutPlan(.goal(try singleGoalWorkout(goal)))
        case .pacer(let pacer):
            return WorkoutKit.WorkoutPlan(.pacer(try pacerWorkout(pacer)))
        case .swimBikeRun(let legs):
            return WorkoutKit.WorkoutPlan(.swimBikeRun(try swimBikeRunWorkout(legs)))
        }
    }

    // MARK: - Per kind

    private func customWorkout(_ custom: Custom) throws -> CustomWorkout {
        let activity = custom.activity.healthKitActivityType
        guard CustomWorkout.supportsActivity(activity) else {
            throw FormatError(
                .unsupportedActivity,
                "WorkoutKit cannot build a custom workout for activity '\(custom.activity.rawValue)'.",
                field: "activity")
        }
        let location = custom.location.healthKitLocation

        return CustomWorkout(
            activity: activity,
            location: location,
            displayName: displayName,
            warmup: try custom.warmup.map {
                try workoutStep($0, activity: activity, location: location, field: "warmup")
            },
            blocks: try custom.blocks.enumerated().map { index, block in
                IntervalBlock(
                    steps: try block.steps.enumerated().map { stepIndex, step in
                        IntervalStep(
                            step.purpose?.workoutKitPurpose ?? .work,
                            step: try workoutStep(
                                step, activity: activity, location: location,
                                field: "blocks[\(index)].steps[\(stepIndex)]"))
                    },
                    iterations: block.iterations)
            },
            cooldown: try custom.cooldown.map {
                try workoutStep($0, activity: activity, location: location, field: "cooldown")
            })
    }

    private func singleGoalWorkout(_ single: SingleGoal) throws -> SingleGoalWorkout {
        let activity = single.activity.healthKitActivityType
        guard SingleGoalWorkout.supportsActivity(activity) else {
            throw FormatError(
                .unsupportedActivity,
                "WorkoutKit cannot build a goal workout for activity '\(single.activity.rawValue)'.",
                field: "activity")
        }
        let location = single.location.healthKitLocation
        let goal = single.goal.workoutKitGoal
        guard SingleGoalWorkout.supportsGoal(goal, activity: activity, location: location) else {
            throw FormatError(
                .unsupportedGoal,
                "A '\(single.goal.typeName)' goal is not supported for \(single.activity.rawValue) (\(single.location.rawValue)).",
                field: "goal")
        }
        return SingleGoalWorkout(
            activity: activity,
            location: location,
            swimmingLocation: single.swimmingLocation.healthKitSwimmingLocation,
            goal: goal)
    }

    private func pacerWorkout(_ pacer: Pacer) throws -> PacerWorkout {
        let activity = pacer.activity.healthKitActivityType
        guard PacerWorkout.supportsActivity(activity) else {
            throw FormatError(
                .unsupportedActivity,
                "WorkoutKit cannot build a pacer workout for activity '\(pacer.activity.rawValue)'.",
                field: "activity")
        }
        return PacerWorkout(
            activity: activity,
            location: pacer.location.healthKitLocation,
            distance: pacer.distance.measurement,
            time: pacer.time.measurement)
    }

    private func swimBikeRunWorkout(_ legs: [Leg]) throws -> SwimBikeRunWorkout {
        let activities = legs.map(\.workoutKitActivity)
        guard SwimBikeRunWorkout.supportsActivityOrdering(activities) else {
            throw FormatError(
                .unsupportedLegOrdering,
                "WorkoutKit does not support this ordering of swim-bike-run legs.",
                field: "legs")
        }
        return SwimBikeRunWorkout(activities: activities, displayName: displayName)
    }

    // MARK: - Steps

    private func workoutStep(
        _ step: Step,
        activity: HKWorkoutActivityType,
        location: HKWorkoutSessionLocationType,
        field: String
    ) throws -> WorkoutStep {
        if case .energy = step.goal {
            throw FormatError(
                .energyGoalInCustomWorkout,
                "An energy goal cannot be used inside a custom workout. Use a 'goal' workout, or a time or distance goal.",
                field: "\(field).goal")
        }

        let goal = step.goal.workoutKitGoal
        guard CustomWorkout.supportsGoal(goal, activity: activity, location: location) else {
            throw FormatError(
                .unsupportedGoal,
                "A '\(step.goal.typeName)' goal is not supported for this activity and location.",
                field: "\(field).goal")
        }

        let alert = step.alert?.workoutKitAlert
        if let alert, let declared = step.alert,
            !CustomWorkout.supportsAlert(alert, activity: activity, location: location)
        {
            throw FormatError(
                .unsupportedAlert,
                "A '\(declared.typeName)' alert is not supported for this activity and location.",
                field: "\(field).alert")
        }

        return WorkoutStep(goal: goal, alert: alert, displayName: step.displayName)
    }
}

extension WorkoutPlanFile {
    /// Converts every workout in the file, in order.
    ///
    /// - Throws: on the first workout that WorkoutKit cannot build. Use
    ///   ``workoutKitPlan()`` per workout when partial results are more useful.
    ///   An import screen usually wants to show the good ones and flag the rest.
    public func workoutKitPlans() throws -> [WorkoutKit.WorkoutPlan] {
        try workouts.map { try $0.workoutKitPlan() }
    }
}
