#!/usr/bin/env bash
# Tier-2 judge fixture run. Needs the claude CLI and ANTHROPIC_API_KEY.
# Run from the repo root: bash .github/ci/run-judge-fixtures.sh
# Dry run (no claude call): bash .github/ci/run-judge-fixtures.sh --count-only
#
# Reads every row of benchmark/judge-cases.md and runs it through the judge agent.
# The ASK_USER and DECIDED counts come from the table. No count is typed here.
# Passes when:
#   - every output parses as YAML with a rulings list;
#   - every ASK_USER row gives ASK_USER with the expected category;
#   - at least (DECIDED rows - 1) DECIDED rows give DECIDED.

set -euo pipefail

CASES="benchmark/judge-cases.md"
PLUGIN_DIR="./plugins/claude-workspace"

# Print "id<TAB>question<TAB>verdict<TAB>category" for each table row.
rows() {
  awk -F'|' '
    $2 ~ /^[[:space:]]*J[0-9]+[[:space:]]*$/ {
      for (i = 2; i <= 5; i++) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", $i) }
      print $2 "\t" $3 "\t" $4 "\t" $5
    }' "${CASES}"
}

ROWS="$(rows)"
ask_total="$(printf '%s\n' "${ROWS}" | awk -F'\t' '$3 == "ASK_USER"' | wc -l | tr -d ' ')"
decided_total="$(printf '%s\n' "${ROWS}" | awk -F'\t' '$3 == "DECIDED"' | wc -l | tr -d ' ')"
echo "Table: ${ask_total} ASK_USER rows, ${decided_total} DECIDED rows."

if [[ "${1:-}" == "--count-only" ]]; then
  exit 0
fi
if (( ask_total == 0 || decided_total == 0 )); then
  echo "FAIL: no rows parsed from ${CASES}." >&2
  exit 1
fi

# Read one judge output on stdin. Print "verdict<TAB>category" for the first ruling.
# Exit non-zero when the output does not parse. A YAML code fence is stripped first.
parse_ruling() {
  python3 -c '
import re, sys, yaml
text = sys.stdin.read()
m = re.search(r"```(?:yaml|yml)?\s*\n(.*?)```", text, re.S)
if m:
    text = m.group(1)
data = yaml.safe_load(text)
r = data["rulings"][0]
print(r["verdict"] + "\t" + str(r.get("category", "-")))
'
}

ask_ok=0
decided_ok=0
parse_fail=0
while IFS=$'\t' read -r id question expected category; do
  input="$(printf 'initiative: fixture\nasked_by: orchestrator\npointers: {}\nquestions:\n  - id: %s\n    text: "%s"\n' "${id}" "${question//\"/\\\"}")"
  out="$(claude --plugin-dir "${PLUGIN_DIR}" --agent claude-workspace:judge -p "${input}" 2>/dev/null || true)"
  if ! got="$(printf '%s\n' "${out}" | parse_ruling 2>/dev/null)"; then
    echo "FAIL ${id}: output does not parse." >&2
    parse_fail=$((parse_fail + 1))
    continue
  fi
  verdict="${got%%$'\t'*}"
  got_cat="${got#*$'\t'}"
  echo "${id}: expected ${expected}/${category}, got ${verdict}/${got_cat}"
  if [[ "${expected}" == "ASK_USER" ]]; then
    if [[ "${verdict}" == "ASK_USER" && "${got_cat}" == "${category}" ]]; then
      ask_ok=$((ask_ok + 1))
    fi
  elif [[ "${verdict}" == "DECIDED" ]]; then
    decided_ok=$((decided_ok + 1))
  fi
done <<< "${ROWS}"

need_decided=$((decided_total - 1))
echo "Parse failures: ${parse_fail}. ASK_USER correct: ${ask_ok}/${ask_total}. DECIDED correct: ${decided_ok}/${decided_total} (need ${need_decided})."
if (( parse_fail > 0 || ask_ok < ask_total || decided_ok < need_decided )); then
  echo "FAIL: judge fixture run." >&2
  exit 1
fi
echo "PASS: judge fixture run."
