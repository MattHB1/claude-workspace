# Limitations / what this is NOT

Claude Workspace is deliberately small and honest about its boundaries. Knowing
what it does **not** do is part of using it well: it lets you keep the right
expectations, stay in the loop where the system needs you, and not reach for a
button that was never built.

This page lists only **real** limitations of the system as it actually ships
today. Each one is grounded in how the skill and the agents behave. For the
positive side -- the invariants that make it strict on purpose -- see
[design-principles.md](./design-principles.md) and
[why-it-refuses.md](./why-it-refuses.md).

---

## It is a prompt / markdown system, not a runtime

The workspace is a skill plus eight agent definitions written in markdown. The
"determinism" it promises is **convention-backed discipline**, not a sandbox that
mechanically blocks every misstep. The one place where there is a real, mechanical
guardrail is the agents' **tool locks**: the read-only adversaries
(`task-checker`, `implementation-verifier`, `research-harvester`,
`context-recovery`, `archivist`) ship with only `Read`/`Glob`/`Grep` tools, so they
literally cannot `Write`/`Edit`. Everything else -- single-responsibility routing,
single-writer ownership of artefacts, "don't restate the canonical payload" -- is
enforced by the rules in the prompt, which the model follows but can still get
wrong.

What this means for you:

- Treat the system as a disciplined collaborator, not an infallible machine.
- The `trust` marker on memory entries (`verified` vs `asserted`) exists precisely
  because claims can be wrong; re-verify rather than trust.
- There is no external service, daemon, scheduler, or database backing any of this.

## Single active initiative at a time (no parallel-active)

The registry (`.workspace/initiatives.md`) enforces a **single-active rule**:
whenever at least one initiative exists, **exactly one** is ACTIVE -- never two.
You can hold many initiatives in a project and **switch** between them, but you
cannot have two active at once and steer them in parallel. Switching only moves the
ACTIVE marker; no files move. See [initiatives.md](./initiatives.md).

## No first-class delete verb (deletion is manual)

The only built-in initiative verbs are **create / switch / list**. There is **no**
built-in delete (or rename) verb. Removing an initiative is a **manual** action:
remove its entry from the registry and delete its `<slug>/` directory by hand. The
docs never present a delete command, because one does not exist. See
[initiatives.md](./initiatives.md) for the honest manual path.

## Memory promotion is manual, never automatic

Knowledge enters the cross-project shared tier (`~/.claude/shared-memory/`) **only
by an explicit promotion decision** made by the orchestrator, on your instruction
or on a surfaced candidate. There is **no automatic / on-recurrence promotion** of
any kind. Read-only agents can surface "this looks reusable" candidates as returned
content, but they never write the shared tier. See [memory.md](./memory.md).

## Memory retrieval is keyword / grep, not semantic

All memory retrieval -- per-initiative and cross-project -- is by **explicit path,
filename/dir convention, or `grep`/`glob`** over the files. There is **no semantic
search, no vector store, no embeddings, no similarity ranking**. This is an
accepted tradeoff for determinism, auditability, and zero infrastructure. The
practical cost: across unrelated projects the **keyword miss-rate is higher** than
within a single project -- if you do not use the words that were written down, the
search can miss a relevant claim. See [memory.md](./memory.md).

## Read-only agents cannot self-fix

The adversarial checkers and the other read-only agents **detect only -- they never
fix**, and they deliberately have no `Write`/`Edit` tools to do so. When a checker
FAILs something, the correction does not get patched in place: a failed plan routes
back to `task-planner`, a failed implementation routes back to `implementer`. No
agent fixes another agent's output. This is by design (see
[design-principles.md](./design-principles.md)), but it does mean a FAIL is a
**round trip**, not an in-place repair.

## Executor agents need pre-authorized tools

The `implementer` (and the verifier that runs tests) need `Write`/`Edit`/`Bash`
access to do their job. Those permissions are granted by you in your Claude Code
settings -- they are not something the workspace can grant itself. If the required
tools are not pre-authorized, the work simply cannot proceed. See
[install.md](./install.md) and [troubleshooting.md](./troubleshooting.md).

## Background agents cannot answer permission prompts

A background agent runs detached and **cannot respond to an interactive permission
prompt**. If a tool it needs is not already authorized, the prompt has no one to
answer it and the action stalls. Pre-authorize the tools it needs, or run the work
in the foreground where you can approve prompts. See [install.md](./install.md).

## It is NOT a CI system or a hosted service

The workspace is a set of local markdown files checked into your repos. It does
**not** run continuous integration, it is **not** a hosted/managed service, and it
does not run a build/test pipeline for you on a schedule. Verification happens when
**you** dispatch a verifier; the gates are things you run, not a server that runs
them. Versioning comes "for free" from git -- there is no separate versioning
mechanism.

## It is NOT a substitute for human review

The adversarial checkers reduce mistakes; they do not eliminate them, and they are
not a stand-in for your judgement. The system is built to **keep you in the loop**
at every handoff -- it surfaces gates and conflicts and lets you decide, rather than
auto-resolving. When a shared claim disagrees with reality, the conflict is
**surfaced, never silently merged**; resolving it is your call.

## It is NOT a guarantee of correctness

Determinism and traceability are not the same as correctness. The same inputs
produce the same auditable outputs, and every claim is path-referenced and
trust-marked -- but a plan can still be wrong, a `verified` re-check can still miss
something, and a shared claim is **evidence, not ground truth**. Re-validate
claims in the new context before acting on them. The point of the trust markers,
the surfacing, and the human-in-the-loop handoffs is to make errors **visible and
recoverable**, not to promise they never happen.
