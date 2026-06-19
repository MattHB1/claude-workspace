# Concepts and Glossary

This page anchors the vocabulary the rest of the documentation reuses. Read it first: every
other page (design principles, workflow, initiatives, memory, and the rest) assumes these terms.

The whole system is a **conversational front door** that takes a software idea from research to a
proposal, to a task plan, through adversarial checking, into implementation, and finally
verification - using strict single-responsibility subagents and canonical, on-disk artefacts as the
single source of truth.

---

## Project vs initiative

These two are **distinct**, and the difference is the foundation of how the system is organised.

**Project**
: A codebase / repository you are working in - the thing on disk. A project is where a `.workspace/`
  directory lives at its root.

**Initiative**
: A single coherent effort within a project - one idea taken through the pipeline (research to
  proposal to plan to build to verify). The **initiative**, not the project, is the **first-class
  unit** of work. Each initiative owns its own complete, non-colliding set of artefacts.

A single project can host **more than one initiative**. Each initiative gets its own subfolder
`.workspace/<slug>/` holding that initiative's full artefact set, so two distinct initiatives never
share or overwrite each other's `proposal.md`, `tasks.md`, `research/`, `verification/`, or
`memory/`.

### How the registry maps a project to its initiatives

The mapping from one project to its many initiatives is recorded in the **initiative registry**, a
single file at the `.workspace/` root:

```
.workspace/initiatives.md      <- registry: lists EVERY initiative in the project
```

The registry records, for each initiative, exactly three fields: its **slug** (the `<slug>/`
subfolder name), a **one-line description**, and a **status**.

**Single-active rule:** whenever at least one initiative exists, **exactly one** is ACTIVE - never
zero, never more than one. (The only moment none is active is an empty workspace before any
initiative has been created.) The registry is the authoritative record of which initiatives exist
and which one is currently active.

When the system enters a project it reads the registry first to resolve the ACTIVE initiative, then
operates under that initiative's `.workspace/<active-slug>/` paths.

See [initiatives.md](./initiatives.md) for naming, slugs, collision avoidance, switching, and how
the (manual, not-a-built-in) deletion path works.

---

## Orchestrator

The **orchestrator** is the role Claude takes when the workspace skill is active. The orchestrator
does **not** personally research, write proposals, plan, implement, verify, or reorganise files.
Instead it:

- **routes** the user's natural-language instructions to the right single-responsibility subagent;
- resolves the ACTIVE initiative from the registry and passes that initiative's absolute paths into
  every subagent dispatch (subagents are path-agnostic and never read the registry themselves);
- keeps the canonical on-disk artefacts as the single source of truth;
- holds the line on determinism and the system's invariants.

The orchestrator is also the **sole content writer** of the registry, of each initiative's memory
files, and of the cross-project shared-memory tier (see [memory.md](./memory.md)). It works
conversationally - following the user's flow rather than forcing a rigid sequence.

See [workflow.md](./workflow.md) for the intent-to-agent routing table.

---

## The eight agents

Work is carried out by **eight** single-responsibility subagents. Each runs in a **fresh, isolated
context** per dispatch and acts only on the paths the orchestrator hands it. The set is fixed - the
registry and memory tiers add no new agent.

Five of the agents are **read-only** (they cannot write project artefacts; the orchestrator persists
their returned output). Three are **generators / executors** that write their own outputs.

| Agent | Role |
|---|---|
| `research-harvester` | Gathers domain knowledge, prior art, examples, risks, and constraints. Read-and-web only; never plans or implements. Feeds the proposal-writer. |
| `proposal-writer` | Turns a raw idea (plus any research) into the canonical **proposal** - the root of truth. Writes only the active initiative's `proposal.md`. |
| `task-planner` | Decomposes the proposal into atomic, ordered tasks with inputs, outputs, dependencies, and acceptance criteria. Writes only the active initiative's `tasks.md`. |
| `task-checker` | Adversarially checks the task list against the proposal. Read-only - it **detects** deviations and **never fixes** them. |
| `implementer` | Executes exactly **one** task as written, in a fresh session. No planning, no reinterpretation. Writes code itself. |
| `implementation-verifier` | Adversarially checks an implementation against its task spec. Read + run-tests only - detects deviations, never fixes them. |
| `context-recovery` | Rebuilds project state when context is lost or drifting. Read-only - reports only what IS. |
| `archivist` | Keeps the file tree clean and predictable. Moves / renames / creates directories - **never edits file content**. |

The two adversarial checkers (`task-checker`, `implementation-verifier`) are **detect-only** by
design: a FAIL routes the correction back to the originating generator (a failed plan to
`task-planner`, a failed implementation to `implementer`) - never patched by the verifier and never
by the orchestrator. See [design-principles.md](./design-principles.md).

---

## Artefacts

**Artefacts** are the canonical, on-disk files that hold the system's state. They - not the
conversation - are the single source of truth: where the conversation and an artefact disagree, the
**artefact wins**. (See [why-it-refuses.md](./why-it-refuses.md) for what happens when they
conflict.)

The core per-initiative artefacts:

- **`proposal.md`** - the initiative's root of truth: problem, constraints, invariants, acceptance
  criteria, scope, required artefacts. Owned by `proposal-writer`.
- **`tasks.md`** - the initiative's atomic task list; each task traces to a proposal acceptance
  criterion. Owned by `task-planner`.
- **`research/`** - the initiative's research briefs (saved by the orchestrator from
  `research-harvester` output).
- **`verification/`** - the initiative's check-and-verify reports (saved by the orchestrator from
  the two adversarial checkers' output).

### The `.workspace/<slug>/` layout

Each initiative's artefacts live under its own `<slug>/` subfolder. Only three items live at the
`.workspace/` root, shared by all of a project's initiatives.

```
.workspace/
  initiatives.md       # registry: every initiative + which is ACTIVE (project-level)
  file-structure.md    # the project's intended/current file tree (project-level, one per project)
  namespaces           # the project's cross-project namespace membership (project-level)
  <slug>/              # one subfolder PER INITIATIVE - its complete, non-colliding artefact set
    proposal.md          # root of truth (proposal-writer)
    tasks.md             # atomic task list (task-planner)
    research/            # research briefs
    verification/        # check & verify reports
    memory/              # per-initiative working-memory + journal (see below)
      index.md             # overwritten state-of-world pointer file
      journal.md           # append-only decision/progress log
      archive/             # relocated detail (moved, never deleted)
```

`file-structure.md` is one file tree **per project** (never per-initiative), and `namespaces` is the
project's cross-project membership shared by **all** its initiatives (never duplicated per
initiative). Everything else is initiative-scoped under `<slug>/`. Per-initiative artefacts are
created on demand, not pre-shipped.

---

## Invariants

**Invariants** are the properties the system enforces on every dispatch - the contract that explains
why it refuses things rather than guessing. There are **six**:

1. **Proposal is the root of truth** - tasks trace to the proposal; implementations trace to tasks.
2. **Single-writer ownership** - each artefact has exactly one content writer.
3. **Adversarial checkers detect only, never fix** - a failure routes back to the originating
   generator.
4. **Fresh, isolated context per agent dispatch** - no drift across dispatches.
5. **Canonical artefacts override the conversation** - files win when they disagree.
6. **No agent fixes another agent's output** - failures route back to the generator that produced
   them.

See [design-principles.md](./design-principles.md) for each invariant framed as the contract, and
[why-it-refuses.md](./why-it-refuses.md) for the refusals they produce.

---

## Memory tiers

Three memory tiers **coexist**, with **no mirroring** between them.

**Per-initiative memory**
: Under the active initiative's `.workspace/<slug>/memory/`. The home for one initiative's
  **episodic** history: a small, **overwritten** `index.md` (state-of-world pointer file), an
  **append-only** `journal.md` (timestamped, attributed, trust-marked decision/progress log), and an
  `archive/` for relocated detail. The orchestrator is its sole writer; it reads this first each
  session and refreshes it at safe checkpoints ("assume interruption"). Memory references canonical
  content by path/anchor and never copies the authoritative payload - canonical artefacts win.

**Cross-project shared memory**
: A single above-the-project home at `~/.claude/shared-memory/` for **durable, recurring**
  knowledge - stable facts, reusable lessons, and durable preferences - so it can be reused across
  separate projects instead of being re-derived. It uses the same flat-file mechanics one level up,
  organised into namespaces (a `global/` namespace plus one per project family). A project opts in
  by declaring which namespaces it reads in its project-level `.workspace/namespaces` file.
  Knowledge enters this tier **only by explicit, manual, orchestrator-owned promotion** - there is no
  automatic promotion; agents may only surface candidates. Shared claims are treated as **evidence to
  re-validate, not ground truth**, and conflicts are surfaced, never silently merged.

**Native Claude Code auto-memory**
: A **separate per-repository** (cwd-keyed, machine-local) tier that Claude Code maintains on its
  own. It coexists with the two tiers above and is **neither mirrored into nor out of** them in
  either direction. It is not the cross-project tier.

Retrieval across all of these is by explicit path, filename/dir convention, or `grep`/`glob` -
keyword-only, never embeddings, vectors, or semantic search. See [memory.md](./memory.md) for when
to use the shared tier, how to promote and inspect it, and how the namespace-based opt-out works.

---

## See also

- [design-principles.md](./design-principles.md) - the six invariants framed as the contract.
- [why-it-refuses.md](./why-it-refuses.md) - what the system will not do, and why.
- [workflow.md](./workflow.md) - the intent-to-agent routing table and the conversational flow.
- [initiatives.md](./initiatives.md) - registry behaviour, slugs, switching, honest deletion.
- [memory.md](./memory.md) - both memory tiers, promotion, inspection, and opt-out.
- [../README.md](../README.md) - the bundled documentation index.
