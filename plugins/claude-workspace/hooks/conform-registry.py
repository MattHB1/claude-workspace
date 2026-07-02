#!/usr/bin/env python3
"""Deterministic SessionStart conformer for `.workspace/initiatives.md` (registry-auto-migrate T1).

Reads $CLAUDE_PROJECT_DIR/.workspace/initiatives.md and — only when it can UNAMBIGUOUSLY
recognise a known drift form and identify the single active initiative row — rewrites the
file to the canonical format pinned in plugins/claude-workspace/skills/workspace/SKILL.md
(lines ~44-51):

    Active row:     | `<slug>` | <description> | <status> | **ACTIVE** |
    Non-active row: | `<slug>` | <description> | <status> |             |

The ONLY transforms performed are (C7/INV5): (i) backtick-wrapping the slug cell (first
column) of data rows, and (ii) placing the literal `**ACTIVE**` marker in the (previously
blank) Active cell of the single identified active row. Every other byte — descriptions,
statuses, row order, header, separator, and surrounding prose — is left untouched.

Safety posture (C4/INV6 — never guess): on ANY ambiguity, unrecognised structure, multiple
or zero recognisable active markers on a non-empty registry, or any error, the file is left
byte-untouched. This is NOT hardening of the parsers: `statusline.js:extractActiveSlug` and
`autolog.py:resolve_active_slug` (the correctness oracle) are never modified by this file.

Active-row recognition precedence (highest risk — see proposal/tasks T1):
  1. A standalone PROSE marker `**ACTIVE: <slug>**` appearing OUTSIDE the table's data rows
     (e.g. a free-floating note) is AUTHORITATIVE — it names the slug directly. Scanning is
     deliberately restricted to non-data-row lines only, so incidental "**ACTIVE**"-like text
     inside a Description/Status cell can never be mistaken for this marker.
  2. Failing that, a table row whose OWN Active cell already reads exactly `**ACTIVE**`
     (the canonical marker itself, just possibly missing a backtick-wrapped slug) is used.
  3. Failing that, a table row whose Status cell (and ONLY the Status cell) reads exactly
     `ACTIVE — ...` (a known drift form) is used, PROVIDED exactly one such row exists.
  Any conflict between sources (they name/point to different rows), any multiplicity within
  a source, or zero recognisable markers on a non-empty registry -> NO-OP + notice. The
  marker is never written onto a row that is not certain to be the active one.

Notice channel (C11): a one-line best-effort notice is emitted via SessionStart hook JSON
output as {"systemMessage": "..."} on stdout. `systemMessage` is surfaced to the user
without being injected into the model's context (unlike plain stdout / `additionalContext`,
which SessionStart hooks otherwise feed into context) — this satisfies "surface the mutation
without polluting context". Silent (no stdout at all) on already-canonical/empty/absent
input, per C11/INV9.

Fail-silent skeleton mirrors autolog.py / statusline-marker.py: never raises, never blocks.
"""

import json
import os
import re
import sys
from pathlib import Path

# INV8/C6: root comes ONLY from $CLAUDE_PROJECT_DIR — no __file__ fallback, no cwd
# derivation, no walk-up. Mirrors autolog.py:get_project_root exactly (unmodified original).
def get_project_root():
    env = os.environ.get("CLAUDE_PROJECT_DIR", "")
    if env:
        return Path(env)
    return None


PIPE_LINE_RE = re.compile(r"^[ \t]*\|")
SEPARATOR_BODY_RE = re.compile(r"[\s:\-]+")
STATUS_ACTIVE_RE = re.compile(r"ACTIVE\s*[—–-]\s*.+", re.DOTALL)
PROSE_ACTIVE_RE = re.compile(r"\*\*ACTIVE:\s*`?([A-Za-z0-9][A-Za-z0-9_-]*)`?\s*\*\*")

CONFORM_NOTICE_TMPL = (
    "conform-registry: conformed .workspace/initiatives.md — active row set to `{slug}` "
    "(canonical format, SKILL.md 44-51)."
)
NOOP_DRIFT_NOTICE = (
    "conform-registry: .workspace/initiatives.md has unrecognised/ambiguous active-row "
    "drift — left unchanged (see SKILL.md 44-51 for the canonical format; git diff is the "
    "backstop)."
)


def _is_separator_line(line: str) -> bool:
    body = line.strip().replace("|", "")
    return bool(body) and bool(SEPARATOR_BODY_RE.fullmatch(body))


def _ws_split(raw: str):
    """Split a raw cell string into (leading_ws, core, trailing_ws)."""
    core = raw.strip()
    if not core:
        return raw, "", ""
    start = raw.index(core)
    end = start + len(core)
    return raw[:start], core, raw[end:]


def _backtick_wrap(raw: str) -> str:
    lead, core, trail = _ws_split(raw)
    if len(core) >= 2 and core[0] == "`" and core[-1] == "`":
        return raw  # already wrapped — unchanged (idempotence)
    return f"{lead}`{core}`{trail}"


def _set_canonical_marker(raw: str) -> str:
    core = raw.strip()
    if core == "**ACTIVE**":
        return raw  # already canonical — unchanged (idempotence)
    # Blank cell being filled: use the canonical template's padding exactly.
    return " **ACTIVE** "


def _oracle_would_resolve(text: str, expected_slug: str) -> bool:
    """Pre-write INV3 gate — see the call site's comment for why this exact shared
    worst-case check (not a re-implementation of either resolver's full contract) is
    sufficient for both `resolve_active_slug` and `extractActiveSlug` post-transform.

    AC25: mirrors the anchored resolvers' whole-cell marker test exactly — split the
    line on '|', trim each cell, and require exact equality to '**ACTIVE**' (not a
    substring). A mention of the token inside another cell (e.g. a description) no
    longer counts as a match here either."""
    for line in text.splitlines():
        if not re.match(r"\s*\|", line):
            continue
        if any(cell.strip() == "**ACTIVE**" for cell in line.split("|")):
            m = re.search(r"`([^`]+)`", line)
            return bool(m and m.group(1) == expected_slug)
    return False


def conform(original: str):
    """Pure function: (original text) -> (new_text, notice_or_None).

    new_text == original whenever nothing changed (whether because the input was already
    canonical/idempotent, empty, or because an ambiguity forced a no-op). The caller
    decides whether to write based on new_text != original, and always uses the returned
    notice (None => stay silent, per C11).
    """
    lines = original.splitlines(keepends=True)

    pipe_idxs = [i for i, l in enumerate(lines) if PIPE_LINE_RE.match(l)]
    if not pipe_idxs:
        return original, None  # AC9/AC10-adjacent: no table at all -> nothing to conform

    # Exactly one contiguous table block is the only recognised structure (C9: single
    # known format, not a general framework). Gaps -> unrecognised.
    if pipe_idxs[-1] - pipe_idxs[0] + 1 != len(pipe_idxs):
        return original, NOOP_DRIFT_NOTICE

    block_start, block_end = pipe_idxs[0], pipe_idxs[-1]
    block = lines[block_start:block_end + 1]

    # block[0] is always the header row — never inspected or touched.
    rest = block[1:]
    if rest and _is_separator_line(rest[0]):
        data_lines = rest[1:]
        data_start_idx = block_start + 2
    else:
        data_lines = rest
        data_start_idx = block_start + 1

    if not data_lines:
        return original, None  # AC9: header/prose but no initiative rows -> silent no-op

    rows = []
    for line in data_lines:
        idxs = [i for i, ch in enumerate(line) if ch == "|"]
        if len(idxs) != 5:
            return original, NOOP_DRIFT_NOTICE  # not the known 4-column canonical shape
        if _is_separator_line(line):
            return original, NOOP_DRIFT_NOTICE  # stray separator-like row -> malformed table
        prefix = line[:idxs[0]]
        suffix = line[idxs[4] + 1:]
        cells = [line[idxs[k] + 1:idxs[k + 1]] for k in range(4)]

        slug_core = cells[0].strip()
        if not slug_core:
            return original, NOOP_DRIFT_NOTICE  # malformed: no slug
        slug_stripped = slug_core.strip("`")

        status_core = cells[2].strip()
        status_is_active = bool(STATUS_ACTIVE_RE.fullmatch(status_core))

        active_core = cells[3].strip()
        if active_core == "":
            active_kind = "blank"
        elif active_core == "**ACTIVE**":
            active_kind = "canonical"
        else:
            return original, NOOP_DRIFT_NOTICE  # unrecognised content in the Active cell

        rows.append({
            "prefix": prefix,
            "suffix": suffix,
            "cells": cells,
            "slug_stripped": slug_stripped,
            "status_is_active": status_is_active,
            "active_kind": active_kind,
        })

    canonical_rows = [i for i, r in enumerate(rows) if r["active_kind"] == "canonical"]
    status_cell_rows = [i for i, r in enumerate(rows) if r["status_is_active"]]

    # Rule 1: standalone prose marker, scanned ONLY outside the data-row lines, so
    # Description/Status cell text can never be mistaken for it (mis-identification guard).
    data_line_set = set(range(data_start_idx, data_start_idx + len(data_lines)))
    prose_slugs = set()
    for i, line in enumerate(lines):
        if i in data_line_set:
            continue
        for m in PROSE_ACTIVE_RE.finditer(line):
            prose_slugs.add(m.group(1))

    def conflicts_with(candidate_idx: int) -> bool:
        others_canonical = [i for i in canonical_rows if i != candidate_idx]
        others_status = [i for i in status_cell_rows if i != candidate_idx]
        return bool(others_canonical or others_status)

    active_idx = None

    if len(prose_slugs) > 1:
        return original, NOOP_DRIFT_NOTICE  # multiple irreconcilable prose markers
    elif len(prose_slugs) == 1:
        target_slug = next(iter(prose_slugs))
        matches = [i for i, r in enumerate(rows) if r["slug_stripped"] == target_slug]
        if len(matches) != 1:
            return original, NOOP_DRIFT_NOTICE  # slug names no row, or names >1 row
        candidate = matches[0]
        if conflicts_with(candidate):
            return original, NOOP_DRIFT_NOTICE  # prose vs. marker/status-cell disagree
        active_idx = candidate
    else:
        if canonical_rows:
            if len(canonical_rows) > 1:
                return original, NOOP_DRIFT_NOTICE  # multiple canonical markers
            candidate = canonical_rows[0]
            if conflicts_with(candidate):
                return original, NOOP_DRIFT_NOTICE  # canonical vs. status-cell disagree
            active_idx = candidate
        elif status_cell_rows:
            if len(status_cell_rows) > 1:
                return original, NOOP_DRIFT_NOTICE  # multiple status-cell candidates
            active_idx = status_cell_rows[0]
        else:
            return original, NOOP_DRIFT_NOTICE  # AC8: zero recognisable marker, non-empty

    # Build the conformed rows: backtick-wrap every slug cell; place the canonical marker
    # ONLY on the identified active row. Every other cell is passed through unchanged.
    new_data_lines = []
    for i, r in enumerate(rows):
        cells = r["cells"]
        new_slug = _backtick_wrap(cells[0])
        new_active = _set_canonical_marker(cells[3]) if i == active_idx else cells[3]
        new_line = r["prefix"] + "|" + new_slug + "|" + cells[1] + "|" + cells[2] + "|" + new_active + "|" + r["suffix"]
        new_data_lines.append(new_line)

    new_lines = list(lines)
    new_lines[data_start_idx:data_start_idx + len(data_lines)] = new_data_lines
    new_text = "".join(new_lines)

    if new_text == original:
        return original, None  # already canonical / idempotent fixed point

    target_slug = rows[active_idx]["slug_stripped"]

    # INV3 safety gate: never COMMIT a conform unless it is verifiably safe under BOTH
    # unmodified, anchored oracle resolvers (statusline.js:extractActiveSlug, autolog.py:
    # resolve_active_slug). Both scan `|`-lines top-to-bottom and short-circuit on the
    # FIRST line carrying a whole trimmed cell exactly equal to "**ACTIVE**", extracting
    # its first backtick-wrapped cell (AC25: whole-cell, not substring — a Description
    # cell that merely mentions "**ACTIVE**" as prose no longer collides in either
    # resolver). Since every row's slug is now backtick-wrapped, JS's start-anchored
    # match and Python's anywhere-in-line match agree on this same worst case, so a
    # single top-down replay against the identical trigger condition suffices as the
    # pre-write guard for both. If it would NOT resolve correctly, this is the
    # mis-identification-guard escape hatch: refuse the write, no-op + notice instead
    # (never write a "conforming" file that the real resolvers cannot correctly read).
    if not _oracle_would_resolve(new_text, target_slug):
        return original, NOOP_DRIFT_NOTICE

    return new_text, CONFORM_NOTICE_TMPL.format(slug=target_slug)


def main() -> None:
    # Best-effort stdin drain; this hook's behaviour never depends on the event payload
    # (it must act identically on every SessionStart source per C2).
    try:
        sys.stdin.read()
    except Exception:
        pass

    root = get_project_root()
    if root is None:
        return  # AC11: unset/empty $CLAUDE_PROJECT_DIR -> silent no-op

    ws_dir = root / ".workspace"
    if not ws_dir.is_dir():
        return  # AC10: absent .workspace/ -> silent no-op

    registry_path = ws_dir / "initiatives.md"
    if not registry_path.is_file():
        return  # AC10: absent file -> silent no-op

    try:
        original = registry_path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return  # AC13: unreadable/binary/permission-denied -> silent no-op

    new_text, notice = conform(original)

    if new_text != original:
        try:
            registry_path.write_text(new_text, encoding="utf-8")
        except OSError:
            return  # INV7: never raise on write failure either

    if notice:
        try:
            print(json.dumps({"systemMessage": notice}))
        except Exception:
            pass


if __name__ == "__main__":
    try:
        main()
    except Exception:
        # INV7: never raise, never block the session.
        pass
