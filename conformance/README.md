# Conformance suite

Test data rather than Swift, so an implementation in any language can run it.

- `valid/` holds files a conforming reader MUST load without error.
- `invalid/` holds files a conforming reader MUST reject, each with a specific
  error code.
- `manifest.json` says what is expected of each file.

```json
{
  "valid": [
    { "file": "valid/minimal-goal.workoutplan", "description": "…", "schemaValid": true }
  ],
  "invalid": [
    { "file": "invalid/energy-goal-in-custom.json", "error": "energy_goal_in_custom_workout",
      "schemaInvalid": true, "description": "…" }
  ]
}
```

`schemaValid: false` marks a file that a reader must accept but that sits outside
the canonical writer profile, because it uses aliases such as `run` or `minutes`.
Writers must not emit those, readers should accept them.

`schemaInvalid: false` marks an invalid file the JSON Schema cannot catch, because
the rule compares two sibling values. Only a reader catches those. The manifest
records the distinction rather than hiding it, since it is the boundary of what
schema validation buys you.

Error codes are part of the specification. The English messages are not, so
localise from the code.

## Running it

Swift: `swift test`, which reads this manifest from
`Tests/WorkoutPlanFormatTests/ConformanceTests.swift`.

Schema only: `python3 scripts/validate.py`.
