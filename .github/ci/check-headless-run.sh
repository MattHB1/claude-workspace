#!/usr/bin/env bash
# Tier 2 headless run check. Needs the claude CLI, jq and ANTHROPIC_API_KEY.
# Run from any folder: bash .github/ci/check-headless-run.sh
# This script makes real claude -p calls. It runs only in the Tier 2 workflow.
#
# It makes a temp fixture repo, a local bare origin, a stub gh and a ticket file.
# The .workspace folder is made at run time in the temp folder (never committed).
# Cases:
#   (a) a ticket that needs a human decision: status blocked, a WIP commit
#       on the bare origin, and no PR (the stub gh logs every call);
#   (b) WORKSPACE_MAX_MINUTES=0: status failed with code time_limit;
#   (c) WORKSPACE_HEADLESS unset: the output shows the pick list.
# Prints one PASS or FAIL line per case. Exit 0 = all pass; non-zero = any FAIL.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
PLUGIN="${REPO_ROOT}/plugins/claude-workspace"

[[ -d "${PLUGIN}" ]] || { echo "ERROR: plugin not found: ${PLUGIN}" >&2; exit 1; }
for t in claude jq git; do
  command -v "${t}" >/dev/null 2>&1 || { echo "ERROR: ${t} not found" >&2; exit 1; }
done

export GIT_CONFIG_NOSYSTEM=1
unset CLAUDE_PROJECT_DIR GIT_DIR GIT_WORK_TREE

TMP="$(mktemp -d)"
TMP="$(cd "${TMP}" && pwd -P)"
trap 'rm -rf "${TMP}"' EXIT

FAILS=0
CUR=""
fail() { CUR+="    ${1}"$'\n'; }
report() { # report <case>
  if [[ -z "${CUR}" ]]; then echo "PASS ${1}"
  else echo "FAIL ${1}"; printf '%s' "${CUR}"; FAILS=$((FAILS + 1)); fi
  CUR=""
}
gq() { git -c user.email=t@t -c user.name=t -c init.defaultBranch=main "$@" >/dev/null 2>&1; }
# last_result FILE: the last WORKSPACE_RESULT: line of a stdout file.
last_result() { grep '^WORKSPACE_RESULT:' "$1" 2>/dev/null | tail -n 1; }

# Stub gh: auth succeeds, every call is logged, so a PR call can be found.
STUB="${TMP}/stub"
mkdir -p "${STUB}"
cat > "${STUB}/gh" <<'STUBEOF'
#!/usr/bin/env bash
echo "$*" >> "${GH_LOG}"
case "$1 $2" in
  "pr create") echo "https://example.invalid/pull/1" ;;
esac
exit 0
STUBEOF
chmod +x "${STUB}/gh"

# mkfixture NAME: repo TMP/NAME on main with a bare origin TMP/NAME-origin.git.
mkfixture() {
  local d="${TMP}/$1"
  gq init --bare "${d}-origin.git"
  gq init "${d}"
  printf '.workspace/\n' > "${d}/.gitignore"
  printf 'def greet():\n    return "hello"\n' > "${d}/app.py"
  gq -C "${d}" add -A; gq -C "${d}" commit -m init
  git -C "${d}" config user.email t@t
  git -C "${d}" config user.name t
  gq -C "${d}" remote add origin "${d}-origin.git"
  gq -C "${d}" push origin main
  mkdir -p "${d}/.workspace"
}

# run_claude NAME OUTFILE [VAR=value ...]: run the skill in fixture NAME with a temp HOME.
run_claude() {
  local name=$1 out=$2; shift 2
  mkdir -p "${TMP}/home-${name}"
  ( unset WORKSPACE_HEADLESS; cd "${TMP}/${name}" && env HOME="${TMP}/home-${name}" PATH="${STUB}:${PATH}" \
      GH_LOG="${TMP}/${name}-gh.log" "$@" \
      claude --plugin-dir "${PLUGIN}" --permission-mode bypassPermissions \
      -p "/claude-workspace:workspace FIX-1" > "${out}" 2> "${out}.err" ) || true
}

# summary_field NAME JQ-EXPR: read one field of the run summary of fixture NAME.
summary_field() {
  local f
  # shellcheck disable=SC2012 # the glob yields plain names; ls output feeds head only
  f="$(ls "${TMP}/$1"/.workspace/*/run-summary.json 2>/dev/null | head -n 1)"
  [[ -n "${f}" ]] || { echo "none"; return; }
  jq -r "$2" "${f}" 2>/dev/null || echo "none"
}

# Ticket texts. Case (a) needs a product choice that the judge cannot decide.
printf 'FIX-1: Change greet() in app.py.\nThe new text depends on a product decision that nobody has made.\nDo not guess. Ask the product owner which text to use.\n' > "${TMP}/ticket-a.md"
printf 'FIX-1: Change greet() in app.py to return "hi".\n' > "${TMP}/ticket-b.md"

# ---- (a) blocked: WIP commit on origin, no PR ----
mkfixture a
: > "${TMP}/a-gh.log"
run_claude a "${TMP}/a.out" WORKSPACE_HEADLESS=1 WORKSPACE_TICKET=FIX-1 \
  WORKSPACE_TICKET_FILE="${TMP}/ticket-a.md"
[[ "$(summary_field a '.status')" == "blocked" ]] || fail "a: status is not blocked"
last_result "${TMP}/a.out" | grep -q '^WORKSPACE_RESULT: blocked' || fail "a: last line is not WORKSPACE_RESULT: blocked"
refs="$(git -C "${TMP}/a-origin.git" for-each-ref --format='%(refname:short)' refs/heads | grep -v '^main$' || true)"
[[ -n "${refs}" ]] || fail "a: no WIP branch on the bare origin"
for br in ${refs}; do
  n="$(git -C "${TMP}/a-origin.git" rev-list --count "main..${br}" 2>/dev/null || echo 0)"
  subj="$(git -C "${TMP}/a-origin.git" log -1 --format=%s "${br}" 2>/dev/null || true)"
  [[ "${n}" -gt 0 ]] || fail "a: branch ${br} has no commit beyond main"
  case "${subj}" in
    "wip(headless): blocked"*) ;;
    *) fail "a: branch ${br} subject is not 'wip(headless): blocked...' (got: ${subj})" ;;
  esac
done
grep -q 'pr create' "${TMP}/a-gh.log" && fail "a: a PR was created"
report "a (blocked, WIP commit, no PR)"

# ---- (b) WORKSPACE_MAX_MINUTES=0 -> failed / time_limit ----
mkfixture b
: > "${TMP}/b-gh.log"
run_claude b "${TMP}/b.out" WORKSPACE_HEADLESS=1 WORKSPACE_TICKET=FIX-1 \
  WORKSPACE_TICKET_FILE="${TMP}/ticket-b.md" WORKSPACE_MAX_MINUTES=0
[[ "$(summary_field b '.status')" == "failed" ]] || fail "b: status is not failed"
[[ "$(summary_field b '.failure.code')" == "time_limit" ]] || fail "b: failure code is not time_limit"
last_result "${TMP}/b.out" | grep -q '^WORKSPACE_RESULT: failed' || fail "b: last line is not WORKSPACE_RESULT: failed"
report "b (MAX_MINUTES=0, failed time_limit)"

# ---- (c) switch unset: the pick list shows ----
mkfixture c
: > "${TMP}/c-gh.log"
# shellcheck disable=SC2016 # the backticks are literal text in the file
printf '# Initiatives\n\n| Slug | Description | Status | Active |\n|---|---|---|---|\n| `demo-open` | Demo initiative. | in progress |  |\n' > "${TMP}/c/.workspace/initiatives.md"
run_claude c "${TMP}/c.out"
grep -q 'demo-open' "${TMP}/c.out" || fail "c: pick list does not show the seeded slug demo-open"
grep -qi 'new initiative' "${TMP}/c.out" || fail "c: pick list does not offer a new initiative"
grep -q 'WORKSPACE_RESULT:' "${TMP}/c.out" && fail "c: headless result line in interactive output"
report "c (switch unset, pick list)"

exit $(( FAILS > 0 ? 1 : 0 ))
