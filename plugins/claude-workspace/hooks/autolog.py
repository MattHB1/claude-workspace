#!/usr/bin/env python3
"""Workspace events hook. Appends one JSONL line per event to the active initiative's events.jsonl."""

import json
import os
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

# Delta (d): workspace-scoped path filter (T1 parameter-contract §Parameter 2)
# Matches .workspace/**, skills/workspace/SKILL.md, and .claude/hooks/**
TRACKED_PATTERNS = re.compile(
    r"(\.workspace/|skills/workspace/SKILL\.md|\.claude/hooks/)"
)

# INV9: output root comes ONLY from $CLAUDE_PROJECT_DIR — no __file__ fallback,
# no cwd derivation, no home fallback.  Returns None when the var is unset/empty;
# callers treat None as a no-op (INV10).
def get_project_root():
    env = os.environ.get("CLAUDE_PROJECT_DIR", "")
    if env:
        return Path(env)
    return None


def resolve_active_slug(root: Path):
    """Read <root>/.workspace/initiatives.md and return the active slug per T1 edge-case rules.

    Returns the slug string if exactly one (or more — take first) ACTIVE row is found,
    or None if the directory/file is absent, unreadable, or has zero ACTIVE rows.
    Degrades gracefully in all error cases (INV9, INV10).
    """
    ws_dir = root / ".workspace"
    if not ws_dir.is_dir():
        return None
    registry = ws_dir / "initiatives.md"
    try:
        text = registry.read_text(encoding="utf-8")
    except (OSError, IOError):
        return None
    for line in text.splitlines():
        # Only consider actual table rows: line must start with '|' (after optional whitespace)
        if not re.match(r"\s*\|", line):
            continue
        if re.search(r"\*\*ACTIVE\*\*", line):
            m = re.search(r"`([^`]+)`", line)
            if m and m.group(1):
                return m.group(1)
            # Slug extraction failed — treat as zero-ACTIVE
            return None
    return None


def utc_now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def short_session(session_id: str) -> str:
    return session_id[:8] if session_id else "unknown"


def is_tracked_path(path: str) -> bool:
    return bool(TRACKED_PATTERNS.search(path))


def truncate(s: str, n: int = 160) -> str:
    s = s.replace("\n", " ").strip()
    return s if len(s) <= n else s[: n - 1] + "…"


def append_jsonl(log_file: Path, record: dict) -> None:
    """Append one JSONL line; create parent dirs if needed."""
    log_file.parent.mkdir(parents=True, exist_ok=True)
    with open(log_file, "a", encoding="utf-8") as f:
        f.write(json.dumps(record, ensure_ascii=False) + "\n")


def emit(
    log_file: Path,
    ts: str,
    session: str,
    event: str,
    detail: str,
    slug: str,
    agent_id,
    agent_type,
) -> None:
    """Emit the AC17 schema line: {ts, session, event, detail, slug, agent_id, agent_type}."""
    append_jsonl(log_file, {
        "ts": ts,
        "session": session,
        "event": event,
        "detail": truncate(detail),
        "slug": slug,
        "agent_id": agent_id,
        "agent_type": agent_type,
    })


def handle_post_tool_use(event: dict, log_file: Path, slug: str) -> None:
    tool = event.get("tool_name", "")
    inp = event.get("tool_input", {}) or {}
    ts = utc_now()
    session = short_session(event.get("session_id", ""))
    # AC17: read attribution fields null-safely; absent/null → None (emitted as JSON null)
    agent_id = event.get("agent_id") or None
    agent_type = event.get("agent_type") or None

    if tool in ("Write", "Edit", "Read"):
        # Delta (d): use workspace path filter; delta (c): emit JSONL with event="edit"
        file_path = inp.get("file_path", "")
        if not is_tracked_path(file_path):
            return
        emit(log_file, ts, session, "edit", file_path, slug, agent_id, agent_type)

    elif tool == "Bash":
        command = inp.get("command", "")
        if not command:
            return
        # Discriminate the three Bash event types per T1 AC4 table
        if re.search(r"\bgit\s+(pull|fetch)\b", command):
            emit(log_file, ts, session, "git-pull", command, slug, agent_id, agent_type)
        elif re.search(r"\bgit\s+push\b", command):
            emit(log_file, ts, session, "git-push", command, slug, agent_id, agent_type)
        elif re.search(r"\bgh\s+pr\s+create\b|https://github\.com/.+/pull/\d+", command):
            emit(log_file, ts, session, "pr-create", command, slug, agent_id, agent_type)
        else:
            # Retain all Bash calls for a complete trace (non-special → "bash")
            emit(log_file, ts, session, "bash", command, slug, agent_id, agent_type)

    elif tool == "Skill":
        skill = inp.get("skill", "")
        args = inp.get("args", "")
        emit(log_file, ts, session, "skill", f"{skill} {args}".strip(), slug, agent_id, agent_type)

    elif tool == "Agent":
        subagent = inp.get("subagent_type", "general-purpose")
        desc = inp.get("description", "")
        emit(log_file, ts, session, "agent", f"{subagent}: {desc}", slug, agent_id, agent_type)

    elif tool == "WebFetch":
        url = inp.get("url", "")
        emit(log_file, ts, session, "webfetch", url, slug, agent_id, agent_type)

    elif tool == "WebSearch":
        query = inp.get("query", "")
        emit(log_file, ts, session, "websearch", query, slug, agent_id, agent_type)


def handle_stop(event: dict, log_file: Path, slug: str) -> None:
    ts = utc_now()
    session = short_session(event.get("session_id", ""))
    # AC17: read attribution fields null-safely; Stop events typically have no agent context
    agent_id = event.get("agent_id") or None
    agent_type = event.get("agent_type") or None
    emit(log_file, ts, session, "stop", "session ended", slug, agent_id, agent_type)


def main() -> None:
    raw = sys.stdin.read().strip()
    if not raw:
        return
    try:
        event = json.loads(raw)
    except json.JSONDecodeError:
        return

    # INV9/INV10: $CLAUDE_PROJECT_DIR ONLY — no-op if unset
    root = get_project_root()
    if root is None:
        return

    # Delta (a) + INV9: resolve active slug with graceful degradation
    slug = resolve_active_slug(root)
    if not slug:
        return

    # Delta (a): per-initiative destination
    log_file = root / ".workspace" / slug / "memory" / "events.jsonl"

    hook = event.get("hook_event_name", "")

    if hook == "PostToolUse":
        handle_post_tool_use(event, log_file, slug)
    elif hook == "Stop":
        handle_stop(event, log_file, slug)


if __name__ == "__main__":
    try:
        main()
    except Exception:
        # INV10: never raise, never block the tool call
        pass
