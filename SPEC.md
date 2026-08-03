# The `.workoutplan` format, version 1

**Status:** stable. Version 1 is frozen: nothing in this document will change in a
way that breaks a file already written against it. See [Versioning](#12-versioning).

A `.workoutplan` file describes one or more structured workouts in JSON, in a shape
that maps one to one onto Apple's [WorkoutKit](https://developer.apple.com/documentation/workoutkit)
object model. Any app can then hand a plan to an Apple Watch without inventing its
own encoding.

The key words MUST, MUST NOT, SHOULD, SHOULD NOT and MAY are to be interpreted as
described in [RFC 2119](https://www.rfc-editor.org/rfc/rfc2119).

---

## 1. Scope

This format covers what WorkoutKit can schedule: interval workouts, single goal
workouts, pacer workouts and swim-bike-run. It is not meant to be a universal
training-file format. The mapping to the watch is lossless and unambiguous, and a
richer model that WorkoutKit could not express would give that up.

Three consequences:

- Constraints that look arbitrary here, such as one alert per step or no reps and
  weights, come from WorkoutKit. [Section 10](#10-constraints-inherited-from-workoutkit)
  lists them.
- The format carries no completed-workout data. It describes a plan, not a log.
- It is not affiliated with or endorsed by Apple.

## 2. File identity

| | |
|---|---|
| Extension | `.workoutplan` |
| Media type | `application/vnd.workoutplan+json` |
| Uniform Type Identifier | `io.github.adurymanov.workoutplan`, conforming to `public.json` |
| Encoding | UTF-8, no byte-order mark |
| Syntax | JSON ([RFC 8259](https://www.rfc-editor.org/rfc/rfc8259)). No comments, no trailing commas |

A file MUST contain a single JSON object. Producers SHOULD write pretty-printed
JSON, because people read and edit these files by hand.

## 3. Top level

```json
{
  "version": 1,
  "workouts": [ … ]
}
```

| Field | Type | Required | Notes |
|---|---|---|---|
| `version` | integer | SHOULD | The format version. Defaults to `1` when absent. Writers SHOULD emit it. |
| `workouts` | array | MUST | At least one workout. Order is preserved. |
| `extensions` | object | MAY | See [Section 11](#11-extensibility). |

A reader MUST reject a file whose `version` is greater than the version it
implements (`unsupported_version`), and MUST reject an empty `workouts` array
(`empty_file`).

## 4. Workout

Every element of `workouts` is an object tagged by `type`.

| Field | Applies to | Notes |
|---|---|---|
| `type` | all | `custom` \| `goal` \| `pacer` \| `swimBikeRun` |
| `scheduledDate` | all | Optional. See [Section 9](#9-dates). |
| `displayName` | all | Optional title shown on the watch. |
| `extensions` | all | Optional. See [Section 11](#11-extensibility). |
| `activity` | custom, goal, pacer | Required. See [Section 8.1](#81-activities). |
| `location` | custom, goal, pacer | `unknown` (default) \| `indoor` \| `outdoor` |
| `warmup`, `cooldown` | custom | Optional [steps](#5-step). |
| `blocks` | custom | Array of [blocks](#51-block). Defaults to empty. |
| `goal` | goal | Required. A [goal](#6-goal) object. |
| `swimmingLocation` | goal | `unknown` (default) \| `pool` \| `openWater`. Meaningful for swimming. |
| `distance`, `time` | pacer | Both required. Measures, e.g. `{"value": 10, "unit": "km"}`. |
| `legs` | swimBikeRun | Required, at least one. See [Section 4.1](#41-leg). |

A workout MUST NOT carry fields belonging to another `type`.

**custom** is a warmup, a sequence of repeated blocks, and a cooldown. This is the
interval workout.

**goal** is one activity with one target: run 5 km, ride 40 minutes, burn 400 kcal.

**pacer** is a distance to be covered in a target time. The watch shows whether you
are ahead or behind.

**swimBikeRun** is multisport, one leg per sport, in order.

### 4.1 Leg

```json
{ "sport": "swimming", "swimmingLocation": "openWater" }
```

| Field | Notes |
|---|---|
| `sport` | `swimming` \| `cycling` \| `running`. Required. |
| `location` | Used by the cycling and running legs. |
| `swimmingLocation` | Used by the swimming leg. |

WorkoutKit decides which orderings of legs it accepts. A reader MUST surface a
rejected ordering as `unsupported_leg_ordering`.

## 5. Step

```json
{
  "purpose": "work",
  "goal": { "type": "time", "value": 5, "unit": "min" },
  "alert": { "type": "heartRateZone", "zone": 4 },
  "displayName": "Threshold"
}
```

| Field | Notes |
|---|---|
| `purpose` | `work` \| `recovery`. Meaningful only inside a block, ignored for warmup and cooldown. Defaults to `work`. |
| `goal` | Defaults to `{"type": "open"}` when absent. |
| `alert` | Optional, and at most one. See [Section 10](#10-constraints-inherited-from-workoutkit). |
| `displayName` | Free text shown on the watch. Reps and load for strength work go here too, for the reason given in [Section 10](#10-constraints-inherited-from-workoutkit). |
| `extensions` | Optional. See [Section 11](#11-extensibility). |

### 5.1 Block

```json
{ "iterations": 4, "steps": [ … ] }
```

`iterations` MUST be at least 1 and defaults to 1. `steps` is the sequence repeated
that many times.

## 6. Goal

A tagged union.

| `type` | Fields | Notes |
|---|---|---|
| `open` | none | Untimed. The athlete taps to advance. |
| `distance` | `value`, `unit` | Unit: `m` `km` `mi` `yd` `ft` |
| `time` | `value`, `unit` | Unit: `s` `min` `h` |
| `energy` | `value`, `unit` | Unit: `kcal` `kJ` `J`. Only in a `goal` workout. |
| `poolSwimDistanceWithTime` | `distance`, `time` | Two measures. Pool swimming. |

`value` MUST be greater than zero.

## 7. Alert

A tagged union. An alert is a live target the watch nudges you toward.

| `type` | Fields |
|---|---|
| `heartRateZone` | `zone` (1 to 5) |
| `heartRateRange` | `min`, `max` (counts per minute) |
| `cadenceRange` | `min`, `max` (counts per minute) |
| `cadenceThreshold` | `value` |
| `powerZone` | `zone` (1 or greater) |
| `powerRange` | `min`, `max`, `unit` (`W` \| `kW`), `metric` |
| `powerThreshold` | `value`, `unit`, `metric` |
| `speedRange` | `min`, `max`, `unit` (`kmh` \| `mph` \| `mps`), `metric` |
| `speedThreshold` | `value`, `unit`, `metric` |

`metric` is `current` or `average`. For speed alerts it defaults to `current`. For
power alerts it is optional in a stricter sense: when it is omitted, WorkoutKit's
own default applies, and a reader MUST NOT substitute `current` for an absent
value.

`min` MUST be less than or equal to `max`. A reversed range is an error
(`invalid_range`), and a reader MUST NOT silently swap the bounds.

Heart rate and cadence are always counts per minute. A `unit` of `bpm`, `rpm` or
`spm` MAY appear on those alerts and MUST be ignored.

The format has no "at most X" alert, because WorkoutKit has none. Express a ceiling
as a range with a conservative lower bound.

Speed is speed, never pace: `12 kmh`, not `5:00 min/km`.

## 8. Vocabulary

### 8.1 Activities

`running`, `cycling`, `walking`, `swimming`, `hiking`, `rowing`, `elliptical`,
`functionalStrengthTraining`, `traditionalStrengthTraining`,
`highIntensityIntervalTraining`, `coreTraining`, `flexibility`, `yoga`, `pilates`,
`jumpRope`, `stairClimbing`, `kickboxing`, `mixedCardio`, `cardioDance`,
`cooldown`, `handCycling`, `downhillSkiing`, `crossCountrySkiing`, `paddleSports`,
`wheelchairWalkPace`, `wheelchairRunPace`.

### 8.2 Canonical spellings and aliases

Writers MUST emit the canonical spelling of every enumerated value, meaning the one
listed in this document and in the JSON Schema. Readers SHOULD additionally accept:

- any casing, and `_`, `-` or spaces as separators, so that `open_water` reads as
  `openWater`;
- the activity shorthands `run`, `jog`, `bike`, `biking`, `cycle`, `walk`, `swim`,
  `hike`, `row`, `strength`, `weights`, `functionalStrength`, `hiit`, `core`,
  `stretching`, `stairs`, `cardio`, `dance`, `ski`, `paddle`;
- spelled-out units: `meters`, `kilometres`, `minutes`, `seconds`, `hours`,
  `watts`, `km/h`, `m/s`, `kilocalories`;
- `rest` for `recovery`, `avg` for `average`, `ow` for `openWater`.

The JSON Schema validates the canonical profile only, so a file using aliases is
readable but not schema-valid. That is deliberate. Readers should be forgiving
about what they accept, while a producer should have one correct spelling to emit.

## 9. Dates

`scheduledDate` is optional. When it is absent, the app decides when the workout
goes on the watch, usually by asking.

Two spellings are allowed and they mean different things:

| Form | Example | Meaning |
|---|---|---|
| Wall clock | `2026-09-08T07:30:00` | 07:30 local time, wherever the athlete is. |
| Absolute | `2026-09-08T04:30:00Z`, `2026-09-08T07:30:00+03:00` | A fixed instant. |

Wall clock is the default a plan generator SHOULD emit, because a training plan
says "Monday morning" rather than "04:30 UTC". A reader MUST resolve a wall-clock
date against the athlete's time zone **at scheduling time**, not at parse time.

Accepted shapes: `YYYY-MM-DD`, `YYYY-MM-DDThh:mm`, `YYYY-MM-DDThh:mm:ss`, the same
with a space instead of `T`, and any of those with a `Z` or `±hh:mm` offset, which
makes them absolute. Anything else is `invalid_date`.

## 10. Constraints inherited from WorkoutKit

These are not the format's choices. They are what the platform accepts, and a
reader MUST reject a file that violates them instead of letting the watch fail
later.

1. **One alert per step.** If both a heart-rate ceiling and a cadence target matter
   on the same interval, pick the one that defines the session and put the other in
   `displayName`.
2. **No reps or weights.** A strength set is a step with a time or open goal, and
   the number of sets is the block's `iterations`. There is nowhere to put "10 reps
   at 60 kg" except `displayName` (`"Bench press 10 x 60 kg"`), which is also the
   only place the athlete would see it. This format does not add a field for it,
   because carrying data the watch cannot use would make files look richer than
   they are.
3. **Energy goals only in a `goal` workout**, never inside a custom workout's steps
   (`energy_goal_in_custom_workout`).
4. **Goals and alerts are validated per activity and location.** A distance goal
   needs an activity that measures distance, and power and speed alerts belong to
   cycling and running. WorkoutKit is the authority here, through its own
   `supports*` checks. Readers MUST surface a failure as `unsupported_goal`,
   `unsupported_alert` or `unsupported_activity`.
5. **There is a ceiling on scheduled workouts.** WorkoutKit exposes it as
   `WorkoutScheduler.maxAllowedScheduledWorkoutCount`, which is 50 at the time of
   writing. Read the constant instead of hard-coding the number.
6. **The watch surfaces scheduled workouts near the current date.** How far ahead
   it looks is platform behaviour and not part of this format. A file may contain
   dates months out, and an app SHOULD expect distant ones not to appear until
   closer to the day.

## 11. Extensibility

Two mechanisms, with different guarantees.

`extensions` is an object allowed at the top level and on every workout, block and
step. Its contents are opaque. Readers MUST ignore them and MUST preserve them when
rewriting the file. Keys SHOULD be namespaced in reverse-DNS form, such as
`"com.example.coach"`.

Properties prefixed with `x-` are allowed anywhere, for quick experiments. Readers
MUST ignore them and MAY drop them when rewriting.

Any other unknown property MUST be ignored by readers and MAY be dropped. Data that
has to survive a round-trip belongs in `extensions`.

## 12. Versioning

`version` is a single integer. It changes only when a file stops being readable by
an older implementation.

Additive changes, such as a new optional field, a new alias or a new activity, do
not change `version`. A v1 reader ignores what it does not know.

Breaking changes, such as removing a field, changing a meaning or adding a
*required* field, increment `version`. A v1 reader MUST refuse such a file instead
of guessing (`unsupported_version`).

Version 1 is frozen. New capability arrives as optional fields, or as version 2.

## 13. Conformance

An implementation conforms to version 1 if, given the suite in
[`conformance/`](conformance):

- it reads every file under `conformance/valid/` without error;
- it rejects every file under `conformance/invalid/` with the error code recorded
  in `conformance/manifest.json`.

Error codes are part of this specification. The accompanying English messages are
not. The full list is in [`Sources/WorkoutPlanFormat/FormatError.swift`](Sources/WorkoutPlanFormat/FormatError.swift).

The JSON Schema at [`schema/workoutplan-v1.schema.json`](schema/workoutplan-v1.schema.json)
validates the canonical writer profile. It catches nearly everything, though some
rules are beyond it, such as comparing `min` to `max`. Passing the schema is
therefore necessary but not sufficient, and `manifest.json` records which fixtures
fall in that gap.
