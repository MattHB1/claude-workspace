#!/usr/bin/env python3
"""SessionStart hook — records session_id and start time for cost tracking."""
import json
import os
import sys
from datetime import datetime, timezone

try:
    data = json.loads(sys.stdin.read())
    session_id = data.get("session_id", "unknown")
    cwd = data.get("cwd", os.getcwd())

    session_dir = os.path.expanduser("~/.claude/sessions")
    os.makedirs(session_dir, exist_ok=True)

    path = os.path.join(session_dir, f"{session_id}.json")
    if not os.path.exists(path):
        with open(path, "w") as f:
            json.dump({
                "session_id": session_id,
                "start_time": datetime.now(timezone.utc).isoformat(),
                "cwd": cwd,
            }, f)
except Exception:
    pass
