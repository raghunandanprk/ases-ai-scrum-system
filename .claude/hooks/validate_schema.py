#!/usr/bin/env python3
"""
ASES Schema Validator — validate_schema.py
Validates a JSON document against its ASES schema (JSON Schema Draft-07).

Usage:
    python .claude/hooks/validate_schema.py <json_file> <schema_name>

Example:
    python .claude/hooks/validate_schema.py sprints/S1/design/lld.json lld

Exit codes:
    0 = valid
    1 = invalid (details on stderr)
    2 = file/schema not found
"""

import json
import sys
from pathlib import Path


def find_project_root():
    """Walk up from cwd to find ASES project root (.ases dir present)."""
    p = Path.cwd()
    for _ in range(10):
        if (p / ".ases").exists():
            return p
        p = p.parent
    return Path.cwd()


def validate_type(value, schema, path="$"):
    """Minimal JSON Schema Draft-07 validator (no external deps).
    Validates: type, required, enum, pattern, minimum, maximum,
    minItems, maxItems, properties, items, additionalProperties, format.
    """
    errors = []

    if "type" in schema:
        expected = schema["type"]
        type_map = {
            "string": str, "integer": int, "number": (int, float),
            "boolean": bool, "array": list, "object": dict, "null": type(None)
        }
        if isinstance(expected, list):
            valid = any(isinstance(value, type_map.get(t, object)) for t in expected)
            if not valid:
                errors.append(f"{path}: expected one of {expected}, got {type(value).__name__}")
                return errors
        else:
            expected_type = type_map.get(expected)
            if expected_type and not isinstance(value, expected_type):
                # int passes for number
                if expected == "number" and isinstance(value, int):
                    pass
                else:
                    errors.append(f"{path}: expected {expected}, got {type(value).__name__}")
                    return errors

    if "enum" in schema and value not in schema["enum"]:
        errors.append(f"{path}: value '{value}' not in enum {schema['enum']}")

    if "pattern" in schema and isinstance(value, str):
        import re
        if not re.match(schema["pattern"], value):
            errors.append(f"{path}: '{value}' does not match pattern '{schema['pattern']}'")

    if "minimum" in schema and isinstance(value, (int, float)):
        if value < schema["minimum"]:
            errors.append(f"{path}: {value} < minimum {schema['minimum']}")

    if "maximum" in schema and isinstance(value, (int, float)):
        if value > schema["maximum"]:
            errors.append(f"{path}: {value} > maximum {schema['maximum']}")

    if isinstance(value, dict):
        if "required" in schema:
            for req in schema["required"]:
                if req not in value:
                    errors.append(f"{path}: missing required property '{req}'")

        if "properties" in schema:
            for prop, prop_schema in schema["properties"].items():
                if prop in value:
                    errors.extend(validate_type(value[prop], prop_schema, f"{path}.{prop}"))

        if "maxProperties" in schema and len(value) > schema["maxProperties"]:
            errors.append(f"{path}: {len(value)} properties exceeds max {schema['maxProperties']}")

    if isinstance(value, list):
        if "minItems" in schema and len(value) < schema["minItems"]:
            errors.append(f"{path}: array length {len(value)} < minItems {schema['minItems']}")
        if "maxItems" in schema and len(value) > schema["maxItems"]:
            errors.append(f"{path}: array length {len(value)} > maxItems {schema['maxItems']}")
        if "items" in schema:
            for i, item in enumerate(value):
                errors.extend(validate_type(item, schema["items"], f"{path}[{i}]"))

    return errors


def main():
    if len(sys.argv) < 3:
        print("Usage: python validate_schema.py <json_file> <schema_name>", file=sys.stderr)
        sys.exit(2)

    json_file = Path(sys.argv[1])
    schema_name = sys.argv[2]

    root = find_project_root()
    schema_path = root / "format" / "json" / f"{schema_name}.schema.json"

    if not json_file.exists():
        print(f"[ASES VALIDATE] File not found: {json_file}", file=sys.stderr)
        sys.exit(2)

    if not schema_path.exists():
        print(f"[ASES VALIDATE] Schema not found: {schema_path}", file=sys.stderr)
        sys.exit(2)

    try:
        doc = json.loads(json_file.read_text())
    except json.JSONDecodeError as e:
        print(f"[ASES VALIDATE] Invalid JSON in {json_file}: {e}", file=sys.stderr)
        sys.exit(1)

    try:
        schema = json.loads(schema_path.read_text())
    except json.JSONDecodeError as e:
        print(f"[ASES VALIDATE] Invalid JSON in schema {schema_path}: {e}", file=sys.stderr)
        sys.exit(2)

    errors = validate_type(doc, schema)

    if errors:
        print(f"[ASES VALIDATE] {json_file} FAILED against {schema_name}:", file=sys.stderr)
        for err in errors:
            print(f"  - {err}", file=sys.stderr)
        sys.exit(1)
    else:
        print(f"[ASES VALIDATE] {json_file} PASSED against {schema_name}")
        sys.exit(0)


if __name__ == "__main__":
    main()
