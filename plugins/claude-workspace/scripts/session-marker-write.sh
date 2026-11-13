#!/usr/bin/env bash
# session-marker-write.sh <slug> [checkout]
# Rewrites this session's marker. Keeps the root= and checkout= already there.
# Pass a checkout path to record a worktree (it replaces checkout=).
slug="$1"
M="$HOME/.claude/.workspace-active"; me="$M/$CLAUDE_CODE_SESSION_ID"
root=$(sed -n 's/^root=//p' "$me"); co=$(sed -n 's/^checkout=//p' "$me")
if [ -n "${2:-}" ]; then co="$2"; fi
printf 'root=%s\ncheckout=%s\nslug=%s\n' "$root" "$co" "$slug" > "$me"
