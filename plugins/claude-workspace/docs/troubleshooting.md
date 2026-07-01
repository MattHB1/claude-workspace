# Troubleshooting

A symptom-first guide. Find the symptom that matches what you saw, read the cause,
apply the fix. Most "errors" here are the system working as designed (permission gates,
refusals, artefact precedence) rather than bugs.

For deeper background, see the operational guide in [install.md](./install.md), the
refusal contract in [why-it-refuses.md](./why-it-refuses.md), and the design contract in
[design-principles.md](./design-principles.md).

---

## 1. Permission errors when an agent tries to change files

**Symptom.** You ask the orchestrator to build, archive, or verify, and the run stops
with a permission prompt, stalls, or fails before any file is written. You may see a
tool-permission request you cannot answer, or a dispatched agent that simply never
finishes.

**Cause.** Three of the agents are executors that actually touch files: the
`implementer` and the `archivist` change files, and the `implementation-verifier` writes
its own reports. They need the `Write`, `Edit`, and `Bash` tools. These tools are not
pre-provisioned for you, and they cannot be granted by anything the plugin ships -- they
have to be granted in your own settings. If they were never granted, the executor stalls
on the permission boundary.

**Fix.** Pre-authorize the tools in a project-level (or user-level)
`settings.local.json` allow list, then start the run again. For example, in
`.claude/settings.local.json`:

```json
{
  "permissions": {
    "allow": ["Write", "Edit", "Bash"]
  }
}
```

You can scope `Bash` more narrowly (for example to specific command prefixes) if you
prefer; anything not pre-allowed will prompt. See [install.md](./install.md) for the full
permissions walkthrough.

---

## 2. Missing `Write` / `Edit` / `Bash` (background agents stall with no prompt)

**Symptom.** A background dispatch (an executor run in the background rather than the
foreground) hangs, makes no progress, or fails silently. No prompt appears for you to
approve. Foreground runs of the same work seem to ask you to approve each step instead.

**Cause.** Background agents cannot answer interactive permission prompts. When the
orchestrator dispatches an executor as a background subagent and that executor hits a
tool-permission prompt, there is nobody present to approve it -- so the dispatch stalls
or fails. This is specifically the `Write` / `Edit` / `Bash` boundary: those tools are
required by the executors and are not granted to you automatically.

**Fix.** For background dispatch you must pre-authorize, not rely on prompts. Add
`Write`, `Edit`, and `Bash` to the `allow` list in your `settings.local.json` (see the
example in section 1) before the background run starts. Plugin-bundled settings cannot
grant these tools -- they must live in your own `settings.local.json`, not in anything
the plugin ships. If you are present at the keyboard, an alternative is to run the agents
in the foreground and approve each prompt as it appears; that path does not work for
background dispatch.

---

## 3. Marketplace auth issues (cannot add, install, or auto-update)

**Symptom.** Adding the marketplace or installing the plugin fails to reach the
repository; or a startup auto-update from the private remote fails -- often silently --
even though your manual install worked.

**Cause.** Distribution is private: who can install or update is governed entirely by the
permissions on the git repository, not by any public listing. Both install and update
clone or pull from the remote, so without repo access they simply fail. The manual
`add` / `install` / `update` path uses your existing git credential helper (for example
`gh auth login`, the OS keychain, or an SSH key already loaded in your agent), so it
needs no extra token. Background auto-update is different: it runs without your
interactive credential helpers, so pulling from a private remote needs a credential
present in the environment.

**Fix.**

- Confirm you actually have access to the private repository. If you cannot reach it with
  your normal git credentials, you have not been granted access -- there is nothing to
  configure locally. (See "Shared, not secret" in [install.md](./install.md): revoking
  access stops future installs and updates, not copies already installed.)
- For the manual path, make sure your git credential helper is set up (for example run
  `gh auth login`, load your SSH key, or unlock the keychain) and use the manual
  `marketplace update` flow.
- For background auto-update against a private GitHub-hosted remote, export a
  `GITHUB_TOKEN` (repo scope) in your shell profile so the non-interactive update has a
  credential:

  ```
  export GITHUB_TOKEN=ghp_xxxxxxxxxxxx
  ```

  Without `GITHUB_TOKEN` (or the equivalent for your host), a private-remote auto-update
  fails silently -- stick to the manual update path instead.

The full install, auth, and update detail (including the exact install commands) lives in
[install.md](./install.md).

---

## 4. "Why did it refuse my plan?"

**Symptom.** You asked for something and the system declined, sent the work back, or
asked you to clarify instead of just doing it. It feels like the tool is being
obstructive.

**Cause.** Refusal is expected behaviour, not a malfunction. The system is built to
refuse three classes of request rather than guess: unsafe plans, ambiguous or
under-specified instructions, and non-deterministic requests. It is also adversarial by
design -- the read-only checkers (`task-checker` and `implementation-verifier`) only
detect deviations; they never fix them. When a check fails, the work routes back to the
generator that produced it (a failed plan returns to the `task-planner`, a failed build
returns to the `implementer`), and is never patched in place by the checker or the
orchestrator.

**Fix.** Read the refused output: it states what was unsafe, ambiguous, or
non-deterministic, and what it needs from you. Supply the missing decision or constraint,
or narrow the request so it is determinate, then let the generator re-run and the check
re-pass. Do not try to force a hand-patch around a failed check -- that is the exact drift
the system exists to prevent. For the full list of what the system will not do and why,
see [why-it-refuses.md](./why-it-refuses.md).

---

## 5. "Why did it say the artefacts disagree with the conversation?"

**Symptom.** You told the orchestrator something in the chat, but it acts on a different
value or says the artefacts contradict what you just said -- as if it is ignoring the
conversation.

**Cause.** The canonical artefacts are authoritative. When the conversation and the
artefacts disagree, the artefacts win: the `proposal.md` is the root of truth, every task
traces to it, and every implementation traces to a task. Memory and chat history are
treated as evidence to re-verify, never as a competing source of truth -- so a claim made
only in conversation does not override what the canonical files say. This is the same
precedence that keeps long sessions from drifting.

**Fix.** Reconcile by changing the artefact, not by arguing with the chat. If the
artefacts are stale or wrong, update the canonical file through its single owner: a
proposal change is a `proposal-writer` job (and the plan should be re-checked afterward),
a task change is a `task-planner` job. Once the artefact reflects the new intent, the
conversation and the files agree and work proceeds. If you only need to record context
rather than change the source of truth, that belongs in memory -- see
[design-principles.md](./design-principles.md) for the precedence rules and
[why-it-refuses.md](./why-it-refuses.md) for the artefacts-vs-conversation case.

## 6. Duplicate log entries in a project that already logs (double-fire)

**Symptom.** After installing this plugin at user scope, a project that already runs its
own logging hook appears to log twice -- once to this plugin's `events.jsonl` and once to
the project's own log file.

**Cause.** This is expected and harmless. Plugin hooks and a project's own hooks
**coexist -- they do not override each other**. When a plugin is enabled, its hooks merge
with your user and project hooks: all matching hooks run, and only *byte-identical* command
strings are de-duplicated. A project that runs its own autolog with a *different* command
(for example, writing to its own `logs/` file) therefore fires **both** its hook and this
plugin's `autolog.py` -- writing to two different files. No data is lost or corrupted; the
two logs are simply independent.

**Fix.** Usually none needed -- dual logging is acceptable and the files do not collide.
This plugin does **not** touch or remove any other project's hooks. If you genuinely want a
single log in a given project, remove that project's own logging hook from its
`.claude/settings.json` yourself; this plugin will not do it for you.

## 7. Commands and agents have a `claude-workspace:` prefix

**Symptom.** After installing the plugin, the workspace skill is invoked as
`/claude-workspace:workspace` rather than `/workspace`, and the subagents appear under
namespaced names.

**Cause.** Plugin-provided skills and agents are **namespaced by the plugin name**. This is
normal Claude Code behaviour for any installed plugin -- the prefix is what lets multiple
plugins ship skills or agents with the same short name without colliding.

**Fix.** Nothing to fix -- use the namespaced names: `/claude-workspace:workspace` for the
orchestrator, and the `claude-workspace:` prefix for the eight subagents when dispatching.
If you previously ran hand-placed copies under bare names (`/workspace`), those are the
old un-namespaced mirrors; once you consume the plugin, the namespaced names are canonical.
