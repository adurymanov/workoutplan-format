#!/usr/bin/env python3
"""Validate the examples and the conformance suite against the JSON Schema.

    python3 scripts/validate.py

Checks three things:

  * every file in examples/ is valid against the schema;
  * every conformance fixture marked `schemaValid` is valid, and every one marked
    `schemaInvalid` is rejected;
  * the fixtures the schema cannot catch are still listed, so the gap between
    "schema-valid" and "reader-valid" stays documented rather than accidental.

Requires: pip install jsonschema
"""

from __future__ import annotations

import json
import pathlib
import sys

try:
    from jsonschema import Draft202012Validator
except ImportError:
    sys.exit("jsonschema is not installed. Run: pip install jsonschema")

ROOT = pathlib.Path(__file__).resolve().parent.parent
SCHEMA_PATH = ROOT / "schema" / "workoutplan-v1.schema.json"
MANIFEST_PATH = ROOT / "conformance" / "manifest.json"


def load(path: pathlib.Path):
    """Returns the parsed document, or None if it is not JSON at all."""
    try:
        return json.loads(path.read_text())
    except json.JSONDecodeError:
        return None


def main() -> int:
    schema = json.loads(SCHEMA_PATH.read_text())
    Draft202012Validator.check_schema(schema)
    validator = Draft202012Validator(schema)

    failures: list[str] = []
    checked = 0

    def schema_errors(path: pathlib.Path) -> list[str] | None:
        document = load(path)
        if document is None:
            return ["not valid JSON"]
        return [
            f"{'/'.join(str(part) for part in error.absolute_path) or '<root>'}: {error.message}"
            for error in validator.iter_errors(document)
        ]

    for path in sorted((ROOT / "examples").glob("*.workoutplan")):
        checked += 1
        errors = schema_errors(path)
        if errors:
            failures.append(f"examples/{path.name} should be valid:\n    " + "\n    ".join(errors))

    manifest = json.loads(MANIFEST_PATH.read_text())
    uncatchable = []

    for entry in manifest["valid"]:
        path = ROOT / "conformance" / entry["file"]
        if not entry.get("schemaValid", True):
            # Reader-valid but deliberately outside the canonical writer profile.
            if not schema_errors(path):
                failures.append(
                    f"{entry['file']} is marked schemaValid=false but the schema accepts it")
            continue
        checked += 1
        errors = schema_errors(path)
        if errors:
            failures.append(f"{entry['file']} should be valid:\n    " + "\n    ".join(errors))

    for entry in manifest["invalid"]:
        path = ROOT / "conformance" / entry["file"]
        checked += 1
        errors = schema_errors(path)
        if entry.get("schemaInvalid", True):
            if not errors:
                failures.append(
                    f"{entry['file']} should be rejected by the schema ({entry['error']})")
        else:
            uncatchable.append(f"{entry['file']} ({entry['error']})")
            if errors:
                failures.append(
                    f"{entry['file']} is marked schemaInvalid=false but the schema rejects it")

    print(f"Checked {checked} files against {SCHEMA_PATH.relative_to(ROOT)}")
    if uncatchable:
        print("\nInvalid only to a reader, not to the schema:")
        for item in uncatchable:
            print(f"  - {item}")

    if failures:
        print(f"\n{len(failures)} failure(s):\n")
        for failure in failures:
            print(f"  ✗ {failure}")
        return 1

    print("\nAll good.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
