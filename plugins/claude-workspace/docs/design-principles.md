# Design Principles - The Invariants as a Contract

Claude Workspace is a deterministic agentic system. Determinism is not an accident
of how it happens to behave on a good day; it is enforced by a small set of
**invariants** that hold before and after every action. These invariants are best
read as a **contract**: they are the reason the system sometimes *refuses* to do
what a casual instruction asks for. When the workspace declines to hand-fix a
failing check, declines to act on the conversation over the written artefacts, or
declines to let one role do another's job, it is not malfunctioning - it is keeping
the contract.

Read this page as the answer to "why won't it just do the thing?". The companion
page [./why-it-refuses.md](./why-it-refuses.md) walks through the concrete refusals
that fall out of these principles.

This page lists **exactly six** invariants. Every one is backed by a real,
enforced mechanism - a "Hard rule you enforce" or an ownership table in the skill,
or a tool lock baked into an agent's definition. None is aspirational, and none is
invented.

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

**Statement.** The active initiative's `proposal.md` is the single canonical
source of truth. Tasks trace to the proposal's acceptance criteria, and
implementations trace to tasks. Nothing downstream may quietly diverge from the
proposal; if the proposal itself needs to change, that is a dedicated job, after
which the plan is re-checked.

**Why it matters.** A deterministic pipeline needs one authority that every other
artefact answers to. If tasks or code could drift from the spec without the spec
moving first, "done" would mean different things to different agents and the system
would lose its single, auditable definition of correctness.

**How it is enforced.** This is Hard rule 3 in the skill ("Proposal is root of
truth"): "Tasks trace to proposal acceptance criteria; implementations trace to
tasks. If the proposal must change, that's a `proposal-writer` job - and the plan
should be re-checked afterward." The `proposal-writer` agent is the sole writer of
`proposal.md`; changing the spec is structurally its job and no other agent's.

---

## 2. Single-writer ownership

**Statement.** Every canonical artefact has **exactly one** content writer. The
generators own their own outputs (`proposal-writer` -> `proposal.md`, `task-planner`
-> `tasks.md`, `implementer` -> code). The orchestrator is the sole content writer
of the registry (`.workspace/initiatives.md`), the per-initiative memory files
(`memory/index.md`, `memory/journal.md`), and the cross-project shared-memory tier.
No artefact has zero, two, or an ambiguous writer.

**Why it matters.** Multiple writers to one file produce races, silent overwrites,
and a record nobody can trust. Pinning each artefact to one writer makes every
change attributable and keeps the source of truth coherent.

**How it is enforced.** The skill states the rule directly in its ownership tables -
for the registry: "the **orchestrator (you)** is the registry's sole content
writer ... No read-only agent writes the registry"; and for memory: "Each artefact
has exactly one content writer - you." The read-only agents are additionally
**tool-locked** out of writing: `task-checker` and `context-recovery` are declared
with `tools: Read, Glob, Grep` only, and `research-harvester` likewise has no
write tools - so they *cannot* write an artefact even if asked. The generators
that do write are limited to their own output file by their role definition.

---

## 3. Adversarial checkers detect only (fixes route back to the generator)

**Statement.** The two adversarial reviewers - `task-checker` (plan vs. proposal)
and `implementation-verifier` (code vs. task) - only **detect** deviations. They
never fix anything. A FAIL is reported with evidence and required corrections; the
correction itself is made by the originating generator, never by the checker and
never hand-patched by the orchestrator.

**Why it matters.** A reviewer that can also edit the thing it reviews has a
conflict of interest: it can "fix" a problem into invisibility instead of reporting
it. Keeping detection and correction in separate hands preserves an honest,
adversarial gate and a clean audit trail of what failed and why.

**How it is enforced.** This is Hard rule 2 in the skill ("Adversarial
verification never fixes"): "`task-checker` and `implementation-verifier` only
detect deviations. When they FAIL something, the correction goes **back to the
generator** ... never to the verifier, and never patched by you." It is reinforced
by tool locks: `task-checker` is `tools: Read, Glob, Grep` (no write, no Bash) and
its definition says it "deliberately ha[s] no tools" to fix; `implementation-verifier`
is `tools: Read, Glob, Grep, Bash` (run tests, but **no Edit/Write**) and is told it
"**cannot** modify code". They are physically unable to repair what they review.

---

## 4. Fresh, isolated context per agent dispatch

**Statement.** Each agent runs in a fresh, isolated context. Every `implementer`
and verifier dispatch is a new session that receives the task spec and the proposal
as explicit inputs; it is never assumed to remember prior turns. Subagents are
path-agnostic - they act only on the paths the orchestrator hands them.

**Why it matters.** Carrying conversational state between dispatches is how
non-determinism and hidden assumptions creep in: an agent "remembers" something that
was never written down and acts on it. Starting fresh from the written inputs makes
each run reproducible and dependent only on the canonical artefacts.

**How it is enforced.** This is Hard rule 4 in the skill ("Fresh execution"):
"Each `implementer` / verifier dispatch is a new isolated session. Give it the task
spec + proposal; don't assume it remembers prior turns." The skill's dispatch
section adds: "Each runs in a fresh, isolated context" and "Subagents are
path-agnostic: they act only on the paths you hand them and do **not** read the
registry or discover/guess the active initiative themselves." The agent definitions
echo this (e.g. the `implementer` operates in a "Fresh session").

---

## 5. Canonical artefacts override the conversation

**Statement.** Where the written canonical artefacts (`proposal.md`, `tasks.md`,
the `verification/` reports, the source tree) disagree with what was said in
conversation or recorded in memory, the **canonical artefact wins**. Memory and
conversation are pointers and reminders, never a competing source of truth.

**Why it matters.** Conversation is lossy and gets compacted; memory can go stale.
If spoken context could override the files, the system would behave differently
depending on what happened to still be in the window - the opposite of determinism.
Anchoring to durable artefacts keeps behaviour stable across resets and interruptions.

**How it is enforced.** The skill states it in two places. In the memory layer's
"Precedence" rule: "Where memory and a canonical artefact ... disagree, the
**canonical artefact wins** - memory is never a competing source of truth"; memory
must "**reference** canonical content by **path/anchor** ... and must **not**
restate/copy the authoritative payload." And in the bootstrap/operating guidance:
"Artefacts in `.workspace/` are authoritative - when in doubt, read them, don't rely
on conversation memory." When a shared claim contradicts an artefact, the skill
requires the conflict be **surfaced, never silently merged**.

---

## 6. No agent fixes another agent's output

**Statement.** Roles never collapse, and no agent repairs an artefact that another
agent owns. A failed plan goes back to `task-planner`; a failed implementation goes
back to `implementer`; a spec change goes back to `proposal-writer`. The orchestrator
routes the fix to the correct owner rather than hand-patching it, and one specialist
never does another's job.

**Why it matters.** Single responsibility is the whole point of the design. If any
agent could reach into another's output, ownership and traceability dissolve, the
adversarial gates become meaningless, and you can no longer say which role is
accountable for any given change.

**How it is enforced.** This is Hard rule 1 in the skill ("Single
responsibility"): "Never collapse roles. Don't let the implementer plan, or the
planner implement. Don't do the specialist work yourself - dispatch it." Combined
with Hard rule 2, failures "route back to the generator." The operating guidance is
explicit: "On a FAIL: summarise the violations, then route the fix to the correct
generator and re-check. Don't hand-fix." The read-only agents' tool locks
(`research-harvester`, `task-checker`, `implementation-verifier`, `context-recovery`
have no Edit/Write; `archivist` may only `mv` via Bash, never edit content) make it
structurally impossible for them to alter anyone's output in the first place.

---

## Why these six, and only these six

Each invariant above maps to a mechanism that is actually enforced - a numbered
Hard rule, a single-writer ownership table, or an agent tool lock - not to a wish
about good behaviour. That is why the list is exactly six and no longer: the
contract only contains promises the system can keep by construction. For the
day-to-day consequences of these principles - the specific things the workspace
will decline to do - see [./why-it-refuses.md](./why-it-refuses.md).
