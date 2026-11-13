# Registry history

The live rules are in the workspace skill: row shape, no `**ACTIVE**` marker, and you as the only writer. This page is the history those rules replaced.

## An old `**ACTIVE**` cell

A registry written by an older plugin can still hold one row whose Active cell is the whole token `**ACTIVE**`, and a header line "Exactly one is ACTIVE". The row still loads. It sets no initiative for any session. Each session picks its own. On the next registry write, remove that token and correct the header so it says the registry lists initiatives and each session picks its own. Do not add a new `**ACTIVE**` marker.

Prose such as `**ACTIVE: <slug>**`, or a status cell `ACTIVE — …`, marks nothing.

## SessionStart conform hook

`hooks/conform-registry.py` runs on SessionStart. It rewrites `<shared root>/.workspace/initiatives.md` when the registry has drifted off the shape that held one `**ACTIVE**` row. The shared root is the main checkout, including when the session is in a linked worktree. This is a scoped exception to "read and report, do not silently rewrite." The hook touches that one path and nothing else. If the structure is unrecognised, or several `**ACTIVE**` markers cannot be reconciled by format normalisation, it leaves the file unchanged. A registry with zero `**ACTIVE**` cells is not rewritten and gets no notice. The hook does not commit or stage. The registry stays git-tracked, so a conform it does make is an ordinary diff. A registry with zero `**ACTIVE**` cells is the current shape. Do not fight a conform diff. Do not re-add the marker.
