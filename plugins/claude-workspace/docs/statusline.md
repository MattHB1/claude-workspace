# Statusline (automatic, session-aware)

The `claude-workspace` plugin ships a statusline. It shows the initiative of this session in your Claude Code title bar.
It is **automatic and session-aware**. After install, it is your only `statusLine`.
It shows the workspace segment **only** while a workspace-orchestrator session is live.
At other times it prints your prior or default statusline exactly. You do nothing.

---

## What it shows, and when

Inside a **workspace-orchestrator session** (the `workspace` skill ran in this session), the statusline prints one line. The line holds:

- your **shortened working directory** (the home prefix becomes `~`),
- the **initiative of the session** as a `⚡<slug>` segment (read from the `slug=` line of the marker of this session), and
- the **model name** of the session.

Example output (ANSI-coloured; colours omitted here for readability):

```
~/code/myproject ⚡my-feature  Claude Sonnet 4.5
```

**When it appears:** a `PostToolUse` event fires for the `Skill` tool with the skill `workspace`. Then the plugin writes a marker file for that session. The `/workspace` command writes the same marker in its first step. The segment shows when the session picks an initiative and the marker holds a `slug=` line. Every later render for that session shows the `⚡<slug>` segment. There is no caching and there are no extra steps. The statusline reads no registry row.

**When it disappears:** in a session where the `workspace` skill never ran ("vanilla" Claude), there is no marker. The statusline does not show the segment. It **runs your prior or default statusline command again and passes the output through unchanged**. Your line looks as it did before you installed this plugin. This holds **even inside a repository that has a `.workspace/initiatives.md`**. That file on disk never triggers the segment. Only the marker of the session triggers it.

---

## The takeover + delegate contract

Claude Code has exactly one `statusLine` slot. The plugin cannot add a segment next to your old statusline. The installer uses a **takeover + delegate** design instead:

1. **Capture.** Your `~/.claude/settings.json` can already have a `statusLine` command that the installer did not write. The installer copies that command unchanged into a sidecar file before it changes anything else. It discards nothing.
2. **Takeover.** The workspace statusline script becomes the **only** `statusLine` command in `settings.json`.
3. **Delegate when inactive.** On every render, the script looks for the session marker. If the marker is present, the script renders the line described above. The `⚡<slug>` segment shows only when the marker has a `slug=` line. If the marker is **absent**, the script runs the captured prior command with the same stdin. It writes the output of that command **unchanged**, byte for byte.

Outside a workspace session, your statusline looks the same as before the install. Inside a session, it gains the `⚡<slug>` segment automatically. You do not toggle anything. You do not run a "restore my statusline" step.

**`--segment` mode does not restore your statusline.** The script also has a `--segment` flag. It prints only the `⚡<slug>` part (or nothing), with no working directory and no model. It exists for developers. Use it to add the segment to your own statusline script. It plays no part in how the automatic install restores your prior line.

---

## Install

**Node is required.** The installer checks for `node` before it changes anything. See "Requirements" below.

**The plugin install location** is the Claude Code plugin cache (the marketplace directory). The plugin manager prints the exact path when you install the plugin. The examples below call it `<plugin-dir>`.

To find `<plugin-dir>`, read the path that the plugin manager printed on install, or run:

```
/plugin show claude-workspace
```

**Run the installer once, on purpose:**

```
node <plugin-dir>/scripts/install-statusline.js
```

The installer does these steps:

1. It checks that `node` is on PATH. If `node` is absent, it wires nothing and prints guidance. See "Requirements".
2. If a foreign `statusLine` command exists in `~/.claude/settings.json`, it **copies it unchanged** into a sidecar file. Outside a workspace session, the script runs that command automatically (see "The takeover + delegate contract"). The uninstall step writes it back (see "Uninstall / revert").
3. It copies the statusline script to a **stable path**, `~/.claude/claude-workspace-statusline.js`. Your `settings.json` points at this copy. It does not point at the versioned plugin cache path, so plugin updates do not break your statusline.
4. It wires that stable-path script as the **only** `statusLine` entry in `~/.claude/settings.json`. The write is backed up and atomic. All other keys in `settings.json` stay byte for byte the same.
5. It is idempotent. If you run it again when the workspace statusline is already installed, the result is the same. It adds no duplicate and it does not capture an already-captured prior command again.

Restart Claude Code after install to activate the statusline.

---

## Uninstall / revert

Run the installer with `--uninstall`:

```
node <plugin-dir>/scripts/install-statusline.js --uninstall
```

This restores your `statusLine` to its **exact pre-install state**:

- If the installer captured a prior `statusLine` command, it writes that command back **byte for byte**.
- If no `statusLine` existed before install, the installer removes the `statusLine` key. It does not leave the key pointing at the workspace script.
- It leaves all other keys in `settings.json` intact. The write is backed up and atomic, as in install.

After you uninstall, restart Claude Code.

---

## Session-id lifecycle and the marker

The marker is a plain text file at `~/.claude/.workspace-active/<session_id>`. It holds `key=value` lines: `root=<shared root>`, `checkout=<checkout path>` and `slug=<slug>`. Each key occurs at most once.
The statusline reads only the marker for its own stdin `session_id`. It shows the `⚡<slug>` segment only when that marker has a `slug=` line.
This replaces the earlier rule that the marker only needs to exist, where an empty marker file was enough. The marker is also the only place that stores the initiative of a session.
The `root=` line of the marker is the one shared root for all sessions in a repo, including sessions in worktrees.
This lifecycle decides how the segment behaves in each session event:

- **`/clear`** starts a new `session_id`. No marker exists for the new id. The segment is **absent** when the new session begins. You do not clean up anything.
  A stale marker for the *old* session_id can stay on disk. It is harmless, because the new session_id never reads it. The `SessionStart(source=clear|startup)` orphan cleanup sweeps it up when it is more than 24 hours old.
- **`/compact`** keeps the **same** `session_id`. Compaction does not touch the marker for that id. The segment **stays** across compaction as before.
- **Ending the session** fires a `SessionEnd` event. The `SessionEnd` hook may delete the marker of that session at once. If it does not, the 24-hour sweep below removes the old marker. A crash or a killed terminal can skip the `SessionEnd` event.
- **Exiting the workspace in conversation** fires **no Claude Code event**. Claude Code has no hook for a spoken or typed exit word. The system does **not** claim to detect this exit. Two approximations exist. Neither one is mechanical and real-time.
  1. The exit procedure in the `workspace` SKILL.md has a fixed step that deletes the marker. The orchestrator runs this step, and it depends on the orchestrator following the procedure. It is not a hook guarantee.
  2. `SessionStart(source=clear|startup)` does a **best-effort cleanup with a 24-hour minimum** of orphaned markers. It never removes a marker that is less than 24 hours old. It never fires on resume or compact.

**Summary:** marker *entry* is mechanical. It happens on a `PostToolUse` `Skill` event where the skill is `workspace`, or in the first step of the `/workspace` command.
At session end, the `SessionEnd` hook may delete the marker at once. If it does not, the 24-hour sweep removes it later.
After a conversational exit, the marker goes only through the SKILL.md exit step, which depends on the orchestrator, or through the delayed best-effort 24-hour sweep.

---

## Requirements

- **Node on PATH.** The statusline command is `node "..."`. It needs `node` to resolve in the shell that Claude Code uses for statusline commands. The installer checks this before it wires anything. If `node` is absent or does not resolve, the installer exits. It does not change `settings.json` and it copies no file. It prints guidance: how to install node, and the manual `--segment` snippet for anyone who builds their own statusline.

Node is bundled with Claude Code in typical installs, so it is usually on PATH already. If the check fails, make sure the `node` binary is available in your shell profile.

---

## Notes

- **Trusted workspace only.** Claude Code runs statusline commands only in trusted workspaces. In an untrusted context, Claude Code skips the statusline and shows a notice ("statusline skipped -- restart to fix"). Mark the workspace as trusted to activate it.
- **Debounced (~300ms).** Claude Code debounces the statusline command. It runs it at most about once every 300ms. The debounce keeps the script light, so it adds no lag you can notice.
- **Plugin install is inert.** Installing or updating the `claude-workspace` plugin never touches your statusline or `settings.json`. Only the installer that you run yourself makes a change, and only when you run it.
