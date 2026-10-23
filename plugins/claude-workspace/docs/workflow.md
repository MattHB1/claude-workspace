# Workflow

This page describes the day-to-day workflow of the Claude Workspace plugin. It
covers three things. First, how your plain-language request goes to a specialist agent.
Second, the typical stage flow of an initiative. Third, the rule that you
**invoke only what you need**.

When the orchestrator skill is on, **you talk to the orchestrator**. You do
not call agents by name. You say what you want in plain language. The
orchestrator sends that request to exactly one single-responsibility agent. It
dispatches the agent as `claude-workspace:<agent>` in a fresh, isolated context.
The agents carry the plugin name as a prefix and appear under those names in
`/agents`. You normally never type them yourself.

See also: [concepts.md](concepts.md) for the vocabulary, [initiatives.md](initiatives.md)
for managing initiatives, and [design-principles.md](design-principles.md) for the
rules that make the routing trustworthy.

---

## Intent to agent (you say X, the orchestrator dispatches `claude-workspace:<agent>`)

There are exactly eight agents. Each does one thing. The trigger phrases below
match the orchestrator's routing table.

| You say... | Orchestrator dispatches | Which... |
|---|---|---|
| "research / look into / what's known about..." | `claude-workspace:research-harvester` | gathers prior art and risks (read and web only); the orchestrator saves its brief into the picked initiative's `research/` |
| "spec it / write the proposal / define the problem" | `claude-workspace:proposal-writer` | writes the picked initiative's `proposal.md` (its root of truth) |
| "plan it / break it down / make tasks" | `claude-workspace:task-planner` | splits the proposal into atomic tasks in `tasks.md` |
| "check the proposal / is it valid and buildable" | `claude-workspace:task-checker` | read-only adversary; checks the proposal before planning (detect-only); the orchestrator saves its report into `verification/` |
| "build / implement / do task N" | `claude-workspace:implementer` | implements exactly one task per dispatch in a fresh session; writes the code itself |
| "verify / does it match the task" | `claude-workspace:implementation-verifier` | read and run-tests only; checks the build against the task as an adversary; the orchestrator saves its report into `verification/` |
| "where are we / I've lost the thread / re-sync" | `claude-workspace:context-recovery` | read-only; rebuilds state from the artefacts and memory; the orchestrator saves the result to the picked initiative's memory |
| "tidy / organise / move these files" | `claude-workspace:archivist` | moves and organises files (never edits content); the orchestrator records its map in the project-level `file-structure.md` |

Each agent has its own model. For the models, the override steps, the fallback rule and the advanced settings, see [install.md](install.md#per-agent-models--cost).

The five read-only agents (`research-harvester`, `task-checker`,
`implementation-verifier`, `context-recovery`, `archivist`) cannot write the
canonical artefacts. This is by design. When they return, the orchestrator
saves their output to the right path. The three generators
(`proposal-writer`, `task-planner`, `implementer`) write their own outputs to the
paths the orchestrator gives them.

---

## Initiative verbs (orchestrator actions, not agent dispatches)

Three conversational verbs manage initiatives. These act directly on the registry
(`.workspace/initiatives.md`) and the per-initiative `<slug>/` subfolders. None
of them dispatches a subagent or adds a new agent. The verbs are exactly
**create / switch / list**. There is no built-in delete or rename (see
[initiatives.md](initiatives.md)).

| You say... | What happens |
|---|---|
| "new initiative <name>" / "start a new initiative" | creates `.workspace/<slug>/`, adds a registry entry, and picks it for this session (no `**ACTIVE**` marker is written) |
| "switch to <name>" / "work on <name>" | changes the `slug=` line in this session's marker to that initiative; refused if another live session works on it; no files move |
| "list initiatives" / "what's in this workspace" | reports the slug, one-line description and status of every initiative, from the registry |

When the workspace starts, the orchestrator lists the open initiatives and waits
for your pick. The pick lives in your session's marker. The orchestrator
resolves the picked initiative's paths and hands them to each agent. The agents
themselves stay path-agnostic.

---

## From ticket to pull request (orchestrator actions)

The create verb takes a **ticket identifier**. The orchestrator uses that identifier as the
initiative slug. A numeric slug is valid. The orchestrator reads the ticket with
a tracker tool when one is available. Otherwise it asks you to paste the ticket
text. It saves the ticket text as a file under the initiative's `research/`.

The orchestrator finds the branch at create time, from one of two sources and no other. The first source is the
branch name the tracker supplies. The second is the initiative slug, when the tracker
supplies none. No branch name comes from the ticket title or any other
guess.

Branch, commit, push, and open-PR are **orchestrator actions**. No agent performs
a git action, and git is never an agent's write-target. These actions use the existing
flow points. They add no new stage and no extra dispatch.

| Moment | What the orchestrator does |
|---|---|
| create the initiative | resolves the branch name and creates the branch |
| after a task passes verification | commits, with no prompt |
| after that commit | asks `push <branch> to origin? y/n`, and pushes only on "y" |
| after the push | asks `open a PR for <branch>? y/n`, and opens it only on "y" |

A push and a pull request leave your machine, and your team can see them.
The orchestrator always asks first.

Tracker write-back happens at exactly **two** moments: when work starts, and when
the pull request opens (the handoff). Each moment is a one-line `y/n` prompt. Each writes to the tracker
only on "y". There is no third moment. No tracker write happens without a
"y".

The plugin has no fixed state names. It reads the real states from your tracker
the first time a write-back prompt appears in a project. You choose which state
each of the two moments maps to. The answers go into the
project-level `.workspace/tracker-states` file. Every later prompt and every
later ticket reads that file, so the orchestrator does not ask you again.

When no tracker tool is available, the orchestrator skips every tracker step
silently. It gives no prompt, no notice and no error. The verb finishes as it would without
the step.

The authoritative rules live in the orchestrator skill (`SKILL.md`, "Git actions"
and "Tracker write-back").

---

## Exiting the workspace

There is no "kill switch" command. The orchestrator is not a running
process. It is this skill's instructions, loaded into the conversation. It stays
on until the conversation context is cleared, and only **you** can
clear it. To leave cleanly:

1. Say **"exit the workspace"** (or "I'm done", "stop orchestrating"). The
   orchestrator runs a mandatory teardown of the picked initiative. It adds a
   journal entry and refreshes the index. Then it confirms that it is safe to leave.
2. Type **`/clear`** to drop the orchestrator (a fresh conversation), or
   **`/compact`** to keep a summary. This step ends the orchestrator.

Nothing is lost. All workspace state lives in the git-controlled `.workspace/`
tree. The exit deletes your session marker. The next time you invoke the
workspace skill, it lists the open initiatives. You pick one. It
starts again from the registry, memory index and journal tail, and you continue
where you stopped.

---

## The plan-to-build `/clear` nudge

The orchestrator gives the same fresh-start reminder at one more point. This point is the
first time it is about to dispatch `claude-workspace:implementer` for the
picked initiative after the plan is complete. For example, you say "build it"
or "do task 1" once `tasks.md` exists. The reminder appears once, at that handoff. It does not appear
before every task.

The nudge depends on session age, as the create, switch and exit reminders do. It
checks how long the current session has run. It speaks only after
a threshold (2 hours by default). Below that threshold, or if it cannot read the session age,
the orchestrator stays silent and dispatches the implementer
as normal.

When the nudge appears, the orchestrator tells you that a fresh start can cut cost
with no loss. The proposal and plan are already saved to disk. Clearing
now drops proposal and planning context that the build phase does not need. You can
type `/clear` (fresh start) or `/compact` (keeps a summary). Then re-invoke
the workspace skill and pick the initiative again. You continue at the
build step. This is advice only. The orchestrator cannot clear context
itself.

---

## The typical stage flow

A full initiative usually moves through these stages:

```
new initiative
   |
   v
research        ->  claude-workspace:research-harvester
   |
   v
ask             ->  you answer the brief's questions (`ask` skill)
   |
   v
spec            ->  claude-workspace:proposal-writer
   |
   v
check           ->  claude-workspace:task-checker        (gate before building)
   |
   v
plan            ->  claude-workspace:task-planner
   |
   v
build           ->  claude-workspace:implementer         (one task per dispatch)
   |
   v
verify          ->  claude-workspace:implementation-verifier  (gate after each task)
```

Build and verify usually repeat per task. Build one task, verify it, then move to
the next. The orchestrator prefers to run `task-checker` on the proposal before planning and
`implementation-verifier` after each task. It shows you the gate and lets you
decide to go on or skip.

When an adversarial checker finds a FAIL, the fix goes **back to the
generator**. A failed proposal check returns to `proposal-writer`. A failed implementation
returns to `implementer`. The checker never fixes, and neither does the
orchestrator (see [design-principles.md](design-principles.md) and
[why-it-refuses.md](why-it-refuses.md)).

Lean is the single default flow for every initiative: propose -> check the
proposal -> plan into tasks -> build -> check each build. There is no
complexity-tiering and no separate fast-track lane. Every initiative gets
this same flow unless you choose to escalate (for example, you ask for
extra scrutiny on a task that needs it). For a ticket, research is a
step in the flow, and it needs no escalation.

Questions that need you come before the proposal draft. After research, the
orchestrator asks them with the `ask` skill and sends your answers to
`proposal-writer`. A question that comes up only while the proposal is written
waits until after the proposal check and before task planning. When an answer
arrives after the proposal exists, `proposal-writer` changes only the lines that
the answer affects. `task-checker` checks only those changed lines. One
proposal check cycle has the first check and at most two fix-and-recheck rounds
(three checks at most). After a third FAIL, the orchestrator stops and talks
with you about the approach. The build check does not change: one fix, one
re-check.

The authoritative rules live in the orchestrator skill (`SKILL.md`, "Flow - lean
by default").

---

## Invoke only what you need (no forced sequence)

The stage flow above is the typical path. It is **a flexible guide**. The workflow
is optional and conversational, and you invoke only what you need. The orchestrator
follows your flow and does not force every stage.

- You do not have to run every stage. If you already have a proposal, say "plan
  it" and skip research. If you just want to know where things stand, say "where
  are we" and the orchestrator dispatches `claude-workspace:context-recovery`
  without touching anything else.
- The orchestrator does not restart the pipeline from the top each turn. It reads
  the picked initiative's state, then acts on what you ask next.
- It keeps you informed at each handoff with a one-line status. An example is
  "proposal updated -> want me to plan it, or review it first?". Your
  reply picks the next move.

Describe the next thing you want. The orchestrator dispatches the
single right agent for it. The stages are a map of the usual path.
