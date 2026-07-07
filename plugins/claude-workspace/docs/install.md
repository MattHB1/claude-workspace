# Install, auth, updates, and permissions

This guide explains how to install `claude-workspace` and keep it current. It covers
the private marketplace add and the git credentials that each path needs. It also covers
manual and background updates, what "shared, not secret" means for distribution, and the
tool permissions that the executor agents need.

For a one-paragraph overview and the quickstart, see the bundled index ([README.md](../README.md)).

---

## Install (private add)

The marketplace lives in a **private git repository**, so you install it with your own
git credentials. The repository handle in the commands below is the public GitHub handle
`MattHB1/claude-workspace`. If your invited private repo differs, use
that repo. You can also use a full git URL such as
`https://github.com/MattHB1/claude-workspace.git`.

In a Claude Code session:

```
/plugin marketplace add MattHB1/claude-workspace
/plugin install claude-workspace@mhb-workspace
/reload-plugins
```

- The first command registers the private marketplace. A git-based marketplace clones
  the whole repo, so the relative-path plugin source resolves automatically.
- The second command installs the plugin (`claude-workspace`) from the marketplace
  (`mhb-workspace`). The names differ on purpose. `mhb-workspace` is the
  marketplace. `claude-workspace` is the plugin that it ships.
- `/reload-plugins` makes the skill and agents available in the current session.

CLI equivalents exist if you prefer them outside a session:

```
claude plugin marketplace add MattHB1/claude-workspace
claude plugin install claude-workspace@mhb-workspace
```

You can also point the marketplace add at a **full git URL** instead of the
`owner/repo` short form:

```
/plugin marketplace add https://github.com/MattHB1/claude-workspace.git
```

---

## Auth and credentials

**Manual add, install and update use your own git credentials.** The manual flow uses
your existing git credential helpers. Examples are `gh auth login`, the macOS Keychain,
or an SSH key that is already loaded in your agent. **The manual path needs no extra
token.** If you cannot reach the repo, you do not have access (see "Shared, not secret"
below).

**Private background auto-update needs a `GITHUB_TOKEN`.** The startup auto-update runs
**without** your interactive credential helpers. A pull from a private remote therefore
needs a credential in the environment. See "Updates" below for the detail.

---

## Updates

**Manual update (no token needed).** To pull the latest version from the private remote:

```
/plugin marketplace update mhb-workspace
/reload-plugins
```

The manual update path uses your existing git credential helper. These are the same
credentials that let you add the marketplace. It needs **no** extra environment token.

**Background auto-update (needs a token).** Auto-update is off by default for third-party
marketplaces. If you turn it on, the startup auto-update runs **without** your interactive
credential helpers. A pull from a **private** remote then needs a credential in the
environment. For a private remote on GitHub, export a `GITHUB_TOKEN` (repo scope) in
your shell profile. For example:

```
export GITHUB_TOKEN=ghp_xxxxxxxxxxxx
```

Without `GITHUB_TOKEN` (or the equivalent for your host), a private-remote auto-update
fails silently. Use the manual `/plugin marketplace update mhb-workspace` command
instead.

---

## Shared, not secret

Distribution is private. The permissions on the git repository **alone** decide who can
install or update (collaborators and team membership). Install and update both clone or
pull from the remote. Without repo access, they fail.

Revoking a person's repo access stops their **future** installs and updates. It does
**not** delete a copy that they already installed. On install, the plugin is copied into
a local per-version cache, and that copy keeps working. Treat the shipped markdown as
**shared, not secret** after delivery. Revocation controls updates. It does not control
copies that are already distributed.

A recipient who wants to remove the plugin can uninstall it and detach the marketplace:

```
/plugin uninstall claude-workspace@mhb-workspace
/plugin marketplace remove mhb-workspace
```

---

## Permissions

Some agents are **executors** that change files. Agents that change files need the
`Write` and `Edit` tools. Agents that run commands need the `Bash` tool. Other agents
have no `Write` or `Edit` tool. The `tools:` line in each agent
file is the master list: `plugins/claude-workspace/agents/*.md:4`. You must grant
`Write`, `Edit` and `Bash` yourself. The plugin does not pre-provide them.

**Background agents cannot answer interactive permission prompts.** The orchestrator can
dispatch an executor as a background subagent. A tool-permission prompt then has nobody
to approve it, and the dispatch stalls or fails. So grant these tools before you start.

You have two options:

1. **Pre-authorize (recommended for background dispatch).** Add a project-level (or
   user-level) `settings.local.json` with an `allow` list that grants `Write`, `Edit`
   and `Bash`. For example, in `.claude/settings.local.json`:

   ```json
   {
     "permissions": {
       "allow": ["Write", "Edit", "Bash"]
     }
   }
   ```

   You can scope `Bash` more narrowly, for example to specific command prefixes. The
   executors prompt for anything that you did not pre-allow. Background runs must
   avoid that prompt.

2. **Interactive prompts (foreground only).** Run the agents in the foreground and
   approve each prompt yourself. You can then skip `settings.local.json` and grant
   `Write`, `Edit` and `Bash` as the prompts appear. This does **not** work for
   background dispatch.

> **Plugin-bundled settings cannot grant these tools.** You must grant `Write`, `Edit`
> and `Bash` in your own `settings.local.json`. The plugin cannot ship them.

If you hit a permission error in practice, see [troubleshooting.md](troubleshooting.md).

---

## Logging hooks: Python requirement and .gitignore

The plugin ships five hook scripts. The file `plugins/claude-workspace/hooks/hooks.json`
is the master list. Each script runs as `python3 "${CLAUDE_PLUGIN_ROOT}/hooks/<script>.py"`.

- `autolog.py` adds one line for each captured event to the `events.jsonl` file of the
  initiative that your session picked.
- `statusline-marker.py` writes the session marker file that the statusline reads. It
  also deletes the marker when the session ends.
- `record-session-start.py` records the session ID and the start time for cost tracking.
- `log-session-cost.py` writes the session cost to `agentic/cost-log.md` when the
  session stops. It needs `ANTHROPIC_ADMIN_KEY` in your environment. Without the key,
  it exits and writes nothing.
- `conform-registry.py` runs at session start. When `initiatives.md` holds one old `**ACTIVE**`
  marker, it adds backticks to the slug cell of every table row. It changes nothing
  else.

Using the hooks requires:

**Python 3.x on PATH.** If `python3` is not on your `PATH`, the hooks fail non-blocking.
Claude logs the non-zero exit but does not interrupt your session. The hooks then
write no events and no cost data. To verify, run `python3 --version`.

**Recommended `.gitignore` entries.** The logging hooks write two files into your
project. You will normally want to keep them out of version control:

- `.workspace/<slug>/memory/events.jsonl` -- the structured event log of one
  initiative (one JSONL line for each captured hook event).
- `agentic/cost-log.md` -- the cost log for each session, written at session end.

A plugin cannot edit your `.gitignore`. Add these lines yourself:

```
.workspace/*/memory/events.jsonl
agentic/cost-log.md
```

Note: `journal.md` and `index.md` (the prose journal and its index) are
**not** excluded on purpose. They are the human-readable record of decisions. Keep
them in version control.

---

## Per-agent models / cost

Each agent has its own model, set in the `model:` line of its agent file. The
`effort:` line sits next to it. The master for both lines is
`plugins/claude-workspace/agents/*.md:5-6`. This guide keeps no copy of the values.

The intent is cost control. Mechanical roles use cheap, fast models. Planning and
adversarial-verification roles use the strongest reasoning model.

Each agent also has an `effort:` field in its frontmatter. The permitted values are
(`low` / `medium` / `high`). This field is a second, separate way to control cost and
drift. It tunes how much reasoning effort the agent applies. It does not change which
model the agent runs on.

### Overriding a per-agent model

To change the model for an agent, put a **same-named** agent file with your own `model:`
value in one of two places. These are your project's `.claude/agents/` directory and your
user `~/.claude/agents/` directory. Your copy **wins** over the plugin's copy.

The override replaces the **whole file**, not one field. Your file must hold the complete
agent definition (name, description, tools and body). Copy the plugin agent as a starting
point. Then change the `model:` line.

### Graceful degradation (no model access)

A `model:` line can hold a full model ID or an alias. A full model ID does **not** fall
back to another model if you lack access. The call fails instead of a silent downgrade.
An alias falls back to the inherited or default model for that session or account, and
does not fail with an error.

Advanced options (this plugin does not rely on them):

- `CLAUDE_CODE_SUBAGENT_MODEL` - set one model for **all** subagents at once.
- `ANTHROPIC_DEFAULT_OPUS_MODEL`, `ANTHROPIC_DEFAULT_SONNET_MODEL`,
  `ANTHROPIC_DEFAULT_HAIKU_MODEL` (i.e. `ANTHROPIC_DEFAULT_{OPUS,SONNET,HAIKU}_MODEL`) -
  repoint a given alias at a specific model for your account or host.
