# Claude Workspace

![version](https://img.shields.io/badge/version-1.21.0-brightgreen)

Claude Workspace turns any folder into a place where ideas get built right. You talk to it
in plain language. It researches your idea, turns it into a spec, plans the work, and builds
it. Independent, adversarial checks catch drift from what you agreed, before you ship.
Every decision lands in a plain file that you can read, search, and revert.
So the work is traceable and does not drift. A multi-day project picks up where you left off.
Everything is plain markdown files in git. You install only the plugin and run nothing else.

**Build the right thing, and prove it.**

---

## The pains it kills

- **"The AI confidently built the wrong thing."** Claude Workspace refuses to guess. Every
  step traces to a written spec. Agents stop and ask. They do not improvise.
- **"I lose the thread on a multi-day project."** Plans, decisions, and progress live in
  plain files on disk. Leave it for days. Then reload where you left off, with no re-explaining.
- **"The plan quietly drifted from the spec."** The proposal is the root of truth. Tasks
  trace to it. An adversarial checker flags drift in the proposal before anyone plans or builds.

---

## Why not just prompt Claude directly?

Prompting Claude is a conversation. Claude Workspace is a conversation with a memory, a spec,
an auditor, and a paper trail.

Raw prompting has predictable failure modes. This is how Claude Workspace addresses each one:

- **Drifts over a long session.** Chat loses early decisions. Claude Workspace keeps a
  written proposal as the single root of truth. Every agent answers to it, not to the
  current conversation.
- **Guesses when uncertain.** One agent improvises. Claude Workspace refuses to guess by
  design. Agents stop and surface ambiguities. They do not invent an answer.
- **No audit trail.** A transcript is not a record. Every decision is a plain file that
  you can search and revert. The git history is the audit trail.
- **Marks its own homework.** In Claude Workspace, checkers are separate agents with
  read-only tools. A FAIL routes back to whoever owns the work. No one patches it silently.

A caveat: the control here is convention-backed discipline plus a few tool locks. It is
not a sandboxed runtime. Claude Workspace reduces and surfaces errors. It does not
guarantee correct output and is not a substitute for human review.

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

See [CHANGELOG.md](CHANGELOG.md) for release history.

This plugin is centrally maintained by the author. To stay current, run:

```text
/plugin marketplace update pocdoc-workspace
/reload-plugins
```

We encourage you to update. New versions fix issues and improve agents. Do not change your
local copy. An update overwrites local changes. The plugin is not open for contributions,
pull requests, or forks. The intended workflow is to install, use, and update.

The [install guide](plugins/claude-workspace/docs/install.md) has the full steps. It covers
the private marketplace add, sign-in, manual and background updates, and the `Write`,
`Edit` and `Bash` permissions that the executor agents need. For the big picture, start with
[concepts](plugins/claude-workspace/docs/concepts.md). The full docs index is at
[`plugins/claude-workspace/README.md`](plugins/claude-workspace/README.md).

---

## The agents

You drive one orchestrator skill (`/claude-workspace:workspace`) in plain language. It routes
your requests and keeps the artefacts as the source of truth. Behind it are eight
subagents, and each has one job. The skills table in
[`plugins/claude-workspace/README.md`](plugins/claude-workspace/README.md) lists the skills.

| Agent | What it does for you |
|---|---|
| Research Harvester | Reads and surfaces relevant context (docs, existing code, prior decisions), so the spec has a base in fact. |
| Proposal Writer | Turns research into a written proposal that you agree on. This proposal is the root of truth for every later step. |
| Task Planner | Breaks the proposal into a traceable task list; each task maps back to a proposal acceptance criterion. |
| Task Checker | Read-only. Checks the proposal for drift and gaps before any planning starts. A FAIL goes to the Proposal Writer. |
| Implementer | Builds to spec, one task at a time. The proposal and the task definition are the only authorities. |
| Implementation Verifier | Read-only. Checks the build against the task definition after implementation. A FAIL goes back to the Implementer. |
| Context Recovery | Rebuilds project state when context is lost or drifting. It is read-only and reports only what exists. |
| Archivist | Keeps the file tree clean and predictable. It moves and renames files and creates directories. It never edits file content. |

Read-only agents (Task Checker, Implementation Verifier) have no tool to write to your codebase.
This is the one mechanical guardrail. For the agent contract, see
[why it refuses](plugins/claude-workspace/docs/why-it-refuses.md) and
[design principles](plugins/claude-workspace/docs/design-principles.md).

Each agent has its own model. The install guide section
[Per-agent models / cost](plugins/claude-workspace/docs/install.md#per-agent-models--cost)
gives the source of the values, the override steps, and the fallback rules.

The orchestrator follows a plain-voice rule. It uses short sentences and common words. It
explains each term before use. It collects its questions into one batch.
It asks the questions that need you after research and before the proposal draft. It formats
them with the `ask` skill. A late answer changes only the affected proposal lines. The check
covers only those lines. One proposal check cycle has at most three checks.

---

## Limits

Claude Workspace is not a sandboxed runtime. It does not guarantee correct output. It is not a
substitute for human review. See
[What this is NOT](plugins/claude-workspace/README.md#what-this-is-not) in the bundled plugin
README. The full list of known gaps is in
[docs/limitations.md](plugins/claude-workspace/docs/limitations.md).

The author maintains this plugin. It is not open for contributions, pull
requests, or forks. Do not modify your local copy. An update overwrites local changes.

---

## Layout

One repo has two roles. It is a private plugin **marketplace** (`pocdoc-workspace`) and the
plugin that it ships (`claude-workspace`). The full documentation is inside the plugin.

```text
.
|-- .claude-plugin/
|   `-- marketplace.json            # marketplace: pocdoc-workspace
|-- .github/                        # CI checks and workflows
|-- benchmark/                      # benchmark files
|-- CHANGELOG.md                    # release history
`-- plugins/
    `-- claude-workspace/           # the plugin
        |-- .claude-plugin/plugin.json
        |-- skills/                 # all 10 skills
        |-- agents/                 # the 8 subagents
        |-- hooks/                  # hook scripts and hooks.json
        |-- scripts/                # statusline scripts
        |-- docs/                   # the docs set
        `-- README.md               # bundled docs index
```

---

## License

Private, all rights reserved (interim). We will review this if the plugin moves to a shared organisation.
