# claude-workspace

A personal pipeline that takes an idea from **research → spec → plan → build → verify**, using strict single-responsibility subagents and adversarial verification. The point: reliable, non-drifting work, with project state kept in flat files so long sessions never "forget."

This repository is both a Claude Code **marketplace** and the **plugin** it ships. It is distributed privately — access is governed by the permissions on the git repository, not by any public listing.

---

## Install (private add)

The marketplace lives in a private git repository, so you install it with your own git credentials. Replace `<owner>/claude-workspace` with the actual private repo you were invited to (or use a full git URL such as `https://github.com/<owner>/claude-workspace.git`).

In a Claude Code session:

```
/plugin marketplace add <owner>/claude-workspace
/plugin install claude-workspace@matt-workspace
/reload-plugins
```

- The first command registers the private marketplace. A git-based marketplace clones the whole repo, so the relative-path plugin source resolves automatically.
- The second installs the plugin (`claude-workspace`) from the marketplace (`matt-workspace`).
- `/reload-plugins` makes the skill and agents available in the current session.

CLI equivalents exist if you prefer them outside a session: `claude plugin marketplace add <owner>/claude-workspace` and `claude plugin install claude-workspace@matt-workspace`.

> The manual `add`/`install` flow uses your existing git credential helpers (for example `gh auth login`, the macOS Keychain, or an SSH key already in your agent). No extra token is needed for the manual path. If you cannot reach the repo, you do not have access — see "Shared, not secret" below.

---

## Usage (namespaced)

Once installed, the orchestrator skill is namespaced under the plugin. Start it with:

```
/claude-workspace:workspace
```

…or just describe what you want once the plugin is loaded. You drive; Claude becomes the **Orchestrator** that routes your instructions to the right specialist agent and keeps the artefacts as the source of truth. It is conversational — say what you need next, not a fixed sequence.

The eight specialist agents are likewise namespaced under the plugin and dispatch as `claude-workspace:<agent>` (for example `claude-workspace:research-harvester`, `claude-workspace:implementer`). You normally never type these — the orchestrator dispatches them for you — but they appear under their namespaced names in `/agents`.

> The first run in a project creates a `.workspace/` folder (with its registry); your first initiative gets its own `.workspace/<slug>/` subfolder and is marked active.

---

## Permissions

Three of the agents are **executors** that actually change files: `claude-workspace:implementer`, `claude-workspace:archivist`, and `claude-workspace:implementation-verifier` (the verifier writes only its reports). They need the `Write`, `Edit`, and `Bash` tools.

**Background agents cannot answer interactive permission prompts.** When the orchestrator dispatches an executor as a background subagent, a tool-permission prompt has nobody to approve it and the dispatch stalls or fails. So a fresh user must grant these tools up front; they are **not** pre-provisioned for you.

You have two options:

1. **Pre-authorize (recommended for background dispatch).** Add a project-level (or user-level) `settings.local.json` with an `allow` list that grants `Write`, `Edit`, and `Bash`. For example, in `.claude/settings.local.json`:

   ```json
   {
     "permissions": {
       "allow": ["Write", "Edit", "Bash"]
     }
   }
   ```

   Scope `Bash` more narrowly if you prefer (for example to specific command prefixes); the executors will prompt for anything not pre-allowed, which is exactly what you want to avoid for background runs.

2. **Interactive-prompt reliance (foreground only).** If you run the agents in the foreground and are present to approve each prompt, you can skip `settings.local.json` and grant `Write`/`Edit`/`Bash` as the prompts appear. This does **not** work for background dispatch.

> Plugin-bundled settings cannot grant these tools — `Write`/`Edit`/`Bash` must be granted in your own `settings.local.json`, not shipped with the plugin.

---

## Shared, not secret

Distribution is private: who can install or update is governed entirely by the permissions on the git repository (collaborators / team membership). Both install and update clone or pull from the remote, so without repo access they simply fail.

Revoking someone's repo access stops their **future** installs and updates. It does **not** delete a copy they have already installed: on install the plugin is copied into a local per-version cache, and that copy keeps working. Treat the shipped markdown as **shared, not secret** once it has been delivered — revocation controls updates, not already-distributed copies.

A recipient who wants to remove it can `/plugin uninstall claude-workspace@matt-workspace` and `/plugin marketplace remove matt-workspace`.

---

## Updates

**Manual update (no token needed).** To pull the latest version from the private remote:

```
/plugin marketplace update matt-workspace
/reload-plugins
```

The manual update path uses your existing git credential helper — the same credentials that let you add the marketplace — so it needs **no** extra environment token.

**Background auto-update (needs a token).** Auto-update is off by default for third-party marketplaces. If you turn it on, the startup auto-update runs **without** your interactive credential helpers, so pulling from a **private** remote requires a credential in the environment. For a GitHub-hosted private remote, export a `GITHUB_TOKEN` (repo scope) in your shell profile, e.g.:

```
export GITHUB_TOKEN=ghp_xxxxxxxxxxxx
```

Without `GITHUB_TOKEN` (or the equivalent for your host), a private-remote auto-update fails silently — stick to the manual `/plugin marketplace update` path instead.

---

## User guide

### What to say (the orchestrator routes it)

| You say… | Goes to | Which… |
|---|---|---|
| "research X" | `claude-workspace:research-harvester` | gathers prior art / risks (read + web only) |
| "spec it" / "write the proposal" | `claude-workspace:proposal-writer` | writes the canonical proposal (root of truth) |
| "plan it" / "break it down" | `claude-workspace:task-planner` | decomposes the proposal into atomic tasks |
| "check the plan" | `claude-workspace:task-checker` | **adversarially** checks tasks vs proposal |
| "build task N" | `claude-workspace:implementer` | implements exactly one task, fresh session |
| "verify it" | `claude-workspace:implementation-verifier` | **adversarially** checks the build vs the task |
| "where are we?" | `claude-workspace:context-recovery` | rebuilds state from the artefacts |
| "tidy the files" | `claude-workspace:archivist` | moves/organises files (never edits content) |

You don't have to run every stage — invoke what you need.

### Initiatives (one workspace, many efforts)

A workspace can hold **many initiatives** — separate efforts in the same project — but **exactly one is active** at a time. Each initiative gets its own subfolder `.workspace/<slug>/` so nothing collides, and a registry (`.workspace/initiatives.md`) tracks them all. Manage them conversationally:

| You say… | What happens |
|---|---|
| "new initiative <name>" | creates `.workspace/<slug>/`, adds it to the registry, marks it active |
| "switch to <name>" | moves the active marker in the registry to that initiative |
| "list initiatives" / "what's in this workspace" | reports every initiative and which one is active, from the registry |

The orchestrator resolves the active initiative's paths and hands them to each agent — the agents themselves stay path-agnostic.

### The rules that make it trustworthy

- **Proposal is the root of truth.** Every task traces to it; every implementation traces to a task.
- **Verifiers never fix.** The two adversarial checkers only *detect*; a failure routes back to the generator (planner or implementer) — never patched in place. (They literally have no write tools.)
- **Single-writer ownership.** Each artefact has exactly one writer.
- **Fresh execution.** Each build/verify runs in its own clean context — no drift.
- **Files win.** If the conversation and the artefacts disagree, the artefacts are authoritative.

### Where things live — `.workspace/` (per project)

Each initiative's artefacts live under its own `.workspace/<slug>/`; a few items are project-level (shared by every initiative) at the root.

```
.workspace/
  initiatives.md       registry: every initiative (slug + description + status), exactly one ACTIVE
  file-structure.md    intended layout (one file tree per project)
  namespaces           this project's cross-project membership (shared by all initiatives)
  <slug>/              one folder per initiative:
    proposal.md          root of truth        tasks.md        atomic task list
    research/            research briefs       verification/   check/verify reports
    memory/              working memory (below)
```

### Memory (so long work survives a full context window)

- **Per-initiative** — `.workspace/<slug>/memory/`: an append-only `journal.md` + a regenerable `index.md`, scoped to the active initiative. The orchestrator reads the active initiative's memory first each session and updates it at the end ("assume interruption").
- **Cross-project** — `~/.claude/shared-memory/` with a `global/` namespace + one per project family (e.g. `acme/`). Durable facts, lessons, and preferences that recur across projects. Knowledge is **promoted manually** (you decide; agents may only suggest). A project opts in via its project-level `.workspace/namespaces` file (shared by all its initiatives).
- Remembered claims are treated as **evidence to re-verify, not fact** — conflicts are surfaced, never silently merged.

### Good to know

- **Permissions:** background agents can't answer permission prompts, so the executor agents need `Write`/`Edit`/`Bash` pre-authorized in `settings.local.json`. A fresh user must grant these themselves (see the "Permissions" section above); they are not pre-provisioned for you.
- **Versioning:** each project's `.workspace/` artefacts are git-tracked in that project's repo; the cross-project tier at `~/.claude/shared-memory/` is a user-owned directory you may git-track yourself.
- **The system can improve itself** — new capabilities (e.g. the memory tiers) are themselves built by running this very pipeline.
