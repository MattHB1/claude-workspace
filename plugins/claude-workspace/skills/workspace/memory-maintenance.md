# Memory maintenance

Load this file at Bootstrap after the registry read, at a safe checkpoint, at session end, and when a guard or a consolidation runs. Do not load it on any other turn. Writers are the sole-writer table in SKILL.md. These steps add no agent and ask no question. A bound or a threshold trip is a note or a report line, then you continue.

## Journal and index

`journal.md` is append-only. You append. You do not edit or delete an entry in place. Consolidation appends a summary and moves detail to `archive/`.

Every entry has `timestamp` (ISO-8601), `role`, and `trust` (`verified` or `asserted`).

`outcome` (`pass`, `fail`, or `retry`) is mandatory on every `implementation-verifier` and `task-checker` entry, including a caught error. On any other entry it is optional. An old entry without it stays valid.

`refs` holds paths and anchors, including a PR URL. Do not add a frontmatter field for a PR. Do not copy the artefact into the entry. Do not write `tier`. An old `tier` line stays. Leave it.

```markdown
---
timestamp: 2026-06-18T14:30:00Z
role: implementation-verifier
trust: verified
outcome: pass
refs:
  - .workspace/<slug>/tasks.md#T4
---
T4 passed verification.
```

`index.md` is overwritten, not appended. Pointers and short summaries only. It is not a database. Rebuild it from `journal.md` (entries and `refs`) plus `proposal.md`, `tasks.md`, and `verification/`. Where those disagree with memory, the artefact wins.

Retrieval is by path, filename, or `grep`/`glob`. No similarity search.

Do not commit `events.jsonl` or `agentic/cost-log.md`. `journal.md` and `index.md` stay tracked. The git-ignore deviation, the cost note, and the metric recipes are in `docs/memory.md`, `docs/cost-and-timing.md`, and `docs/efficiency-metrics.md`. You do not run those recipes as part of the flow.

## Safe checkpoint and teardown

A **safe checkpoint** is the moment after a task passes verification. Also run teardown at session end (Exit). Not at other moments.

At those two moments: append a journal entry for what was done or decided, and overwrite the index. Then run every guard row below whose When column names this moment. State has to be on disk before you continue, so a reset loses nothing.

## Guard table

Run only the rows whose When column names the moment you are in. Create, Switch, Bootstrap, and Teardown each say "run the guard rows that name this moment." Do not restate a row there. Thresholds are starting points: do not lower one from a guess. Measure first.

| Check | When | What |
|---|---|---|
| Registry consolidation | Bootstrap (as soon as `initiatives.md` is read), Teardown | `wc -c` on `.workspace/initiatives.md` against **~10–12 KB**. At or over: run the procedure below, then `registry consolidated: was N KB, now M KB`. |
| Index-bloat | Bootstrap (after `index.md` is read), Teardown (after the refresh), Switch, Create | `wc -c` on `.workspace/<slug>/memory/index.md` against **~10–15 KB**. At or over: rebuild the index lean from its sources, then `index re-derived lean: was N KB, now M KB`. Do not archive the index. |
| Epic | Teardown, Switch, Create | `grep -c '^timestamp:'` on `journal.md` against **~30**. At or over: `this initiative has grown to N — it may be Epic-sized; consider splitting into tighter initiatives`. No `y/n`. Do not split, create, or switch on your own. |
| Repeated-FAIL | Bootstrap (after the journal tail is read), Teardown | `grep -cE '^outcome: fail'` on `journal.md` against **3**. At or over: `this initiative has N outcome: fail entries — check for a task looping between generator and verifier instead of a single fix-and-recheck pass`. No `y/n`. Do not fix or re-route. |

None of the four blocks or delays the moment that ran it. On Create the index is empty and the journal has no entries, so index-bloat and epic do not trip. Run them anyway.

## Consolidation

You own it. Journal and `events.jsonl` each consolidate when teardown runs or the file is over **500 KB** (`wc -c`). One policy, both files. Append a summary entry to the live journal and `mv` the superseded detail to `.workspace/<slug>/memory/archive/`. Do not delete unique information. Do not rewrite an old entry. `archivist` may do the `mv` and may not edit content. A git-ignored `events.jsonl` has no git recovery. The 500 KB bound still applies. Note that and continue.

**Registry procedure**, when the registry row trips:

1. Move completed or superseded detail from `initiatives.md` into `initiatives-archive.md`.
2. Leave that row's status cell short.
3. Keep open-initiative rows and the project-level names (`file-structure.md`, `namespaces`, `tracker-states`).
4. Every slug that was in the table is still a row, and the slug is still the first backtick-wrapped cell (SKILL.md). If either check fails, fix the row before you report the line.
