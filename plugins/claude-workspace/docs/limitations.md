# Limitations / what this is NOT

Claude Workspace is small on purpose. This page states its limits plainly.
Knowing what it does **not** do helps you keep the right expectations. It also
helps you stay in the loop where the system needs you. You will not look for a
button that does not exist.

This page lists only **real** limitations of the system as it ships today. Each
one comes from how the skill and the agents behave. For the positive side, see
[design-principles.md](./design-principles.md) and
[why-it-refuses.md](./why-it-refuses.md). These pages explain the invariants that
make the system strict on purpose.

---

## It is a prompt / markdown system, not a runtime

The workspace is a skill plus eight agent definitions written in markdown. The
"determinism" it promises is **convention-backed discipline**. It is not a
sandbox that blocks every misstep.

The one mechanical guardrail is the tool list of each agent. An agent can use
only the tools on its `tools:` line. Some agents have no `Write` or `Edit` tool,
so they cannot change files. The master list is the `tools:` line (line 4) in
each file of `plugins/claude-workspace/agents/`.

Everything else is a rule in the prompt. This covers single-responsibility
routing, single-writer ownership of artefacts, and "do not restate the canonical
payload". The model follows these rules, but it can still get them wrong.

What this means for you:

- Treat the system as a disciplined collaborator. It is not an infallible machine.
- Claims can be wrong. For this reason, memory entries carry a `trust` marker
  (`verified` or `asserted`). Re-check a claim before you rely on it.
- No external service, daemon, scheduler or database backs any of this.

## Session markers and parallel sessions

Each session picks its own initiative. The pick lives in a per-session marker in
`~/.claude/.workspace-active/`. These limits apply.

- **Stale markers after a crash.** A crash can leave a marker behind. The marker
  blocks that initiative for other sessions. Check whether the session that the
  block names has ended. If it has, tell the orchestrator that the other session
  has ended. The orchestrator deletes the stale marker and continues. Without your
  statement, the block stays. A normal session end deletes its own marker. The
  24-hour sweep removes old markers.
- **Two sessions cannot work on one initiative.** The block stops the second pick.
- **Parallel sessions use different branches or worktrees.** Two live sessions
  never share one checkout. Take a main-locked repo where another live session has
  the same shared root and the same checkout. There, the orchestrator makes a git
  worktree for the second session. It stops and reports when git refuses the
  worktree. It never forces one.
- **A main-allowed repo has one live workspace session.** A repo is main-allowed
  when `.workspace/main-commits` holds the word `allowed`. The plugin never makes a
  worktree there. A second session gets a block until the first session ends.

See [initiatives.md](./initiatives.md).

## No first-class delete verb (deletion is manual)

The only built-in initiative verbs are **create / switch / list**. There is **no**
built-in delete or rename verb. You remove an initiative by hand. Remove its entry
from the registry, then delete its `<slug>/` directory. The docs show no delete
command, because none exists. See [initiatives.md](./initiatives.md) for the manual
steps.

## Memory promotion is manual, never automatic

Knowledge enters the cross-project shared tier (`~/.claude/shared-memory/`)
**only through an explicit promotion decision**. The orchestrator makes that
decision on your instruction or on a candidate that it shows you. There is **no
automatic promotion** of any kind. Read-only agents can return "this looks
reusable" candidates as content. They never write the shared tier. See
[memory.md](./memory.md).

## Memory retrieval is keyword / grep, not semantic

All memory retrieval works by **explicit path, filename or directory convention,
or `grep` and `glob`** over the files. This covers per-initiative memory and
cross-project memory. There is **no semantic search, no vector store, no
embeddings and no similarity ranking**. The tradeoff gives you determinism,
auditability and zero infrastructure. It has a cost. Across unrelated projects,
the **keyword miss-rate is higher** than inside one project. If you do not use the
words that were written down, the search can miss a relevant claim. See
[memory.md](./memory.md).

## Read-only agents cannot self-fix

The adversarial checkers and the other read-only agents **detect only. They never
fix.** They have no `Write` or `Edit` tool, so they cannot patch a file. When a
checker returns FAIL, nobody patches the output in place. A failed proposal check
goes back to `proposal-writer`. A failed implementation check goes back to
`implementer`. No agent fixes the output of another agent. This is by design (see
[design-principles.md](./design-principles.md)). A FAIL is a **round trip**. It is
not an in-place repair.

## Some agents need tools that you pre-authorize

Some agents need tools that can change files or run commands. Agents that change
files need `Write` and `Edit`. Agents that run commands, such as tests, need
`Bash`. You grant these permissions in your Claude Code settings. The workspace
cannot grant them to itself. If a needed tool is not pre-authorized, the work
cannot proceed. The `tools:` line (line 4) in each file of
`plugins/claude-workspace/agents/` shows what each agent can use. See
[install.md](./install.md) and [troubleshooting.md](./troubleshooting.md).

## Background agents cannot answer permission prompts

A background agent runs detached. It **cannot answer an interactive permission
prompt**. If a tool it needs is not yet authorized, nobody answers the prompt and
the action stalls. Pre-authorize the tools it needs. You can also run the work in
the foreground, where you can approve prompts. See [install.md](./install.md).

## It is NOT a CI system or a hosted service

CI means continuous integration, the automatic build and test of each change. The
workspace is a set of local markdown files checked into your repos. It does
**not** run CI. It is **not** a hosted or managed service. It does not run a
build or test pipeline for you on a schedule. Verification happens when **you**
dispatch a verifier. You run the gates yourself, and no server runs them. Git
gives you versioning, so the workspace has no separate versioning mechanism.

## It brings no tracker connection of its own

The plugin does **not** supply or configure a connection to a ticket tracker. It
uses a tracker tool only when your environment already provides one and the tool
is already authorized. With no such tool, the flow still works. You paste the
ticket text, and you make the tracker updates by hand.

## It never closes a ticket

The plugin proposes no close transition and no move to a Done state. Closing
follows review and merge, and that call belongs to a person.

## It is NOT a substitute for human review

The adversarial checkers reduce mistakes. They do not remove them, and they do not
replace your judgement. The system **keeps you in the loop** at every handoff. It
shows you gates and conflicts, and you decide. It does not resolve them on its own.
When a shared claim disagrees with reality, the system **shows the conflict and
never merges it silently**. You resolve it.

## It is NOT a guarantee of correctness

Determinism and traceability are not the same as correctness. The same inputs
give the same auditable outputs. Every claim has a path reference and a trust
marker. Even so, a plan can be wrong, and a `verified` re-check can miss
something. A shared claim is **evidence, not ground truth**. Re-check claims in
the new context before you act on them. The trust markers, the conflict display
and the human handoffs make errors **visible and recoverable**. They do not
prevent every error.
