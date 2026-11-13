#!/usr/bin/env bash
# worktree-exclude.sh <root>
# Adds .claude/worktrees/ to the common git exclude. Changes no tracked file.
g=$(git -C "$1" rev-parse --path-format=absolute --git-common-dir)
mkdir -p "$g/info"
if ! grep -qxF '.claude/worktrees/' "$g/info/exclude" 2>/dev/null; then
  [ -n "$(tail -c1 "$g/info/exclude" 2>/dev/null)" ] && echo >> "$g/info/exclude"
  echo '.claude/worktrees/' >> "$g/info/exclude"
fi
