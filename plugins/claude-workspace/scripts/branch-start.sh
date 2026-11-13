#!/usr/bin/env bash
# branch-start.sh <root>
# Prints the start point for a new branch. Does not move any branch.
r="$1"
if git -C "$r" remote get-url origin >/dev/null 2>&1; then
  if git -C "$r" fetch origin >/dev/null 2>&1; then ok=yes; else ok=no; fi
else ok=none; fi
d=$(git -C "$r" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##')
for c in main master; do
  if [ -z "$d" ]; then
    if git -C "$r" show-ref --verify --quiet "refs/heads/$c" || git -C "$r" show-ref --verify --quiet "refs/remotes/origin/$c"; then d=$c; fi
  fi
done
if [ -z "$d" ]; then echo "NO-DEFAULT: stop and ask the user"
elif [ "$ok" = yes ] && git -C "$r" show-ref --verify --quiet "refs/remotes/origin/$d"; then echo "START=origin/$d"
elif [ "$ok" = yes ]; then echo "START=$d (origin has no $d: tell the user that the start point is the local $d)"
elif [ "$ok" = none ]; then echo "START=$d (no origin: tell the user there was no fetch)"
else echo "FETCH-FAILED: stop and report"; fi
