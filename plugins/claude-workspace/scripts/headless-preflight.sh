#!/usr/bin/env bash
# headless-preflight.sh <root>
# Prints OK, or one "ERROR: <code>" line (first failing check wins).
# Codes: dirty_main, no_origin, main_allowed_repo, gh_unavailable.
# Changes under .workspace/ and .claude/worktrees/ do not count as dirty.
# The main-allowed test is copied from session-pick-check.sh. That script
# reads the root from the session marker and takes a slug. Preflight has no marker.
root="$1"
if [ -n "$(git -C "$root" status --porcelain -- . ':(exclude).workspace' ':(exclude).claude/worktrees' 2>/dev/null)" ]; then
  echo "ERROR: dirty_main"; exit 1
fi
if ! git -C "$root" remote get-url origin >/dev/null 2>&1; then
  echo "ERROR: no_origin"; exit 1
fi
if [ "$(cat "$root/.workspace/main-commits" 2>/dev/null)" = allowed ]; then
  echo "ERROR: main_allowed_repo"; exit 1
fi
if ! gh auth status >/dev/null 2>&1; then
  echo "ERROR: gh_unavailable"; exit 1
fi
echo "OK"
