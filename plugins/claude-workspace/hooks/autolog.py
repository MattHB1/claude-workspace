#!/usr/bin/env python3
"""Workspace events hook. Appends one JSONL line per event to the events.jsonl of the
initiative that this session picked.

The slug comes only from the slug= line of this session's marker
(~/.claude/.workspace-active/<session_id>). No marker, or no slug= line, means no
event. The hook reads no registry row. Events go to
<shared root>/.workspace/<slug>/memory/events.jsonl. The shared root is the same
for every worktree of a repo (see get_project_root). This change supersedes the
old rule that took the root only from $CLAUDE_PROJECT_DIR and the slug from the
registry ACTIVE row.
"""

import json
import os
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

# Delta (d): workspace-scoped path filter (T1 parameter-contract §Parameter 2)
# Matches .workspace/**, skills/workspace/SKILL.md, and .claude/hooks/**
TRACKED_PATTERNS = re.compile(
    r"(\.workspace/|skills/workspace/SKILL\.md|\.claude/hooks/)"
)

def _git(cwd, *args):
    """Run git in cwd. Return stripped stdout, or None on any error or timeout."""
    if not cwd:
        return None
    try:
        r = subprocess.run(
            ["git", *args],
            cwd=str(cwd),
            capture_output=True,
            text=True,
            timeout=5,
            check=False,
        )
    except (OSError, subprocess.SubprocessError, ValueError):
        return None
    out = r.stdout.strip()
    if r.returncode != 0 or not out:
        return None
    return out


# INV9 (superseded): the old rule said the output root comes ONLY from
# $CLAUDE_PROJECT_DIR. The multi-live-workspaces change replaces it. The root is
# now the shared root, so every worktree of a repo uses one .workspace/ folder:
#   1. the parent of `git rev-parse --path-format=absolute --git-common-dir`
#      (run from the hook cwd), when that path ends in /.git;
#   2. else `git rev-parse --show-toplevel` (bare repo or submodule);
#   3. else $CLAUDE_PROJECT_DIR (outside git);
#   4. else None.
# Git errors and timeouts never raise. Callers treat None as a no-op (INV10).
def get_project_root(cwd=None):
    common = _git(cwd, "rev-parse", "--path-format=absolute", "--git-common-dir")
    if common:
        if common.endswith("/.git"):
            return Path(common).parent
        top = _git(cwd, "rev-parse", "--show-toplevel")
        if top:
            return Path(top)
    env = os.environ.get("CLAUDE_PROJECT_DIR", "")
    if env:
        return Path(env)
    return None


def get_checkout_path(cwd):
    """Return the checkout path (git toplevel) of cwd, or None outside git."""
    top = _git(cwd, "rev-parse", "--show-toplevel")
    return Path(top) if top else None


def marker_dir():
    """Return the folder that holds the session markers."""
    return Path.home() / ".claude" / ".workspace-active"


def marker_path(session_id):
    """Return the marker path of a session. This is the one master of the path."""
    return marker_dir() / session_id


def read_marker(session_id):
    """Read ~/.claude/.workspace-active/<session_id> as key=value lines.

    Returns a dict. Returns {} when the marker is absent or unreadable.
    """
    if not session_id:
        return {}
    try:
        text = marker_path(session_id).read_text(encoding="utf-8")
    except (OSError, ValueError):
        return {}
    data = {}
    for line in text.splitlines():
        key, sep, value = line.partition("=")
        if sep and key.strip() and key.strip() not in data:
            data[key.strip()] = value.strip()
    return data


def utc_now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def short_session(session_id: str) -> str:
    return session_id[:8] if session_id else "unknown"


def is_tracked_path(path: str) -> bool:
    return bool(TRACKED_PATTERNS.search(path))


# T8 (AC3, AC4): deterministic artefact-class for edit events, derived purely
# from string-matching the file_path. No inference/similarity/semantic checks.
_CODE_EXTS = (
    ".py", ".sh", ".js", ".ts", ".json", ".yml", ".yaml", ".toml",
)


def classify_artefact(path: str) -> str:
    """Classify a file_path into a stable artefact class via deterministic
    path-string matching only."""
    name = path.rsplit("/", 1)[-1]
    if name == "proposal.md":
        return "spec"
    if name == "tasks.md":
        return "plan"
    if name in ("initiatives.md", "initiatives-archive.md"):
        return "registry"
    if "/memory/" in path or path.startswith("memory/"):
        return "memory"
    if name in ("ideation.md", "purpose.md"):
        return "memory"
    if "/docs/" in path or path.startswith("docs/"):
        return "docs"
    if name.upper().startswith("README") or name.upper().startswith("CHANGELOG"):
        return "docs"
    if name.endswith(_CODE_EXTS):
        return "code"
    return "other"


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
    artefact_class=None,
) -> None:
    """Emit the AC17 schema line: {ts, session, event, detail, slug, agent_id, agent_type}.

    T8 (AC3, AC4): optional additive `artefact_class` field, only populated for
    edit events; all other callers/consumers of the original seven fields are
    unaffected.
    """
    record = {
        "ts": ts,
        "session": session,
        "event": event,
        "detail": truncate(detail),
        "slug": slug,
        "agent_id": agent_id,
        "agent_type": agent_type,
    }
    if artefact_class is not None:
        record["artefact_class"] = artefact_class
    append_jsonl(log_file, record)


def handle_post_tool_use(event: dict, log_file: Path, slug: str) -> None:
    tool = event.get("tool_name", "")
    inp = event.get("tool_input", {}) or {}
    ts = utc_now()
    session = short_session(event.get("session_id", ""))
    # AC17: read attribution fields null-safely; absent/null → None (emitted as JSON null)
    agent_id = event.get("agent_id") or None
    agent_type = event.get("agent_type") or None

    if tool == "Read":
        # Read-only access to a tracked path: distinct discriminator so read-only
        # agents are never conflated with mutations (event="read").
        file_path = inp.get("file_path", "")
        if not is_tracked_path(file_path):
            return
        emit(log_file, ts, session, "read", file_path, slug, agent_id, agent_type)

    elif tool in ("Write", "Edit"):
        # Mutation of a tracked path (event="edit").
        file_path = inp.get("file_path", "")
        if not is_tracked_path(file_path):
            return
        emit(
            log_file, ts, session, "edit", file_path, slug, agent_id, agent_type,
            artefact_class=classify_artefact(file_path),
        )

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

    # Slug only from this session's marker; no slug means no event
    slug = read_marker(event.get("session_id", "")).get("slug", "")
    if not slug:
        return

    # Shared root from the hook cwd; None is a no-op (INV10)
    root = get_project_root(event.get("cwd", ""))
    if root is None:
        return

    # Per-initiative destination
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
