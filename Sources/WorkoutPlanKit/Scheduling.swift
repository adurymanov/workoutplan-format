import Foundation
import WorkoutKit
import WorkoutPlanFormat

/// A workout that is ready to go onto the watch: converted, dated, and paired
/// with the file entry it came from.
public struct ResolvedWorkout: Sendable {
    public let source: Workout
    public let plan: WorkoutKit.WorkoutPlan
    public let date: DateComponents

    /// Apps that let the athlete pick dates in their own UI build these directly,
    /// rather than going through ``WorkoutPlanScheduler/resolve(_:timeZone:dateForUndated:)``.
    public init(source: Workout, plan: WorkoutKit.WorkoutPlan, date: DateComponents) {
        self.source = source
        self.plan = plan
        self.date = date
    }

    public var scheduledWorkoutPlan: ScheduledWorkoutPlan {
        ScheduledWorkoutPlan(plan, date: date)
    }
}

/// Whether the app may put workouts on the paired watch.
///
/// This mirrors `WorkoutScheduler.AuthorizationState`, which WorkoutKit does not
/// mark `Sendable`. Returning Apple's type from an `async` API pushes a
/// concurrency warning onto every caller that reads it from the main actor, and
/// that warning becomes an error in the Swift 6 language mode, so the package
/// hands back its own value type instead.
public enum SchedulingAuthorization: Sendable, Hashable {
    case notDetermined
    case restricted
    case denied
    case authorized
    /// A state introduced by a newer WorkoutKit than this package knows about.
    case unrecognised

    public init(_ state: WorkoutScheduler.AuthorizationState) {
        switch state {
        case .notDetermined: self = .notDetermined
        case .restricted: self = .restricted
        case .denied: self = .denied
        case .authorized: self = .authorized
        @unknown default: self = .unrecognised
        }
    }

    /// Whether scheduling will actually work right now.
    public var isAuthorized: Bool { self == .authorized }
}

/// Thin, testable wrapper over `WorkoutScheduler`.
///
/// Scheduling itself is one call; what this adds is resolving a file's workouts
/// into dated, WorkoutKit-ready values, which is the part worth unit-testing
/// without a paired watch.
public enum WorkoutPlanScheduler {

    /// Whether the current device can schedule workouts at all.
    public static var isSupported: Bool { WorkoutScheduler.isSupported }

    /// The most workouts WorkoutKit will keep scheduled at once.
    public static var maxScheduledWorkoutCount: Int {
        WorkoutScheduler.maxAllowedScheduledWorkoutCount
    }

    /// Converts every workout in a file and assigns each one a date.
    ///
    /// - Parameters:
    ///   - file: the decoded `.workoutplan` file.
    ///   - timeZone: the zone that wall-clock `scheduledDate` values are resolved
    ///     in. Defaults to the device's.
    ///   - dateForUndated: called for workouts whose `scheduledDate` is absent;
    ///     the file leaves that choice to the app.
    public static func resolve(
        _ file: WorkoutPlanFile,
        timeZone: TimeZone = .autoupdatingCurrent,
        dateForUndated: (Workout) -> Date
    ) throws -> [ResolvedWorkout] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        return try file.workouts.map { workout in
            let components: DateComponents
            if let scheduled = workout.scheduledDate {
                components = scheduled.schedulingComponents(in: timeZone, calendar: calendar)
            } else {
                var fallback = calendar.dateComponents(
                    [.year, .month, .day, .hour, .minute], from: dateForUndated(workout))
                fallback.calendar = calendar
                fallback.timeZone = timeZone
                components = fallback
            }
            return ResolvedWorkout(
                source: workout, plan: try workout.workoutKitPlan(), date: components)
        }
    }

    /// Requests permission to put workouts on the paired watch.
    @discardableResult
    public static func requestAuthorization() async -> SchedulingAuthorization {
        SchedulingAuthorization(await WorkoutScheduler.shared.requestAuthorization())
    }

    public static var authorizationState: SchedulingAuthorization {
        get async { SchedulingAuthorization(await WorkoutScheduler.shared.authorizationState) }
    }

    /// Schedules the given workouts, in order.
    public static func schedule(_ workouts: [ResolvedWorkout]) async {
        for workout in workouts {
            await WorkoutScheduler.shared.schedule(workout.plan, at: workout.date)
        }
    }

    /// Everything currently scheduled, as WorkoutKit reports it.
    public static var scheduledWorkouts: [ScheduledWorkoutPlan] {
        get async { await WorkoutScheduler.shared.scheduledWorkouts }
    }

    public static func remove(_ workout: ScheduledWorkoutPlan) async {
        await WorkoutScheduler.shared.remove(workout.plan, at: workout.date)
    }

    public static func removeAll() async {
        await WorkoutScheduler.shared.removeAllWorkouts()
    }
}
