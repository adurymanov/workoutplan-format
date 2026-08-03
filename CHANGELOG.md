# Changelog

Format versions and library versions move independently. The format's `version`
field changes only on a breaking change to the file format, as described in
[SPEC.md §12](SPEC.md#12-versioning), while the package follows semantic
versioning.

## [2.0.0] - 2026-08-03

Both changes came out of integrating the package into a real app, which is also
why the major bump lands the same day: better to fix the API now than to carry
a deprecated shim for the one consumer that exists.

The **file format is untouched**. Files written against version 1 stay valid, and
`WorkoutPlanFile.currentVersion` is still 1. Only the Swift API changed.

### Changed

- `WorkoutPlanScheduler.authorizationState` and `requestAuthorization()` now
  return `SchedulingAuthorization` instead of `WorkoutScheduler.AuthorizationState`.
  WorkoutKit does not mark its enum `Sendable`, so reading it from an `async`
  property on the main actor produced a concurrency warning in every consuming
  app, and that warning is an error in the Swift 6 language mode.

  To migrate, switch over the new enum. It has the same four cases plus
  `unrecognised`, for a state a future WorkoutKit might add.

### Added

- `ResolvedWorkout` has a public initialiser. The memberwise one was internal, so
  apps that let the athlete pick dates in their own UI could not build the value
  the scheduling API takes.

## [1.0.0] - 2026-08-03

First release. Format version 1 is frozen, and the package API is covered by
semantic versioning from here on.

### Added

- Format version 1: specification, JSON Schema (draft 2020-12), eight examples and
  a conformance suite that any implementation can run.
- `WorkoutPlanFormat`, which reads, writes and validates `.workoutplan` files using
  Foundation alone.
- `WorkoutPlanKit`, which maps them to WorkoutKit and schedules them to a paired
  Apple Watch.
- `extensions` containers at file, workout, block and step level, preserved across
  a read and write round-trip.
- Wall-clock and absolute `scheduledDate` values. Wall-clock times resolve against
  the athlete's time zone at scheduling time rather than at parse time.
