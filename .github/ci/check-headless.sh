#!/usr/bin/env bash
# Tier-1 check: headless mode (scripts, rules file, schema, fixtures, size, bash 3.2 lint).
# Run from any folder: bash .github/ci/check-headless.sh
# Runs under bash 3.2 too: /bin/bash .github/ci/check-headless.sh
#
# Groups (AC numbers are from the headless-mode proposal):
#   AC2  headless-env.sh table cases
#   AC3  headless-preflight.sh cases on temp repos (git init, bare origin, stub gh)
#   AC4  key tokens in headless.md, one per call site 1-20 and per listed item
#   D9   each prompt named in SKILL.md Hard Rule 8 and "Bypass the judge" is in headless.md
#   AC5  the closed code list in headless.md equals the schema enums, both ways
#   AC6  check-run-summary.py on the three fixtures (pass) and one bad case (fail)
#   AC7  SKILL.md is at most 19,500 bytes
#   AC9  no bash-4 construct in .github/ci/ or plugin scripts/
#
# A missing artefact is a FAIL line, not a crash. The script reports every failure,
# then exits non-zero if any occurred.
#
# Token rule for AC4: headless.md must contain each token below (case-insensitive,
# fixed string). Closed-list rule for AC5: in headless.md, a line that starts with
# optional "- " or "* ", then `failed` or `blocked` in backticks, then a colon, lists
# the codes of that status as backticked words.
#
# The lint patterns hold one letter in a bracket, so they cannot match their own text.
# The seeded bad word is built from parts at run time, so no bash-4 word sits in this file.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
# shellcheck source=expected.sh disable=SC1091 # path is set at run time; lint runs without -x
source "${SCRIPT_DIR}/expected.sh"

P="${REPO_ROOT}/plugins/claude-workspace"
ENV_SH="${P}/scripts/headless-env.sh"
PRE_SH="${P}/scripts/headless-preflight.sh"
RULES="${P}/skills/workspace/headless.md"
SKILL="${P}/skills/workspace/SKILL.md"
SCHEMA="${P}/docs/run-summary.schema.json"
VALIDATOR="${SCRIPT_DIR}/check-run-summary.py"
MAX_SKILL_BYTES=19500

export PYTHONDONTWRITEBYTECODE=1 GIT_CONFIG_NOSYSTEM=1
unset CLAUDE_PROJECT_DIR GIT_DIR GIT_WORK_TREE

TMP="$(mktemp -d)"
TMP="$(cd "${TMP}" && pwd -P)"
trap 'rm -rf "${TMP}"' EXIT
export HOME="${TMP}/home"
mkdir -p "${HOME}"

fail=0
report() {
  echo "FAIL: $*" >&2
  fail=1
}

# ---- AC2. headless-env.sh ----
# env_case <desc> <want-rc: 0|nz> <want-mode: exact|has> <want-text> [VAR=value ...]
env_case() {
  local desc=$1 want_rc=$2 mode=$3 want=$4 out rc line
  shift 4
  out="$(env -i PATH="${PATH}" HOME="${HOME}" "$@" /bin/bash "${ENV_SH}" 2>&1)"
  rc=$?
  if [[ "${want_rc}" == "0" && "${rc}" -ne 0 ]]; then
    report "headless-env.sh ${desc}: exit ${rc}, want 0."
  elif [[ "${want_rc}" == "nz" && "${rc}" -eq 0 ]]; then
    report "headless-env.sh ${desc}: exit 0, want non-zero."
  fi
  if [[ "${mode}" == "exact" ]]; then
    [[ "${out}" == "${want}" ]] || report "headless-env.sh ${desc}: got [${out}], want [${want}]."
  else
    while IFS= read -r line; do
      printf '%s\n' "${out}" | grep -Fxq -- "${line}" \
        || report "headless-env.sh ${desc}: output lacks line [${line}]."
    done <<EOF
${want}
EOF
  fi
}

if [[ ! -f "${ENV_SH}" ]]; then
  report "${ENV_SH} is missing (AC2 cases not run)."
else
  env_case "switch unset" 0 exact "HEADLESS=0"
  env_case "switch not 1" 0 exact "HEADLESS=0" WORKSPACE_HEADLESS=true WORKSPACE_TICKET=T-1
  env_case "no ticket" nz exact "ERROR: no_ticket" WORKSPACE_HEADLESS=1
  env_case "defaults" 0 has "HEADLESS=1
TICKET=T-1
MAX_MINUTES=60
MAX_IMPL_RETRIES=1
MAX_TASKS=10" WORKSPACE_HEADLESS=1 WORKSPACE_TICKET=T-1
  env_case "bound override" 0 has "MAX_MINUTES=0" \
    WORKSPACE_HEADLESS=1 WORKSPACE_TICKET=T-1 WORKSPACE_MAX_MINUTES=0
  env_case "non-numeric bound" nz exact "ERROR: invalid_bound" \
    WORKSPACE_HEADLESS=1 WORKSPACE_TICKET=T-1 WORKSPACE_MAX_TASKS=abc
  env_case "negative bound" nz exact "ERROR: invalid_bound" \
    WORKSPACE_HEADLESS=1 WORKSPACE_TICKET=T-1 WORKSPACE_MAX_MINUTES=-5
  env_case "retries clamp" 0 has "MAX_IMPL_RETRIES=1" \
    WORKSPACE_HEADLESS=1 WORKSPACE_TICKET=T-1 WORKSPACE_MAX_IMPL_RETRIES=5
fi

# ---- AC3. headless-preflight.sh ----
STUB="${TMP}/stub"
mkdir -p "${STUB}"
cat > "${STUB}/gh" <<'EOF'
#!/bin/sh
# Stub gh: "auth status" fails when STUB_GH_FAIL is set.
if [ "$1" = "auth" ] && [ -n "${STUB_GH_FAIL:-}" ]; then exit 1; fi
exit 0
EOF
chmod +x "${STUB}/gh"

# mk_repo <name> [noorigin]: a repo with one commit and (by default) a bare origin.
mk_repo() {
  local d="${TMP}/$1"
  mkdir -p "${d}"
  git -C "${d}" init -q -b main
  git -C "${d}" config user.email t@example.com
  git -C "${d}" config user.name t
  echo one > "${d}/tracked.txt"
  git -C "${d}" add tracked.txt
  git -C "${d}" commit -q -m init
  if [[ "${2:-}" != "noorigin" ]]; then
    git init -q --bare "${TMP}/$1-origin.git"
    git -C "${d}" remote add origin "${TMP}/$1-origin.git"
    git -C "${d}" push -q origin main 2>/dev/null
  fi
  echo "${d}"
}

# pre_case <desc> <want> <root> [VAR=value ...]
pre_case() {
  local desc=$1 want=$2 root=$3 out
  shift 3
  out="$(env -i PATH="${STUB}:${PATH}" HOME="${HOME}" GIT_CONFIG_NOSYSTEM=1 "$@" \
    /bin/bash "${PRE_SH}" "${root}" 2>&1)"
  [[ "${out}" == "${want}" ]] || report "headless-preflight.sh ${desc}: got [${out}], want [${want}]."
}

if [[ ! -f "${PRE_SH}" ]]; then
  report "${PRE_SH} is missing (AC3 cases not run)."
else
  r="$(mk_repo clean)"
  pre_case "clean" "OK" "${r}"

  r="$(mk_repo dirty)"
  echo two >> "${r}/tracked.txt"
  pre_case "dirty tracked file" "ERROR: dirty_main" "${r}"

  r="$(mk_repo ignored)"
  mkdir -p "${r}/.workspace/x" "${r}/.claude/worktrees/y"
  echo a > "${r}/.workspace/x/f"
  echo b > "${r}/.claude/worktrees/y/f"
  pre_case "changes only under .workspace and .claude/worktrees" "OK" "${r}"

  r="$(mk_repo noorigin noorigin)"
  pre_case "no origin" "ERROR: no_origin" "${r}"

  r="$(mk_repo allowed)"
  mkdir -p "${r}/.workspace"
  echo allowed > "${r}/.workspace/main-commits"
  pre_case "main-allowed" "ERROR: main_allowed_repo" "${r}"

  r="$(mk_repo noghauth)"
  pre_case "gh auth fails" "ERROR: gh_unavailable" "${r}" STUB_GH_FAIL=1
fi

# ---- AC4. headless.md tokens ----
# One token per call site 1-20 (spec order), then one per listed item.
SITE_TOKENS=(
  "headless-env.sh"            # 1  Memory read: env script, preflight, Create or Switch
  "no_ticket_text"             # 2  Create: tracker read or paste
  "no_root"                    # 3  NO-ROOT
  "concurrent_run"             # 4  BLOCK same-initiative / one-session / stale marker
  "main_allowed_repo"          # 5  worktree always
  "no_default_branch"          # 6  NO-DEFAULT and fetch stops
  "worktree_refused"           # 7  git refuses worktree or branch
  "remove nothing"             # 8  merge check preset n
  "push_failed"                # 9  push preset y
  "pr_failed"                  # 10 PR preset y
  "tracker_mapping_missing"    # 11 tracker write-back
  "needs_human"                # 12 judge ASK_USER
  "follow_ups"                 # 13 out-of-scope problem
  "proposal_check_limit"       # 14 third proposal-check FAIL
  "implementer_stop"           # 15 second implementer STOP
  "judge_error"                # 16 judge output fails to parse twice
  "build_check_failed"         # 17 build re-check still FAILs
  "quality_check_unavailable"  # 18 quality check not run twice
  "guard trips"                # 19 silent notices
  "teardown"                   # 20 Exit
)
ITEM_TOKENS=(
  "remove nothing"             # preset: merge check n
  "git push"                   # preset: push y
  "gh pr create"               # preset: PR y
  "WORKSPACE_PR_DRAFT=0"       # PR draft switch
  "tracker-states"             # preset: tracker write-back y
  "awaiting ticket reply"      # blocked stop 1
  "wip(headless): blocked"     # blocked stop 2
  "one comment"                # blocked stop 3
  "WORKSPACE_RESULT: blocked"  # blocked stop 4
  "Resume"                     # blocked stop 5
  "auto-fix-blocked"
  "WORKSPACE_MAX_MINUTES"      # bounds table
  "WORKSPACE_MAX_IMPL_RETRIES"
  "WORKSPACE_MAX_TASKS"
  ".registry.lock"
  "30 s"
  "ticket_mismatch"
  "WORKSPACE_TICKET_FILE"
  "Create"
  "Switch"
  "every exit"                 # teardown on every exit
  "WORKSPACE_RESULT:"
)

if [[ ! -f "${RULES}" ]]; then
  report "${RULES} is missing (AC4, D9 and AC5 checks not run)."
else
  i=0
  for t in "${SITE_TOKENS[@]}"; do
    i=$((i + 1))
    grep -iqF -- "${t}" "${RULES}" || report "headless.md lacks the token for site ${i}: [${t}]."
  done
  for t in "${ITEM_TOKENS[@]}"; do
    grep -iqF -- "${t}" "${RULES}" || report "headless.md lacks the item token [${t}]."
  done

  # ---- D9. Prompts named in SKILL.md map to a headless.md token ----
  # Each row is "phrase in SKILL.md|token in headless.md". The phrase must still be in
  # SKILL.md (Hard Rule 8 line or the "Bypass the judge" line), so a changed list shows up
  # here. The phrase "the four `y/n` gates" maps to the four preset tokens: merge check,
  # push, PR and tracker write-back.
  HR8="$(grep -E '^8\. \*\*A bound is a stop' "${SKILL}" || true)"
  BYP="$(grep -F 'Bypass the judge' "${SKILL}" || true)"
  D9_ROWS=(
    "HR8|the initiative pick|initiative pick"
    "HR8|NO-ROOT|NO-ROOT"
    "HR8|no default branch|no_default_branch"
    "HR8|push|git push"
    "HR8|open-PR|gh pr create"
    "HR8|worktree removal|remove nothing"
    "HR8|tracker write-back|tracker-states"
    "HR8|ASK_USER|ASK_USER"
    "BYP|the four \`y/n\` gates|remove nothing"
    "BYP|the four \`y/n\` gates|git push"
    "BYP|the four \`y/n\` gates|gh pr create"
    "BYP|the four \`y/n\` gates|tracker-states"
    "BYP|environment stops|environment stop"
    "BYP|the session pick|session pick"
    "BYP|the \"paste the ticket\" fallback|paste the ticket"
    "BYP|the third proposal-check FAIL|proposal_check_limit"
  )
  for row in "${D9_ROWS[@]}"; do
    src="${row%%|*}"; rest="${row#*|}"; phrase="${rest%%|*}"; token="${rest#*|}"
    if [[ "${src}" == "HR8" ]]; then text="${HR8}"; else text="${BYP}"; fi
    printf '%s' "${text}" | grep -qF -- "${phrase}" \
      || report "D9 mapping stale: SKILL.md (${src}) no longer names [${phrase}]."
    grep -iqF -- "${token}" "${RULES}" \
      || report "D9: SKILL.md (${src}) names [${phrase}] but headless.md lacks [${token}]."
  done
fi

# ---- AC5. Code list parity: headless.md vs the schema enums ----
codes_from_rules() { # codes_from_rules <failed|blocked>
  # shellcheck disable=SC2016 # the backticks are literal characters for grep
  grep -E "^[-*]? *\`$1\` *:" "${RULES}" | sed -e 's/^[^:]*://' \
    | grep -oE '`[a-z_]+`' | tr -d '`' | sort -u
}
codes_from_schema() { # codes_from_schema <failure|blocked_reason>
  # Reuse find_enum from check-run-summary.py (one source). run_path skips its main block.
  [[ -f "${VALIDATOR}" && -f "${SCHEMA}" ]] || return 1
  python3 -I -c 'import runpy,sys,json; m=runpy.run_path(sys.argv[1]); s=json.load(open(sys.argv[2])); e=m["find_enum"](s,[sys.argv[3],"code"]); sys.exit(1) if e is None else print("\n".join(e))' \
    "${VALIDATOR}" "${SCHEMA}" "$1" | sort -u
  return "${PIPESTATUS[0]}"
}

if [[ ! -f "${SCHEMA}" ]]; then
  report "${SCHEMA} is missing (AC5 parity not run)."
elif [[ -f "${RULES}" ]]; then
  for pair in "failed:failure" "blocked:blocked_reason"; do
    status="${pair%%:*}"; key="${pair#*:}"
    rules_codes="$(codes_from_rules "${status}")"
    schema_codes="$(codes_from_schema "${key}")" || schema_codes=""
    if [[ -z "${rules_codes}" ]]; then
      report "headless.md has no closed code list marked \`${status}\`."
    fi
    if [[ -z "${schema_codes}" ]]; then
      report "schema has no ${key}.code enum (or it cannot be read)."
    fi
    if [[ -n "${rules_codes}" && -n "${schema_codes}" ]]; then
      only_rules="$(comm -23 <(printf '%s\n' "${rules_codes}") <(printf '%s\n' "${schema_codes}"))"
      only_schema="$(comm -13 <(printf '%s\n' "${rules_codes}") <(printf '%s\n' "${schema_codes}"))"
      # shellcheck disable=SC2116,SC2086 # unquoted echo joins the lines into one line on purpose
      [[ -z "${only_rules}" ]] || report "${status} codes in headless.md but not in the schema: $(echo ${only_rules})."
      # shellcheck disable=SC2116,SC2086 # unquoted echo joins the lines into one line on purpose
      [[ -z "${only_schema}" ]] || report "${status} codes in the schema but not in headless.md: $(echo ${only_schema})."
    fi
  done
fi

# ---- AC6. Validator and fixtures ----
if [[ ! -f "${VALIDATOR}" ]]; then
  report "${VALIDATOR} is missing (AC6 not run)."
else
  for s in pr_opened blocked failed; do
    fx="${REPO_ROOT}/benchmark/run-summary-${s}.json"
    if [[ ! -f "${fx}" ]]; then
      report "fixture ${fx} is missing."
    else
      python3 -I "${VALIDATOR}" "${fx}" >/dev/null 2>&1 \
        || report "check-run-summary.py rejects fixture run-summary-${s}.json."
    fi
  done
  # Bad case: status blocked with a null blocked_reason. Made here, in a temp dir.
  mkdir -p "${TMP}/bad"
  cat > "${TMP}/bad/run-summary.json" <<'EOF'
{
  "schema_version": 1,
  "status": "blocked",
  "ticket": "T-1", "slug": "T-1",
  "branch": "t-1-x", "worktree": "/abs/.claude/worktrees/T-1",
  "pr_url": null,
  "stage_reached": "plan",
  "started_at": "2026-11-13T15:00:00Z", "finished_at": "2026-11-13T15:10:00Z",
  "duration_seconds": 600,
  "tasks": {"planned": 1, "passed": 0},
  "decisions": {"total": 1, "decided": 0, "ask_user": 1, "low_confidence": 0},
  "blocked_reason": null,
  "failure": null,
  "head_sha": "abc1234", "pushed": false,
  "notes": [], "follow_ups": [],
  "plugin_version": "1.26.0"
}
EOF
  if python3 -I "${VALIDATOR}" "${TMP}/bad/run-summary.json" >/dev/null 2>&1; then
    report "check-run-summary.py accepts a blocked summary with null blocked_reason."
  fi
fi

# ---- AC7 / D6. SKILL.md size ----
if [[ ! -f "${SKILL}" ]]; then
  report "${SKILL} is missing."
else
  size="$(wc -c < "${SKILL}" | tr -d ' ')"
  [[ "${size}" -le "${MAX_SKILL_BYTES}" ]] || report "SKILL.md is ${size} bytes, over ${MAX_SKILL_BYTES}."
fi

# ---- AC9. Bash 3.2 lint ----
# Five bash-4 constructs. One letter of each pattern sits in a bracket.
LINT_PATTERNS=(
  'map[f]ile'
  'read[a]rray'
  'declare -[A]'
  '\$\{[^}]*[,],'
  '\$\{[^}]*[\^]\^'
)
# lint_dirs <dir>...: print every hit. No file is excluded.
lint_dirs() {
  local pat
  for pat in "${LINT_PATTERNS[@]}"; do
    grep -rEn -e "${pat}" "$@" 2>/dev/null
  done
}
hits="$(lint_dirs "${SCRIPT_DIR}" "${P}/scripts")"
if [[ -n "${hits}" ]]; then
  report "bash-4 construct in .github/ci/ or plugin scripts/:"
  printf '%s\n' "${hits}" >&2
fi
# Seed a temp file with each word, built from parts, and confirm the lint sees it.
mkdir -p "${TMP}/seed"
{
  echo "map""file -t x"
  echo "read""array -t x"
  echo "declare -""A m"
  echo 'echo $'"{x"',,}'
  echo 'echo $'"{x"'^^}'
  echo 'echo $'"{X"',,}'
  echo 'echo $'"{1"'^^}'
} > "${TMP}/seed/bad.sh"
seed_hits="$(lint_dirs "${TMP}/seed")"
seed_count="$(printf '%s\n' "${seed_hits}" | grep -c . || true)"
[[ "${seed_count}" -eq 7 ]] || report "lint found ${seed_count} of 7 seeded bash-4 constructs."

if [[ "${fail}" -ne 0 ]]; then
  echo "check-headless.sh: FAILED" >&2
  exit 1
fi
echo "check-headless.sh: OK"
