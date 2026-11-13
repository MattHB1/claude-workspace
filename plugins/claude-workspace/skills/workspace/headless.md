# Headless mode

Load this file when Step 0 runs `headless-env.sh` and it prints `HEADLESS=1`. Do not load it on any other turn. In headless mode this file overrides every prompt and stop that `SKILL.md`, `session-and-git.md` and `memory-maintenance.md` name. Nobody is present. Every point that waits for a human has an outcome here: decide, or stop as `blocked` or `failed`. With `HEADLESS=0`, none of this applies.

`<base>` and `<root>` are as in `session-and-git.md`. Scripts are `<base>/../../scripts/`. Run each as its own Bash call. Never merge, release, tag, close, or move a ticket to Done. Never use `--force`.

## Step 0

1. Run `bash "<base>/../../scripts/headless-env.sh"`. Read its output. Do not parse env yourself. Output is `KEY=value` lines (`HEADLESS`, `TICKET`, `MAX_MINUTES`, `MAX_IMPL_RETRIES`, `MAX_TASKS`) or one `ERROR: <code>` line. On `ERROR`, it is a pre-pick failure (below).
2. If the id in the prompt differs from `TICKET`, fail with `ticket_mismatch`. A `--headless` flag is a hint only. A flag without the env var runs interactively.
3. Run `bash "<base>/../../scripts/headless-preflight.sh" "<root>"`. Read its output: `OK` or `ERROR: <code>`. On `ERROR`, it is a pre-pick failure.
4. Do the initiative pick by ticket id. Show no list. Wait for no choice. The slug is the ticket id. Slug in `initiatives.md`: Switch (resume). Slug not there: Create.
5. Run the session pick check as in `session-and-git.md` › Session pick. Write the marker. Write `run-summary.json` with `status: running` (below).

## Ticket input

Create reads the ticket through the tracker tool into `research/ticket.md`. Use `WORKSPACE_TICKET_FILE` (a path to ticket text) only when the tracker read is impossible. Do not paste the ticket and do not ask for it. No tracker tool and no `WORKSPACE_TICKET_FILE`, or a failed read: fail with `no_ticket_text`.

## The 20 sites

Each row is a `file › section` site. Code is the `failed` or `blocked` code.

| # | Site | Headless outcome |
|---|---|---|
| 1 | `SKILL.md` › Memory read | Step 0 above: env script, preflight, then Create or Switch by ticket id |
| 2 | `session-and-git.md` › Create, tracker read or "paste the ticket" | `WORKSPACE_TICKET_FILE`, else `failed` `no_ticket_text` |
| 3 | `session-and-git.md` › Session pick, `NO-ROOT` | `failed` `no_root` |
| 4 | same, `BLOCK same-initiative`, `BLOCK one-session`, stale marker | `failed` `concurrent_run`. Print the other marker's path on its own line before `WORKSPACE_FAILURE: concurrent_run`; the `WORKSPACE_FAILURE` line carries the code only. Never delete another session's marker |
| 5 | `session-and-git.md` › Worktree and branch start, step 1 | Always a worktree at `<root>/.claude/worktrees/<slug>`. Main-allowed repo: `failed` `main_allowed_repo` |
| 6 | same, step 3, `NO-DEFAULT`, `FETCH-FAILED`, no fetch, origin has no default | `failed`: `no_default_branch`, `fetch_failed`, or `no_origin`. Never continue from a local default |
| 7 | same, steps 5 and 6, git refuses the worktree or branch | `failed` `worktree_refused` |
| 8 | `session-and-git.md` › Merge check, step 4 | Preset `n`. Remove nothing. List merged worktrees in `notes` |
| 9 | `SKILL.md` › Git prompts, Flow step 5, push | Preset `y`. A push failure: `failed` `push_failed` |
| 10 | `session-and-git.md` › PR body decisions | Preset `y`. See Presets |
| 11 | `session-and-git.md` › Tracker write-back | Preset `y`. See Presets |
| 12 | `SKILL.md` › Decide, do not ask, ASK_USER | Blocked stop, `blocked` `needs_human`. All ASK_USER items of the batch go in one note |
| 13 | same, out-of-scope problem | Never blocks. Log and defer. List in `follow_ups`. Raise no ticket |
| 14 | `SKILL.md` › Hard Rule 5, third proposal-check FAIL | Blocked stop, `blocked` `proposal_check_limit`. Open findings go in the note |
| 15 | `SKILL.md` › Flow step 4, second implementer STOP on one task | Blocked stop, `blocked` `implementer_stop`. The STOP report goes in the note |
| 16 | same, judge output fails to parse twice | `failed` `judge_error` |
| 17 | Hard Rule 5, build re-check still FAILs after the one fix | `failed` `build_check_failed` |
| 18 | `SKILL.md` › Ticket fix check, `quality check not run` twice | `failed` `quality_check_unavailable` |
| 19 | `SKILL.md` › Session-age nudge, advisory guard rows in `memory-maintenance.md` | Silent. Guard trips go in `notes` as guard trips |
| 20 | `session-and-git.md` › Exit | Teardown runs on every exit |

An environment stop is any stop in the table that names an environment fault (sites 3 to 7). It is `failed` with the code in its row. Do not wait for a human. Do not invent a code.

## Presets

- Merge check: `n`. Remove nothing.
- Push: `y`. Run `git push` for the run branch.
- PR: `y`. Run `gh pr create` with the `## Decisions` body and a `Headless run` footer. Open it as a draft. Set `WORKSPACE_PR_DRAFT=0` to open it ready. A `gh` failure: `failed` `pr_failed`.
- Tracker write-back: `y` when `tracker-states` exists. Without a mapping, skip the write and add `tracker_mapping_missing` to `notes`. Never guess state names. This code is a note, not a failure. No tracker tool: skip silently.

## Blocked stop

Use for ASK_USER (site 12) and sites 14 and 15.

1. Append the rulings to `decisions.md` with `User: blocked — awaiting ticket reply`.
2. Commit work on disk as `wip(headless): blocked — <code> [unverified]`. Then push. Hard Rule 6 allows it. Open no PR.
3. Through the tracker tool, add one comment and the label `auto-fix-blocked`. The comment holds each question, why it needs a human, the suggested default, and the branch name. No tracker tool: `tracker_note_written: false`.
4. Write `run-summary.json` with `status: blocked`. Run teardown. Print `WORKSPACE_RESULT: blocked` as the last line. End the turn.
5. Resume: a later run with the same ticket takes the Switch path. Re-read the ticket, comments included, into `research/ticket.md`. Pass the latest human reply to `proposal-writer` as a dated answer (Hard Rule 3, line-only change).

## Bounds

`headless-env.sh` validates these.

| Var | Default | Breach |
|---|---|---|
| `WORKSPACE_MAX_MINUTES` | 60 | `failed` `time_limit` |
| `WORKSPACE_MAX_IMPL_RETRIES` | 1 (range 0 to 1) | `failed` `build_check_failed` |
| `WORKSPACE_MAX_TASKS` | 10 | after planning, `failed` `task_limit` |

Elapsed time: read `start_time` in `~/.claude/sessions/<id>.json` (written by `record-session-start.py`). If that file or field is missing, use `started_at` from `run-summary.json`. Check it at every handoff line and before each dispatch. On a breach: WIP commit and push, write the summary, teardown, end.

## Registry lock

Wrap each write to `<root>/.workspace/initiatives.md` in a lock: `mkdir <root>/.workspace/.registry.lock`. On success, write, then `rmdir` it. If `mkdir` fails, retry. Wait at most 30 s, then `failed` `registry_locked`.

## Run summary

You are the sole writer of `.workspace/<slug>/run-summary.json`. Plain JSON, no comments. The fields and enums are in `docs/run-summary.schema.json`. That file is the master copy of every code.

- At the pick: write it with `status: running`.
- At the end: overwrite it with the final status. Timestamps are UTC ISO-8601.
- `blocked_reason` is non-null only for `blocked`. `failure` is non-null only for `failed`.
- A summary that still shows `running` means the run crashed. The runner treats it as `failed`.
- A failure that happens before this run has written its own `running` summary writes no summary (for example `headless-env.sh` or preflight `ERROR`, `ticket_mismatch`, `no_ticket_text`, `concurrent_run`, `worktree_refused`, `registry_locked`). A run never overwrites another run's `run-summary.json`. Print `WORKSPACE_FAILURE: <code>`, then `WORKSPACE_RESULT: failed` as the last line.
- Every other end prints `WORKSPACE_RESULT: <status>` as the last line. `pr_opened` is the status when the PR is open.

## Teardown

Run teardown on every exit, whatever the status: `memory-maintenance.md` › Safe checkpoint and teardown. Write the summary first, then teardown, then print the final line. On a failure before the `running` write, teardown only deletes this session's marker if this run wrote one, and touches no initiative folder this run did not create.

## Closed code list

Use only these codes. A new code needs a change to the schema first.

- `failed`: `no_ticket`, `invalid_bound`, `ticket_mismatch`, `no_ticket_text`, `no_root`, `concurrent_run`, `main_allowed_repo`, `no_default_branch`, `fetch_failed`, `no_origin`, `worktree_refused`, `dirty_main`, `gh_unavailable`, `registry_locked`, `push_failed`, `pr_failed`, `judge_error`, `build_check_failed`, `quality_check_unavailable`, `time_limit`, `task_limit`
- `blocked`: `needs_human`, `proposal_check_limit`, `implementer_stop`

`tracker_mapping_missing` is a `notes` entry only. It is in neither list.
