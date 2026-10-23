#!/usr/bin/env python3
"""Dedicated statusline marker hook (C7a) - separate from autolog.py by design.

The marker is ~/.claude/.workspace-active/<session_id>. It holds key=value lines
(root=, checkout=, slug=). This change supersedes the old pure-existence marker rule.
The marker path comes from autolog.py, the one master of that path.

Responsibilities:
  1. PostToolUse on the `Skill` tool where tool_input.skill == "workspace": write
     root= and checkout= lines when the marker is absent or empty. Never change a
     marker that has content (INV6, AC2).
  2. Command line: `--session <id> --cwd <path>` does the same write. It reads no
     stdin, never raises, and exits 0.
  3. SessionStart with source in {"startup", "clear"}: best-effort delete of orphaned
     marker files older than the 24h floor (INV10, AC8).
  4. SessionEnd: delete this session's marker.

Single-responsibility: disabling/removing this hook can never affect autolog's
events.jsonl, and disabling autolog can never affect the statusline marker (C7a, C13).
"""

import json
import os
import sys
import time

# Do not leave hooks/__pycache__/ in the plugin tree.
sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
try:
    import autolog
except Exception:  # noqa: BLE001
    # Same discipline as below: a missing or broken autolog must never raise.
    sys.exit(0)

# AC8/INV10: tunable orphan-cleanup threshold. 24h is concurrency-safe — it can never
# kill a freshly-active parallel session's marker — and harmless even if too generous,
# because a stale marker only affects rendering for its OWN session_id; it can never
# match a live statusline session_id that isn't itself stale.
ORPHAN_MAX_AGE_SECONDS = 24 * 60 * 60

MARKER_DIR = str(autolog.marker_dir())


def write_marker(session_id: str, cwd: str) -> None:
    """Write root= and checkout= when the marker is absent or empty (M1, M2).

    A marker that has content stays unchanged (AC2).
    """
    if not session_id:
        return
    path = autolog.marker_path(session_id)
    try:
        if path.stat().st_size > 0:
            return
    except OSError:
        pass
    root = autolog.get_project_root(cwd)
    checkout = autolog.get_checkout_path(cwd)
    lines = []
    if root:
        lines.append("root=" + str(root))
    if checkout:
        lines.append("checkout=" + str(checkout))
    path.parent.mkdir(parents=True, exist_ok=True)
    # An empty marker still marks the session as a workspace session.
    path.write_text("".join(line + "\n" for line in lines), encoding="utf-8")


def handle_post_tool_use(event: dict) -> None:
    """INV6: write a marker iff tool_name == 'Skill' AND tool_input.skill == 'workspace'."""
    if event.get("tool_name") != "Skill":
        return
    tool_input = event.get("tool_input") or {}
    if tool_input.get("skill") != "workspace":
        return
    write_marker(event.get("session_id", ""), event.get("cwd", ""))


def handle_session_end(event: dict) -> None:
    """Delete this session's marker. Never raises on a missing file."""
    session_id = event.get("session_id", "")
    if not session_id:
        return
    try:
        autolog.marker_path(session_id).unlink()
    except OSError:
        pass


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


def main_cli(argv: list) -> None:
    """Command-line mode: --session <id> --cwd <path>. Reads no stdin."""
    args = {}
    for i, a in enumerate(argv[:-1]):
        if a in ("--session", "--cwd"):
            args[a] = argv[i + 1]
    write_marker(args.get("--session", ""), args.get("--cwd", ""))


def main() -> None:
    if len(sys.argv) > 1:
        main_cli(sys.argv[1:])
        return
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
    elif hook == "SessionEnd":
        handle_session_end(event)


if __name__ == "__main__":
    try:
        main()
    except Exception:
        # Mirror autolog's discipline: never raise, never block the tool call.
        pass
