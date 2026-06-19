# Claude Workspace

**Claude Workspace turns any folder into a deterministic, multi-agent workspace that audits and
documents itself.** You work conversationally: it takes your ideas, researches them, and turns them
into verified implementation plans -- with every plan and every result covered by independent,
adversarial checks. The output isn't limited to code; it can be whatever the work needs -- a spec,
docs, a migration, a config, a refactor, a plan.

*Deterministic* describes the workspace, not the model's creativity: it never guesses where things
live or leans on whatever happens to be left in the chat. Artefacts are explicit files, retrieval is
by path and `grep` (no fuzzy recall or embeddings), and each artefact has exactly one writer -- so the
work stays auditable and doesn't drift across a long session. It is *self-documenting* because the
proposal, task list, verification reports, and decision journal **are** the project record, written
as the work happens. It is *self-auditing* because adversarial checkers grade every plan and build,
and only *detect* -- fixes route back to whoever produced the work.

Behind the conversation: one orchestrator skill (`/claude-workspace:workspace`) routes your natural
requests to eight single-responsibility subagents (research -> proposal -> planning -> adversarial
check -> implementation -> verification), keeping canonical, versioned artefacts as the single source
of truth.

This repository is both the (private) plugin **marketplace** (`matt-workspace`) and the plugin
(`claude-workspace`). Full documentation ships inside the plugin: see the bundled docs index at
[`plugins/claude-workspace/README.md`](plugins/claude-workspace/README.md).

---

## The agents

You drive one orchestrator skill (`/claude-workspace:workspace`) in plain language; it routes and
holds the line on determinism, and never does the specialist work itself. Behind it are eight
single-responsibility subagents, each running in a fresh, isolated session:

| Agent | Role | Learn more |
|---|---|---|
| `research-harvester` | Gather prior art, examples, and risks (read + web only) | [workflow](plugins/claude-workspace/docs/workflow.md) |
| `proposal-writer` | Turn an idea into the canonical proposal (the root of truth) | [concepts](plugins/claude-workspace/docs/concepts.md) |
| `task-planner` | Decompose the proposal into atomic, ordered, traceable tasks | [workflow](plugins/claude-workspace/docs/workflow.md) |
| `task-checker` | Adversarially check the plan against the proposal (detect only) | [design principles](plugins/claude-workspace/docs/design-principles.md) |
| `implementer` | Execute exactly one task, no reinterpretation | [workflow](plugins/claude-workspace/docs/workflow.md) |
| `implementation-verifier` | Adversarially verify an implementation vs its task (detect only) | [design principles](plugins/claude-workspace/docs/design-principles.md) |
| `context-recovery` | Rebuild project state when you have lost the thread | [concepts](plugins/claude-workspace/docs/concepts.md) |
| `archivist` | Move and organize files (never edits content) | [workflow](plugins/claude-workspace/docs/workflow.md) |

Checkers and verifiers only *detect* deviations; corrections route back to the originating
generator, never patched by the grader. See
[why it refuses](plugins/claude-workspace/docs/why-it-refuses.md) and
[design principles](plugins/claude-workspace/docs/design-principles.md) for the contract behind this.

---

## Quickstart

You need read access to this repository. In Claude Code:

```text
/plugin marketplace add MattHB1/claude-workspace
/plugin install claude-workspace@matt-workspace
/reload-plugins
```

Then start the orchestrator and talk to it:

```text
/claude-workspace:workspace
```

For the full operational walkthrough -- private marketplace add, auth, manual vs background updates,
shared-not-secret distribution, and the `Write`/`Edit`/`Bash` permissions the executor agents need --
see [install](plugins/claude-workspace/docs/install.md). For the big picture, start with
[concepts](plugins/claude-workspace/docs/concepts.md) and the bundled docs index at
[`plugins/claude-workspace/README.md`](plugins/claude-workspace/README.md).

---

## Layout

```text
.
|-- .claude-plugin/
|   `-- marketplace.json            # marketplace: matt-workspace
`-- plugins/
    `-- claude-workspace/           # the plugin
        |-- .claude-plugin/plugin.json
        |-- skills/workspace/SKILL.md
        |-- agents/                 # the 8 subagents
        |-- docs/                   # the docs set
        `-- README.md               # bundled docs index
```

## License

Private / all rights reserved (interim). To be revisited if/when this moves to a shared org.
