#!/usr/bin/env bash
# Check for multi-live-workspaces: AC4, AC5, AC8, AC8c, AC8d, AC8e.
#
# Builds temporary git repos with a bare origin and linked worktrees, and sets a
# temporary HOME (M8) so the real ~/.claude is never read or written. The shell
# recipes are extracted from plugins/claude-workspace/skills/workspace/SKILL.md
# and run as that file states them, so the test follows the skill. This session's
# marker comes from `statusline-marker.py --session <id> --cwd <path>`.
#
# Run from any folder: bash .github/ci/check-multi-live.sh
# Prints one PASS or FAIL line per AC. Exit 0 = all pass; non-zero = any FAIL.
# Not listed in expected.sh.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
PLUGIN="${REPO_ROOT}/plugins/claude-workspace"
SKILL="${PLUGIN}/skills/workspace/SKILL.md"
HOOK="${PLUGIN}/hooks/statusline-marker.py"
AUTOLOG="${PLUGIN}/hooks/autolog.py"
CONFORM="${PLUGIN}/hooks/conform-registry.py"
STATUSLINE="${PLUGIN}/scripts/statusline.js"

for f in "${SKILL}" "${HOOK}" "${AUTOLOG}" "${CONFORM}" "${STATUSLINE}"; do
  [[ -f "${f}" ]] || { echo "ERROR: file not found: ${f}" >&2; exit 1; }
done

export PYTHONDONTWRITEBYTECODE=1 GIT_CONFIG_NOSYSTEM=1
unset CLAUDE_PROJECT_DIR GIT_DIR GIT_WORK_TREE

TMP="$(mktemp -d)"
TMP="$(cd "${TMP}" && pwd -P)"
trap 'rm -rf "${TMP}"' EXIT
H="${TMP}/home"
MDIR="${H}/.claude/.workspace-active"
mkdir -p "${MDIR}"

FAILS=0
CUR=""   # failure messages of the AC under test

fail() { CUR+="    ${1}"$'\n'; }
check() { # check "<description>" <test command...>
  local d=$1; shift
  "$@" >/dev/null 2>&1 || fail "${d}"
}
eq() { # eq "<description>" "<got>" "<want>"
  [[ "$2" == "$3" ]] || fail "$1: got [$2], want [$3]"
}
report() { # report <AC>
  if [[ -z "${CUR}" ]]; then echo "PASS ${1}"
  else echo "FAIL ${1}"; printf '%s' "${CUR}"; FAILS=$((FAILS + 1)); fi
  CUR=""
}

# ---- git helpers ----
gq() { git -c user.email=t@t -c user.name=t -c init.defaultBranch=main "$@" >/dev/null 2>&1; }

# mkrepo DIR: bare origin DIR-origin.git; repo DIR on main (one commit); origin one commit ahead.
mkrepo() {
  local d=$1
  gq init --bare "${d}-origin.git"
  gq init "${d}"
  printf '.workspace/\n' > "${d}/.gitignore"; echo a > "${d}/f"
  gq -C "${d}" add -A; gq -C "${d}" commit -m c1
  gq -C "${d}" remote add origin "${d}-origin.git"; gq -C "${d}" push origin main
  gq clone "${d}-origin.git" "${d}-tmp"
  echo b >> "${d}-tmp/f"; gq -C "${d}-tmp" commit -am c2-origin
  gq -C "${d}-tmp" push origin main; rm -rf "${d}-tmp"
  gq -C "${d}" fetch origin   # origin/main is one commit ahead of local main
}
# push_origin_commit DIR: add one more commit to origin of DIR (no fetch in DIR).
push_origin_commit() {
  local d=$1
  gq clone "${d}-origin.git" "${d}-tmp"
  echo c >> "${d}-tmp/f"; gq -C "${d}-tmp" commit -am c3-origin
  gq -C "${d}-tmp" push origin main; rm -rf "${d}-tmp"
}

# ---- recipe extraction from SKILL.md ----
# code_block <anchor-regex>: print the first fenced block after the first line that matches the anchor.
code_block() {
  awk -v a="$1" '
    !found && $0 ~ a { found = 1; next }
    found && /^```/ { if (inb) exit; inb = 1; next }
    found && inb { print }
  ' "${SKILL}"
}
# bullet_cmds <bullet-prefix>: print each backtick span (one per line) of the bullet that starts with the prefix.
bullet_cmds() {
  awk -v p="$1" 'index($0, p) == 1 { s = $0; while (match(s, /`[^`]+`/)) { print substr(s, RSTART + 1, RLENGTH - 2); s = substr(s, RSTART + RLENGTH) } }' "${SKILL}"
}

R_PICK="$(code_block '^Shell recipe for the check')"
R_MARK="$(code_block '^\*\*After the pick passes')"
R_S2="$(code_block '^\*\*2\. Use an existing worktree')"
R_S3="$(code_block '^\*\*3\. Start point')"
R_S4="$(code_block '^\*\*4\. Keep worktrees')"
S5_WT_NEW="$(bullet_cmds '- Worktree needed, new branch:' | sed -n 1p)"
S5_WT_OLD="$(bullet_cmds '- Worktree needed, existing branch:' | sed -n 1p)"
S5_NO_NEW_1="$(bullet_cmds '- No worktree needed, new branch:' | sed -n 1p)"
S5_NO_NEW_2="$(bullet_cmds '- No worktree needed, new branch:' | sed -n 2p)"
for v in R_PICK R_MARK R_S2 R_S3 R_S4 S5_WT_NEW S5_WT_OLD S5_NO_NEW_1 S5_NO_NEW_2; do
  [[ -n "${!v}" ]] || { echo "ERROR: could not extract recipe ${v} from ${SKILL}" >&2; exit 1; }
done

# run_in CWD SID CODE [KEY=VALUE ...]: run one recipe as its own bash call.
# Replaces <slug> <root> <branch> <start> <wt> with the values in SUB_*.
sub() {
  local c=$1
  c=${c//<slug>/${SUB_SLUG:-}}; c=${c//<root>/${SUB_ROOT:-}}; c=${c//<branch>/${SUB_BRANCH:-}}
  c=${c//<start>/${SUB_START:-}}; c=${c//<worktree path>/${SUB_WT:-}}
  printf '%s' "${c}"
}
run_in() {
  local cwd=$1 sid=$2 code; code="$(sub "$3")"
  (cd "${cwd}" && HOME="${H}" CLAUDE_CODE_SESSION_ID="${sid}" bash -c "${code}" 2>&1)
}
# Step 0 of SKILL.md: the marker command, through the hook's command-line mode.
step0() { (cd "$1" && HOME="${H}" python3 -B "${HOOK}" --session "$2" --cwd "$1" >/dev/null 2>&1); }
# Marker write recipe. A worktree adds the line co="<worktree path>" after the co=$(...) line.
mark_write() { # mark_write CWD SID SLUG [WORKTREE]
  local code="${R_MARK}"
  if [[ -n "${4:-}" ]]; then
    code="$(printf '%s\n' "${code}" | awk -v w="$4" '{print} /co=\$\(/ {print "co=\"" w "\""}')"
  fi
  SUB_SLUG=$3 run_in "$1" "$2" "${code}" >/dev/null
}
# cd_info DIR: the Step 6 check, run as its own bash call. Prints pwd, then the branch.
cd_info() { (cd "${REPO_ROOT}" && HOME="${H}" bash -c "cd \"$1\" && pwd && git branch --show-current"); }
mval() { sed -n "s/^$2=//p" "${MDIR}/$1"; } # mval SID KEY

# =====================================================================
# Repo 1: main-locked. Main checkout on init-a (one extra commit). Session B is live
# on the main checkout with another slug. Session A picks a new initiative.
# =====================================================================
R1="${TMP}/r1"; mkrepo "${R1}"
gq -C "${R1}" switch -c init-a
echo x > "${R1}/x"; gq -C "${R1}" add -A; gq -C "${R1}" commit -m init-a-commit
INITA="$(git -C "${R1}" rev-parse HEAD)"
LOCAL_MAIN_BEFORE="$(git -C "${R1}" rev-parse main)"
ORIGIN_MAIN="$(git -C "${R1}" rev-parse origin/main)"
mkdir -p "${R1}/.workspace"
step0 "${R1}" sess-a
step0 "${R1}" sess-b
# session B holds slug "other" (its own marker, written by the marker recipe)
SUB_SLUG=other run_in "${R1}" sess-b "${R_MARK}" >/dev/null
MARK_A_BEFORE="$(cat "${MDIR}/sess-a")"

# ---- AC5: marker of another session with same root= and slug= blocks ----
OUT="$(SUB_SLUG=other run_in "${R1}" sess-a "${R_PICK}")"
[[ "${OUT}" == *"BLOCK same-initiative: ${MDIR}/sess-b"* ]] || fail "same slug: no BLOCK naming ${MDIR}/sess-b; output [${OUT}]"
eq "AC5 this marker unchanged" "$(cat "${MDIR}/sess-a")" "${MARK_A_BEFORE}"
OUT="$(SUB_SLUG=init-a run_in "${R1}" sess-a "${R_PICK}")"
[[ "${OUT}" != *BLOCK* ]] || fail "different slug blocked; output [${OUT}]"
# A marker with another root= does not block.
printf 'root=%s\ncheckout=%s\nslug=%s\n' "/elsewhere" "/elsewhere" "init-a" > "${MDIR}/sess-x"
OUT="$(SUB_SLUG=init-a run_in "${R1}" sess-a "${R_PICK}")"
[[ "${OUT}" != *BLOCK* ]] || fail "marker with another root blocked; output [${OUT}]"
rm -f "${MDIR}/sess-x"
eq "step0 root=" "$(mval sess-a root)" "${R1}"
eq "step0 checkout=" "$(mval sess-a checkout)" "${R1}"
report AC5

# ---- AC8: worktree needed, new branch ----
SUB_SLUG=init-a
OUT="$(run_in "${R1}" sess-a "${R_PICK}")"
[[ "${OUT}" == *"SAME-CHECKOUT: ${MDIR}/sess-b"* ]] || fail "step 1: no SAME-CHECKOUT line; output [${OUT}]"
[[ "${OUT}" != *MAIN-ALLOWED* ]] || fail "step 1: MAIN-ALLOWED printed in a main-locked repo"
SUB_ROOT="${R1}"
OUT="$(run_in "${R1}" sess-a "${R_S3}")"
eq "step 3 start point" "${OUT}" "START=origin/main"
SUB_START=origin/main
run_in "${R1}" sess-a "${R_S4}" >/dev/null
BRANCH=init-a-new; WT="${R1}/.claude/worktrees/ticket-1"
SUB_ROOT="${R1}" SUB_SLUG=ticket-1 SUB_BRANCH=${BRANCH} SUB_WT="${WT}" SUB_START=origin/main
# new-initiative pick uses the new slug for the path
OUT="$(SUB_SLUG=ticket-1 run_in "${R1}" sess-a "${R_PICK}")"
[[ "${OUT}" == *SAME-CHECKOUT* ]] || fail "pick check for ticket-1 lost SAME-CHECKOUT"
run_in "${R1}" sess-a "${S5_WT_NEW}" >/dev/null
eq "main checkout branch unchanged" "$(git -C "${R1}" branch --show-current)" "init-a"
git -C "${R1}" worktree list --porcelain | grep -qxF "worktree ${WT}" || fail "worktree list lacks ${WT}"
git -C "${R1}" worktree list --porcelain | grep -qxF "branch refs/heads/${BRANCH}" || fail "worktree list lacks branch ${BRANCH}"
eq "worktree branch" "$(git -C "${WT}" branch --show-current)" "${BRANCH}"
# AC10 spot check: the worktree folder does not show in git status.
eq "git status of main checkout" "$(git -C "${R1}" status --porcelain)" ""
report AC8

# ---- AC8d: cd, pwd, branch, marker checkout= ----
mark_write "${R1}" sess-a ticket-1 "${WT}"
OUT="$(run_in "${R1}" sess-a "cd \"${WT}\"")"; eq "cd exit output" "${OUT}" ""
OUT="$(cd_info "${WT}")"
eq "AC8d pwd" "$(printf '%s\n' "${OUT}" | sed -n 1p)" "${WT}"
eq "AC8d branch" "$(printf '%s\n' "${OUT}" | sed -n 2p)" "${BRANCH}"
eq "AC8d marker checkout=" "$(mval sess-a checkout)" "${WT}"
eq "AC8d marker root=" "$(mval sess-a root)" "${R1}"
eq "AC8d marker slug=" "$(mval sess-a slug)" "ticket-1"
check "AC8d: SKILL.md states the working-directory line for the three briefs" \
  grep -q 'Add a working-directory line to each brief for `implementer`, `implementation-verifier` and `archivist`' "${SKILL}"
check "AC8d: SKILL.md states the .workspace/ path rule" \
  grep -q '`.workspace/` paths stay at `<root>/.workspace/`' "${SKILL}"
report AC8d

# ---- AC4: one shared .workspace/ from the worktree ----
cat > "${R1}/.workspace/initiatives.md" <<'REG'
# Initiatives

| Slug | Description | Status | Active |
|------|-------------|--------|--------|
| ticket-1 | test row | open | **ACTIVE** |
REG
EV_STOP="{\"session_id\":\"sess-a\",\"cwd\":\"${WT}\",\"hook_event_name\":\"Stop\"}"
(cd "${WT}" && HOME="${H}" CLAUDE_PROJECT_DIR="${WT}" python3 -B "${AUTOLOG}" <<<"${EV_STOP}" >/dev/null 2>&1)
check "autolog wrote ${R1}/.workspace/ticket-1/memory/events.jsonl" test -s "${R1}/.workspace/ticket-1/memory/events.jsonl"
(cd "${WT}" && HOME="${H}" CLAUDE_PROJECT_DIR="${WT}" python3 -B "${CONFORM}" <<<"{\"cwd\":\"${WT}\",\"hook_event_name\":\"SessionStart\"}" >/dev/null 2>&1)
grep -qF '| `ticket-1` |' "${R1}/.workspace/initiatives.md" || fail "conform-registry did not rewrite the registry at the shared root"
SL="$(cd "${WT}" && HOME="${H}" CLAUDE_PROJECT_DIR="${WT}" node "${STATUSLINE}" <<<"{\"session_id\":\"sess-a\",\"cwd\":\"${WT}\",\"workspace\":{\"current_dir\":\"${WT}\"}}" 2>&1)"
[[ "${SL}" == *"ticket-1"* ]] || fail "statusline.js shows no slug from the marker; output [${SL}]"
[[ -z "$(find "${WT}" -name '.workspace' -not -path '*/.git/*' 2>/dev/null)" ]] || fail "a .workspace entry exists below the worktree"
# Outside git: the root is $CLAUDE_PROJECT_DIR, as today.
NG="${TMP}/nogit"; mkdir -p "${NG}/.workspace"
(export CLAUDE_PROJECT_DIR="${NG}"; step0 "${NG}" sess-ng)   # Step 0 outside git, then the marker recipe
mark_write "${NG}" sess-ng ng-1
(cd "${NG}" && HOME="${H}" CLAUDE_PROJECT_DIR="${NG}" python3 -B "${AUTOLOG}" <<<"{\"session_id\":\"sess-ng\",\"cwd\":\"${NG}\",\"hook_event_name\":\"Stop\"}" >/dev/null 2>&1)
check "outside git: autolog wrote under \$CLAUDE_PROJECT_DIR/.workspace/" test -s "${NG}/.workspace/ng-1/memory/events.jsonl"
printf '# Initiatives\n\n| Slug | Description | Status | Active |\n|------|-------------|--------|--------|\n| ng-1 | row | open | **ACTIVE** |\n' > "${NG}/.workspace/initiatives.md"
(cd "${NG}" && HOME="${H}" CLAUDE_PROJECT_DIR="${NG}" python3 -B "${CONFORM}" <<<"{\"cwd\":\"${NG}\",\"hook_event_name\":\"SessionStart\"}" >/dev/null 2>&1)
grep -qF '| `ng-1` |' "${NG}/.workspace/initiatives.md" || fail "outside git: conform-registry did not use \$CLAUDE_PROJECT_DIR"
report AC4

# ---- AC8e (a) to (c), worktree form (b) ----
eq "(b) worktree branch tip" "$(git -C "${R1}" rev-parse "${BRANCH}")" "${ORIGIN_MAIN}"
git -C "${R1}" merge-base --is-ancestor "${INITA}" "${BRANCH}" 2>/dev/null && fail "(c) init-a commit is an ancestor of ${BRANCH}"
eq "(c) local main did not move" "$(git -C "${R1}" rev-parse main)" "${LOCAL_MAIN_BEFORE}"
git -C "${R1}" rev-parse --abbrev-ref "${BRANCH}@{u}" >/dev/null 2>&1 && fail "(c) ${BRANCH} has an upstream"

# =====================================================================
# Repo 2: AC8e (a): no marker, main checkout on init-a, no-worktree Create.
# =====================================================================
R2="${TMP}/r2"; mkrepo "${R2}"
gq -C "${R2}" switch -c init-a; echo x > "${R2}/x"; gq -C "${R2}" add -A; gq -C "${R2}" commit -m init-a-commit
INITA2="$(git -C "${R2}" rev-parse HEAD)"; MAIN2="$(git -C "${R2}" rev-parse main)"; OM2="$(git -C "${R2}" rev-parse origin/main)"
step0 "${R2}" sess-c
SUB_ROOT="${R2}" SUB_SLUG=ticket-2 SUB_BRANCH=ticket-2-branch
OUT="$(run_in "${R2}" sess-c "${R_PICK}")"
[[ "${OUT}" != *SAME-CHECKOUT* && "${OUT}" != *MAIN-ALLOWED* ]] || fail "(a) step 1 wrongly asks for a worktree; output [${OUT}]"
eq "(a) start point" "$(run_in "${R2}" sess-c "${R_S3}")" "START=origin/main"
SUB_START=origin/main
run_in "${R2}" sess-c "${S5_NO_NEW_1}" >/dev/null
run_in "${R2}" sess-c "${S5_NO_NEW_2}" >/dev/null
eq "(a) current branch" "$(git -C "${R2}" branch --show-current)" "ticket-2-branch"
eq "(a) tip is the origin/main commit" "$(git -C "${R2}" rev-parse ticket-2-branch)" "${OM2}"
git -C "${R2}" merge-base --is-ancestor "${INITA2}" ticket-2-branch 2>/dev/null && fail "(a) init-a commit is an ancestor"
eq "(a) local main did not move" "$(git -C "${R2}" rev-parse main)" "${MAIN2}"
git -C "${R2}" rev-parse --abbrev-ref "ticket-2-branch@{u}" >/dev/null 2>&1 && fail "(a) branch has an upstream"
[[ "$(git -C "${R2}" worktree list | wc -l | tr -d ' ')" == 1 ]] || fail "(a) a worktree was created"

# ---- AC8e (d): main on main, marker present, new commit on origin ----
R3="${TMP}/r3"; mkrepo "${R3}"
step0 "${R3}" sess-d; step0 "${R3}" sess-e
SUB_SLUG=other run_in "${R3}" sess-e "${R_MARK}" >/dev/null
push_origin_commit "${R3}"   # origin gets c3; R3 has not fetched it
NEW_ORIGIN="$(git -C "${R3}-origin.git" rev-parse main)"
HEAD3="$(git -C "${R3}" rev-parse HEAD)"; ST3="$(git -C "${R3}" status --porcelain)"; MAIN3="$(git -C "${R3}" rev-parse main)"
SUB_ROOT="${R3}" SUB_SLUG=ticket-3 SUB_BRANCH=ticket-3-branch SUB_WT="${R3}/.claude/worktrees/ticket-3"
OUT="$(run_in "${R3}" sess-d "${R_PICK}")"
[[ "${OUT}" == *SAME-CHECKOUT* ]] || fail "(d) step 1 prints no SAME-CHECKOUT; output [${OUT}]"
eq "(d) start point" "$(run_in "${R3}" sess-d "${R_S3}")" "START=origin/main"
SUB_START=origin/main
run_in "${R3}" sess-d "${R_S4}" >/dev/null
run_in "${R3}" sess-d "${S5_WT_NEW}" >/dev/null
eq "(d) tip has the new origin commit" "$(git -C "${R3}" rev-parse ticket-3-branch)" "${NEW_ORIGIN}"
eq "(d) main HEAD unchanged" "$(git -C "${R3}" rev-parse HEAD)" "${HEAD3}"
eq "(d) main status unchanged" "$(git -C "${R3}" status --porcelain)" "${ST3}"
eq "(d) local main did not move" "$(git -C "${R3}" rev-parse main)" "${MAIN3}"
git -C "${R3}" rev-parse --abbrev-ref "ticket-3-branch@{u}" >/dev/null 2>&1 && fail "(d) branch has an upstream"
eq "(d) worktree branch" "$(git -C "${R3}" worktree list --porcelain | awk -v p="worktree ${SUB_WT}" '$0==p{f=1} f&&/^branch /{print $2; exit}')" "refs/heads/ticket-3-branch"
eq "(d) pick check on repo with a worktree: git status clean" "$(git -C "${R3}" status --porcelain)" ""
report AC8e

# =====================================================================
# Repo 4: AC8c: main-locked, branch held by a linked worktree, no other marker.
# =====================================================================
R4="${TMP}/r4"; mkrepo "${R4}"
EXW="${TMP}/existing wt"
gq -C "${R4}" worktree add --no-track -b w "${EXW}" origin/main
step0 "${R4}" sess-f
SUB_ROOT="${R4}" SUB_SLUG=w SUB_BRANCH=w
OUT="$(run_in "${R4}" sess-f "${R_PICK}")"
[[ "${OUT}" != *SAME-CHECKOUT* ]] || fail "step 1 asks for a worktree with no other marker; output [${OUT}]"
eq "step 2 prints the worktree path" "$(run_in "${R4}" sess-f "${R_S2}")" "${EXW}"
eq "main checkout not switched" "$(git -C "${R4}" branch --show-current)" "main"
# A branch with no linked worktree prints nothing.
SUB_BRANCH=nope; eq "step 2 prints nothing for a branch with no worktree" "$(run_in "${R4}" sess-f "${R_S2}")" ""
SUB_BRANCH=w
# Step 6 with the existing worktree.
mark_write "${R4}" sess-f w "${EXW}"
OUT="$(cd_info "${EXW}")"
eq "AC8c pwd" "$(printf '%s\n' "${OUT}" | sed -n 1p)" "${EXW}"
eq "AC8c branch" "$(printf '%s\n' "${OUT}" | sed -n 2p)" "w"
eq "AC8c marker checkout=" "$(mval sess-f checkout)" "${EXW}"
[[ "$(git -C "${R4}" worktree list | wc -l | tr -d ' ')" == 2 ]] || fail "a new worktree was made for an existing one"
# Existing branch with no worktree, worktree needed: the existing-branch form.
gq -C "${R4}" branch --no-track old origin/main
step0 "${R4}" sess-g; step0 "${R4}" sess-h
SUB_SLUG=other run_in "${R4}" sess-h "${R_MARK}" >/dev/null
SUB_BRANCH=old SUB_SLUG=old-i SUB_WT="${R4}/.claude/worktrees/old-i"
run_in "${R4}" sess-g "${R_S4}" >/dev/null
run_in "${R4}" sess-g "${S5_WT_OLD}" >/dev/null
eq "existing-branch worktree" "$(git -C "${SUB_WT}" branch --show-current)" "old"
report AC8c

echo
if [[ "${FAILS}" -gt 0 ]]; then
  echo "FAIL: ${FAILS} AC check(s) failed"
  exit 1
fi
echo "OK: all multi-live checks passed"
exit 0
