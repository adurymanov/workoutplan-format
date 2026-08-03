# Changelog

Format versions and library versions move independently. The format's `version`
field changes only on a breaking change to the file format, as described in
[SPEC.md §12](SPEC.md#12-versioning), while the package follows semantic
versioning.

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
