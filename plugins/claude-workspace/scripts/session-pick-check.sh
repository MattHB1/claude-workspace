#!/usr/bin/env bash
# session-pick-check.sh <slug>
# Prints the pick-check lines for this session. A BLOCK line names the blocking marker.
# MAIN-ALLOWED means the repo allows one live session. SAME-CHECKOUT names another
# marker on this checkout. LIVE-CHECKOUT lists every other marker with the same root.
slug="$1"
M="$HOME/.claude/.workspace-active"; me="$M/$CLAUDE_CODE_SESSION_ID"
root=$(sed -n 's/^root=//p' "$me")
if [ -z "$root" ]; then
  echo "NO-ROOT: stop the pick and ask the user"
else
  co=$(sed -n 's/^checkout=//p' "$me"); co=${co:-$root}
  allowed=no; [ "$(cat "$root/.workspace/main-commits" 2>/dev/null)" = allowed ] && allowed=yes
  [ "$allowed" = yes ] && echo "MAIN-ALLOWED"
  find "$M" -type f ! -path "$me" | while read -r f; do
    [ "$(sed -n 's/^root=//p' "$f")" = "$root" ] || continue
    oc=$(sed -n 's/^checkout=//p' "$f"); oc=${oc:-$root}
    echo "LIVE-CHECKOUT: $f checkout=$oc"
    if [ "$allowed" = yes ]; then echo "BLOCK one-session: $f"
    else
      if [ "$(sed -n 's/^slug=//p' "$f")" = "$slug" ]; then echo "BLOCK same-initiative: $f"; fi
      if [ "$oc" = "$co" ]; then echo "SAME-CHECKOUT: $f"; fi
    fi
  done
fi
