# Concepts and Glossary

This page defines the terms that the other pages reuse. Read it first. Every other page (design principles, workflow, initiatives, memory) uses these terms.

The system is a **conversational front door**. It takes a software idea from research to a proposal, to a task plan, through adversarial checking, into implementation, and last to verification. Each subagent has one job. The files on disk are the single source of truth.

---

## Project vs initiative

These two terms differ. The difference is the base of how the system works.

**Project**
: A codebase or repository that you work in. It is the thing on disk. A project has a `.workspace/` directory at its root.

**Initiative**
: One coherent effort in a project. It takes one idea through the pipeline (research, proposal, plan, build, verify). The **initiative**, and not the project, is the **first-class unit** of work. Each initiative owns its own set of artefacts. These sets never collide.

A project can hold **more than one initiative**. Each initiative gets its own subfolder, `.workspace/<slug>/`. That subfolder holds the full artefact set of the initiative. Two initiatives never share or overwrite a `proposal.md`, `tasks.md`, `research/`, `verification/`, or `memory/`.

### How the registry maps a project to its initiatives

The **initiative registry** records which initiatives a project has. It is one file at the `.workspace/` root:

```
.workspace/initiatives.md      <- registry: lists EVERY initiative in the project
```

The registry records three fields for each initiative. They are its **slug** (the name of the `<slug>/` subfolder), a **one-line description**, and a **status**.

**Session pick:** the registry does not mark one initiative as current. The registry is the authoritative record of which initiatives exist. Each session picks its initiative when it starts work. The session marker stores the pick. The registry does not. Two sessions in the same repo cannot pick the same initiative.

When the system enters a project, it reads the registry first and lists the open initiatives. The user picks one, or starts a new one. The system then works under the `.workspace/<slug>/` paths of that initiative.

See [initiatives.md](./initiatives.md) for naming, slugs, collision avoidance, switching, and the manual deletion path. The system has no built-in delete command.

---

## Orchestrator

The **orchestrator** is the role that Claude takes when the workspace skill is on. The orchestrator does **not** research, write proposals, plan, implement, verify, or reorganise files itself. Instead it does these things:

- It **routes** your natural-language instructions to the right subagent.
- It uses the initiative that this session picked. It passes the absolute paths of that initiative into every subagent dispatch. Subagents do not know the paths and never read the registry.
- It keeps the files on disk as the single source of truth.
- It holds the line on determinism and on the invariants of the system.

The orchestrator is also the **sole content writer** of the registry. It also writes the memory files of each initiative and the cross-project shared-memory tier (see [memory.md](./memory.md)). It works as a conversation and follows your flow. It does not force a fixed order.

The orchestrator speaks to you in plain words. It uses short sentences and common words. It explains each term before it uses the term. It collects its questions into one batch. It asks the questions that need you after research and before the proposal draft. It formats them with the `ask` skill.

A question that comes up only while the proposal is written waits. It waits until after the proposal check and before task planning. A late answer can change the proposal. Then `proposal-writer` changes only the lines that the answer affects. `task-checker` checks only those lines.

One proposal check cycle has at most three checks. After a third FAIL, the orchestrator stops and talks with you about the approach.

**Decide, do not ask.** The orchestrator does work that git history can undo with no question. It reports what it did. It asks before work that git history cannot undo. Examples are a push, a pull request, or a tracker write-back. The user sets product direction. The orchestrator does not decide it.

The orchestrator fixes a problem that relates directly to the work in hand. It logs any other problem that it finds. It then asks the user to choose: raise a new ticket, or add the problem to this ticket. It does not act on that problem before the user answers. A fix-check finding goes to the user. The orchestrator does not fix it.

**Ticket-driven work.** An initiative can start from a ticket. The ticket identifier becomes the slug. The orchestrator takes the ticket text from an available tracker tool, or from text that you paste. It saves the text under `research/` of the initiative. The branch name is the name that the tracker gives, or else the slug.

The orchestrator also runs the git actions. It commits with no prompt. It asks a one-line `y/n` before it pushes and before it opens a pull request. It offers a tracker write-back at two moments only: work started, and pull request opened. Each offer has the same one-line `y/n`. It proposes no close, because closing follows review and merge. With no tracker tool, the orchestrator skips every tracker step. It gives no prompt, no notice, and no error.

See [workflow.md](./workflow.md) for the table that maps each intent to an agent.

---

## The eight agents

Eight subagents do the work. Each has one job. Each runs in a **fresh, isolated context** for each dispatch. Each acts only on the paths that the orchestrator gives it. The set is fixed. The registry and the memory tiers add no new agent.

Five of the agents are **read-only**. They cannot write project artefacts. The orchestrator saves their returned output. Three are **generators or executors**. They write their own outputs.

| Agent | Role |
|---|---|
| `research-harvester` | Gathers domain knowledge, prior art, examples, risks, and constraints. It can read files and search the web. It never plans or implements. It feeds the proposal-writer. |
| `proposal-writer` | Turns a raw idea (and any research) into the **proposal**, the root of truth. It writes only the `proposal.md` of this session's initiative. |
| `task-planner` | Splits the proposal into small, ordered tasks. Each task has inputs, outputs, dependencies, and acceptance criteria. It writes only the `tasks.md` of this session's initiative. |
| `task-checker` | Checks the proposal with an adversarial view, before planning. It is read-only. It **detects** deviations and **never fixes** them. |
| `implementer` | Does exactly **one** task as written, in a fresh session. It does no planning and no reinterpretation. It writes code itself. |
| `implementation-verifier` | Checks an implementation against its task spec with an adversarial view. It can read files and run tests. It detects deviations and never fixes them. |
| `context-recovery` | Rebuilds the project state when context is lost or drifts. It is read-only. It reports only what IS. |
| `archivist` | Keeps the file tree clean and predictable. It moves and renames files and creates directories. It **never edits file content**. |

Each agent has its own model. For override steps, fallback rules, and advanced settings, see the section "Per-agent models / cost" in [install.md](./install.md#per-agent-models--cost).

The two adversarial checkers (`task-checker` and `implementation-verifier`) **only detect**, by design. A FAIL sends the correction back to the generator that made the work. A failed proposal goes to `proposal-writer`. A failed implementation goes to `implementer`. The verifier never patches it. The orchestrator never patches it. See [design-principles.md](./design-principles.md).

---

## Artefacts

**Artefacts** are the files on disk that hold the state of the system. They are the single source of truth, and the conversation is not. When the conversation and an artefact disagree, the **artefact wins**. (See [why-it-refuses.md](./why-it-refuses.md) for what happens in a conflict.)

The core per-initiative artefacts are these:

- **`proposal.md`** - the root of truth of the initiative. It holds the problem, constraints, invariants, acceptance criteria, scope, and required artefacts. `proposal-writer` owns it.
- **`tasks.md`** - the task list of the initiative. Each task traces to a proposal acceptance criterion. `task-planner` owns it.
- **`research/`** - the research briefs of the initiative. The orchestrator saves them from `research-harvester` output.
- **`verification/`** - the check and verify reports of the initiative. The orchestrator saves them from the output of the two adversarial checkers.

### The `.workspace/<slug>/` layout

Each initiative keeps its artefacts under its own `<slug>/` subfolder. Some items live at the `.workspace/` root instead. All initiatives of a project share them. The next tree shows each root item and who writes it.

```
.workspace/
  initiatives.md          # registry: every initiative (written by the orchestrator)
  initiatives-archive.md  # detail moved out of the registry when it grows large (written by the orchestrator)
  file-structure.md       # the project's intended and current file tree (recorded by the orchestrator from archivist output)
  namespaces              # the project's cross-project namespace membership (written by the orchestrator)
  tracker-states          # the project's map from transition point to tracker state name (recorded by the orchestrator from your answers)
  main-commits            # the word "allowed" lets the repo allow one live session on the main checkout (written by you)
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

The orchestrator creates `initiatives-archive.md` only when the registry grows large. The orchestrator creates `namespaces` when a project first reads the shared memory tier. You create `main-commits` when you want a repo to allow one live session on the main checkout. Without that file, the repo is main-locked.

`file-structure.md` is one file tree **per project**. It is never per initiative. `namespaces` is the cross-project membership of the project. **All** initiatives share it. It is never copied per initiative.

`tracker-states` holds the project's map from each transition point to the tracker state name that you picked. It has two lines, one for each transition point. It holds no state for a single ticket. All initiatives of the project share it too. Everything else belongs to one initiative, under `<slug>/`. The plugin creates the per-initiative artefacts on demand. It ships none of them.

---

## Invariants

**Invariants** are the properties that the system enforces on every dispatch. They are the contract that explains why the system refuses a request and does not guess. Two layers exist.

**Orchestrator invariants** - three of them. The names `INV-O1`, `INV-O2`, and `INV-O3` appear in [skills/workspace/SKILL.md](../skills/workspace/SKILL.md). `INV` is short for invariant, and `O` means orchestrator. The form `INV-*` stands for any rule code of this kind.

1. **Verified foundation (INV-O1)** - never plan on, build on, or report as done any work that has not passed independent verification.
2. **Status honesty (INV-O2)** - a work item's verified-or-asserted status travels with every reference to it, everywhere.
3. **Structure follows write-targets (INV-O3)** - the write-targets of tasks must not overlap if you dispatch the tasks together in a parallel wave. The number of acceptance criteria (AC) does not set the limit.

**Agent-intrinsic invariant families** - these are "Always / Never" properties that each agent holds in its own prompt (see `agents/*.md`). They apply to every task. They form four families:

- **completeness before commitment** (`research-harvester`, `proposal-writer`, `task-checker`)
- **structure follows the write-target** (`task-planner`)
- **verified before foundation** (`implementer`, `implementation-verifier`, `context-recovery`)
- **scope confinement to the request** (`proposal-writer`, `task-checker`)

The last family sets the outer limit of an initiative: the ticket decides what gets built. Its rule text has one home, in `agents/proposal-writer.md`.

See [design-principles.md](./design-principles.md) for each invariant as a contract. See [why-it-refuses.md](./why-it-refuses.md) for the refusals that they cause.

---

## Memory tiers

Three memory tiers **coexist**. They do **not mirror** each other.

**Per-initiative memory**
: It lives under `.workspace/<slug>/memory/` of this session's initiative. It is the home of the **episodic** history of one initiative. It has a small `index.md` that the orchestrator **overwrites** (a state-of-world pointer file). It has an **append-only** `journal.md` (a log of decisions and progress with time, author, and trust marks). It has an `archive/` for moved detail. The orchestrator is its sole writer. It reads this memory first in each session. It refreshes the memory at safe checkpoints ("assume interruption"). Memory points to canonical content by path or anchor. It never copies the authoritative payload. Canonical artefacts win.

**Cross-project shared memory**
: One home above the project, at `~/.claude/shared-memory/`. It holds **durable, recurring** knowledge: stable facts, reusable lessons, and durable preferences. Separate projects can reuse it, so they do not derive it again. It uses the same flat-file mechanics one level up. It has namespaces: a `global/` namespace and one for each project family. A project opts in. It declares which namespaces it reads in its `.workspace/namespaces` file. Knowledge enters this tier **only by explicit, manual promotion that the orchestrator owns**. No automatic promotion exists. Agents can only surface candidates. The system treats shared claims as **evidence to re-validate, not ground truth**. It shows conflicts and never merges them silently.

**Native Claude Code auto-memory**
: A **separate per-repository tier** (keyed by working directory, kept on your machine). Claude Code maintains it on its own. It coexists with the two tiers above. The system **does not mirror it into or out of** them. It is not the cross-project tier.

Retrieval across all tiers uses an explicit path, a filename or directory rule, or `grep` and `glob`. It uses keywords only. It never uses embeddings, vectors, or semantic search. See [memory.md](./memory.md) for when to use the shared tier, how to promote and inspect it, and how the namespace opt-out works.

---

## See also

- [design-principles.md](./design-principles.md) - the invariants as a contract.
- [why-it-refuses.md](./why-it-refuses.md) - what the system will not do, and why.
- [workflow.md](./workflow.md) - the table that maps each intent to an agent, and the conversational flow.
- [initiatives.md](./initiatives.md) - registry behaviour, slugs, switching, and deletion.
- [memory.md](./memory.md) - both memory tiers, promotion, inspection, and opt-out.
- [../README.md](../README.md) - the index of the bundled documentation.
