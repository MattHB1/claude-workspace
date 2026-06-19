# Why it refuses things (this is expected)

Claude Workspace is deliberately strict. When you ask it to do something unsafe,
something ambiguous, or something that would break its determinism guarantees, it
will **push back** instead of guessing. It will also defer to the written artefacts
over anything said in chat. This is a **feature, not the system "being difficult."**
The whole point of the workspace is that the same inputs produce the same,
auditable outputs, and that no agent quietly invents an answer to keep things
moving.

If you hit one of the refusals below, nothing is broken. The system is doing
exactly what it was built to do. Each section says what triggers the pushback and
what to do instead.

The underlying rules that cause these refusals are the system's invariants. See
[design-principles.md](./design-principles.md) for the full contract.

---

## 1. It refuses (or pushes back on) unsafe plans

The orchestrator does not just rubber-stamp a plan and start building. Two
adversarial, read-only checkers exist specifically to find problems before they
ship:

- `task-checker` reviews whether the plan actually matches the proposal.
- `implementation-verifier` reviews whether built work actually matches its task.

These checkers **only detect** deviations. They never patch what they find. When a
checker FAILs something, the system does **not** quietly fix it in place; the
correction is routed **back to the generator** that produced it. A failed plan goes
back to `task-planner`; a failed implementation goes back to `implementer`. The
verifier never fixes its own findings, and the orchestrator does not hand-patch
them either.

The workflow also prefers **gates before progress**: running `task-checker` after
planning, and `implementation-verifier` after each task. The system surfaces the
gate and lets you decide to proceed or skip, rather than barrelling ahead.

**What this looks like:**

- You ask it to build a task whose plan was just FAILed by `task-checker`. It will
  surface the violations and route the fix back to `task-planner` first, rather than
  building on top of a broken plan.
- A verification FAILs. Instead of editing the verifier's report into a pass, the
  system summarises the violations and sends the work back to `implementer`.

**What to do instead:** let the fix go back to the originating generator and re-run
the check. Don't ask the checker or the orchestrator to "just fix it" -- that role
separation is intentional.

---

## 2. It refuses ambiguous or under-specified instructions

The system runs on a strict division of labour: research, proposal-writing,
planning, checking, implementing, and verifying are **separate roles**, and roles
are never collapsed. The implementer does not plan; the planner does not implement.
Specialist work is dispatched to the specialist, never improvised by the
orchestrator.

A direct consequence: when an instruction is ambiguous, the system would have to
**guess** which role does what, or invent missing detail, to proceed. It is built
not to do that. The proposal's acceptance criteria are meant to be the unambiguous
contract that planning and implementation trace to; when that contract is unclear or
missing, the honest move is to stop and clarify rather than fabricate it.

**What this looks like:**

- You say "just build it" but there is no proposal, or the proposal has no
  acceptance criteria covering what you asked. The system asks for a spec first,
  because there is nothing for the work to trace to.
- A task is under-specified or conflicts with what the implementer finds. The
  implementer stops and reports the ambiguity instead of inventing an
  interpretation.

**What to do instead:** clarify the instruction, or fix the proposal so the
acceptance criteria say exactly what "done" means. If the proposal itself needs to
change, that is a `proposal-writer` job, and the plan should be re-checked
afterward. Tightening the spec is the fix -- not pressuring the agent to guess.

---

## 3. It refuses anything that violates determinism

Determinism, auditability, and zero hidden infrastructure are core promises. The
system will decline requests that would break them.

- **Retrieval is deterministic.** Memory and shared knowledge are retrieved by
  explicit path, filename/directory convention, or `grep`/`glob` over plain files --
  **never** by embeddings, vectors, similarity ranking, or semantic search. The loss
  of semantic retrieval is an **accepted tradeoff** for determinism and
  auditability. Asking it to "search by meaning" or to stand up a vector/embedding
  store for memory runs against this on purpose.
- **No automatic promotion.** Durable knowledge enters the shared cross-project tier
  **only by an explicit promotion decision** made by the orchestrator. There is **no
  automatic / on-recurrence promotion** mechanism of any kind. Read-only agents may
  surface a "this looks reusable" candidate, but they never write it; you decide and
  the orchestrator persists.
- **No new runtime for memory.** Initiative memory is flat files -- no database, no
  vector/graph/embedding store, no daemon, no external service. Requests to add one
  for memory are out of scope by design.
- **Single-writer ownership.** Each artefact has exactly one content writer. The
  read-only agents (research-harvester, task-checker, implementation-verifier,
  context-recovery, archivist) are tool-locked out of writing artefacts. Asking a
  read-only agent to write its own output, or asking one agent to fix another
  agent's output, is refused -- the orchestrator persists read-only output, and
  failures route back to the originating generator.

**What this looks like:**

- "Make the workspace remember this across all my projects automatically." There is
  no auto-promotion; the system asks you to promote explicitly instead.
- "Have the verifier rewrite the failing code." The verifier is detect-only; the fix
  routes back to the implementer.

**What to do instead:** use the explicit, deterministic path -- name the file or
keyword to retrieve, ask for an explicit promotion, or route the fix to the right
generator.

---

## 4. When the artefacts disagree with the conversation, the artefacts win

This is the case people are most surprised by. The canonical, on-disk artefacts --
the initiative's `proposal.md`, `tasks.md`, `verification/`, and the source files --
are the **single source of truth**. The chat history is not.

The rule is explicit: **artefacts in `.workspace/` are authoritative -- when in
doubt, read them, don't rely on conversation memory.** Where memory and a canonical
artefact disagree, **the canonical artefact wins**; memory is never a competing
source of truth. The memory layer only **references** canonical content by
path/anchor and must not restate or copy the authoritative payload.

**Why the artefacts win, and why this is good:**

- **They are durable and auditable.** A long session forgets its early history as
  the context window fills; a file does not. Trusting the file over fuzzy recall is
  what keeps the system consistent across days, resets, and compactions.
- **They are versioned.** Artefacts live in git, so every change is reviewable and
  revertible. Conversation is not.
- **It prevents drift.** If chat could silently override the spec, two runs of the
  "same" instruction could diverge. Pinning truth to the written artefact is what
  makes the system deterministic.

When a claim disagrees with an artefact, the conflict is **surfaced, never silently
merged or auto-resolved.** This holds for every conflict kind the system tracks:
a shared claim vs. the live working tree, a shared claim vs. the canonical artefact,
a shared claim vs. the initiative's own memory, and two shared claims that
contradict each other. No instruction permits silently adopting or merging an
unverified claim over what the artefacts say.

**What this looks like:**

- You remember agreeing in chat to a scope that the proposal does not contain. The
  system goes by the proposal and flags the mismatch, rather than acting on the
  remembered version.
- A shared lesson from another project contradicts this initiative's `proposal.md`.
  The system surfaces the conflict for you to resolve; it does not quietly merge the
  outside claim.

**What to do instead:** if the conversation is right and the artefact is stale,
**update the artefact** -- that is the fix. Changing the proposal is a
`proposal-writer` job, after which the plan should be re-checked. Once the artefact
reflects the new reality, the disagreement is gone, because the artefact is now the
truth everything traces to.

---

## In short

| You see this | Why | Do this |
|---|---|---|
| It won't build on a FAILed plan | Gates before progress; checkers detect only | Let the fix route back to the generator, then re-check |
| It asks you to clarify | Roles are not collapsed; it won't guess | Clarify, or fix the proposal's acceptance criteria |
| It won't "search by meaning" or auto-remember | Deterministic, keyword-only retrieval; no auto-promotion | Use explicit paths/keywords; promote explicitly |
| It trusts the file over the chat | Canonical artefacts are authoritative | Update the artefact so it reflects reality |

Refusal here is the system keeping its promises. For the invariants behind every one
of these behaviours, read [design-principles.md](./design-principles.md).
