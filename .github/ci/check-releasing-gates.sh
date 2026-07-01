#!/usr/bin/env bash
# Tier-1 gate: four folded-in RELEASING.md gates
# Run as: bash .github/ci/check-releasing-gates.sh   (from repo root)
#
# Gates:
#   A — PII scan (AC8)
#   B — UESA regression in both adversary agents (AC9)
#   C — no build-machinery in repo (AC10)
#   D — exact distributable tree (AC11)
#
# Self-trip avoidance (C6/AC16):
#   The .github/ci/ directory contains the detection literals as strings;
#   it is excluded from Gates A and C so the script does not flag itself.
#
# Single source of truth: .github/ci/expected.sh (I4)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=expected.sh
source "${SCRIPT_DIR}/expected.sh"

FAILURES=()

# ---------------------------------------------------------------------------
# GATE A — PII scan (AC8)
# Patterns: pocdoc, central-be, admin-be, matt@mypocdoc.com, mypocdoc, /Users/matthb
# Exclusions:
#   - .git/           (standard)
#   - .github/ci/     (C6: this dir contains detection literals as strings)
#   - .workspace/     (local, git-ignored dev state; never tracked/shipped, and
#                      its journals legitimately contain project names/paths)
# Allowance: case-insensitive "matthb" that is exactly the public handle MattHB1
#             in README install commands is permitted.
#             The exact marketplace token "pocdoc-workspace" is also permitted
#             (stripped before re-grep; bare "pocdoc" still fails).
# ---------------------------------------------------------------------------
gate_a_pii() {
  local hits
  # Grep repo-wide, excluding .git and .github/ci (self-trip avoidance).
  # We collect all raw matches first, then filter out the MattHB1 allowance.
  hits=$(grep -rniE \
    'pocdoc|central-be|admin-be|matt@mypocdoc\.com|mypocdoc|/Users/matthb' \
    --exclude-dir='.git' \
    --exclude-dir='.github' \
    --exclude-dir='.workspace' \
    . 2>/dev/null || true)

  # Re-scan .github/ but exclude .github/ci/ (CI machinery contains detection literals)
  local github_hits
  github_hits=$(grep -rniE \
    'pocdoc|central-be|admin-be|matt@mypocdoc\.com|mypocdoc|/Users/matthb' \
    --exclude-dir='.git' \
    .github/ 2>/dev/null | grep -v '^\.github/ci/' || true)

  hits="${hits}"$'\n'"${github_hits}"

  # Filter out the allowed MattHB1 and pocdoc-workspace token occurrences:
  # A line is allowed if, after stripping those two exact tokens (case-insensitive),
  # no banned pattern remains.
  # Allowed tokens:
  #   MattHB1        — the public GitHub handle (existing allowance)
  #   pocdoc-workspace — the exact org marketplace token (new allowance;
  #                      bare "pocdoc" is NOT stripped and still fails)
  # Strategy: strip each allowed token from the content portion, then re-grep.
  local offenders=""
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    # Strip MattHB1 token (case-insensitive) from the line content portion
    # (everything after the first colon, i.e. after "file:lineno:")
    local prefix content cleaned
    prefix=$(printf '%s' "$line" | cut -d: -f1-2)
    content=$(printf '%s' "$line" | cut -d: -f3-)
    cleaned=$(printf '%s' "$content" | sed -E 's/[Mm][Aa][Tt][Tt][Hh][Bb]1//g' \
                                     | sed -E 's/[Pp][Oo][Cc][Dd][Oo][Cc]-[Ww][Oo][Rr][Kk][Ss][Pp][Aa][Cc][Ee]//g')
    # Now check if any banned pattern still appears in the cleaned content
    if printf '%s' "$cleaned" | grep -qiE 'pocdoc|central-be|admin-be|matt@mypocdoc\.com|mypocdoc|/Users/matthb'; then
      offenders="${offenders}${line}"$'\n'
    fi
  done <<< "$hits"

  if [[ -n "$offenders" ]]; then
    FAILURES+=("GATE A [PII] — banned PII token(s) found:"$'\n'"$offenders")
  fi
}

# ---------------------------------------------------------------------------
# GATE B — UESA regression (AC9)
# Both adversary agents must contain the verify-before-blocking / EXTERNAL-STATE rule.
# Pattern (from RELEASING.md): EXTERNAL.?STATE|file:line|Read/Glob/Grep|WEAK/INFORMATIONAL
# ---------------------------------------------------------------------------
gate_b_uesa() {
  local task_checker="plugins/claude-workspace/agents/task-checker.md"
  local impl_verifier="plugins/claude-workspace/agents/implementation-verifier.md"
  local pattern='EXTERNAL.?STATE|file:line|Read/Glob/Grep|WEAK/INFORMATIONAL'
  local failed=0

  for agent_file in "$task_checker" "$impl_verifier"; do
    if ! grep -qiE "$pattern" "$agent_file" 2>/dev/null; then
      FAILURES+=("GATE B [UESA] — verify-before-blocking / EXTERNAL-STATE rule missing from: ${agent_file}")
      failed=1
    fi
  done
}

# ---------------------------------------------------------------------------
# GATE C — no build machinery in repo (AC10)
# Checks that EXCLUDED_MACHINERY patterns (from expected.sh) do not appear
# as paths anywhere in the repo.
# Exclusions:
#   - .git/       (standard)
#   - .github/    (C6: CI scripts name these patterns for detection purposes)
#   - .workspace/ (local, git-ignored dev state; never tracked/shipped, so it is
#                  not distributable machinery — excluded like .git/.github)
# ---------------------------------------------------------------------------
gate_c_no_machinery() {
  local offending_paths=()

  # Build the actual file list (excluding .git and .github)
  while IFS= read -r -d '' filepath; do
    local relpath="${filepath#./}"

    for pattern in "${EXCLUDED_MACHINERY[@]}"; do
      # Use shell glob-style match: pattern may contain * (e.g. settings*.json)
      # We check both the basename and the full relative path component by component.
      local basename
      basename=$(basename "$relpath")

      if [[ "$pattern" == *'*'* ]]; then
        # Glob pattern — match against basename only
        # shellcheck disable=SC2053
        if [[ "$basename" == $pattern ]]; then
          offending_paths+=("$relpath (matches machinery pattern: $pattern)")
          break
        fi
      else
        # Literal pattern — match as path component (basename OR directory segment)
        # Check if the pattern appears as a complete path component
        if [[ "$basename" == "$pattern" ]] || printf '%s' "/$relpath/" | grep -qF "/${pattern}/"; then
          offending_paths+=("$relpath (matches machinery pattern: $pattern)")
          break
        fi
      fi
    done
  done < <(find . -not -path './.git/*' -not -path './.github/*' -not -path './.workspace' -not -path './.workspace/*' -print0)

  if [[ ${#offending_paths[@]} -gt 0 ]]; then
    local msg="GATE C [NO-MACHINERY] — build-machinery pattern(s) found in repo:"
    for p in "${offending_paths[@]}"; do
      msg="${msg}"$'\n'"  ${p}"
    done
    FAILURES+=("$msg")
  fi
}

# ---------------------------------------------------------------------------
# GATE D — exact distributable tree (AC11/I5)
# Actual set = every file under plugins/claude-workspace/ PLUS root
#   .claude-plugin/marketplace.json PLUS root README.md.
# .github/ is NOT distributable and must NOT be included in the scan.
# Compare against EXPECTED_TREE from expected.sh — must be exact match (24 paths).
# ---------------------------------------------------------------------------
gate_d_exact_tree() {
  # Collect actual distributable files
  local actual_files=()
  while IFS= read -r -d '' f; do
    actual_files+=("${f#./}")
  done < <(find ./plugins/claude-workspace -type f -print0)

  # Add the two root distributable files
  [[ -f ".claude-plugin/marketplace.json" ]] && actual_files+=(".claude-plugin/marketplace.json")
  [[ -f "README.md" ]] && actual_files+=("README.md")

  # Sort both sets for comparison
  local actual_sorted expected_sorted
  actual_sorted=$(printf '%s\n' "${actual_files[@]}" | sort)
  expected_sorted=$(printf '%s\n' "${EXPECTED_TREE[@]}" | sort)

  # Find EXTRA files (present but not in expected)
  local extra missing
  extra=$(comm -23 <(echo "$actual_sorted") <(echo "$expected_sorted"))
  # Find MISSING files (expected but not present)
  missing=$(comm -13 <(echo "$actual_sorted") <(echo "$expected_sorted"))

  local failed=0
  local msg="GATE D [EXACT-TREE] — distributable tree mismatch:"
  if [[ -n "$extra" ]]; then
    msg="${msg}"$'\n'"  EXTRA files (present but not expected):"
    while IFS= read -r f; do
      msg="${msg}"$'\n'"    ${f}"
    done <<< "$extra"
    failed=1
  fi
  if [[ -n "$missing" ]]; then
    msg="${msg}"$'\n'"  MISSING files (expected but absent):"
    while IFS= read -r f; do
      msg="${msg}"$'\n'"    ${f}"
    done <<< "$missing"
    failed=1
  fi

  if [[ $failed -eq 1 ]]; then
    FAILURES+=("$msg")
  fi
}

# ---------------------------------------------------------------------------
# Run all four gates, collect failures, report and exit
# ---------------------------------------------------------------------------
gate_a_pii
gate_b_uesa
gate_c_no_machinery
gate_d_exact_tree

if [[ ${#FAILURES[@]} -eq 0 ]]; then
  echo "check-releasing-gates: all four gates PASSED"
  exit 0
fi

echo "check-releasing-gates: FAILED — ${#FAILURES[@]} gate(s) failed:" >&2
echo "" >&2
for failure in "${FAILURES[@]}"; do
  echo "---" >&2
  echo "$failure" >&2
  echo "" >&2
done
exit 1
