#!/usr/bin/env bash
# Tier-1 check: the set of agent files under plugins/claude-workspace/agents/
# must EQUAL the expected set exactly — no missing, no extra.
#
# Run from repo root: bash .github/ci/check-agents.sh
# Exit 0 = pass; non-zero = violation (missing and/or extra agents reported).
#
# Expected agent list is sourced from the single source of truth (C4/I4);
# agent names are NEVER hardcoded in this script.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source the single shared list — provides EXPECTED_AGENTS array.
# shellcheck source=expected.sh
source "${SCRIPT_DIR}/expected.sh"

AGENTS_DIR="plugins/claude-workspace/agents"

if [[ ! -d "${AGENTS_DIR}" ]]; then
  echo "ERROR: agents directory not found: ${AGENTS_DIR}" >&2
  exit 1
fi

# Compare the expected list with the agent files on disk.
# (Sorted lists and comm rather than associative arrays, so this runs on macOS's stock bash 3.2 too.)
expected_sorted="$(printf '%s\n' "${EXPECTED_AGENTS[@]}" | sort -u)"
discovered_sorted="$(find "${AGENTS_DIR}" -maxdepth 1 -name '*.md' -exec basename {} .md \; | sort -u)"

missing=()
while IFS= read -r agent; do
  [[ -n "${agent}" ]] && missing+=("${agent}")
done < <(comm -23 <(printf '%s\n' "${expected_sorted}") <(printf '%s\n' "${discovered_sorted}"))

extra=()
while IFS= read -r agent; do
  [[ -n "${agent}" ]] && extra+=("${agent}")
done < <(comm -13 <(printf '%s\n' "${expected_sorted}") <(printf '%s\n' "${discovered_sorted}"))

fail=0

if [[ ${#missing[@]} -gt 0 ]]; then
  echo "FAIL: missing agents (expected but not found under ${AGENTS_DIR}):" >&2
  for agent in "${missing[@]}"; do
    echo "  - ${agent}" >&2
  done
  fail=1
fi

if [[ ${#extra[@]} -gt 0 ]]; then
  echo "FAIL: extra agents (found under ${AGENTS_DIR} but not in expected list):" >&2
  for agent in "${extra[@]}"; do
    echo "  + ${agent}" >&2
  done
  fail=1
fi

if [[ ${fail} -ne 0 ]]; then
  echo "Agent roster check failed. Update .github/ci/expected.sh to change the expected set." >&2
  exit 1
fi

echo "OK: agent roster matches expected set (${#EXPECTED_AGENTS[@]} agents)."
