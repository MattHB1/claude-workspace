# Why it refuses things (this is expected)

Claude Workspace is strict on purpose. Sometimes you ask it to do something unsafe or ambiguous. Sometimes the request would break its determinism guarantees. In these cases it **pushes back** and does not guess. It also trusts the written artefacts over anything said in chat. This is a **feature. The system is not "being difficult."** The same inputs must give the same outputs, and you must be able to audit them. No agent may quietly invent an answer to keep things moving.

If you hit one of the refusals below, nothing is broken. The system does what it was built to do. Each section says what triggers the pushback and what to do instead.

The rules behind these refusals are the system's invariants (rules that always hold). See [design-principles.md](./design-principles.md) for the full contract.

---

## 1. It refuses (or pushes back on) unsafe proposals and plans

The orchestrator does not rubber-stamp a proposal or a plan and start to build. Two adversarial, read-only checkers look for problems before they ship:

- `task-checker` checks the proposal before planning starts. It asks if the proposal is sound, complete and minimal.
- `implementation-verifier` checks whether built work matches its task.

These checkers **only detect** deviations. They never patch what they find. When a checker FAILs something, the system does **not** quietly fix it in place. The correction goes **back to the generator** that made it. A failed proposal goes back to `proposal-writer`. A failed implementation goes back to `implementer`. The verifier never fixes its own findings, and the orchestrator does not hand-patch them either.

The workflow also prefers **gates before progress**. It runs `task-checker` on the proposal before planning, and it runs `implementation-verifier` after each task. The system shows you the gate and lets you decide to proceed or skip. It does not rush ahead.

**What this looks like:**

- You ask it to plan a proposal that `task-checker` just FAILed. It shows you the violations and sends the fix back to `proposal-writer` first. It does not build on a broken proposal.
- A verification FAILs. The system does not edit the verifier's report into a pass. It summarises the violations and sends the work back to `implementer`.

**What to do instead:** let the fix go back to the generator that made it, and run the check again. Do not ask the checker or the orchestrator to "just fix it". The separation of roles is intentional.

---

## 2. It refuses ambiguous or under-specified instructions

The system uses a strict division of labour. Research, proposal-writing, planning, checking, implementing and verifying are **separate roles**. The system never merges roles. The implementer does not plan, and the planner does not implement. The orchestrator sends specialist work to the specialist and does not improvise it.

This has a direct result. When an instruction is ambiguous, the system would have to **guess** which role does what, or invent missing detail, to proceed. It is built not to do that. The acceptance criteria in the proposal are the clear contract that planning and implementation trace to. When that contract is unclear or missing, the system stops and asks you to clarify. It does not make one up.

**What this looks like:**

- You say "just build it" but there is no proposal. Or the proposal has no acceptance criteria for what you asked. The system asks for a spec first, because the work has nothing to trace to.
- A task is under-specified, or it conflicts with what the implementer finds. The implementer stops and reports the ambiguity. It does not invent an interpretation.

**What to do instead:** clarify the instruction. Or fix the proposal so that the acceptance criteria say exactly what "done" means. A change to the proposal is a job for `proposal-writer`, and `task-checker` then checks the proposal again. Tighten the spec. Do not pressure the agent to guess.

---

## 3. It refuses anything that violates determinism

Determinism, auditability and zero hidden infrastructure are core promises. The system declines requests that would break them.

- **Retrieval is deterministic.** The system retrieves memory and shared knowledge by explicit path, by filename or directory convention, or by `grep` or `glob`. It never uses embeddings, vectors, similarity ranking or semantic search. We accept the loss of semantic retrieval as a tradeoff for determinism and auditability. If you ask it to "search by meaning", or to set up a vector or embedding store for memory, it refuses on purpose.
- **No automatic promotion.** Durable knowledge enters the shared cross-project tier **only by an explicit promotion decision** from the orchestrator. The system has **no automatic or on-recurrence promotion** of any kind. Read-only agents may suggest a "this looks reusable" candidate, but they never write it. You decide, and the orchestrator saves it.
- **No new runtime for memory.** Initiative memory is flat files. It uses no database, no vector, graph or embedding store, no daemon and no external service. Requests to add one for memory are out of scope by design.
- **Single-writer ownership.** Each artefact has exactly one content writer. The read-only agents are `research-harvester`, `task-checker`, `implementation-verifier`, `context-recovery` and `archivist`. Their tools lock them out of writing artefacts. The system refuses two kinds of request. One asks a read-only agent to write its own output. The other asks one agent to fix the output of another agent. The orchestrator saves read-only output, and failures go back to the generator that made them.

**What this looks like:**

- "Make the workspace remember this across all my projects automatically." There is no automatic promotion. The system asks you to promote it explicitly.
- "Have the verifier rewrite the failing code." The verifier only detects. The fix goes back to the implementer.

**What to do instead:** use the explicit, deterministic path. Name the file or keyword to retrieve. Ask for an explicit promotion. Or send the fix to the right generator.

---

## 4. When the artefacts disagree with the conversation, the artefacts win

This case surprises people most. The canonical artefacts on disk are the **single source of truth**. They are the initiative's `proposal.md`, `tasks.md`, `verification/` and the source files. The chat history is not a source of truth.

The rule is explicit: **artefacts in `.workspace/` are authoritative. When in doubt, read them. Do not rely on conversation memory.** When memory and a canonical artefact disagree, **the canonical artefact wins**. Memory never competes with it as a source of truth. The memory layer only **points to** canonical content by path or anchor. It must not restate or copy the authoritative content.

**Why the artefacts win, and why this is good:**

- **They are durable and auditable.** A long session forgets its early history as the context window fills. A file does not. A file you can trust over fuzzy recall keeps the system consistent across days, resets and compactions.
- **They are versioned.** Artefacts live in git, so you can review and revert every change. Conversation is not versioned.
- **It prevents drift.** If chat could silently override the spec, two runs of the "same" instruction could differ. Pinning truth to the written artefact makes the system deterministic.

When a claim disagrees with an artefact, the system **shows the conflict. It never silently merges or auto-resolves it.** This holds for every kind of conflict the system tracks:

- a shared claim against the live working tree
- a shared claim against the canonical artefact
- a shared claim against the initiative's own memory
- two shared claims that contradict each other

No instruction permits the system to silently adopt or merge an unverified claim over what the artefacts say.

**What this looks like:**

- You remember that you agreed in chat to a scope that the proposal does not contain. The system goes by the proposal and flags the mismatch. It does not act on the remembered version.
- A shared lesson from another project contradicts the `proposal.md` of this initiative. The system shows you the conflict so that you can resolve it. It does not quietly merge the outside claim.

**What to do instead:** if the conversation is right and the artefact is out of date, **update the artefact**. That is the fix. A change to the proposal is a job for `proposal-writer`, and `task-checker` then checks the proposal again. When the artefact matches the new facts, the disagreement is gone. Everything now traces to the updated artefact.

---

## 5. It refuses work the ticket did not ask for

The ticket sets the boundary of the work. Sometimes a proposal holds something that the ticket never asked for. Then `task-checker` FAILs it. This can feel harsh when the extra item is a good idea. But this is how scope grows without notice. Each addition looks small on its own. Together they turn a small ticket into a large change that nobody reviewed.

Two ways past the boundary stay open. Something that the ticket cannot be finished without is in scope. So is a repair of what this change itself makes wrong. The proposal must name both as what they are. Then you can see the extra work and agree to it. Silence about it is also a FAIL. The rule and its two exceptions live in one place: `agents/proposal-writer.md`.

**What this looks like:**

- The proposal tidies a nearby module that the ticket never mentioned. The checker FAILs it, and the fix goes back to `proposal-writer`.
- The proposal includes a true dependency and says nothing about it. The checker FAILs it because the claim is missing.

**What to do instead:** take the extra item out and give it its own ticket. Or, if it belongs to one of the two exceptions, have `proposal-writer` say so plainly in the proposal.

---

## In short

| You see this | Why | Do this |
|---|---|---|
| It will not plan or build on a FAILed proposal | Gates before progress. Checkers only detect. | Let the fix go back to the generator, then check again |
| It asks you to clarify | Roles stay separate. It will not guess. | Clarify, or fix the acceptance criteria in the proposal |
| It will not "search by meaning" or remember on its own | Retrieval uses keywords only. There is no automatic promotion. | Use explicit paths or keywords. Promote explicitly. |
| It trusts the file over the chat | Canonical artefacts are authoritative | Update the artefact so that it matches the facts |
| It will not build what the ticket did not ask for | The ticket sets the scope boundary | Raise a separate ticket, or name the exception in the proposal |

Each refusal is the system keeping its promises. For the invariants behind these behaviours, read [design-principles.md](./design-principles.md).
