#!/usr/bin/env bash
# Tier-1 check: namespacing tokens present in SKILL.md (AC7 / C4 / I4).
# Run from the repo root: bash .github/ci/check-namespacing.sh
#
# For each expected agent, asserts that the token "claude-workspace:<agent>"
# is present in plugins/claude-workspace/skills/workspace/SKILL.md.
# Agent names are sourced from .github/ci/expected.sh (EXPECTED_AGENTS) — never hardcoded here.
#
# Exits non-zero with a clear message listing any missing token(s).
# Exits 0 if every expected namespacing token is present.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load the single source of truth for agent names (C4/I4 — no inline copy here).
# shellcheck source=.github/ci/expected.sh
source "${SCRIPT_DIR}/expected.sh"

SKILL_FILE="plugins/claude-workspace/skills/workspace/SKILL.md"

if [[ ! -f "${SKILL_FILE}" ]]; then
  echo "FAIL: ${SKILL_FILE} not found (run from repo root)." >&2
  exit 1
fi

FAILURES=0

for BASE_NAME in "${EXPECTED_AGENTS[@]}"; do
  TOKEN="claude-workspace:${BASE_NAME}"
  if grep -qF "${TOKEN}" "${SKILL_FILE}"; then
    echo "PASS: '${TOKEN}' found in ${SKILL_FILE}."
  else
    echo "FAIL: namespacing token '${TOKEN}' is missing from ${SKILL_FILE}." >&2
    FAILURES=$((FAILURES + 1))
  fi
done

if [[ "${FAILURES}" -gt 0 ]]; then
  echo "" >&2
  echo "check-namespacing.sh: ${FAILURES} namespacing token(s) missing from ${SKILL_FILE}." >&2
  exit 1
fi

echo ""
echo "check-namespacing.sh: all namespacing tokens present in ${SKILL_FILE}."
