# Reference task (fixed, re-runnable)

## 1. Purpose

A single fixed pipeline exercise, re-run under successive pipeline versions, to sense
same-task deltas in operator-felt friction (waiting/rework/steering). It exists for
directional reassurance and regression-catching, NOT as a causal gate. This is ONE task —
explicitly NOT a multi-task bench.

## 2. Fixed prompt (FROZEN — do not edit)

Run the following, verbatim, through the full workspace pipeline (propose → check → plan →
build → verify):

> Add one new deterministic efficiency-metric grep recipe (Metric 6 — "PR merge count", i.e.
> a count of `gh pr merge` events found in `events.jsonl`) to SKILL.md's efficiency-metric
> recipes section, with its one-line grep and a short description, following the exact
> pattern of Metrics 1–5.

This is a small, self-contained, single-file, single-write-target task chosen to be cheap
to run and to minimize run-to-run variance while still exercising the pipeline end-to-end.
Changing this prompt invalidates cross-version comparison — if the prompt ever needs to
change, that is a new reference task, not an edit to this one.

## 3. Fixed repo baseline

Each run starts from a NAMED baseline: a specific git commit/tag of this repo, checked out
clean.

**Initial baseline (recorded 2026-08-04):**
- Nearest tag: `v1.13.0`
- Full commit: `cff9c91772596bcd8120f7b2105880a3ad3fc71b`

Rule: run from a clean checkout of the named baseline for that pipeline version; after
measuring, discard changes — the reference task's edits are never committed. Update the
recorded baseline here only when the team deliberately re-pins to a new starting point
(e.g. after a major pipeline change makes the old baseline stale); each re-pin should record
both the new tag and full commit alongside the version it applies to.

## 4. Run-home (reuse, no new machinery)

Runs are executed inside a dedicated initiative slug — suggested slug `benchmark-run`. All
run telemetry is captured by that slug's EXISTING per-initiative `journal.md` and
`events.jsonl`. There is:
- NO new run-log file
- NO new format
- NO new script

The captured signals are exactly what the existing pipeline already produces: the felt
self-rating (recorded once at teardown), the artefact-classed edit-churn, and the verifier's
`outcome:` field.

## 5. What to compare across runs

Eyeball the following deterministic signals run-over-run:
- Felt waiting / rework / steering (self-rating at teardown)
- Code-class edit-churn (from classed events)
- Verifier fail count / steering (FAIL-routes recorded in the trace)
- Agent-dispatch count

Caveat: a single run is high-variance and this comparison is directional only, not a
statistical claim. Per H2's own falsification test, run the reference task twice under one
pipeline version first to gauge run-to-run variance before trusting any cross-version delta.
