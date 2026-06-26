#!/usr/bin/env bash
# check-skills.sh — Tier 1 check: AC6
# Assert that:
#   1. plugins/claude-workspace/skills/workspace/SKILL.md exists AND has valid YAML
#      frontmatter carrying non-empty 'name' AND 'description'.
#   2. plugins/claude-workspace/skills/workspace/MEMORY-XPROJECT.md exists (presence only).
#      MEMORY-XPROJECT.md is a plain-markdown on-demand include with NO frontmatter by
#      design (it begins "# Cross-project memory tier — full rules").  This script checks
#      its presence with test -f and NEVER parses or asserts frontmatter on it (D6).
#
# Usage: bash .github/ci/check-skills.sh  (run from repo root)
# Exit 0 — both files pass their respective checks.
# Exit 1 — one or more checks fail; clear message printed.

set -euo pipefail

SKILL_FILE="plugins/claude-workspace/skills/workspace/SKILL.md"
MEMORY_FILE="plugins/claude-workspace/skills/workspace/MEMORY-XPROJECT.md"
REQUIRED_KEYS=("name" "description")

# Determine parse strategy: prefer python3 + pyyaml, fall back to grep.
USE_PYTHON=0
if command -v python3 &>/dev/null; then
  if python3 -c "import yaml" 2>/dev/null; then
    USE_PYTHON=1
  fi
fi

# ----------------------------------------------------------------------------
# extract_frontmatter <file>
# Prints only the YAML block between the first pair of '---' lines (exclusive).
# ----------------------------------------------------------------------------
extract_frontmatter() {
  local file="$1"
  awk '
    /^---[[:space:]]*$/ {
      count++
      if (count == 1) next          # skip opening delimiter
      if (count == 2) exit          # stop at closing delimiter
    }
    count == 1 { print }
  ' "$file"
}

has_two_delimiters() {
  local file="$1"
  local n
  n=$(grep -c '^---[[:space:]]*$' "$file" || true)
  [ "$n" -ge 2 ]
}

# ----------------------------------------------------------------------------
# check_skill_python <file>
# Uses python3 + pyyaml to parse the frontmatter and validate required keys.
# Prints error lines; returns 1 if any error found.
# ----------------------------------------------------------------------------
check_skill_python() {
  local file="$1"
  local fm
  fm="$(extract_frontmatter "$file")"

  python3 - "$file" "$fm" <<'PYEOF'
import sys, yaml

filepath = sys.argv[1]
frontmatter = sys.argv[2]
required_keys = ["name", "description"]

if not frontmatter.strip():
    print(f"  {filepath}: frontmatter block is empty or missing")
    sys.exit(1)

try:
    data = yaml.safe_load(frontmatter)
except yaml.YAMLError as e:
    print(f"  {filepath}: frontmatter YAML parse error — {e}")
    sys.exit(1)

if not isinstance(data, dict):
    print(f"  {filepath}: frontmatter did not parse as a YAML mapping")
    sys.exit(1)

errors = []
for key in required_keys:
    val = data.get(key)
    if val is None:
        errors.append(f"key '{key}' missing")
    elif str(val).strip() == "":
        errors.append(f"key '{key}' is empty")

if errors:
    print(f"  {filepath}: " + "; ".join(errors))
    sys.exit(1)

sys.exit(0)
PYEOF
}

# ----------------------------------------------------------------------------
# check_skill_grep <file>
# Grep-based fallback: verifies each required key appears in the frontmatter
# with a non-empty value (pattern: ^key: <non-whitespace>).
# ----------------------------------------------------------------------------
check_skill_grep() {
  local file="$1"
  local fm
  fm="$(extract_frontmatter "$file")"

  if [ -z "$(echo "$fm" | tr -d '[:space:]')" ]; then
    echo "  ${file}: frontmatter block is empty or missing"
    return 1
  fi

  local errors=()
  local key
  for key in "${REQUIRED_KEYS[@]}"; do
    if ! echo "$fm" | grep -qE "^${key}:[[:space:]]+\S"; then
      errors+=("key '${key}' missing or empty")
    fi
  done

  if [ "${#errors[@]}" -gt 0 ]; then
    echo "  ${file}: $(IFS='; '; echo "${errors[*]}")"
    return 1
  fi

  return 0
}

# ----------------------------------------------------------------------------
# Main checks
# ----------------------------------------------------------------------------
fail=0

# --- Check 1: SKILL.md exists ---
if [ ! -f "$SKILL_FILE" ]; then
  echo "FAIL: ${SKILL_FILE} is absent."
  fail=1
else
  # Check that SKILL.md has at least two '---' frontmatter delimiters.
  if ! has_two_delimiters "$SKILL_FILE"; then
    echo "FAIL: ${SKILL_FILE}: missing frontmatter delimiters (need at least two '---' lines)."
    fail=1
  else
    if [ "$USE_PYTHON" -eq 1 ]; then
      if ! check_skill_python "$SKILL_FILE"; then
        echo "FAIL: ${SKILL_FILE} has invalid or incomplete frontmatter (see above)."
        fail=1
      fi
    else
      if ! check_skill_grep "$SKILL_FILE"; then
        echo "FAIL: ${SKILL_FILE} has invalid or incomplete frontmatter (see above)."
        fail=1
      fi
    fi
  fi
fi

# --- Check 2: MEMORY-XPROJECT.md exists (presence only — no frontmatter asserted) ---
# D6: MEMORY-XPROJECT.md is a plain-markdown on-demand include with NO frontmatter by
# design.  Only test -f is used; no frontmatter parsing is performed on this file.
if ! test -f "$MEMORY_FILE"; then
  echo "FAIL: ${MEMORY_FILE} is absent."
  fail=1
fi

# --- Check 3: Methodology skills frontmatter (ideate, decide, plan, reflect) ---
# Each must exist and carry valid YAML frontmatter with non-empty 'name' and 'description'.
# No 'claude-workspace:' namespace prefix is required in the 'name' field.
METHODOLOGY_SKILLS=(ideate decide plan reflect)
for skill in "${METHODOLOGY_SKILLS[@]}"; do
  mskill_file="plugins/claude-workspace/skills/${skill}/SKILL.md"
  if [ ! -f "$mskill_file" ]; then
    echo "FAIL: ${mskill_file} is absent."
    fail=1
  else
    if ! has_two_delimiters "$mskill_file"; then
      echo "FAIL: ${mskill_file}: missing frontmatter delimiters (need at least two '---' lines)."
      fail=1
    else
      if [ "$USE_PYTHON" -eq 1 ]; then
        if ! check_skill_python "$mskill_file"; then
          echo "FAIL: ${mskill_file} has invalid or incomplete frontmatter (see above)."
          fail=1
        fi
      else
        if ! check_skill_grep "$mskill_file"; then
          echo "FAIL: ${mskill_file} has invalid or incomplete frontmatter (see above)."
          fail=1
        fi
      fi
    fi
  fi
done

# --- Result ---
if [ "$fail" -ne 0 ]; then
  echo ""
  echo "FAIL: skills check did not pass (see above)."
  exit 1
fi

echo "OK: ${SKILL_FILE} present with valid frontmatter (name, description); ${MEMORY_FILE} present; plugins/claude-workspace/skills/{ideate,decide,plan,reflect}/SKILL.md present with valid frontmatter."
exit 0
