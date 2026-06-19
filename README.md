# Claude Workspace

A deterministic, multi-agent **workspace for Claude Code**. You talk to a single orchestrator
conversationally; it routes your requests to eight single-responsibility subagents that take a
software idea from **research -> proposal -> planning -> adversarial review -> implementation ->
verification** -- with canonical, versioned artefacts as the single source of truth.

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
