# Changelog

All notable changes to the claude-workspace plugin are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.10.0] - 2026-07-15

### Added
- Registry consolidation policy: a byte-size trigger (`wc -c` against a single tunable
  threshold), evaluated at bootstrap and teardown, gated by a one-line y/n prompt (never
  automatic); non-destructive procedure that relocates completed/superseded entries to
  `initiatives-archive.md` while trimming status cells and keeping live pointers in the
  main registry.

## [1.9.1] - 2026-07-06

### Added
- Split-AC closure check for cross-task verification.

## [1.9.0] - 2026-07-03

### Changed
- Collapsed the pipeline to a lean-by-default flow: retired the execution-tier rubric and
  the Lightweight Lane, removing multi-round correction/re-check loops from the default path.

## [1.8.1] - 2026-07-03

### Changed
- Lightweight Lane: dropped the file-count cap; L4 now serves as an anti-sprawl guard instead.

### Added
- Age-gated plan→implement `/clear` nudge.

## [1.8.0] - 2026-07-02

### Added
- Lightweight Lane: small, well-scoped changes can skip proposal/tasks and run
  implement → single adversarial verify with inline acceptance criteria.

### Changed
- Verification economy across all tiers: one check per stage, PASS is terminal, with a
  bounded delta-scoped re-check on FAIL.

## [1.7.0] - 2026-07-02

### Added
- SessionStart hook that auto-conforms a drifted `initiatives.md` registry to the
  canonical row format.

### Changed
- Active-initiative marker resolution anchored to a whole-cell match (statusline and
  logging resolvers).

## [1.6.6] - 2026-07-01

### Fixed
- Logging: `Read` now gets its own `event:"read"` discriminator instead of being
  mislabelled as an edit.

## [1.6.5] - 2026-07-01

### Added
- Age-gated `/clear` reminder on initiative create/switch.

### Fixed
- Plugin README version badge bumped to match (CI drift-gate).

## [1.6.4] - 2026-07-01

### Fixed
- Release gate: also exclude the local `.workspace` dev state from the PII scan (Gate A).

## [1.6.3] - 2026-07-01

### Fixed
- Release gate: exclude the local, git-ignored `.workspace` dev state from the
  build-machinery scan.

### Changed
- Local `.workspace` dev state is now git-ignored.

## [1.6.2] - 2026-07-01

### Added
- Statusline git-branch segment.
- Plugin-consume documentation.

## [1.6.1] - 2026-07-01

### Fixed
- Statusline marker is now also written on `/workspace` slash-command entry (previously
  only written via the PostToolUse(Skill) hook, missing that entry path).

## [1.6.0] - 2026-07-01

### Added
- Automatic, session-aware initiative statusline (supersedes the earlier opt-in statusline).

## [1.5.0] - 2026-06-30

### Added
- Per-initiative `events.jsonl` observability hook (PostToolUse + Stop), with event
  discriminators and agent_id/agent_type attribution.
- Hooks bundled with the plugin (`hooks.json` + `${CLAUDE_PLUGIN_ROOT}`), with dual
  registration.

## [1.4.0] - 2026-06-26

### Added
- "Necessity invariant": every artefact must be the smallest, simplest thing that fully
  satisfies the real need (bidirectional traceability + reuse-or-justify); applied to
  right-size the ideation-spiral skill.
- Static version badge in the plugin README + a CI drift-gate to keep it in sync.

### Changed
- Plugin tree synced with the ideation-spiral skill and the folded methodology skills.

## [1.3.0] - 2026-06-25

### Added
- `ideate`/`decide`/`plan`/`reflect` methodology skills folded into the plugin (shipped
  to every installer).
- New `ideation-spiral` skill: a Frame→Diverge→Challenge→Converge loop with an in-skill
  adversarial pass and an objective convergence gate, plus `docs/ideation-spiral.md`.
- Opt-in statusline showing the active initiative.
- GitHub Actions release smoke-test gate (Tier 1 structural checks; Tier 2 headless load).
- Tiered execution-tier routing section in the skill, plus execution-tier verification
  rubric docs.
- Explicit "exit the workspace" verb, with how-to-leave docs.

### Changed
- Benefit-led rewrite of both READMEs.

### Fixed
- Tier 2 CI startup failures (invalid job-level `if`/indentation).

## [1.2.0] - 2026-06-22

### Changed
- Token-optimised tooling: SKILL slimmed, the cross-project tier moved to an on-demand
  include, and agents made leaner — reducing token consumption without weakening
  verification.

## [1.1.0] - 2026-06-19

### Added
- Repo-root README (overview, install, usage), restructured into a `docs/` set with a
  slim README index.
- Per-agent model selection (cost-optimized) + docs.

### Changed
- README rewritten to lead with what the workspace actually does.

### Fixed
- Agents now require evidence before blocking on external-state facts.

## [1.0.0] - 2026-06-19

### Added
- Initial release of the claude-workspace plugin: an 8-agent + orchestrator-skill
  pipeline for spec-driven change control.
