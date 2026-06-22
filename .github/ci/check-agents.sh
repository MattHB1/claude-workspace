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

# Build an associative array of expected agent names.
declare -A expected_set
for agent in "${EXPECTED_AGENTS[@]}"; do
  expected_set["${agent}"]=1
done

# Discover agent names from the directory (basename minus .md extension).
declare -A discovered_set
while IFS= read -r filepath; do
  basename_no_ext="$(basename "${filepath}" .md)"
  discovered_set["${basename_no_ext}"]=1
done < <(find "${AGENTS_DIR}" -maxdepth 1 -name '*.md' | sort)

# Compute missing agents (in expected but not discovered).
missing=()
for agent in "${!expected_set[@]}"; do
  if [[ -z "${discovered_set[${agent}]+_}" ]]; then
    missing+=("${agent}")
  fi
done

# Compute extra agents (discovered but not in expected).
extra=()
for agent in "${!discovered_set[@]}"; do
  if [[ -z "${expected_set[${agent}]+_}" ]]; then
    extra+=("${agent}")
  fi
done

# Sort for stable, readable output.
IFS=$'\n' missing=($(sort <<<"${missing[*]+"${missing[*]}"}")); unset IFS
IFS=$'\n' extra=($(sort <<<"${extra[*]+"${extra[*]}"}")); unset IFS

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

echo "OK: agent roster matches expected set (${#expected_set[@]} agents)."
