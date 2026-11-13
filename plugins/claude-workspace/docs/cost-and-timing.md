# Cost, timing, and prompt caching

This page is reference. The orchestrator does not act on it during a task.

## What the session hooks can and cannot attribute

`log-session-cost.py` (Stop) and `record-session-start.py` (SessionStart) are per session and per date. They are not per task and not per initiative.

- `log-session-cost.py` calls the Anthropic Admin API. The API buckets usage by session and date. Cost cannot be attributed to a task or an initiative. The script writes `$CLAUDE_PROJECT_DIR/agentic/cost-log.md` (from `$CLAUDE_PROJECT_DIR`, not the working directory and not a home-path fallback). It does not write `events.jsonl`. With no `ANTHROPIC_ADMIN_KEY` it writes nothing and raises no error.
- `record-session-start.py` writes the session start to `~/.claude/sessions/`. Pair it with the Stop event for a session duration only.
- `events.jsonl` is the per-initiative event trace. `cost-log.md` is the per-session cost ledger. Do not treat them as one file.

The greps that count dispatches, outcomes, pushes, and pull requests are in [efficiency-metrics.md](efficiency-metrics.md).

## Prompt caching

The SDK's default prompt-caching TTL is 5 minutes. Leave that default. Do not enable the 1-hour tier. If rate-limit pressure grows, revisit the setting then. Make no code change as part of ordinary work.
