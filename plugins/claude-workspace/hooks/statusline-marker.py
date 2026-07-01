#!/usr/bin/env python3
"""Dedicated statusline marker hook (C7a) — separate from autolog.py by design.

Two responsibilities only:
  1. PostToolUse on the `Skill` tool where tool_input.skill == "workspace": write a
     pure-existence marker at ~/.claude/.workspace-active/<session_id> (INV6, AC5, AC6).
  2. SessionStart with source in {"startup", "clear"}: best-effort delete of orphaned
     marker files older than the 24h floor (INV10, AC8).

Single-responsibility: disabling/removing this hook can never affect autolog's
events.jsonl, and disabling autolog can never affect the statusline marker (C7a, C13).
"""

import json
import os
import sys
import time

# AC8/INV10: tunable orphan-cleanup threshold. 24h is concurrency-safe — it can never
# kill a freshly-active parallel session's marker — and harmless even if too generous,
# because a stale marker only affects rendering for its OWN session_id; it can never
# match a live statusline session_id that isn't itself stale.
ORPHAN_MAX_AGE_SECONDS = 24 * 60 * 60

MARKER_DIR = os.path.expanduser("~/.claude/.workspace-active")


def marker_path(session_id: str) -> str:
    """AC6 contract: exactly os.path.expanduser('~/.claude/.workspace-active/' + session_id)."""
    return os.path.expanduser("~/.claude/.workspace-active/" + session_id)


def handle_post_tool_use(event: dict) -> None:
    """INV6: write a marker iff tool_name == 'Skill' AND tool_input.skill == 'workspace'."""
    if event.get("tool_name") != "Skill":
        return
    tool_input = event.get("tool_input") or {}
    if tool_input.get("skill") != "workspace":
        return
    session_id = event.get("session_id", "")
    if not session_id:
        return
    path = marker_path(session_id)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    # Pure-existence marker: minimal, PII-free content.
    with open(path, "w", encoding="utf-8") as f:
        f.write("")


def handle_session_start(event: dict) -> None:
    """AC8/INV10: on source in {startup, clear}, delete markers older than the 24h floor.

    NEVER removes a marker younger than ORPHAN_MAX_AGE_SECONDS. Does nothing on
    source in {resume, compact} (or any other/absent source).
    """
    source = event.get("source", "")
    if source not in ("startup", "clear"):
        return
    if not os.path.isdir(MARKER_DIR):
        return
    now = time.time()
    try:
        entries = os.listdir(MARKER_DIR)
    except OSError:
        return
    for name in entries:
        path = os.path.join(MARKER_DIR, name)
        try:
            mtime = os.path.getmtime(path)
        except OSError:
            continue
        age = now - mtime
        if age > ORPHAN_MAX_AGE_SECONDS:
            try:
                os.remove(path)
            except OSError:
                pass


def main() -> None:
    raw = sys.stdin.read().strip()
    if not raw:
        return
    try:
        event = json.loads(raw)
    except json.JSONDecodeError:
        return
    if not isinstance(event, dict):
        return

    hook = event.get("hook_event_name", "")

    if hook == "PostToolUse":
        handle_post_tool_use(event)
    elif hook == "SessionStart":
        handle_session_start(event)


if __name__ == "__main__":
    try:
        main()
    except Exception:
        # Mirror autolog's discipline: never raise, never block the tool call.
        pass
