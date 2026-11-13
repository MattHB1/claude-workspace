#!/usr/bin/env python3
"""Check one run-summary.json file. Use: check-run-summary.py <file>.

Reads the required keys and the enums from
plugins/claude-workspace/docs/run-summary.schema.json.
The schema must have a top-level "required" array. Each enum must sit inline
under "properties", or inside an "anyOf" or "oneOf" branch. The schema must
not use "$ref" or "$defs".
Exits 0 when the file is valid. Exits 1 and prints each problem when not.
"""

import json
import os
import re
import sys

SCHEMA = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    "..",
    "..",
    "plugins",
    "claude-workspace",
    "docs",
    "run-summary.schema.json",
)
UTC_TS = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?Z$")


def find_enum(node, path):
    """Follow property names in path. Look inside anyOf/oneOf when needed."""
    if not path:
        if isinstance(node, dict):
            if "enum" in node:
                return [v for v in node["enum"] if v is not None]
            for key in ("anyOf", "oneOf"):
                for sub in node.get(key, []):
                    found = find_enum(sub, path)
                    if found is not None:
                        return found
        return None
    if not isinstance(node, dict):
        return None
    if "properties" in node and path[0] in node["properties"]:
        return find_enum(node["properties"][path[0]], path[1:])
    for key in ("anyOf", "oneOf"):
        for sub in node.get(key, []):
            found = find_enum(sub, path)
            if found is not None:
                return found
    return None


def load_enums():
    try:
        with open(SCHEMA, encoding="utf-8") as fh:
            schema = json.load(fh)
    except FileNotFoundError:
        sys.exit(f"ERROR: schema file is missing: {os.path.normpath(SCHEMA)}")
    except ValueError as exc:
        sys.exit(f"ERROR: schema file is not valid JSON: {exc}")
    required = schema.get("required") if isinstance(schema, dict) else None
    if not isinstance(required, list) or not required:
        sys.exit("ERROR: schema file has no top-level required array")
    paths = {
        "status": ["status"],
        "stage_reached": ["stage_reached"],
        "failure.code": ["failure", "code"],
        "blocked_reason.code": ["blocked_reason", "code"],
    }
    enums = {"required": required}
    for name, path in paths.items():
        enums[name] = find_enum(schema, path)
        if not enums[name]:
            sys.exit(f"ERROR: schema file has no enum for {name}")
    return enums


def check(doc, enums):
    errs = []
    if not isinstance(doc, dict):
        return ["summary is not a JSON object"]
    for key in enums["required"]:
        if key not in doc:
            errs.append(f"missing key: {key}")
    if errs:
        return errs
    if doc["schema_version"] != 1 or isinstance(doc["schema_version"], bool):
        errs.append("schema_version must be 1")
    status = doc["status"]
    if status not in enums["status"]:
        errs.append(f"status not in enum: {status!r}")
    if doc["stage_reached"] not in enums["stage_reached"]:
        errs.append("stage_reached not in enum: {!r}".format(doc["stage_reached"]))
    for field, only in (
        ("blocked_reason", "blocked"),
        ("failure", "failed"),
        ("pr_url", "pr_opened"),
    ):
        if (doc[field] is not None) != (status == only):
            errs.append(f"{field} must be non-null only when status is {only}")
    for field in ("failure", "blocked_reason"):
        obj = doc[field]
        if obj is None:
            continue
        if not isinstance(obj, dict):
            errs.append(f"{field} must be an object or null")
        elif obj.get("code") not in enums[field + ".code"]:
            errs.append("{}.code not in enum: {!r}".format(field, obj.get("code")))
    for field in ("started_at", "finished_at"):
        value = doc[field]
        if value is None and field == "finished_at" and status == "running":
            continue
        if not isinstance(value, str) or not UTC_TS.match(value):
            errs.append(f"{field} must be UTC ISO-8601 (YYYY-MM-DDTHH:MM:SSZ)")
    return errs


def main(argv):
    if len(argv) != 2:
        sys.exit("usage: check-run-summary.py <summary-file>")
    enums = load_enums()
    try:
        with open(argv[1], encoding="utf-8") as fh:
            doc = json.load(fh)
    except (OSError, ValueError) as exc:
        sys.exit(f"ERROR: cannot read summary {argv[1]}: {exc}")
    errs = check(doc, enums)
    for err in errs:
        print(f"FAIL: {err}")
    return 1 if errs else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
