# Troubleshooting

This guide starts from the symptom. Find the symptom that matches what you saw, read the cause, and apply the fix. Most "errors" here are the system working as designed (permission gates, refusals, artefact precedence). They are not bugs.

For more background, see the operational guide in [install.md](./install.md), the refusal contract in [why-it-refuses.md](./why-it-refuses.md), and the design contract in [design-principles.md](./design-principles.md).

---

## 1. Permission errors when an agent tries to change files

**Symptom.** You ask the orchestrator to build, archive, or verify. The run stops with a permission prompt, stalls, or fails before any file is written. You may see a tool-permission request you cannot answer. A dispatched agent may never finish.

**Cause.** Some agents run commands or change files. Those agents need tools such as `Write`, `Edit`, or `Bash`. Some agents have no `Write` or `Edit` tool. The `tools:` line (line 4) of each file in `agents/*.md` is the master list of tools for that agent. You must grant the tools that the agents need. The plugin cannot grant them. You grant them in your own settings. If you never granted them, the agent stalls at the permission boundary.

**Fix.** Pre-authorize the tools in a project-level (or user-level) `settings.local.json` allow list. Then start the run again. For example, in `.claude/settings.local.json`:

```json
{
  "permissions": {
    "allow": ["Write", "Edit", "Bash"]
  }
}
```

You can limit `Bash` to specific command prefixes if you prefer. The system prompts for anything you did not pre-allow. See [install.md](./install.md) for the full permissions walkthrough.

---

## 2. Missing `Write` / `Edit` / `Bash` (background agents stall with no prompt)

**Symptom.** A background dispatch (an executor run in the background instead of the foreground) hangs, makes no progress, or fails silently. No prompt appears for you to approve. Foreground runs of the same work ask you to approve each step.

**Cause.** Background agents cannot answer interactive permission prompts. The orchestrator can dispatch an executor as a background subagent. If that executor hits a tool-permission prompt, nobody is present to approve it. The dispatch then stalls or fails. This is the `Write` / `Edit` / `Bash` boundary. The executors need those tools, and the system does not grant them to you automatically.

**Fix.** For a background dispatch, you must pre-authorize. Do not rely on prompts. Add `Write`, `Edit`, and `Bash` to the `allow` list in your `settings.local.json` (see the example in section 1) before the background run starts. Plugin-bundled settings cannot grant these tools. They must live in your own `settings.local.json`. If you sit at the keyboard, you can run the agents in the foreground and approve each prompt as it appears. That path does not work for a background dispatch.

---

## 3. Marketplace auth issues (cannot add, install, or auto-update)

**Symptom.** Adding the marketplace or installing the plugin fails to reach the repository. Or a startup auto-update from the private remote fails, often silently, even though your manual install worked.

**Cause.** Distribution is private. The permissions on the git repository alone decide who can install or update. No public listing matters. Install and update both clone or pull from the remote. Without repo access, they fail. The manual `add` / `install` / `update` path uses your existing git credential helper. For example, it can use `gh auth login`, the OS keychain, or an SSH key already loaded in your agent. It needs no extra token. Background auto-update is different. It runs without your interactive credential helpers. To pull from a private remote, it needs a credential in the environment.

**Fix.**

- Confirm that you have access to the private repository. If you cannot reach it with your normal git credentials, nobody has granted you access. You have nothing to configure locally. (See "Shared, not secret" in [install.md](./install.md). Revoking access stops future installs and updates. Copies that you already installed stay in place.)
- For the manual path, make sure your git credential helper is set up. For example, run `gh auth login`, load your SSH key, or unlock the keychain. Then use the manual `marketplace update` flow.
- For background auto-update against a private GitHub-hosted remote, export a `GITHUB_TOKEN` (repo scope) in your shell profile. The non-interactive update then has a credential:

  ```
  export GITHUB_TOKEN=ghp_xxxxxxxxxxxx
  ```

  Without `GITHUB_TOKEN` (or the equivalent for your host), a private-remote auto-update fails silently. Use the manual update path instead.

The full install, auth, and update detail (including the exact install commands) is in [install.md](./install.md).

---

## 4. "Why did it refuse my plan?"

**Symptom.** You asked for something and the system declined, sent the work back, or asked you to clarify. It feels like the tool is in your way.

**Cause.** Refusal is expected behaviour. It is not a malfunction. The system refuses three classes of request instead of guessing: unsafe plans, ambiguous or under-specified instructions, and non-deterministic requests. It is also adversarial by design. The read-only checkers (`task-checker` and `implementation-verifier`) only detect deviations. They never fix them. When a check fails, the work goes back to the generator that produced it. A failed proposal check returns to the `proposal-writer`. A failed build returns to the `implementer`. Neither the checker nor the orchestrator patches the work in place.

**Fix.** Read the refused output. It states what was unsafe, ambiguous, or non-deterministic, and what it needs from you. Supply the missing decision or constraint, or narrow the request so it is determinate. Then let the generator run again and the check pass again. Do not try to force a hand-patch around a failed check. That is the drift the system exists to prevent. For the full list of what the system will not do and why, see [why-it-refuses.md](./why-it-refuses.md).

---

## 5. "Why did it say the artefacts disagree with the conversation?"

**Symptom.** You told the orchestrator something in the chat. It acts on a different value, or says the artefacts contradict what you just said. It seems to ignore the conversation.

**Cause.** The canonical artefacts are authoritative. When the conversation and the artefacts disagree, the artefacts win. The `proposal.md` is the root of truth. Every task traces to it, and every implementation traces to a task. The system treats memory and chat history as evidence to re-verify. They never compete as a source of truth. A claim made only in conversation does not override what the canonical files say. The same precedence keeps long sessions from drifting.

**Fix.** Change the artefact. Do not argue with the chat. If the artefacts are stale or wrong, update the canonical file through its single owner. A proposal change is a `proposal-writer` job, and the proposal is checked again afterward. A task change is a `task-planner` job. After the artefact shows the new intent, the conversation and the files agree and work continues. If you only need to record context, put it in memory. See [design-principles.md](./design-principles.md) for the precedence rules and [why-it-refuses.md](./why-it-refuses.md) for the artefacts-versus-conversation case.

## 6. Duplicate log entries in a project that already logs (double-fire)

**Symptom.** You install this plugin at user scope. A project that already runs its own logging hook now seems to log twice. One entry goes to this plugin's `events.jsonl` and one goes to the project's own log file.

**Cause.** This is expected and harmless. Plugin hooks and a project's own hooks **coexist and do not override each other**. When you enable a plugin, its hooks merge with your user and project hooks. All matching hooks run. Only *byte-identical* command strings are de-duplicated. A project can run its own autolog with a *different* command (for example, one that writes to its own `logs/` file). That project then fires **both** its own hook and this plugin's `autolog.py`. They write to two different files. No data is lost or corrupted. The two logs are independent.

**Fix.** Usually you need none. Dual logging is acceptable, and the files do not collide. This plugin does **not** touch or remove any other project's hooks. If you want a single log in a given project, remove that project's own logging hook from its `.claude/settings.json` yourself. This plugin does not do it for you.

## 7. Commands and agents have a `claude-workspace:` prefix

**Symptom.** After you install the plugin, you invoke the workspace skill as `/claude-workspace:workspace` instead of `/workspace`. The subagents appear under namespaced names.

**Cause.** The plugin name namespaces plugin-provided skills and agents. This is normal Claude Code behaviour for any installed plugin. The prefix lets many plugins ship skills or agents with the same short name without a collision.

**Fix.** Nothing to fix. Use the namespaced names: `/claude-workspace:workspace` for the orchestrator, and the `claude-workspace:` prefix for the eight subagents when you dispatch. You may have hand-placed copies under bare names (`/workspace`). Those are the old un-namespaced mirrors. Once you use the plugin, the namespaced names are canonical.
