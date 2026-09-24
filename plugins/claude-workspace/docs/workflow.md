# Workflow

This page describes the day-to-day workflow of the Claude Workspace plugin: how
your natural-language intent is routed to a specialist agent, the typical stage
flow of an initiative, and the principle that you **invoke only what you need**.

When the orchestrator skill is active, **you talk to the orchestrator**. You do
not call agents by name. You say what you want in plain language, and the
orchestrator routes that intent to exactly one single-responsibility agent,
dispatched as `claude-workspace:<agent>` in a fresh, isolated context. The agents
are namespaced under the plugin and appear under those names in `/agents`, but you
normally never type them yourself.

See also: [concepts.md](concepts.md) for the vocabulary, [initiatives.md](initiatives.md)
for managing initiatives, and [design-principles.md](design-principles.md) for the
rules that make the routing trustworthy.

---

## Intent to agent (you say X, the orchestrator dispatches `claude-workspace:<agent>`)

There are exactly eight agents. Each does one thing. The trigger phrases below
match the orchestrator's routing table.

| You say... | Orchestrator dispatches | Model | Which... |
|---|---|---|---|
| "research / look into / what's known about..." | `claude-workspace:research-harvester` | sonnet | gathers prior art and risks (read + web only); the orchestrator saves its brief into the active initiative's `research/` |
| "spec it / write the proposal / define the problem" | `claude-workspace:proposal-writer` | opus | writes the active initiative's `proposal.md` (its root of truth) |
| "plan it / break it down / make tasks" | `claude-workspace:task-planner` | opus | decomposes the proposal into atomic tasks in `tasks.md` |
| "check the plan / does the plan match the spec" | `claude-workspace:task-checker` | opus | read-only adversary; checks tasks against the proposal (detect-only); the orchestrator saves its report into `verification/` |
| "build / implement / do task N" | `claude-workspace:implementer` | sonnet | implements exactly one task per dispatch in a fresh session; writes the code itself |
| "verify / does it match the task" | `claude-workspace:implementation-verifier` | opus | read + run-tests only; adversarially checks the build against the task; the orchestrator saves its report into `verification/` |
| "where are we / I've lost the thread / re-sync" | `claude-workspace:context-recovery` | sonnet | read-only; rebuilds state from the artefacts and memory; the orchestrator persists the result to the active initiative's memory |
| "tidy / organise / move these files" | `claude-workspace:archivist` | haiku | moves and organises files (never edits content); the orchestrator records its map to the project-level `file-structure.md` |

Models use bare aliases (opus / sonnet / haiku); for the full mapping, override instructions, graceful degradation, and advanced levers see [install.md](install.md).

The five read-only agents (`research-harvester`, `task-checker`,
`implementation-verifier`, `context-recovery`, `archivist`) cannot write the
canonical artefacts - that is by design. When they return, the orchestrator
persists their output to the right path. The three generators
(`proposal-writer`, `task-planner`, `implementer`) write their own outputs to the
paths the orchestrator supplies.

---

## Initiative verbs (orchestrator actions, not agent dispatches)

Three conversational verbs manage initiatives. These act directly on the registry
(`.workspace/initiatives.md`) and the per-initiative `<slug>/` subfolders - none
of them dispatches a subagent or introduces a new agent. The verbs are exactly
**create / switch / list**; there is no built-in delete or rename (see
[initiatives.md](initiatives.md)).

| You say... | What happens |
|---|---|
| "new initiative <name>" / "start a new initiative" | creates `.workspace/<slug>/`, adds a registry entry, and marks it active (demoting whichever was previously active) |
| "switch to <name>" / "make <name> active" / "work on <name>" | moves the ACTIVE marker in the registry to that initiative; no files move |
| "list initiatives" / "what's in this workspace" | reports every initiative's slug, one-line description, and status from the registry, highlighting the active one |

Whenever at least one initiative exists, exactly one is ACTIVE. The orchestrator
resolves the active initiative's paths and hands them to each agent; the agents
themselves stay path-agnostic.

---

## From ticket to pull request (orchestrator actions)

The create verb takes a **ticket identifier**, and that identifier is used as the
initiative slug; a numeric slug is valid. The orchestrator reads the ticket with
a tracker tool when one is available, and otherwise asks you to paste the ticket
text. The ticket text is saved as a file under the initiative's `research/`.

The branch is resolved at create time, from one of two sources and no other: the
branch name the tracker supplies, or the initiative slug when the tracker
supplies none. No branch name is derived from the ticket title or any other
guess.

Branch, commit, push, and open-PR are **orchestrator actions**. No agent performs
a git action, and git is never an agent's write-target. These ride the existing
flow points and add no new stage and no extra dispatch:

| Moment | What the orchestrator does |
|---|---|
| create the initiative | resolves the branch name and creates the branch |
| after a task passes verification | commits, with no prompt |
| after that commit | asks `push <branch> to origin? y/n`, and pushes only on "y" |
| after the push | asks `open a PR for <branch>? y/n`, and opens it only on "y" |

Push and opening a pull request leave your machine and are visible to your team,
so each is always asked for first.

Tracker write-back fires at exactly **two** moments: when work starts, and when
the pull request is opened (the handoff). Each is a one-line `y/n` prompt, in the
same style as the registry-consolidation prompt, and each writes to the tracker
only on "y". There is no third moment, and no tracker write happens without a
"y".

The plugin hardcodes no state name. The real states are read from your tracker
the first time a write-back prompt fires in a project; you choose which state
each of the two moments maps to, and the answers are recorded in the
project-level `.workspace/tracker-states` file. Every later prompt and every
later ticket reads that file, so you are not asked again.

When no tracker tool is available, every tracker step is skipped silently - no
prompt, no notice, no error - and the verb completes exactly as it would without
the step.

The authoritative rules live in the orchestrator skill (`SKILL.md`, "Git actions"
and "Tracker write-back").

---

## Exiting the workspace

There is no "kill switch" command, because the orchestrator is not a running
process - it is this skill's instructions loaded into the conversation. It stays
in effect until the conversation context itself is cleared, which only **you** can
do. To leave cleanly:

1. Say **"exit the workspace"** (or "I'm done", "stop orchestrating"). The
   orchestrator runs a mandatory teardown of the active initiative - appends a
   journal entry and refreshes the index - then confirms it is safe to leave.
2. Type **`/clear`** to fully drop the orchestrator (a fresh conversation), or
   **`/compact`** to keep a summary. This is the step that actually exits.

Nothing is lost. All workspace state lives in the git-controlled `.workspace/`
tree, and the ACTIVE marker is left untouched - so the next time you invoke the
workspace skill it re-bootstraps the same initiative from the registry, memory
index, and journal tail, and you pick up where you left off.

---

## The plan-to-build `/clear` nudge

The orchestrator offers the same fresh-start reminder at one more point: the
first time it is about to dispatch `claude-workspace:implementer` for the
active initiative after the plan is complete (for example, you say "build it"
or "do task 1" once `tasks.md` exists). This fires once, at that handoff, not
before every task.

The nudge is age-gated, the same way the create/switch/exit reminders are: it
checks how long the current session has been running and only speaks up past
a threshold (2 hours by default). Below that threshold, or if the session age
cannot be read, the orchestrator stays silent and dispatches the implementer
as normal.

When it does fire, the orchestrator tells you that a fresh start can cut cost
with no loss - the proposal and plan are already saved to disk, so clearing
now drops proposal/planning context the build phase does not need. You can
type `/clear` (fresh start) or `/compact` (keeps a summary), then re-invoke
the workspace skill to land back in the same initiative, picking up at the
build step. This is advisory only - the orchestrator cannot clear context
itself.

---

## The typical stage flow

A full initiative tends to move through these stages:

```
new initiative
   |
   v
research        ->  claude-workspace:research-harvester
   |
   v
spec            ->  claude-workspace:proposal-writer
   |
   v
plan            ->  claude-workspace:task-planner
   |
   v
check           ->  claude-workspace:task-checker        (gate before building)
   |
   v
build           ->  claude-workspace:implementer         (one task per dispatch)
   |
   v
verify          ->  claude-workspace:implementation-verifier  (gate after each task)
```

Build and verify usually repeat per task: build one task, verify it, then move to
the next. The orchestrator prefers running `task-checker` after planning and
`implementation-verifier` after each task, surfacing the gate and letting you
decide to proceed or skip.

When an adversarial checker FAILs something, the correction routes **back to the
generator** - a failed plan returns to `task-planner`, a failed implementation
returns to `implementer`. The checker never fixes, and neither does the
orchestrator (see [design-principles.md](design-principles.md) and
[why-it-refuses.md](why-it-refuses.md)).

Lean is the single default flow for every initiative: propose -> check the
proposal -> plan into tasks -> build -> check each build. There is no
complexity-tiering and no separate fast-track lane - every initiative gets
this same flow unless you deliberately escalate (for example, asking for
deeper research or extra scrutiny on a task that warrants it). The
authoritative rules live in the orchestrator skill (`SKILL.md`, "Flow - lean
by default").

---

## Invoke only what you need (no forced sequence)

The stage flow above is the typical path, **not a rigid sequence**. The workflow
is optional and conversational: you invoke only what you need. The orchestrator
follows your flow and does not force every stage.

- You do not have to run every stage. If you already have a proposal, say "plan
  it" and skip research. If you just want to know where things stand, say "where
  are we" and the orchestrator dispatches `claude-workspace:context-recovery`
  without touching anything else.
- The orchestrator does not restart the pipeline from the top each turn. It reads
  the active initiative's state, then acts on what you ask next.
- It keeps you in the loop at each handoff with a one-line status (for example
  "proposal updated -> want me to plan it, or review it first?") and lets your
  reply pick the next move.

In short: describe the next thing you want, and the orchestrator dispatches the
single right agent for it. The stages are a map, not a track.
