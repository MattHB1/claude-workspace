# Statusline (automatic, session-aware)

The `claude-workspace` plugin ships a statusline that surfaces the active
initiative in your Claude Code title bar. It is **automatic and session-aware**:
once installed it becomes your sole `statusLine`, and it renders the workspace
segment **only** while a workspace-orchestrator session is live — otherwise it
gets out of the way and reproduces your prior/default statusline exactly, with
no action from you.

---

## What it shows, and when

Inside a **workspace-orchestrator session** (the `workspace` skill has been
invoked this session), the statusline prints a single line containing:

- your **shortened working directory** (home prefix replaced with `~`),
- the **active initiative** as a `⚡<slug>` segment (read from
  `.workspace/initiatives.md`, the first backtick-delimited cell of the
  `**ACTIVE**` table row), and
- the session's **model name**.

Example output (ANSI-coloured; colours omitted here for readability):

```
~/code/myproject ⚡my-feature  Claude Sonnet 4.5
```

**When it appears:** the moment a `PostToolUse` event fires for the `Skill`
tool with the invoked skill `workspace`, a marker file is written for that
session. From then on, every statusline render for that session shows the
`⚡<slug>` segment — updating automatically if the `**ACTIVE**` row changes
(no caching, no extra steps).

**When it disappears:** in any session where the `workspace` skill has never
been invoked — "vanilla" Claude — there is no marker, and the statusline does
not show the segment at all. Instead it **re-invokes your prior/default
statusline command and passes its output through verbatim**, so your line
looks exactly as it did before this plugin was installed. This holds **even
inside a repository that contains a `.workspace/initiatives.md`** — presence
of that file on disk is never sufficient to trigger the segment; only the
session-scoped marker is.

---

## The takeover + delegate contract

Because Claude Code exposes exactly one `statusLine` slot, this plugin cannot
simply "add" a segment alongside whatever you already had wired. Instead the
installer uses a **takeover + delegate** design:

1. **Capture.** If `~/.claude/settings.json` already has a `statusLine`
   command the installer did not itself author, that command is captured
   verbatim into a sidecar file before anything else changes. Nothing you
   already had is discarded.
2. **Takeover.** The workspace statusline script becomes the **sole**
   `statusLine` command in `settings.json`.
3. **Delegate when inactive.** On every render, the script checks for the
   session marker. If the marker is present, it renders the `⚡<slug>` line
   described above. If the marker is **absent**, it re-invokes the captured
   prior command with the same stdin and writes that command's output
   **verbatim** — byte-for-byte the line you had before.

The net effect: outside a workspace session your statusline is
indistinguishable from what you had pre-install; inside one, it gains the
`⚡<slug>` segment automatically. No manual toggling, no "restore my
statusline" step.

**`--segment` mode is not the restore mechanism.** The script also supports a
`--segment` flag that prints only the `⚡<slug>` chunk (or nothing) with no
cwd and no model. This exists purely as a developer/compose affordance for
anyone who wants to fold the segment into a hand-rolled statusline script of
their own — it plays no role in how the automatic install restores your prior
line.

---

## Install

**Node is required.** The installer preflights `node` before touching
anything; see "Requirements" below.

**The plugin install location** is the Claude Code plugin cache (the
marketplace directory). Its exact path is printed by the plugin manager when
you install the plugin. In the examples below it is referred to as
`<plugin-dir>`.

To find `<plugin-dir>`, check the path the plugin manager printed on install,
or run:

```
/plugin show claude-workspace
```

**Run the installer once, deliberately:**

```
node <plugin-dir>/scripts/install-statusline.js
```

The installer:

1. Preflights `node` on PATH. If node is absent it wires nothing and prints
   guidance; see "Requirements".
2. If a foreign `statusLine` command already exists in
   `~/.claude/settings.json`, **captures it verbatim** into a sidecar file so
   it can be restored automatically (see "The takeover + delegate contract").
3. Copies the statusline script to a **stable path** at
   `~/.claude/claude-workspace-statusline.js`. This copy is what your
   `settings.json` will point at -- not the versioned plugin cache path, so
   plugin updates do not break your statusline.
4. Wires that stable-path script as the **sole** `statusLine` entry in
   `~/.claude/settings.json`. The write is backed up and atomic; all other
   keys in `settings.json` are preserved byte-for-byte.
5. Is idempotent -- re-running when the workspace statusline is already
   installed produces the same result, with no duplication and no re-capture
   of an already-captured prior command.

Restart Claude Code after install to activate the statusline.

---

## Uninstall / revert

Run the installer with `--uninstall`:

```
node <plugin-dir>/scripts/install-statusline.js --uninstall
```

This restores your `statusLine` to its **exact pre-install state**:

- If a prior `statusLine` command was captured at install time, it is written
  back **byte-for-byte**.
- If no `statusLine` existed before install, the `statusLine` key is removed
  entirely rather than left pointing at the workspace script.
- All other keys in `settings.json` are left intact. The write is backed up
  and atomic, same as install.

After uninstalling, restart Claude Code.

---

## Session-id lifecycle and the marker

The workspace segment's presence is governed entirely by whether a marker file exists at
`~/.claude/.workspace-active/<session_id>` for the statusline's own stdin `session_id` — nothing else.
That single fact determines the segment's behaviour across every session-lifecycle event:

- **`/clear`** starts a brand-new `session_id`. No marker has ever been written for that new id, so the
  segment is **absent** the moment the new session begins — automatically, with no cleanup step required.
  (A stale marker for the *old* session_id may still exist on disk; it is harmless because it can never be
  read under the new session_id. It is eventually swept up by the `SessionStart(source=clear|startup)`
  orphan cleanup once it is >24h old.)
- **`/compact`** keeps the **same** `session_id`. The marker for that id is untouched by compaction, so the
  segment **persists** across compaction exactly as before.
- **Exiting the workspace conversationally** fires **no Claude Code event of any kind** — there is no hook
  surface for a spoken/typed exit verb. The system does **not** claim to detect this. Two approximations
  exist, both explicitly non-mechanical or non-realtime: (1) the `workspace` SKILL.md exit procedure has an
  explicit, deterministic marker-delete step that is **orchestrator-executed and compliance-dependent**, not
  a hook guarantee; (2) `SessionStart(source=clear|startup)` performs a **best-effort, 24-hour-floor** cleanup
  of orphaned markers (never removes anything <24h; never fires on resume/compact).

**Honest summary:** marker *entry* is mechanical (a `PostToolUse` `Skill` event where the skill is
`workspace`); marker *exit* is not — it is approximated by session-id churn (`/clear`), a compliance-dependent
SKILL.md step, and a delayed best-effort startup/clear sweep.

---

## Requirements

- **Node on PATH.** The statusline command is `node "..."` and relies on `node`
  being resolvable in the shell environment Claude Code uses for statusline
  commands. The installer preflights this before wiring anything: if `node` is
  absent or unresolvable, it exits without modifying `settings.json` or copying
  any file, and prints actionable guidance (how to install node, and the manual
  `--segment` snippet as a fallback for anyone composing their own statusline).

Node is bundled with Claude Code in typical installs, so it is usually already
on PATH. If the preflight fails, check that the `node` binary is accessible in
your shell profile.

---

## Notes

- **Trusted workspace only.** Claude Code runs statusline commands only in
  trusted workspaces. In an untrusted context the statusline is skipped and
  Claude Code shows a notice ("statusline skipped -- restart to fix"). Mark the
  workspace as trusted to activate it.
- **Debounced (~300ms).** The statusline command is debounced by Claude Code at
  approximately 300ms between invocations, so the script stays lightweight and
  does not create noticeable lag.
- **Plugin install is inert.** Installing or updating the `claude-workspace`
  plugin never touches your statusline or `settings.json`. Only the
  explicitly-run installer makes any change, and only when you run it.
