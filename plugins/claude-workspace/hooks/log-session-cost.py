#!/usr/bin/env python3
"""Stop hook — fetches session cost from Anthropic Admin API and upserts agentic/cost-log.md.

To enable: set ANTHROPIC_ADMIN_KEY=sk-ant-admin-... in your shell environment.
While unset the hook exits silently without writing anything.

Admin API endpoint (may need updating if Anthropic changes the path):
  GET https://api.anthropic.com/v1/organizations/usage_report/messages
"""
import json
import os
import sys
import urllib.request
from datetime import datetime, timezone

ADMIN_KEY = os.environ.get("ANTHROPIC_ADMIN_KEY", "")
SESSION_DIR = os.path.expanduser("~/.claude/sessions")
ERROR_LOG = os.path.join(SESSION_DIR, "cost-hook-errors.log")

# Pricing per million tokens (claude-sonnet-4-6 defaults — update as needed)
PRICE_INPUT = 3.0
PRICE_OUTPUT = 15.0
PRICE_CACHE_READ = 0.30
PRICE_CACHE_WRITE = 3.75

ADMIN_API_URL = "https://api.anthropic.com/v1/organizations/usage_report/messages"


def log_error(msg):
    try:
        with open(ERROR_LOG, "a") as f:
            f.write(f"[{datetime.now(timezone.utc).isoformat()}] {msg}\n")
    except Exception:
        pass


def main():
    if not ADMIN_KEY:
        return  # Disabled — add ANTHROPIC_ADMIN_KEY to your env to enable

    project_root = os.environ.get("CLAUDE_PROJECT_DIR", "")
    if not project_root:
        return  # $CLAUDE_PROJECT_DIR unset — no-op

    try:
        data = json.loads(sys.stdin.read())
        session_id = data.get("session_id", "unknown")
    except Exception as e:
        log_error(f"Failed to parse hook input: {e}")
        return

    session_file = os.path.join(SESSION_DIR, f"{session_id}.json")
    try:
        with open(session_file) as f:
            session_data = json.load(f)
        start_time = session_data["start_time"]
    except Exception as e:
        log_error(f"Could not read session file {session_file}: {e}")
        return

    end_time = datetime.now(timezone.utc).isoformat()
    date_str = datetime.now(timezone.utc).strftime("%Y-%m-%d")

    try:
        url = f"{ADMIN_API_URL}?start_time={start_time}&end_time={end_time}&time_bucket=1d"
        req = urllib.request.Request(url, headers={
            "x-api-key": ADMIN_KEY,
            "anthropic-version": "2023-06-01",
        })
        with urllib.request.urlopen(req, timeout=10) as resp:
            result = json.loads(resp.read())
    except Exception as e:
        log_error(f"Admin API request failed: {e}")
        return

    input_tokens = 0
    output_tokens = 0
    cache_read = 0
    cache_write = 0
    for bucket in result.get("data", []):
        input_tokens += bucket.get("input_tokens", 0)
        output_tokens += bucket.get("output_tokens", 0)
        cache_read += bucket.get("cache_read_input_tokens", 0)
        cache_write += bucket.get("cache_creation_input_tokens", 0)

    cost = (
        input_tokens * PRICE_INPUT / 1_000_000
        + output_tokens * PRICE_OUTPUT / 1_000_000
        + cache_read * PRICE_CACHE_READ / 1_000_000
        + cache_write * PRICE_CACHE_WRITE / 1_000_000
    )

    short_id = session_id[:8]
    new_row = (
        f"| {short_id} | {date_str} | {input_tokens:,} | {output_tokens:,} "
        f"| {cache_read:,} | {cache_write:,} | ${cost:.4f} |\n"
    )

    log_path = os.path.join(project_root, "agentic", "cost-log.md")
    header = (
        "# Session Cost Log\n\n"
        "| Session | Date | Input tokens | Output tokens | Cache read | Cache write | Est. cost (USD) |\n"
        "|---|---|---|---|---|---|---|\n"
    )

    try:
        os.makedirs(os.path.dirname(log_path), exist_ok=True)
        if os.path.exists(log_path):
            with open(log_path) as f:
                lines = f.readlines()
            updated = False
            new_lines = []
            for line in lines:
                if line.startswith(f"| {short_id} "):
                    new_lines.append(new_row)
                    updated = True
                else:
                    new_lines.append(line)
            if not updated:
                new_lines.append(new_row)
            with open(log_path, "w") as f:
                f.writelines(new_lines)
        else:
            with open(log_path, "w") as f:
                f.write(header + new_row)
    except Exception as e:
        log_error(f"Failed to write cost log at {log_path}: {e}")


main()
