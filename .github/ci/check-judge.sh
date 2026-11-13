#!/usr/bin/env bash
# Tier-1 check: the judge agent file, the agent-count text, and the SKILL.md judge references.
# Run from the repo root: bash .github/ci/check-judge.sh
#
# Fails when:
#   - agents/judge.md is missing;
#   - its "tools" line is not exactly "Read, Glob, Grep";
#   - its "effort" line is not "medium";
#   - it is more than 4096 bytes;
#   - its body lacks one of the five categories, DECIDED or ASK_USER;
#   - a case-insensitive search finds an "eight"/"8" agent count in the EXPECTED_TREE
#     files, .github/ci/ or .github/workflows/ (CHANGELOG.md is not searched);
#   - SKILL.md lacks the judge namespacing token or the decisions file name.
# The script reports every failure, then exits non-zero if any occurred.
#
# File list is sourced from expected.sh — never copied here.
# The count patterns are built from parts, so they cannot match the text of this script.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=expected.sh
source "${SCRIPT_DIR}/expected.sh"

JUDGE_FILE="plugins/claude-workspace/agents/judge.md"
SKILL_FILE="plugins/claude-workspace/skills/workspace/SKILL.md"
MAX_BYTES=4096
CATEGORIES=(irreversible security money-external product-intent scope)
VERDICTS=(DECIDED ASK_USER)

fail=0
report() {
  echo "FAIL: $*" >&2
  fail=1
}

# ---- 1. judge.md file checks ----
if [[ ! -f "${JUDGE_FILE}" ]]; then
  report "${JUDGE_FILE} is missing."
else
  # Frontmatter = lines between the first two '---' lines.
  front="$(awk '/^---[[:space:]]*$/ { n++; next } n == 1 { print } n >= 2 { exit }' "${JUDGE_FILE}")"
  body="$(awk '/^---[[:space:]]*$/ { n++; next } n >= 2 { print }' "${JUDGE_FILE}")"

  tools_line="$(printf '%s\n' "${front}" | grep -E '^tools:' | head -n 1 || true)"
  if [[ "${tools_line}" != "tools: Read, Glob, Grep" ]]; then
    report "${JUDGE_FILE}: tools must be exactly 'Read, Glob, Grep' (found: '${tools_line}')."
  fi

  effort_line="$(printf '%s\n' "${front}" | grep -E '^effort:' | head -n 1 || true)"
  if [[ "${effort_line}" != "effort: medium" ]]; then
    report "${JUDGE_FILE}: effort must be 'medium' (found: '${effort_line}')."
  fi

  size="$(wc -c < "${JUDGE_FILE}" | tr -d ' ')"
  if (( size > MAX_BYTES )); then
    report "${JUDGE_FILE}: ${size} bytes is more than ${MAX_BYTES}."
  fi

  for word in "${CATEGORIES[@]}" "${VERDICTS[@]}"; do
    if ! printf '%s\n' "${body}" | grep -qF -- "${word}"; then
      report "${JUDGE_FILE}: body does not name '${word}'."
    fi
  done
fi

# ---- 2. agent-count search ----
# Pattern parts. Each part alone is harmless; the joined regex has a number word
# followed by up to three filler words and then "agent"/"subagent", so the regex
# text itself (which has regex syntax between those parts) does not match.
LEAD='(^|[^0-9A-Za-z])'
NUM='(eight|8)'
FILL='([ -][A-Za-z-]+){0,3}[ -]'
NOUN='((sub)?agents?|roles?)'
COUNT_RE="${LEAD}${NUM}\\**${FILL}${NOUN}"
# Parenthesised count after an agent noun, e.g. a roster heading with the number in brackets.
PAREN_RE="${NOUN}( names)? \\(${NUM}\\)"

search_files=()
for f in "${EXPECTED_TREE[@]}"; do
  [[ -f "${f}" ]] && search_files+=("${f}")
done
# Directory search, in a stable order. CHANGELOG.md is not in any of these paths.
while IFS= read -r f; do
  search_files+=("${f}")
done < <(find .github/ci .github/workflows -type f | sort)

# De-duplicate while keeping order (the loop above may repeat nothing today, but stay safe).
# (while-read loop, not a bash-4 builtin, so this runs on macOS stock bash 3.2 too.)
deduped=()
while IFS= read -r f; do
  deduped+=("${f}")
done < <(printf '%s\n' "${search_files[@]}" | awk '!seen[$0]++')
search_files=("${deduped[@]}")

# Each file is flattened to one line first, so a phrase that wraps across two lines
# is still found. The report shows the file and the matched text.
hits=""
for f in "${search_files[@]}"; do
  found="$(tr '\n' ' ' < "${f}" | grep -oiE -e "${COUNT_RE}" -e "${PAREN_RE}" || true)"
  while IFS= read -r m; do
    [[ -n "${m}" ]] && hits+="${f}: ${m}"$'\n'
  done <<< "${found}"
done
if [[ -n "${hits}" ]]; then
  report "found an 'eight'/'8' agent count (the roster has nine agents):"
  printf '%s' "${hits}" | sed 's/^/  /' >&2
fi

# ---- 3. SKILL.md references ----
if [[ ! -f "${SKILL_FILE}" ]]; then
  report "${SKILL_FILE} is missing."
else
  for token in "claude-workspace:judge" "decisions.md"; do
    if ! grep -qF -- "${token}" "${SKILL_FILE}"; then
      report "${SKILL_FILE} does not contain '${token}'."
    fi
  done
fi

if (( fail != 0 )); then
  echo "Judge check failed." >&2
  exit 1
fi
echo "OK: judge agent file, agent-count text and SKILL.md references pass."
