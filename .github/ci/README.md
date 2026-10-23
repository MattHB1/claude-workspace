# CI smoke-test machinery

This `.github/ci/` directory holds the CI smoke-test machinery for the claude-workspace plugin. There are two tiers: a free, no-secret structural gate (Tier 1) that runs on every push and pull request to `main`, and an auth-gated real-load gate (Tier 2) that runs only on release tags. Tier 1 performs offline structural checks — manifest validity, agent set, frontmatter, skill files, namespacing, PII, and exact-tree integrity — using no secrets and no `claude` CLI. Tier 2 installs the CLI, runs a headless invocation against the plugin, and asserts the pinned init-event shape to confirm the plugin loads clean and all eight namespaced agents register.

## Secrets

**Tier 2 requires the `ANTHROPIC_API_KEY` repository secret.** To configure it: go to the repository on GitHub → Settings → Secrets and variables → Actions → New repository secret, then add `ANTHROPIC_API_KEY` with a valid Anthropic API key as the value.

**Tier 1 requires NO secrets and runs with none configured.** It is fully offline and will pass or fail identically on an air-gapped runner.

## Tier 2 is tag-only and never blocks ordinary push/PR

Tier 2 triggers only on release tags. The load-check job is additionally guarded so it is skipped when `ANTHROPIC_API_KEY` is absent — it will never execute the CLI install or invocation without the secret, and it is entirely unreachable on a push or pull request to `main`.

## Further reading

- `PINNED-INIT.md` — the pinned headless init-event shape (top-level `.plugins[]`, `.agents[]`, `.skills[]`; `plugin_errors` absent-or-empty) and the CLI version it was confirmed against; the Tier 2 assertions target this shape.
- `expected.sh` — the single source-of-truth lists: expected agent names, exact distributable tree contents, and excluded build-machinery patterns; consumed by all checks that need them.

## Files in this directory

- `PINNED-INIT.md` — the pinned init-event shape for Tier 2.
- `README.md` — this file.
- `check-agents.sh` — Tier 1: the agent files equal the expected set.
- `check-frontmatter.sh` — Tier 1: each agent file has valid frontmatter.
- `check-load.sh` — Tier 2: the headless load assertions.
- `check-manifests.sh` — Tier 1: `plugin.json` and `marketplace.json` are valid, and the version badges match.
- `check-multi-live.sh` — checks the per-session picks and worktrees. You run it by hand. No workflow runs it.
- `check-namespacing.sh` — Tier 1: `SKILL.md` has a `claude-workspace:<agent>` token for each agent.
- `check-releasing-gates.sh` — Tier 1: the release gates, including the PII scan.
- `check-skills.sh` — Tier 1: the skill files (the workspace `SKILL.md`, `MEMORY-XPROJECT.md` and the other skills) exist and have valid frontmatter.
- `expected.sh` — the shared lists that the checks use.
