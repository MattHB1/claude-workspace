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

The amount of verification a task gets scales with its blast radius, by a
deterministic rubric (file kind, path, and diff - never a judgement call):

- **Trivial** - documentation, comments, whitespace, or human-only metadata.
  The orchestrator builds it and proceeds; an adversarial verify is available
  on request but not forced, because the change has no semantic effect.
- **Local-semantic** - a single-scope logic change that touches no shared
  contract, no other repo, and no plugin file. Adversarial verification is
  **required**.
- **Structural** - anything touching a schema, a shared invariant, more than
  one repo, the plugin, or the core orchestration rules. The full
  check -> build -> verify path runs, unchanged.

The rubric only ever escalates - when a task is ambiguous or reaches further
than it first appears - and never downgrades verification. **A change with any
semantic effect is always verified;** the trivial lane applies only to edits
that change no behaviour. The authoritative rules live in the orchestrator
skill (`SKILL.md`).

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
