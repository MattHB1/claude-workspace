# Design Principles - The Invariants as a Contract

Claude Workspace is a deterministic agentic system. It gives the same kind of result each time. It does not depend on a good day.

A small set of **invariants** makes this happen. An invariant is a rule that holds before and after every action. Read the invariants as a **contract**. The contract is the reason the system sometimes *refuses* a casual instruction.

The workspace refuses in three cases. It does not hand-fix a failing check. It does not act on the conversation over the written artefacts. It does not let one role do the job of another. In each case it keeps the contract. It is not broken.

Read this page as the answer to "why won't it just do the thing?". The companion page [./why-it-refuses.md](./why-it-refuses.md) shows the concrete refusals that follow from these principles.

This page covers the six oldest orchestrator invariants. Each one has a real mechanism that enforces it. The mechanism is a "Hard rules you enforce" in the skill, an ownership table in the skill, or a tool lock in an agent definition. None is a wish, and none is invented.

The names INV-O1, INV-O2 and the like are rule codes. "INV" is short for invariant. The letter after it shows the owner. "O" means the orchestrator. The other letters mean one agent each.

The skill names three more orchestrator invariants. Two of them are verified foundation (INV-O1) and structure-follows-write-targets (INV-O3).

The third is Status honesty (INV-O2). It says that a work item always carries its verification status.

Each agent definition also has its own invariants. These are examples:

- INV-R1 in `research-harvester`.
- INV-C1 and INV-C2 in `task-checker`.
- INV-P1 in `proposal-writer`.
- INV-T1 in `task-planner`.
- INV-I1 and INV-I2 in `implementer`.
- INV-CR1 in `context-recovery`.

The total count of invariants is not fixed at six. It grows when the skill and the agent definitions grow. One thing stays fixed. Every invariant, old or new, traces to a real mechanism that is enforced.

Two of these invariants, INV-P1 and INV-C1, answer different questions. Together they give one position on scope.

**The ticket decides what gets built. Footprint closure decides how completely that thing gets built.**

The ticket draws the boundary. Inside the boundary, the work must be complete. A change can make a surface stale, contradictory or wrong. That surface is part of the change. To repair the wake of a change is to finish it.

INV-P1 in `proposal-writer` states the rule. It also gives the carve-outs and the question that separates them. INV-C2 in `task-checker` is the gate. It fails a proposal that goes past its ticket. The rule text lives in one place only. See [../agents/proposal-writer.md](../agents/proposal-writer.md).

```
            +-----------------------------------------------------+
            |                  proposal.md                        |
            |             (the root of truth)                     |
            +-----------------------------------------------------+
                 |                                      ^
                 | tasks trace to it                    | only proposal-writer
                 v                                      | may change it
            +-----------+      detect only       +--------------+
            |  tasks.md | <-------------------->  |  checkers /  |
            +-----------+   failures route back   |  verifiers   |
                 |          to the generator      | (no Write/   |
                 | one task per dispatch          |  Edit tools) |
                 v                                +--------------+
            +-----------------------+
            |  implementer          |  fresh, isolated context each dispatch
            |  (writes code)        |
            +-----------------------+

    canonical artefacts on disk  >  anything said in the conversation
```

---

## 1. The proposal is the root of truth

**Statement.** The picked initiative's `proposal.md` is the one canonical source of truth. Tasks trace to the acceptance criteria in the proposal. Implementations trace to tasks. Nothing downstream may drift from the proposal. If the proposal must change, a dedicated job does it. After that job, the proposal is checked again.

**Why it matters.** A deterministic pipeline needs one authority. Every other artefact answers to it. Suppose tasks or code drift from the spec while the spec stays the same. Then "done" means different things to different agents. The system loses its single, auditable definition of correctness.

**How it is enforced.** This is Hard rule 3 in the skill ("Proposal is root of truth").
The skill says:
"Tasks trace to proposal acceptance criteria; implementations trace to tasks. If the proposal must change, that's a `proposal-writer` job — and the proposal should be re-checked afterward."
The `proposal-writer` agent is the only writer of `proposal.md`. A change to the spec is its job and no other agent's job.

---

## 2. Single-writer ownership

**Statement.** Every canonical artefact has **exactly one** content writer. Each generator owns its own output. `proposal-writer` writes `proposal.md`. `task-planner` writes `tasks.md`. `implementer` writes code. The orchestrator is the only content writer of three things. These are the registry (`.workspace/initiatives.md`), the per-initiative memory files (`memory/index.md`, `memory/journal.md`) and the cross-project shared-memory tier. No artefact has zero writers, two writers or an unclear writer.

**Why it matters.** Many writers to one file cause races and silent overwrites. Nobody can trust the record. One writer per artefact makes each change traceable. It also keeps the source of truth coherent.

**How it is enforced.** The ownership tables in the skill state the rule. For the registry, the skill says:
"the **orchestrator (you)** is the registry's sole content writer."
It also says:
"No read-only agent writes the registry."
For memory, the skill says:
"Each artefact has exactly one content writer — you."
Tool locks add a second layer. `task-checker` and `context-recovery` have `tools: Read, Glob, Grep` only. `research-harvester` has no write tools either. They *cannot* write an artefact, even if asked. The role definition of each generator limits it to its own output file.

---

## 3. Adversarial checkers detect only (fixes route back to the generator)

**Statement.** Two adversarial reviewers exist. `task-checker` checks the proposal before planning. `implementation-verifier` checks code against its task. Both only **detect** deviations. They never fix anything. A FAIL comes with evidence and required corrections. The generator that made the artefact makes the correction. The checker never makes it. The orchestrator never hand-patches it.

**Why it matters.** A reviewer that can edit the thing it reviews has a conflict of interest. It can "fix" a problem out of sight instead of reporting it. Detection and correction stay in separate hands. This keeps the gate adversarial and keeps a clean audit trail of what failed and why.

**How it is enforced.** This is Hard rule 2 in the skill ("Adversarial verification never fixes"). The skill says:
"`task-checker` and `implementation-verifier` only detect deviations."
It also says that a FAIL goes:
"**back to the generator**"
and that the fix goes:
"never to the verifier, and never patched by you."
Tool locks add a second layer. `task-checker` has `tools: Read, Glob, Grep`, with no write tool and no Bash. Its definition says:
"you deliberately have no tools to do so"
`implementation-verifier` has `tools: Read, Glob, Grep, Bash`. It can run tests but has **no Edit or Write** tool. Its definition says:
"You **cannot** modify code"
Neither agent can repair what it reviews.

---

## 4. Fresh, isolated context per agent dispatch

**Statement.** Each agent runs in a fresh, isolated context. Each `implementer` dispatch and each verifier dispatch is a new session. It gets the task spec and the proposal as explicit inputs. It does not remember earlier turns. Subagents are path-agnostic. They act only on the paths that the orchestrator gives them.

**Why it matters.** State carried between dispatches lets non-determinism and hidden assumptions in. An agent "remembers" something that nobody wrote down, and it acts on that. A fresh start from written inputs makes each run repeatable. Each run then depends only on the canonical artefacts.

**How it is enforced.** This is Hard rule 4 in the skill ("Fresh execution"). The skill says:
"Each `implementer` / verifier dispatch is a new isolated session. Give it the task spec + proposal; don't assume it remembers prior turns."
The dispatch section of the skill says:
"Each runs in a fresh, isolated context."
The same section says that subagents are path-agnostic. They act only on the paths that the orchestrator hands them. They do not read the registry or the markers. They do not discover or guess the initiative. The `implementer` definition also says "Fresh session".

---

## 5. Canonical artefacts override the conversation

**Statement.** The canonical artefacts are `proposal.md`, `tasks.md`, the `verification/` reports and the source tree. Sometimes they disagree with the conversation or with memory. Then the **canonical artefact wins**. Memory and conversation are pointers and reminders. They never compete as a source of truth.

**Why it matters.** Conversation loses detail and gets compacted. Memory can go stale. Suppose spoken context could override the files. Then behaviour would change with whatever is still in the window. That is the opposite of determinism. Durable artefacts keep behaviour stable across resets and interruptions.

**How it is enforced.** The skill states the rule in two places. The "Precedence" rule of the memory layer says:
"Where memory and a canonical artefact"
It continues:
"disagree, the **canonical artefact wins** — memory is never a competing source of truth."
The same rule says that the journal and index **reference** canonical content by **path/anchor**. They must **not restate/copy** the authoritative payload. The bootstrap guidance says:
"Artefacts in `.workspace/` are authoritative — when in doubt, read them, don't rely on conversation memory."
When a shared claim contradicts an artefact, the skill requires the conflict to be **surfaced, never silently merged**.

---

## 6. No agent fixes another agent's output

**Statement.** Roles never collapse. No agent repairs an artefact that another agent owns. A failed proposal check goes back to `proposal-writer`. A failed implementation goes back to `implementer`. A spec change goes back to `proposal-writer`. The orchestrator sends the fix to the right owner. It does not hand-patch. One specialist never does the job of another.

**Why it matters.** Single responsibility is the whole point of the design. Suppose any agent could reach into the output of another. Then ownership and traceability fall apart. The adversarial gates lose their meaning. Nobody can say which role is accountable for a change.

**How it is enforced.** This is Hard rule 1 in the skill ("Single responsibility"). The skill says:
"Never collapse roles. Don't let the implementer plan, or the planner implement. Don't do the specialist work yourself — dispatch it."
Hard rule 2 adds that failures go back to the generator. The operating guidance says:
"route the fix to the correct generator"
and:
"Don't hand-fix."
Tool locks make it structurally impossible for some agents to alter the output of others. `research-harvester`, `task-checker`, `implementation-verifier` and `context-recovery` have no Edit or Write tool. `archivist` may only move files with `mv` in Bash. It never edits content.

---

## Why these are trustworthy, not why there are six

Each invariant above maps to a mechanism that the system enforces. The mechanism is a numbered Hard rule, a single-writer ownership table or an agent tool lock. It is not a wish about good behaviour.

This holds for these six. It holds for INV-O1, INV-O2 and INV-O3. It holds for every agent invariant family too. The contract holds only promises that the system keeps by construction, however many promises there are.

For the day-to-day results of these principles, see [./why-it-refuses.md](./why-it-refuses.md). That page lists the things the workspace declines to do.
