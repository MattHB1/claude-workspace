# Statusline helper (opt-in)

The `claude-workspace` plugin ships an optional statusline that surfaces the
active initiative in your Claude Code title bar. It is **never auto-enabled** --
you run an installer deliberately when you want it.

---

## What it shows

Inside a workspace project, the statusline prints a single line containing:

- your **shortened working directory** (home prefix replaced with `~`),
- the **active initiative** as a `⚡<slug>` segment (read from
  `.workspace/initiatives.md`, the first backtick-delimited cell of the
  `**ACTIVE**` row), and
- the session's **model name**.

Example output (ANSI-coloured; colours omitted here for readability):

```
~/code/myproject ⚡my-feature  Claude Sonnet 4.5
```

Outside a workspace project (no `.workspace/initiatives.md` found when walking
up from the current directory), the statusline is **silent on the initiative
segment** -- it does not emit a `⚡` chunk. In default mode it still
prints the cwd and model; in `--segment` mode it prints nothing at all.

---

## Opt-in install

**Node is required.** The installer preflights `node` before touching anything;
see "Requirements" below.

**The plugin install location** is the Claude Code plugin cache (the marketplace
directory). Its exact path is printed by the plugin manager when you install the
plugin. In the examples below it is referred to as `<plugin-dir>`.

To find `<plugin-dir>`, check the path the plugin manager printed on install, or
run:

```
/plugin show claude-workspace
```

The path ends with something like `.../marketplaces/pocdoc-workspace/plugins/claude-workspace`.

**Run the installer once, deliberately:**

```
node <plugin-dir>/scripts/install-statusline.js
```

The installer:

1. Preflights `node` on PATH. If node is absent it wires nothing and prints
   guidance; see "Requirements".
2. Copies the statusline script to a **stable path** at
   `~/.claude/claude-workspace-statusline.js`. This copy is what your
   `settings.json` will point at -- not the versioned plugin cache path, so
   plugin updates do not break your statusline.
3. Adds a `statusLine` entry to `~/.claude/settings.json`:
   `{ "type": "command", "command": "node \"~/.claude/claude-workspace-statusline.js\"" }`.
   The write is additive (only the `statusLine` key is touched), backed up, and
   atomic. All other keys in `settings.json` are preserved byte-for-byte.
4. Is idempotent -- re-running when a `claude-workspace` statusline is already
   wired produces the same result with no duplication.

Restart Claude Code after install to activate the statusline.

---

## If you already have a statusline

If `~/.claude/settings.json` already contains a `statusLine` key, the installer
**will not overwrite it**. Instead it prints a compose snippet you can fold into
your own statusline manually:

```
node "~/.claude/claude-workspace-statusline.js" --segment
```

Pipe your session JSON to this command and append its output to your own
statusline line. In `--segment` mode the script prints **only** the
`⚡<slug>` chunk (no cwd, no model) -- or nothing if the cwd is not
inside a workspace project.

Example (schematic -- adapt to your own statusline script):

```javascript
// Inside your own statusline script that already reads stdin:
const segmentOutput = require('child_process')
  .execFileSync('node', [homeDir + '/.claude/claude-workspace-statusline.js', '--segment'],
    { input: rawStdin, encoding: 'utf8' });
line += ' ' + segmentOutput.trim();
```

The installer also prints a pointer to this docs page when it detects an
existing statusline.

---

## Customize

The installed copy at `~/.claude/claude-workspace-statusline.js` is yours to
edit. To change the **glyph** (`⚡`) or the **ANSI colours**, open that
file and adjust the relevant constants near the top:

```javascript
// ANSI helpers.
const CYAN    = '\x1b[36m';
const MAGENTA = '\x1b[35m';
const DIM     = '\x1b[2m';
const RESET   = '\x1b[0m';
```

The `⚡` glyph appears in the `segmentMode` block and in the default-mode
block -- search for the `⚡` character in the file to find both places.

Plugin updates do not overwrite your installed copy (the stable path
`~/.claude/claude-workspace-statusline.js` is written only by the installer, not
by the plugin load). Re-run the installer only if you want to pull in a new
version of the script from an updated plugin.

---

## Remove

To revert:

1. Open `~/.claude/settings.json` and delete the `statusLine` key (or restore
   the `.bak` backup the installer saved alongside it before writing).
2. Delete the stable script copy: `~/.claude/claude-workspace-statusline.js`.
3. Restart Claude Code.

That is the complete uninstall -- no other files are left behind.

---

## Requirements

- **Node on PATH.** The statusline command is `node "..."` and relies on `node`
  being resolvable in the shell environment Claude Code uses for statusline
  commands. The installer preflights this before wiring anything: if `node` is
  absent or unresolvable, it exits without modifying `settings.json` or copying
  any file, and prints actionable guidance (how to install node, and the manual
  `--segment` snippet as a fallback).

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
  plugin never touches your statusline or `settings.json`. Only the explicitly-
  run installer makes any change.
