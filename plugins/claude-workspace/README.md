# claude-workspace

A personal pipeline that takes an idea from **research -> spec -> plan -> build -> verify**, using strict single-responsibility subagents and adversarial verification. The point: reliable, non-drifting work, with project state kept in flat files so long sessions never "forget." This README is the index -- the one-paragraph map of the plugin. Each topic below lives in its own page under `docs/`; start with the quickstart, then follow the table of contents.

---

## Quickstart (about 60 seconds)

This is a pointer-level quickstart. The full operational guide -- private marketplace add, auth/credentials, manual vs background updates, permissions, and "shared, not secret" distribution -- lives in [docs/install.md](docs/install.md).

In a Claude Code session, run the three install commands (replace `MattHB1/claude-workspace` with the private repo you were invited to if it differs):

```
/plugin marketplace add MattHB1/claude-workspace
/plugin install claude-workspace@matt-workspace
/reload-plugins
```

Then start the orchestrator:

```
/claude-workspace:workspace
```

You drive; Claude becomes the Orchestrator that routes your instructions to the right specialist agent and keeps the artefacts as the source of truth. For the full setup (permissions you must grant, updates, and distribution model), see [docs/install.md](docs/install.md).

---

## Repository layout: one repo, two roles

This single repository is **both** a Claude Code marketplace **and** the plugin it ships. That dual role explains the file layout:

```
claude-workspace/                         <- the git repo you add as a marketplace
  .claude-plugin/
    marketplace.json                      <- marketplace manifest (name: "matt-workspace")
  plugins/
    claude-workspace/                     <- the plugin (name: "claude-workspace")
      .claude-plugin/
        plugin.json                       <- plugin manifest, nested under the plugin
      skills/
      agents/
      docs/                               <- the documentation set this index links to
      README.md                           <- this file
```

Four "why" points this layout raises, answered explicitly:

1. **Why is `marketplace.json` at the repo root?** Claude Code discovers a marketplace by reading `.claude-plugin/marketplace.json` at the **root** of whatever repo you add with `/plugin marketplace add`. A git-based marketplace clones the whole repo, so the root manifest is what registers the marketplace; placing it anywhere else would not be found.

2. **Why is `plugin.json` nested under `plugins/claude-workspace/.claude-plugin/`?** The marketplace manifest points at the plugin via a relative `source` (`./plugins/claude-workspace`). The plugin's own manifest lives inside that plugin directory, in its own `.claude-plugin/` folder, so each plugin carries its manifest with it. The two manifests are distinct files for distinct roles -- one describes the marketplace, one describes the plugin.

3. **Why does the plugin live under `plugins/`?** Keeping the plugin in a `plugins/` subdirectory lets the one repository be a marketplace at its root while still shipping the plugin as a self-contained directory underneath. It is the relative `source` target the marketplace manifest resolves to, and it keeps the marketplace concern (root) separate from the plugin concern (the subdirectory).

4. **Why does the marketplace name (`matt-workspace`) differ from the plugin name (`claude-workspace`)?** They name two different things. `matt-workspace` is the marketplace you register; `claude-workspace` is the plugin you install from it. That is why the install command reads `claude-workspace@matt-workspace` -- plugin `claude-workspace` from marketplace `matt-workspace`. The names are independent on purpose.

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
| [docs/troubleshooting.md](docs/troubleshooting.md) | Fixes for permission errors, missing tools, marketplace auth, and the two "why did it refuse" cases. |
| [docs/limitations.md](docs/limitations.md) | Known gaps and what the system is NOT (no semantic retrieval, no auto-promotion, no built-in delete, and more). |
