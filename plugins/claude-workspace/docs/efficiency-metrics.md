# Efficiency metrics

These greps count what the journal and `events.jsonl` already record. They are not a step in the flow. The orchestrator does not run them unless you ask. Substitute the initiative slug.

**Metric 2 — Dispatches per task** (`events.jsonl` `agent` events):

```sh
grep '"event": *"agent"' .workspace/<slug>/memory/events.jsonl | wc -l
```

Counts Agent-dispatch lines. Bound by `ts` range, or by the task's journal `refs` and timestamp, to scope one task.

**Metric 3 — Gate pass/fail per task** (`journal.md` `outcome`):

```sh
grep -E '^outcome:' .workspace/<slug>/memory/journal.md
```

**Metric 4 — Retry count per task:**

```sh
grep -cE '^outcome: (fail|retry)' .workspace/<slug>/memory/journal.md
```

**Metric 4b — Steering effort.** Verifier entries only, and `fail` only. Each FAIL routes back to the generator.

```sh
grep -B4 -E '^outcome: fail' .workspace/<slug>/memory/journal.md | grep -c '^role: implementation-verifier'
```

There is no count of mid-task user corrections. No signal for that exists.

`git-push` and `pr-create` are written by the orchestrator after a task passes verification, and only when the `y/n` answer is "y". This describes interactive mode. In headless mode, no `y/n` prompt exists. See [docs/headless.md](./headless.md).

**Metric 5 — Git push count:**

```sh
grep -c '"event": *"git-push"' .workspace/<slug>/memory/events.jsonl
```

**Metric 5b — PR create count:**

```sh
grep -c '"event": *"pr-create"' .workspace/<slug>/memory/events.jsonl
```

Per-task wall-clock duration and per-task token counts are not derivable from these files. The Admin API reports per session and date, not per task. No recipe is given for them.

Metric 1 (a task-risk tier) was removed in 1.23.0. The numbers above were left as they were.
