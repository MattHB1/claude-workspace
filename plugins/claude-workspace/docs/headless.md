# Headless mode

Headless mode lets an unattended runner take one tracker ticket to a pull request with nobody present. The skill never waits for a human. At each point that would wait, it decides, or it stops as `blocked` or `failed`. The full rules are in `skills/workspace/headless.md`. This page is for the person who writes the runner.

With `WORKSPACE_HEADLESS` unset, the skill behaves as in the interactive workflow.

## Environment variables

| Variable | Default | Meaning |
|---|---|---|
| `WORKSPACE_HEADLESS` | unset | Set to `1` to turn headless on. Any other value, or no value, means interactive. |
| `WORKSPACE_TICKET` | none | The ticket id. Required when headless is on. |
| `WORKSPACE_TICKET_FILE` | unset | Path to the ticket text. The skill uses it only when it cannot read the tracker. |
| `WORKSPACE_MAX_MINUTES` | 60 | Time bound. A breach gives `failed` (`time_limit`). |
| `WORKSPACE_MAX_IMPL_RETRIES` | 1 | Build retries. The range is 0 to 1. A higher value becomes 1. A breach gives `failed` (`build_check_failed`). |
| `WORKSPACE_MAX_TASKS` | 10 | Task limit. More tasks after planning gives `failed` (`task_limit`). |
| `WORKSPACE_PR_DRAFT` | on | The PR opens as a draft. Set to `0` for a normal PR. |

A bound that is not a number, or is negative, gives `failed` (`invalid_bound`). A missing `WORKSPACE_TICKET` gives `failed` (`no_ticket`).

## Run command

```
WORKSPACE_HEADLESS=1 WORKSPACE_TICKET=POC-1234 claude -p "/claude-workspace:workspace POC-1234"
```

The skill skips the initiative pick. If the ticket is already in the registry, it resumes that initiative. If not, it creates one. The run ends at a pull request, or at a stop.

## Statuses

| Status | Meaning |
|---|---|
| `running` | The run started. It has not finished. |
| `pr_opened` | The PR is open. |
| `blocked` | The run needs a human answer. No PR is open. |
| `failed` | The run cannot go on. |

The skill writes `.workspace/<slug>/run-summary.json` after the pick, with status `running`. It overwrites the file when the run ends. The schema is `docs/run-summary.schema.json`.

## Result lines

The last line on stdout is always `WORKSPACE_RESULT: <status>`.

A failure before the summary exists writes no `run-summary.json`. Examples are a bad environment, a failed preflight, and a ticket mismatch. In this case the skill prints `WORKSPACE_FAILURE: <code>`, then `WORKSPACE_RESULT: failed` as the last line.

A missing summary means `failed`. A summary still at `running` also means `failed`: the run crashed or was killed.

## Exit codes

The skill cannot set the exit code of `claude -p`. The runner maps the status to an exit code.

| Status | Exit code |
|---|---|
| `pr_opened` | 0 |
| `blocked` | 2 |
| `failed` | 1 |
| `running` | 1 |

## Codes

The file [run-summary.schema.json](run-summary.schema.json) holds the closed list of `failed` and `blocked` codes, and the skill file `skills/workspace/headless.md` says when each code fires.

## Blocked stop and resume

A blocked run does these steps:

1. It records the judge rulings in `decisions.md`.
2. It commits the work on disk to the run branch as `wip(headless): blocked — <code> [unverified]`, and pushes. It opens no PR.
3. It adds one comment and the label `auto-fix-blocked` to the ticket, through the tracker tool. The comment holds each question, why it needs a human, a suggested default, and the branch name. If no tracker tool exists, the summary shows `tracker_note_written: false`, and the runner passes the note on.
4. It writes `run-summary.json` with status `blocked`, tears down, prints `WORKSPACE_RESULT: blocked`, and ends.

To resume, a human answers on the ticket. Then the runner starts a new run with the same ticket. The run takes the resume path. It reads the ticket again, comments included, and passes the latest human reply to the proposal writer as a dated answer.

## Hard kill

The skill checks the time bound only at handoff lines and before each dispatch. A long step can pass the bound with no check. The runner must also enforce a hard kill (a timeout on the `claude -p` process). A killed run leaves the summary at `running`, or leaves no summary. The runner treats both as `failed`.
