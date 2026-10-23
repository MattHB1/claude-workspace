# Initiatives and the registry

In Claude Workspace the **initiative** -- not the project -- is the first-class
unit of work. A single project can host more than one initiative, so each
initiative gets its own subfolder under `.workspace/` and is tracked in a single
registry file. This page explains how initiatives are named, how their artefacts
are kept from colliding, how you switch between them, how the registry is stored,
and -- honestly -- how to remove one.

For the broader vocabulary (project vs. initiative, artefacts, agents) see
[concepts.md](concepts.md). For the conversational verbs in context see
[workflow.md](workflow.md).

## The three managing verbs

The orchestrator exposes exactly three conversational verbs for initiatives, and
they are the whole surface area:

- **Create a new initiative** -- "new initiative <name>", "start a new
  initiative", "spin up an initiative for...".
- **Switch this session's initiative** -- "switch to <name>", "work on <name>".
- **List initiatives** -- "list initiatives", "what's in this workspace", "what
  initiatives do we have".

These are orchestrator actions against the registry and the `<slug>/`
subfolders. None of them dispatches a subagent or introduces a new agent. There
is no fourth verb -- in particular, there is no delete or rename verb (see
"Removing an initiative" below).

## Naming and slugs

Each initiative has a **slug**: a short identifier that doubles as the name of
its subfolder under `.workspace/`. When you create an initiative, the
orchestrator picks a `<slug>` for it and creates the `.workspace/<slug>/`
subtree. Every artefact that belongs to that initiative resolves under its own
`<slug>/` directory.

The slug is the stable handle for the initiative: the registry refers to it, the
on-disk subfolder is named after it, and the switch verb names it when changing
which initiative this session works on.

The slug can be a ticket or issue number. When you create an initiative from a
ticket, the ticket identifier becomes the slug, and a **numeric slug is valid** --
`.workspace/4821/` is a normal initiative subfolder.

## How collisions are avoided

Because a project can hold several initiatives at once, their artefacts could in
principle clash. The workspace prevents this structurally: every initiative's
complete artefact set lives inside its own `.workspace/<slug>/` subfolder, and
**two distinct initiatives never share or overwrite any of these** -- each
resolves under its own `<slug>/`.

The per-initiative artefacts that live under `<slug>/` include:

```
.workspace/
  initiatives.md       # the registry (project-level, shared)
  file-structure.md    # project-level layout (shared, one per project)
  namespaces           # project-level shared-memory declaration (shared)
  tracker-states       # project-level transition-point -> tracker state-name mapping (shared)
  <slug>/              # one subfolder PER INITIATIVE -- non-colliding
    proposal.md        # this initiative's root of truth
    tasks.md           # this initiative's task list
    research/          # this initiative's research briefs
    verification/      # this initiative's check & verify reports
    memory/            # this initiative's working-memory + journal
```

Only four artefacts live at the `.workspace/` root and are shared across all of
a project's initiatives: the registry `initiatives.md`, the project-level
`file-structure.md`, the project-level `namespaces` declaration, and the
project-level `tracker-states` mapping. Everything else is initiative-scoped
under `<slug>/`. Because each initiative's
`proposal.md`, `tasks.md`, `research/`, `verification/`, and `memory/` resolve
inside a distinct `<slug>/` directory, naming collisions between initiatives
cannot happen by construction.

## How the session pick works (the per-session marker)

Each session picks its own initiative. The registry does not store the pick.

> **Session pick:** when you start the workspace, the orchestrator reads the
> registry and lists every open initiative, plus "new initiative". It then waits.
> You pick one. The orchestrator loads no initiative memory before you pick.

The pick lives in a per-session marker file,
`~/.claude/.workspace-active/<session_id>`. It holds plain `key=value` lines:

- `root=` -- the shared root of the repo (the folder that holds `.workspace/`).
- `checkout=` -- the checkout path of this session (the repo or a worktree).
- `slug=` -- the initiative this session picked.

The orchestrator writes `root=` and `checkout=` when the session starts. It writes
`slug=` after your pick passes the checks below. It never changes a marker that
already has content, except to write the pick.

- **Creating** an initiative picks the new one for this session. It writes no
  `**ACTIVE**` marker in the registry.
- **Switching** changes the `slug=` line in this session's marker. **No files
  move.** The artefacts of every initiative stay exactly where they are under
  their own `<slug>/`.
- **Exit** deletes this session's marker. The next session picks again.

**Block on the same initiative.** Before it writes `slug=`, the orchestrator scans
the markers of the other sessions. If another live session has the same `root=`
and `slug=`, the pick fails. The message names the initiative. Your marker does
not change. This holds for Create-pick and for Switch.

**Stale marker.** A crash can leave a marker behind. If a block names a session
that has ended, tell the orchestrator that the other session has ended. It
deletes that marker and continues. Without your statement, the block stays.

**Main-locked and main-allowed repos.** By default, a repo is **main-locked**.
Parallel sessions then use different branches.
When two live sessions share one checkout, the orchestrator makes a git worktree
at `<root>/.claude/worktrees/<slug>` for the new session.

To make a repo **main-allowed**, write the single word `allowed` to
`<repo>/.workspace/main-commits`:

```
echo allowed > <repo>/.workspace/main-commits
```

With no file, the repo is main-locked. In a main-allowed repo, the plugin never
makes or enters a worktree. It allows one live workspace session at a time. A
second session that shares the `root=` gets a block that says so, and it writes
no slug. The orchestrator reads this state only from that file.

**Age-gated `/clear` reminder.** Create and switch both check how long the
session has been running. Past a threshold (default 2 hours), the orchestrator
offers an advisory reminder: type `/clear` or `/compact`, then re-invoke the
workspace and pick again. Below the threshold, or if
the session age can't be read, the reminder stays silent and the verb completes
as normal.

**Guard checks on create/switch.** Create and switch both also run the
index-bloat guard (checks the newly-picked initiative's `memory/index.md`
size) and the Epic/granularity guard (checks its `memory/journal.md` entry
count). Neither guard blocks or delays create or switch.
The index-bloat guard acts alone. If the index is at or over its size limit, the
orchestrator re-derives the index lean itself and reports one line. It asks no
y/n question.
The Epic/granularity guard is advisory only. It shows one line of notice. It
does not split the initiative, does not act, and asks no question.
If a check finds nothing, it stays silent.

## How the registry is stored

The registry is a single, orchestrator-owned, parseable file at the
`.workspace/` root: `.workspace/initiatives.md`. It records **every** initiative
in the project. Each entry carries exactly three fields:

- **slug** -- the initiative's `<slug>/` subfolder name.
- **one-line description** -- a short human-readable summary of the initiative.
- **status** -- the lifecycle state of the initiative.

The registry is the authoritative record of which initiatives exist. It does not
record which one a session works on. The session marker holds that. The **orchestrator is the registry's sole content writer** -- no
read-only agent writes the registry. The List verb simply reports from this
file: every initiative's slug, one-line description, and status.

If a project has no `.workspace/` at all, the orchestrator creates the directory
and an empty registry, then guides you through creating the first initiative
(which creates its `<slug>/` subtree).

## Removing an initiative (manual, not a built-in)

**There is no built-in delete or rename verb.** The orchestrator's initiative
surface is exactly create / switch / list -- nothing removes an initiative for
you, and the docs do not pretend otherwise.

If you genuinely need to remove an initiative, it is a **manual** operation you
perform **by hand**, not a first-class command:

1. **Remove its row from the registry.** Edit `.workspace/initiatives.md` and
   delete the entry (slug + one-line description + status) for that initiative.
2. **Remove its directory.** Delete the `.workspace/<slug>/` subfolder, which
   holds that initiative's `proposal.md`, `tasks.md`, `research/`,
   `verification/`, and `memory/`.
3. **Check the session markers.** A marker whose session has ended
   can stay on disk. Delete it by hand from `~/.claude/.workspace-active/`.

Because `.workspace/` is under git, a manual removal is versioned and revertible
like any other change. This manual path is the honest reality: removal is a hand
edit of the registry plus a directory deletion, not a supported verb.
