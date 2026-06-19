# Claude Workspace

A deterministic, multi-agent **workspace for Claude Code**. You talk to a single orchestrator
conversationally; it routes your requests to eight single-responsibility subagents that take a
software idea from **research → proposal → planning → adversarial review → implementation →
verification** — with canonical, versioned artefacts as the single source of truth.

This repository is both the (private) plugin **marketplace** (`matt-workspace`) and the plugin
(`claude-workspace`).

---

## What it does

- **Orchestrator skill** — `/claude-workspace:workspace`. You drive it in plain language; it
  *routes* and holds the line on determinism. It never does the specialist work itself.
- **8 single-responsibility subagents**, each a fresh, isolated session:
  | Agent | Role |
  |---|---|
  | `research-harvester` | Gather prior art, examples, risks (read + web only) |
  | `proposal-writer` | Turn an idea into the canonical proposal (the root of truth) |
  | `task-planner` | Decompose the proposal into atomic, ordered, traceable tasks |
  | `task-checker` | Adversarially check the plan against the proposal (detect only) |
  | `implementer` | Execute exactly one task, no reinterpretation |
  | `implementation-verifier` | Adversarially verify an implementation vs its task (detect only) |
  | `context-recovery` | Rebuild project state when you've lost the thread |
  | `archivist` | Move/organize files (never edits content) |
- **Initiative-scoped artefacts** — each initiative lives under `.workspace/<slug>/`
  (`proposal.md`, `tasks.md`, `research/`, `verification/`, `memory/`), tracked by a registry so a
  project can host several initiatives without collisions.
- **Adversarial verification** — checkers and verifiers only *detect* deviations; corrections route
  back to the generator, never patched by the grader.
- **Working memory** — a per-initiative journal + index (so long efforts survive context limits),
  plus an optional cross-project shared-memory tier for durable, reusable lessons.

After install, the skill appears as `/claude-workspace:workspace` and the agents as
`claude-workspace:<name>` in `/agents`.

---

## Install (private)

You need read access to this repository. In Claude Code:

```text
/plugin marketplace add MattHB1/claude-workspace
/plugin install claude-workspace@matt-workspace
/reload-plugins
```

- Manual updates: `/plugin marketplace update matt-workspace` (uses your own git credentials).
- Background auto-update of a private remote needs a `GITHUB_TOKEN` in your environment.
- **Executor agents** (`implementer`, `archivist`) need `Write`/`Edit`/`Bash`. Grant these via a
  `settings.local.json` `allow` entry, or approve the interactive prompts. See the bundled guide
  (`plugins/claude-workspace/README.md`) for the exact entry — background agents can't answer
  permission prompts.

---

## Use

Start the orchestrator:

```text
/claude-workspace:workspace
```

Then just talk to it. It recognizes intents like:

| You say… | It does |
|---|---|
| `new initiative <name>` · `switch to <name>` · `list initiatives` | Manage initiatives in the registry |
| `research <topic>` | → `research-harvester`, saves a brief |
| `spec it` / `write the proposal` | → `proposal-writer` writes `proposal.md` |
| `plan it` / `break it down` | → `task-planner` writes `tasks.md` |
| `check the plan` | → `task-checker` (adversarial) |
| `build task N` | → `implementer` (one task, fresh session) |
| `verify it` | → `implementation-verifier` (adversarial) |
| `where are we` | → `context-recovery` re-syncs state |
| `tidy the files` | → `archivist` reorganizes |

A typical flow: `new initiative <x>` → `research …` → `spec it` → `plan it` → `check the plan` →
`build task 1` → `verify it` → repeat. The orchestrator keeps you in the loop at each handoff.

> **Full guide:** see [`plugins/claude-workspace/README.md`](plugins/claude-workspace/README.md) for
> the complete walkthrough — the artefact layout, the memory tiers, permissions, and the workflow in
> detail.

---

## Layout

```text
.
├── .claude-plugin/
│   └── marketplace.json            # marketplace: matt-workspace
└── plugins/
    └── claude-workspace/           # the plugin
        ├── .claude-plugin/plugin.json
        ├── skills/workspace/SKILL.md
        ├── agents/                 # the 8 subagents
        └── README.md               # full usage guide
```

## License

Private / all rights reserved (interim). To be revisited if/when this moves to a shared org.
