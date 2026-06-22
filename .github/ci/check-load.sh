#!/usr/bin/env bash
# Tier-2 headless load assertions.
# Called from .github/workflows/tier2-load.yml after the claude invocation.
#
# Reads the raw stream-json output from stdin (or the file named $1).
# Asserts (per AC15 / C7 / PINNED-INIT.md):
#   (a) .plugins[] contains an entry with .name == "claude-workspace"
#   (b) .agents[] contains ALL 8 namespaced agents (sourced from expected.sh / EXPECTED_AGENTS)
#   (c) plugin_errors is absent or empty (absent-or-empty logic; see PINNED-INIT.md)
#
# Exits non-zero with a clear message on any violation.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load the single source of truth for agent names.
# shellcheck source=.github/ci/expected.sh
source "${SCRIPT_DIR}/expected.sh"

# Accept stdin or a filename argument.
if [[ $# -ge 1 && -f "$1" ]]; then
  INPUT_FILE="$1"
else
  INPUT_FILE="$(mktemp)"
  trap 'rm -f "$INPUT_FILE"' EXIT
  cat > "$INPUT_FILE"
fi

# Extract the single init event line.
INIT_LINE=$(jq -c 'select(.type=="system" and .subtype=="init")' "$INPUT_FILE")

if [[ -z "$INIT_LINE" ]]; then
  echo "FAIL: no system/init event found in claude output." >&2
  exit 1
fi

FAILURES=0

# ---------------------------------------------------------------
# (a) .plugins[] contains an entry with .name == "claude-workspace"
# ---------------------------------------------------------------
PLUGIN_MATCH=$(echo "$INIT_LINE" | jq -r '
  [ .plugins[]? | select(.name=="claude-workspace") ] | length
')
if [[ "$PLUGIN_MATCH" -eq 0 ]]; then
  echo "FAIL (a): 'claude-workspace' not found in .plugins[] of the init event." >&2
  echo "  Actual .plugins[]: $(echo "$INIT_LINE" | jq '.plugins')" >&2
  FAILURES=$((FAILURES + 1))
else
  echo "PASS (a): plugin 'claude-workspace' present in .plugins[]."
fi

# ---------------------------------------------------------------
# (b) .agents[] contains all 8 namespaced agents (from expected.sh)
# ---------------------------------------------------------------
AGENTS_JSON=$(echo "$INIT_LINE" | jq '.agents // []')

for BASE_NAME in "${EXPECTED_AGENTS[@]}"; do
  NAMESPACED="claude-workspace:${BASE_NAME}"
  FOUND=$(echo "$AGENTS_JSON" | jq --arg agent "$NAMESPACED" '
    [ .[] | select(. == $agent) ] | length
  ')
  if [[ "$FOUND" -eq 0 ]]; then
    echo "FAIL (b): agent '${NAMESPACED}' not found in .agents[] of the init event." >&2
    FAILURES=$((FAILURES + 1))
  else
    echo "PASS (b): agent '${NAMESPACED}' present in .agents[]."
  fi
done

# ---------------------------------------------------------------
# (c) plugin_errors absent or empty
# Use has() to check presence; if present, check length.
# ---------------------------------------------------------------
ERRORS_STATUS=$(echo "$INIT_LINE" | jq -r '
  if has("plugin_errors") then
    (.plugin_errors | length | tostring)
  else
    "absent"
  end
')
if [[ "$ERRORS_STATUS" == "absent" || "$ERRORS_STATUS" == "0" ]]; then
  echo "PASS (c): plugin_errors is ${ERRORS_STATUS} - clean load."
else
  echo "FAIL (c): plugin_errors is present and non-empty (${ERRORS_STATUS} error(s))." >&2
  echo "  plugin_errors: $(echo "$INIT_LINE" | jq '.plugin_errors')" >&2
  FAILURES=$((FAILURES + 1))
fi

# ---------------------------------------------------------------
# Summary
# ---------------------------------------------------------------
if [[ "$FAILURES" -gt 0 ]]; then
  echo "" >&2
  echo "check-load.sh: ${FAILURES} assertion(s) failed. See PINNED-INIT.md for the pinned shape." >&2
  exit 1
fi

echo ""
echo "check-load.sh: all Tier-2 load assertions passed."
