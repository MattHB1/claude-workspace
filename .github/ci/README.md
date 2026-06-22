# CI smoke-test machinery

This `.github/ci/` directory holds the CI smoke-test machinery for the claude-workspace plugin. There are two tiers: a free, no-secret structural gate (Tier 1) that runs on every push and pull request to `main`, and an auth-gated real-load gate (Tier 2) that runs only on release tags. Tier 1 performs offline structural checks — manifest validity, agent set, frontmatter, namespacing, PII, and exact-tree integrity — using no secrets and no `claude` CLI. Tier 2 installs the CLI, runs a headless invocation against the plugin, and asserts the pinned init-event shape to confirm the plugin loads clean and all eight namespaced agents register.

## Secrets

**Tier 2 requires the `ANTHROPIC_API_KEY` repository secret.** To configure it: go to the repository on GitHub → Settings → Secrets and variables → Actions → New repository secret, then add `ANTHROPIC_API_KEY` with a valid Anthropic API key as the value.

**Tier 1 requires NO secrets and runs with none configured.** It is fully offline and will pass or fail identically on an air-gapped runner.

## Tier 2 is tag-only and never blocks ordinary push/PR

Tier 2 triggers only on release tags. The load-check job is additionally guarded so it is skipped when `ANTHROPIC_API_KEY` is absent — it will never execute the CLI install or invocation without the secret, and it is entirely unreachable on a push or pull request to `main`.

## Further reading

- `PINNED-INIT.md` — the pinned headless init-event shape (top-level `.plugins[]`, `.agents[]`, `.skills[]`; `plugin_errors` absent-or-empty) and the CLI version it was confirmed against; the Tier 2 assertions target this shape.
- `expected.sh` — the single source-of-truth lists: expected agent names, exact distributable tree contents, and excluded build-machinery patterns; consumed by all checks that need them.
