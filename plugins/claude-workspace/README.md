# claude-workspace

![version](https://img.shields.io/badge/version-1.3.0-brightgreen)

Claude Workspace turns any folder into a place where ideas get built right. You talk to it
in plain language; it researches your idea, turns it into a spec, plans the work, and builds
it -- and independent, adversarial checks catch when the plan or build drifts from what you
agreed, before you ship. Every decision lands in a plain file you can read, grep, and revert.
So the work is traceable, it doesn't drift, and even a multi-day project picks up exactly
where you left off.

**Build the right thing, and prove it.**

---

## What it's good for

- **"The AI confidently built the wrong thing."** Claude Workspace refuses to guess. It stops
  and asks, traces every step back to a written spec, and flags when the build doesn't match
  what you agreed on -- before you ship.
- **"I lose the thread on a multi-day project."** Plans, decisions, and progress live in plain
  files on disk. Drop a project for days; reload exactly where you left off, no re-explaining.
- **"The plan quietly drifted from the spec."** The proposal is the root of truth. Every task
  traces to it, and an adversarial checker flags drift before a single line is built.
- **"I can't trust the output, and there's no way to check."** Every decision is a versioned
  file with one named owner. The agents that review your work are tool-locked read-only --
  they literally cannot edit what they review.

---

## Why not just prompt Claude directly?

Prompting Claude is a conversation; Claude Workspace is a conversation with a memory, a spec,
an auditor, and a paper trail.

Raw prompting has predictable failure modes -- and this is how Claude Workspace addresses each:

- **Drifts over a long session** -- chat loses early decisions. Claude Workspace keeps a
  written proposal as the single root of truth; every agent answers to it, not to the
  current conversation.
- **Guesses when uncertain** -- one agent improvises. Claude Workspace refuses-to-guess by
  design: agents stop and surface the ambiguity rather than inventing an answer.
- **No audit trail** -- a transcript is not a record. Every decision is a plain file you can
  grep and revert; the git history is the audit trail.
- **Marks its own homework** -- the same agent that writes the plan checks the plan. In
  Claude Workspace, checkers are entirely separate agents, tool-locked read-only. A FAIL
  routes back to whoever owns the work; it cannot be silently patched.
- **Forgets between sessions** -- you re-explain every time. The per-initiative journal and
  index reload only what matters, so you pick up where you left off.

Honest caveat: determinism here is convention-backed discipline plus a few real tool-locks,
not a sandboxed runtime. Claude Workspace reduces and surfaces errors; it does not guarantee
correct output and is not a substitute for human review.

---

## How it feels to use

You invoke the orchestrator with `/claude-workspace:workspace` and then just talk to it.

Say "research this idea" -- the Researcher agent reads the relevant context and surfaces what
it finds. Then "spec it out" -- the Spec Writer turns the research into a written proposal
you agree on. Next, "plan the work" -- the Planner breaks the spec into a task list that
traces back to it. Before any building starts, "check the plan" -- the Task Checker (a
separate, read-only agent) flags anything that has drifted from the proposal.

Now you build: "implement task 1" -- the Implementation agent writes the code, to spec. Then
"verify it" -- the Verifier (also read-only, also tool-locked) checks the build against the
task definition. If it finds a gap, the failure goes back to the Implementation agent to fix,
not to the Verifier to quietly patch.

You run only the stages you need. It's a map, not a track.

---

## What you get that you can trust

- **Detect-only, tool-locked checkers.** The agents that review your plan and build cannot
  edit what they review. A failure routes back to the generator -- no silent patching.
- **Single-writer + git audit trail.** Every decision is a versioned file with one named
  owner. The git history is the audit trail; every change is attributable and revertible.
- **Proposal as root of truth.** One spec that everything answers to. "Done" means the same
  thing at every stage. Traceability is structural, not a convention you hope people follow.
- **Artefacts win over chat.** Your written record is stable across session resets and
  context compaction. The artefact is the source of truth; the transcript is a byproduct.
- **No infra to babysit.** Everything is flat markdown files in git. Nothing to install,
  run, or maintain beyond the plugin itself.
- **Refuses to guess.** When an agent hits an ambiguity it can't resolve from the artefacts,
  it stops and asks rather than inventing an answer.

---

## The agents

Each agent has a single job. Read-only agents are tool-locked so they cannot write to your
codebase even if prompted to. See [docs/workflow.md](docs/workflow.md) for the full intent
and command table.

| Agent | What it does for you |
|---|---|
| Orchestrator | Routes your instructions to the right specialist; keeps artefacts as the source of truth throughout the session. |
| Researcher | Reads and surfaces relevant context -- docs, existing code, prior decisions -- so the spec is grounded. |
| Spec Writer | Turns research into a written proposal you agree on; this becomes the root of truth every subsequent step answers to. |
| Planner | Breaks the proposal into a traceable task list; each task maps back to a proposal acceptance criterion. |
| Task Checker | Read-only, tool-locked. Flags drift between the plan and the proposal before any building starts. Failures route to the Planner. |
| Implementation Agent | Builds to spec, one task at a time, with the proposal and task definition as the only authorities. |
| Verifier | Read-only, tool-locked. Checks the build against the task definition after implementation. Failures route back to the Implementation Agent. |
| Journal Agent | Maintains the per-initiative journal and index so sessions stay coherent across reloads. |

---

## Skills

Four methodology skills ship with the plugin. Invoke them directly in a Claude Code session:

| Skill | What it does |
|---|---|
| `/claude-workspace:ideate` | Structured ideation: Frame → Diverge → Adversarial-challenge → Converge. |
| `/claude-workspace:decide` | Decision process: surface options, stress-test, and converge on a recorded choice. |
| `/claude-workspace:plan` | Planning methodology: decompose a goal into a traceable, reviewable task structure. |
| `/claude-workspace:reflect` | Reflection methodology: review what happened, extract learnings, and record them. |

These are general-purpose methodology skills. They are independent of any active initiative and can be invoked at any time.

---

## What this is NOT

- **Not a sandboxed runtime.** The determinism here is convention-backed discipline plus a
  few real tool-locks (the read-only agents). There is no mechanical isolation around the
  full build. Reduces and surfaces errors; does not guarantee correctness.
- **Not a substitute for human review.** Adversarial checks catch common failure modes; they
  do not catch everything. You still review the output.
- **Not total recall.** Session memory is bounded: the journal reloads approximately the
  most recent entries plus an index. Retrieval is keyword-based (grep-style), not semantic.
  There is no semantic search.
- **Not built for multiple active initiatives.** One initiative is active at a time. There
  is no built-in delete -- closing an initiative is a manual step.
- **Not automatic cross-project learning.** Promoting a pattern from one project to another
  is a deliberate, manual step. Nothing propagates automatically; you choose what carries
  over and re-validate it.
- **Not open for modification.** This plugin is centrally maintained by the author. Do not
  modify your local copy -- local changes are overwritten on update. It is not open for
  contributions, pull requests, or forks. (Updating is a different matter; see below.)

---

## Quickstart

Full setup guide (auth, permissions, per-agent models, distribution model) is in
[docs/install.md](docs/install.md). Here is the short version.

In a Claude Code session, run the three install commands:

```
/plugin marketplace add vitalsignssolutionsltd/claude-workspace
/plugin install claude-workspace@pocdoc-workspace
/reload-plugins
```

Then start the orchestrator:

```
/claude-workspace:workspace
```

### Staying current

This plugin is centrally maintained by the author. To stay current, run:

```
/plugin marketplace update
/reload-plugins
```

Updating is encouraged -- new versions fix issues and improve agents. What is discouraged is
modifying your local copy: local changes are overwritten on update, and the plugin is not
open for contributions, pull requests, or forks. Install, use, update -- that is the intended
workflow.

---

## Documentation

The full guide is split into focused pages under `docs/`:

| Page | What it covers |
|---|---|
| [docs/concepts.md](docs/concepts.md) | Glossary of core terms; how a project differs from an initiative and how the registry maps them. |
| [docs/design-principles.md](docs/design-principles.md) | The six invariants stated as the contract that explains why the system behaves and refuses as it does. |
| [docs/why-it-refuses.md](docs/why-it-refuses.md) | What the system will NOT do -- unsafe, ambiguous, and non-deterministic requests -- and why refusal is expected. |
| [docs/workflow.md](docs/workflow.md) | The intent/command table (what you say -> which agent) and the optional, conversational stage flow. |
| [docs/initiatives.md](docs/initiatives.md) | Initiative naming, slugs, switching, the registry and single-active rule, and honest (manual) deletion. |
| [docs/memory.md](docs/memory.md) | The per-initiative and cross-project memory tiers: when to use, how to promote and inspect, and namespace opt-out. |
| [docs/safety-and-compliance.md](docs/safety-and-compliance.md) | The safety posture as a feature: PII gates, distribution gates, repo-wide greps, and SAC-style checks. |
| [docs/install.md](docs/install.md) | Full operational guide: private marketplace add, auth, manual vs background updates, permissions, distribution. Per-agent models (cost-optimized: opus / sonnet / haiku per agent) with override and degradation instructions. |
| [docs/statusline.md](docs/statusline.md) | Opt-in statusline that shows the active initiative in your Claude Code prompt. |
| [docs/troubleshooting.md](docs/troubleshooting.md) | Fixes for permission errors, missing tools, marketplace auth, and the two "why did it refuse" cases. |
| [docs/limitations.md](docs/limitations.md) | Known gaps and what the system is NOT (no semantic retrieval, no auto-promotion, no built-in delete, and more). |
| [docs/ideation-spiral.md](docs/ideation-spiral.md) | How to use the ideation spiral (triggers, the Frame→Diverge→Challenge→Converge loop, convergence gate), its capabilities and boundaries, and how to thread `ideation.md` downstream into the pipeline or export it externally. |
