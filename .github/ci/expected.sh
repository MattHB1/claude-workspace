#!/usr/bin/env bash
# Single source of truth for all Tier-1 check scripts (per C4/I4).
# Source this file — do NOT re-declare these lists anywhere else.
#
# To update the distributable (e.g. add a doc or an agent), update THIS file only.
# Every check that consumes these lists reads from here at runtime.
#
# Consumed by: Tier-1 checks for agent roster, exact-tree, and build-machinery exclusion.

# -------------------------------------------------------------------
# 1. Expected agent names (8) — AC15(b) / AC4
#    Basename of each agents/*.md file (without the .md extension).
# -------------------------------------------------------------------
EXPECTED_AGENTS=(
  archivist
  context-recovery
  implementation-verifier
  implementer
  proposal-writer
  research-harvester
  task-checker
  task-planner
)

# -------------------------------------------------------------------
# 2. Exact distributable file set (31) — AC11 / I5
#    Repo-root-relative paths. Every file here must be present;
#    no file outside this list may appear in the distributable tree.
# -------------------------------------------------------------------
EXPECTED_TREE=(
  plugins/claude-workspace/.claude-plugin/plugin.json
  plugins/claude-workspace/agents/archivist.md
  plugins/claude-workspace/agents/context-recovery.md
  plugins/claude-workspace/agents/implementation-verifier.md
  plugins/claude-workspace/agents/implementer.md
  plugins/claude-workspace/agents/proposal-writer.md
  plugins/claude-workspace/agents/research-harvester.md
  plugins/claude-workspace/agents/task-checker.md
  plugins/claude-workspace/agents/task-planner.md
  plugins/claude-workspace/skills/workspace/SKILL.md
  plugins/claude-workspace/skills/workspace/MEMORY-XPROJECT.md
  plugins/claude-workspace/skills/ideate/SKILL.md
  plugins/claude-workspace/skills/decide/SKILL.md
  plugins/claude-workspace/skills/plan/SKILL.md
  plugins/claude-workspace/skills/reflect/SKILL.md
  plugins/claude-workspace/README.md
  plugins/claude-workspace/docs/concepts.md
  plugins/claude-workspace/docs/design-principles.md
  plugins/claude-workspace/docs/initiatives.md
  plugins/claude-workspace/docs/install.md
  plugins/claude-workspace/docs/limitations.md
  plugins/claude-workspace/docs/memory.md
  plugins/claude-workspace/docs/safety-and-compliance.md
  plugins/claude-workspace/docs/statusline.md
  plugins/claude-workspace/docs/troubleshooting.md
  plugins/claude-workspace/docs/why-it-refuses.md
  plugins/claude-workspace/docs/workflow.md
  plugins/claude-workspace/scripts/install-statusline.js
  plugins/claude-workspace/scripts/statusline.js
  .claude-plugin/marketplace.json
  README.md
)

# -------------------------------------------------------------------
# 3. Excluded build-machinery patterns (6) — AC10
#    Files/dirs matching these patterns must NOT appear in the repo
#    (the gate excludes the CI artefact's own files per C6).
# -------------------------------------------------------------------
EXCLUDED_MACHINERY=(
  export.sh
  EXPORT.md
  transforms.md
  .workspace
  memory
  'settings*.json'
)
