#!/usr/bin/env bash
# check-frontmatter.sh — Tier 1 check: AC5
# Assert every plugins/claude-workspace/agents/*.md file has valid YAML frontmatter
# containing non-empty values for all four required keys: name, description, tools, model.
#
# Usage: bash .github/ci/check-frontmatter.sh  (run from repo root)
# Exit 0 — all agent files pass.
# Exit 1 — one or more agent files fail; offending file(s) and missing/empty key(s) listed.

set -euo pipefail

AGENTS_GLOB="plugins/claude-workspace/agents/*.md"
REQUIRED_KEYS=("name" "description" "tools" "model")

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
# Returns non-zero if the file does not have two '---' delimiters.
# ----------------------------------------------------------------------------
extract_frontmatter() {
  local file="$1"
  # awk: print lines between first '---' and second '---' (exclusive).
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
# check_file_python <file>
# Uses python3 + pyyaml to parse the frontmatter and validate required keys.
# Prints error lines to stdout; returns 1 if any error found.
# ----------------------------------------------------------------------------
check_file_python() {
  local file="$1"
  local fm
  fm="$(extract_frontmatter "$file")"

  python3 - "$file" "$fm" <<'PYEOF'
import sys, yaml

filepath = sys.argv[1]
frontmatter = sys.argv[2]
required_keys = ["name", "description", "tools", "model"]

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
# check_file_grep <file>
# Grep-based fallback: verifies each required key appears in the frontmatter
# with a non-empty value (pattern: ^key: <non-whitespace>).
# ----------------------------------------------------------------------------
check_file_grep() {
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
    # Match lines like:  key: some value
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
# Main loop
# ----------------------------------------------------------------------------
fail=0
checked=0

# Use 'eval' to expand glob so the script works when run from repo root.
for agent_file in $AGENTS_GLOB; do
  if [ ! -f "$agent_file" ]; then
    echo "ERROR: no agent files found matching: ${AGENTS_GLOB}" >&2
    exit 1
  fi

  checked=$((checked + 1))

  # Check that the file has at least two '---' delimiters.
  if ! has_two_delimiters "$agent_file"; then
    echo "  ${agent_file}: missing frontmatter delimiters (need at least two '---' lines)"
    fail=1
    continue
  fi

  if [ "$USE_PYTHON" -eq 1 ]; then
    if ! check_file_python "$agent_file"; then
      fail=1
    fi
  else
    if ! check_file_grep "$agent_file"; then
      fail=1
    fi
  fi
done

if [ "$checked" -eq 0 ]; then
  echo "ERROR: no agent files found matching: ${AGENTS_GLOB}" >&2
  exit 1
fi

if [ "$fail" -ne 0 ]; then
  echo ""
  echo "FAIL: one or more agent files have invalid or incomplete frontmatter (see above)."
  exit 1
fi

echo "OK: all ${checked} agent file(s) have valid frontmatter with required keys (name, description, tools, model)."
exit 0
