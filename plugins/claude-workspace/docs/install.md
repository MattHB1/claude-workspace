# Install, auth, updates, and permissions

This is the full operational guide for getting `claude-workspace` running and keeping
it current. It covers the private marketplace add, the git credentials each path needs,
manual versus background updates, what "shared, not secret" means for distribution, and
the tool permissions the executor agents require.

For a one-paragraph overview and the quickstart, see the bundled index ([README.md](../README.md)).

---

## Install (private add)

The marketplace lives in a **private git repository**, so you install it with your own
git credentials. The repository handle in the commands below is the public GitHub handle
`vitalsignssolutionsltd/claude-workspace`; use the actual private repo you were invited to if it differs
(or use a full git URL such as `https://github.com/vitalsignssolutionsltd/claude-workspace.git`).

In a Claude Code session:

```
/plugin marketplace add vitalsignssolutionsltd/claude-workspace
/plugin install claude-workspace@pocdoc-workspace
/reload-plugins
```

- The first command registers the private marketplace. A git-based marketplace clones
  the whole repo, so the relative-path plugin source resolves automatically.
- The second installs the plugin (`claude-workspace`) from the marketplace
  (`pocdoc-workspace`). Note the names differ on purpose: `pocdoc-workspace` is the
  marketplace, `claude-workspace` is the plugin it ships.
- `/reload-plugins` makes the skill and agents available in the current session.

CLI equivalents exist if you prefer them outside a session:

```
claude plugin marketplace add vitalsignssolutionsltd/claude-workspace
claude plugin install claude-workspace@pocdoc-workspace
```

You can also point the marketplace add at a **full git URL** instead of the
`owner/repo` short form:

```
/plugin marketplace add https://github.com/vitalsignssolutionsltd/claude-workspace.git
```

---

## Auth and credentials

**Manual add / install / update use your own git credentials.** The manual flow goes
through your existing git credential helpers - for example `gh auth login`, the macOS
Keychain, or an SSH key already loaded in your agent. **No extra token is needed for the
manual path.** If you cannot reach the repo at all, you do not have access (see
"Shared, not secret" below).

**Private background auto-update needs a `GITHUB_TOKEN`.** The startup auto-update runs
**without** your interactive credential helpers, so pulling from a private remote needs a
credential present in the environment. See "Updates" below for the detail.

---

## Updates

**Manual update (no token needed).** To pull the latest version from the private remote:

```
/plugin marketplace update pocdoc-workspace
/reload-plugins
```

The manual update path uses your existing git credential helper - the same credentials
that let you add the marketplace - so it needs **no** extra environment token.

**Background auto-update (needs a token).** Auto-update is off by default for third-party
marketplaces. If you turn it on, the startup auto-update runs **without** your interactive
credential helpers, so pulling from a **private** remote requires a credential in the
environment. For a GitHub-hosted private remote, export a `GITHUB_TOKEN` (repo scope) in
your shell profile, e.g.:

```
export GITHUB_TOKEN=ghp_xxxxxxxxxxxx
```

Without `GITHUB_TOKEN` (or the equivalent for your host), a private-remote auto-update
fails silently - stick to the manual `/plugin marketplace update` path instead.

---

## Shared, not secret

Distribution is private: who can install or update is governed **entirely by the
permissions on the git repository** (collaborators / team membership). Both install and
update clone or pull from the remote, so without repo access they simply fail.

Revoking someone's repo access stops their **future** installs and updates. It does
**not** delete a copy they have already installed: on install the plugin is copied into a
local per-version cache, and that copy keeps working. Treat the shipped markdown as
**shared, not secret** once it has been delivered - revocation controls updates, not
already-distributed copies.

A recipient who wants to remove it can uninstall and detach the marketplace:

```
/plugin uninstall claude-workspace@pocdoc-workspace
/plugin marketplace remove pocdoc-workspace
```

---

## Permissions

Three of the agents are **executors** that actually change files:
`claude-workspace:implementer`, `claude-workspace:archivist`, and
`claude-workspace:implementation-verifier` (the verifier writes only its reports). They
need the `Write`, `Edit`, and `Bash` tools.

**Background agents cannot answer interactive permission prompts.** When the orchestrator
dispatches an executor as a background subagent, a tool-permission prompt has nobody to
approve it and the dispatch stalls or fails. So a fresh user must grant these tools up
front; they are **not** pre-provisioned for you.

You have two options:

1. **Pre-authorize (recommended for background dispatch).** Add a project-level (or
   user-level) `settings.local.json` with an `allow` list that grants `Write`, `Edit`,
   and `Bash`. For example, in `.claude/settings.local.json`:

   ```json
   {
     "permissions": {
       "allow": ["Write", "Edit", "Bash"]
     }
   }
   ```

   Scope `Bash` more narrowly if you prefer (for example to specific command prefixes);
   the executors will prompt for anything not pre-allowed, which is exactly what you want
   to avoid for background runs.

2. **Interactive-prompt reliance (foreground only).** If you run the agents in the
   foreground and are present to approve each prompt, you can skip `settings.local.json`
   and grant `Write`/`Edit`/`Bash` as the prompts appear. This does **not** work for
   background dispatch.

> **Plugin-bundled settings cannot grant these tools** - `Write`/`Edit`/`Bash` must be
> granted in your own `settings.local.json`, not shipped with the plugin.

If you hit a permission error in practice, see [troubleshooting.md](troubleshooting.md).

---

## Logging hooks: Python requirement and .gitignore

The plugin ships three logging hooks that capture session events, session start
timing, and per-session cost into your project. Using them requires:

**Python 3.x on PATH.** The hooks are invoked as
`python3 "${CLAUDE_PLUGIN_ROOT}/hooks/<script>.py"`. If `python3` is not on your
`PATH`, the hooks fail non-blocking -- Claude logs the non-zero exit but does not
interrupt your session, and no events or cost data are written. Logging simply does
not occur. To verify: `python3 --version`.

**Recommended `.gitignore` entries.** The logging hooks write two files into your
project that you will normally want to keep out of version control:

- `.workspace/<slug>/memory/events.jsonl` -- the per-initiative structured event
  log (one JSONL line per captured hook event).
- `agentic/cost-log.md` -- the per-session cost log written at session end.

Because a plugin cannot edit your `.gitignore`, add these lines yourself:

```
.workspace/*/memory/events.jsonl
agentic/cost-log.md
```

Note: `journal.md` and `index.md` (the prose journal and its index) are
intentionally **not** excluded -- they are the human-readable record of decisions
and stay tracked in version control.

---

## Per-agent models / cost

Each agent ships with a deliberately chosen model tier set via its frontmatter `model:`
field, using the bare aliases `opus` / `sonnet` / `haiku` (not pinned model IDs). The
intent is cost-aware: cheap, fast tiers for mechanical roles and the strongest reasoning
tier for the planning and adversarial-verification roles.

| Agent | Model | Rationale |
|---|---|---|
| `proposal-writer` | `opus` | High-reasoning authoring of the root-of-truth spec. |
| `task-planner` | `opus` | High-reasoning decomposition; correctness-critical. |
| `task-checker` | `opus` | Adversarial spec enforcement; reasoning-critical. |
| `implementation-verifier` | `opus` | Adversarial review; reasoning-critical. |
| `implementer` | `sonnet` | Mechanical execution of a fully-specified task; fast/cheaper. |
| `research-harvester` | `sonnet` | Read + web gathering; fast/cheaper. |
| `context-recovery` | `sonnet` | State reconstruction; fast/cheaper. |
| `archivist` | `haiku` | Pure file moves; cheapest/fastest. |

Totals: 4 `opus` / 3 `sonnet` / 1 `haiku`. The cost rationale in one line: cheap/fast on
the mechanical roles, stronger on planning plus adversarial verification.

### Overriding a per-agent model

To change the model for an agent, drop a **same-named** agent file (carrying your own
`model:` value) into either your project's `.claude/agents/` or your user
`~/.claude/agents/` directory. That copy **wins** over the plugin's copy.

The override is **whole-file, not field-level**: your file replaces the plugin agent
entirely, so it must contain the complete agent definition (name, description, tools, and
body), not just the `model:` line you want to change. Copy the plugin agent as a starting
point and adjust the `model:` line.

### Graceful degradation (no Opus access)

The aliases degrade gracefully. An installer **without Opus access** does not see a hard
failure on the `opus`-aliased agents - the alias **falls back to the inherited/default
model** for that session/account instead of erroring. Because the agents use aliases
rather than pinned IDs, the selection also survives model refreshes.

Advanced levers (documented here as options; not the mechanism this plugin relies on):

- `CLAUDE_CODE_SUBAGENT_MODEL` - set one model for **all** subagents at once.
- `ANTHROPIC_DEFAULT_OPUS_MODEL`, `ANTHROPIC_DEFAULT_SONNET_MODEL`,
  `ANTHROPIC_DEFAULT_HAIKU_MODEL` (i.e. `ANTHROPIC_DEFAULT_{OPUS,SONNET,HAIKU}_MODEL`) -
  repoint a given alias at a specific model for your account/host.
