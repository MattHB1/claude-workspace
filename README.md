# Claude Workspace

![version](https://img.shields.io/badge/version-1.10.0-brightgreen)

Claude Workspace turns any folder into a place where ideas get built right. You talk to it
in plain language; it researches your idea, turns it into a spec, plans the work, and builds
it -- and independent, adversarial checks catch when the plan or build drifts from what you
agreed, before you ship. Every decision lands in a plain file you can read, grep, and revert.
So the work is traceable, it doesn't drift, and even a multi-day project picks up exactly
where you left off. Everything is plain markdown files in git -- nothing to install, run,
or maintain beyond the plugin itself.

**Build the right thing, and prove it.**

---

## The pains it kills

- **"The AI confidently built the wrong thing."** Claude Workspace refuses to guess. Every
  step traces to a written spec; agents stop and ask rather than improvise.
- **"I lose the thread on a multi-day project."** Plans, decisions, and progress live in
  plain files on disk. Drop it for days; reload exactly where you left off, no re-explaining.
- **"The plan quietly drifted from the spec."** The proposal is the root of truth. Tasks
  trace to it, and an adversarial checker flags drift before a single line is built.

---

## Why not just prompt Claude directly?

Prompting Claude is a conversation; Claude Workspace is a conversation with a memory, a spec,
an auditor, and a paper trail.

Raw prompting has predictable failure modes -- and this is how Claude Workspace addresses each:

- **Drifts over a long session.** Chat loses early decisions. Claude Workspace keeps a
  written proposal as the single root of truth; every agent answers to it, not to the
  current conversation.
- **Guesses when uncertain.** One agent improvises. Claude Workspace refuses-to-guess by
  design: agents stop and surface ambiguities rather than inventing an answer.
- **No audit trail.** A transcript is not a record. Every decision is a plain file you can
  grep and revert; the git history is the audit trail.
- **Marks its own homework.** In Claude Workspace, checkers are entirely separate agents,
  tool-locked read-only. A FAIL routes back to whoever owns the work -- no silent patching.

Honest caveat: the determinism here is convention-backed discipline plus a few real
tool-locks, not a sandboxed runtime. Claude Workspace reduces and surfaces errors; it does
not guarantee correct output and is not a substitute for human review.

---

## Quickstart

You need read access to this repository. In Claude Code:

```text
/plugin marketplace add vitalsignssolutionsltd/claude-workspace
/plugin install claude-workspace@pocdoc-workspace
/reload-plugins
```

Then start the orchestrator and talk to it:

```text
/claude-workspace:workspace
```

### Staying current

This plugin is centrally maintained by the author. To stay current, run:

```text
/plugin marketplace update
/reload-plugins
```

Updating is encouraged -- new versions fix issues and improve agents. What is discouraged is
modifying your local copy: local changes are overwritten on update, and the plugin is not
open for contributions, pull requests, or forks. Install, use, update -- that is the
intended workflow.

For the full operational walkthrough -- private marketplace add, auth, manual vs background
updates, and the `Write`/`Edit`/`Bash` permissions the executor agents need -- see
[install](plugins/claude-workspace/docs/install.md). For the big picture, start with
[concepts](plugins/claude-workspace/docs/concepts.md) and the full docs index at
[`plugins/claude-workspace/README.md`](plugins/claude-workspace/README.md).

---

## The agents

You drive one orchestrator skill (`/claude-workspace:workspace`) in plain language; it routes
your requests and keeps the artefacts as the source of truth. Behind it are eight
single-responsibility subagents:

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

Read-only agents (Task Checker, Verifier) are tool-locked from writing to your codebase --
the one mechanical guardrail. For the agent contract, see
[why it refuses](plugins/claude-workspace/docs/why-it-refuses.md) and
[design principles](plugins/claude-workspace/docs/design-principles.md).

Models use bare aliases (opus / sonnet / haiku); for the full mapping, override instructions,
and graceful degradation see [install](plugins/claude-workspace/docs/install.md).

---

## Honest limits

Claude Workspace is not a sandboxed runtime, does not guarantee correct output, and is not a
substitute for human review. See
[What this is NOT](plugins/claude-workspace/README.md#what-this-is-not) in the bundled plugin
README, or [docs/limitations.md](plugins/claude-workspace/docs/limitations.md) for the full
list of known gaps.

This plugin is centrally maintained by the author and is not open for contributions, pull
requests, or forks. Do not modify your local copy -- local changes are overwritten on update.

---

## Layout

One repo, two roles: a private plugin **marketplace** (`pocdoc-workspace`) and the plugin it
ships (`claude-workspace`). Full documentation is inside the plugin.

```text
.
|-- .claude-plugin/
|   `-- marketplace.json            # marketplace: pocdoc-workspace
`-- plugins/
    `-- claude-workspace/           # the plugin
        |-- .claude-plugin/plugin.json
        |-- skills/workspace/SKILL.md
        |-- agents/                 # the 8 subagents
        |-- docs/                   # the docs set
        `-- README.md               # bundled docs index
```

---

## License

Private / all rights reserved (interim). To be revisited if/when this moves to a shared org.
