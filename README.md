# workoutplan-format

An open file format, and a Swift SDK, for structured workouts that can be scheduled
onto an Apple Watch.

Apple ships an API for putting a planned workout on the watch
([WorkoutKit](https://developer.apple.com/documentation/workoutkit)), but no
interchange format for one. Every coaching app, training-plan generator and weekend
script ends up inventing its own JSON and its own mapping code. This repository
holds a specification, a JSON Schema, a conformance suite and a reference
implementation so they do not have to.

```json
{
  "version": 1,
  "workouts": [
    {
      "type": "custom",
      "scheduledDate": "2026-09-08T07:30:00",
      "activity": "running",
      "location": "outdoor",
      "displayName": "Threshold intervals",
      "warmup": { "goal": { "type": "time", "value": 10, "unit": "min" } },
      "blocks": [
        {
          "iterations": 4,
          "steps": [
            { "purpose": "work", "goal": { "type": "distance", "value": 1, "unit": "km" },
              "alert": { "type": "heartRateZone", "zone": 4 } },
            { "purpose": "recovery", "goal": { "type": "time", "value": 2, "unit": "min" } }
          ]
        }
      ],
      "cooldown": { "goal": { "type": "time", "value": 5, "unit": "min" } }
    }
  ]
}
```

## What is here

| | |
|---|---|
| [`SPEC.md`](SPEC.md) | The specification. Normative. |
| [`schema/`](schema) | JSON Schema (draft 2020-12) for editors and CI. |
| [`examples/`](examples) | Eight complete files, one per shape of workout. |
| [`conformance/`](conformance) | Test suite in plain JSON: files that must load, files that must fail, and the error code each failure must report. |
| `Sources/WorkoutPlanFormat` | Reading, writing and validating. Foundation only. |
| `Sources/WorkoutPlanKit` | Mapping to WorkoutKit and scheduling to the watch. |

## Using the Swift package

```swift
.package(url: "https://github.com/adurymanov/workoutplan-format.git", from: "2.0.0")
```

There are two products, so that tools which only read files do not pull in
WorkoutKit:

```swift
import WorkoutPlanFormat

let file = try WorkoutPlanFile(contentsOf: url)
for workout in file.workouts {
    print(workout.displayName ?? workout.kind.typeName)
}
```

```swift
import WorkoutPlanKit

// Convert, date, and put on the paired watch.
let resolved = try WorkoutPlanScheduler.resolve(file) { _ in Date().addingTimeInterval(3600) }
await WorkoutPlanScheduler.requestAuthorization()
await WorkoutPlanScheduler.schedule(resolved)
```

Errors are a single [`FormatError`](Sources/WorkoutPlanFormat/FormatError.swift)
type carrying a stable `code`, a developer-facing `message`, and the `field` that
caused it. An import screen can use that to flag one bad workout rather than
rejecting the whole file:

```swift
do {
    _ = try workout.workoutKitPlan()
} catch let error as FormatError where error.code == .unsupportedAlert {
    // "A 'powerRange' alert is not supported for this activity and location."
}
```

Platforms: iOS 18+, watchOS 11+, macOS 15+, visionOS 2+. `WorkoutPlanFormat` on its
own needs only Foundation.

## Validating a file

```bash
python3 scripts/validate.py
```

Checks every example and every conformance fixture against the JSON Schema. It also
prints the rules the schema cannot express, such as comparing `min` to `max`, so
that the gap is written down somewhere.

```bash
swift test
```

Runs the same conformance suite through the Swift implementation and maps every
example through real WorkoutKit, including Apple's own `supports*` validators. No
simulator or paired watch is involved: WorkoutKit ships in the macOS SDK.

## Writing your own implementation

1. Read [`SPEC.md`](SPEC.md).
2. Validate against [`schema/workoutplan-v1.schema.json`](schema/workoutplan-v1.schema.json).
3. Run [`conformance/`](conformance): load everything under `valid/`, reject
   everything under `invalid/` with the code in `manifest.json`.

The error codes are part of the specification. The English messages are not.

## Scope and limits

The format mirrors WorkoutKit one to one, which is where both its usefulness and
its limits come from: one alert per step, no structured reps or weights, energy
goals in only one place. Those constraints are Apple's, and
[`SPEC.md` §10](SPEC.md#10-constraints-inherited-from-workoutkit) says which is
which.

It is therefore Apple-specific by design. For a format that also spans Garmin,
Zwift and Wahoo, look elsewhere, and expect to give up the exact mapping to the
watch in exchange.

## License

MIT. See [LICENSE](LICENSE).

Not affiliated with or endorsed by Apple. Apple Watch, WorkoutKit and HealthKit are
trademarks of Apple Inc.
