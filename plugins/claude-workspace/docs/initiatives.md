# Initiatives and the registry

In Claude Workspace the **initiative** is the first-class unit of work. The project is not. A single project can host more than one initiative. Each initiative has its own subfolder under `.workspace/`. One registry file tracks all of them. This page explains how initiatives get names, how their artefacts stay apart, and how you switch between them. It also explains how the registry is stored and how you remove an initiative.

For the broader vocabulary (project vs. initiative, artefacts, agents), see
[concepts.md](concepts.md). For the conversational verbs in context, see
[workflow.md](workflow.md).

## The three managing verbs

The orchestrator has three conversational verbs for initiatives. They are the whole surface area:

- **Create a new initiative** -- "new initiative <name>", "start a new
  initiative", "spin up an initiative for...".
- **Switch this session's initiative** -- "switch to <name>", "work on <name>".
- **List initiatives** -- "list initiatives", "what's in this workspace", "what
  initiatives do we have".

These are orchestrator actions against the registry and the `<slug>/`
subfolders. None of them dispatches a subagent or adds a new agent. There
is no fourth verb. In particular, there is no delete verb and no rename verb (see
"Removing an initiative" below).

## Naming and slugs

Each initiative has a **slug**. A slug is a short identifier that is also the name of
its subfolder under `.workspace/`. When you create an initiative, the
orchestrator picks a `<slug>` for it and creates the `.workspace/<slug>/`
subtree. Every artefact of that initiative lives under its own `<slug>/` directory.

The slug is the stable handle for the initiative. The registry refers to it. The
subfolder on disk has its name. The switch verb names it when you change
the initiative that this session works on.

The slug can be a ticket or issue number. When you create an initiative from a
ticket, the ticket identifier becomes the slug. A **numeric slug is valid**.
`.workspace/4821/` is a normal initiative subfolder.

## How collisions are avoided

A project can hold several initiatives at once, so their artefacts could clash. The workspace prevents this by its structure. The complete artefact set of each initiative lives inside its own `.workspace/<slug>/` subfolder. **Two distinct initiatives never share or overwrite any of these.** Each one resolves under its own `<slug>/`.

The `.workspace/` folder holds these items:

```
.workspace/
  initiatives.md          # the registry (project-level, shared) - written by the orchestrator
  initiatives-archive.md  # older registry detail moved out of initiatives.md - written by the orchestrator
  file-structure.md       # project-level layout (shared, one per project) - written by the orchestrator
  namespaces              # project-level shared-memory declaration (shared) - written by the orchestrator
  tracker-states          # project-level transition-point -> tracker state-name mapping (shared) - written by the orchestrator
  main-commits            # optional switch for main-allowed repos (shared) - written by you
  <slug>/                 # one subfolder PER INITIATIVE -- non-colliding
    proposal.md           # this initiative's root of truth
    tasks.md              # this initiative's task list
    research/             # this initiative's research briefs
    verification/         # this initiative's check & verify reports
    memory/               # this initiative's working-memory + journal
```

Six items live at the `.workspace/` root and all initiatives of a project share them. They are the registry `initiatives.md`, the registry overflow file `initiatives-archive.md`, and the layout file `file-structure.md`. The other three are the `namespaces` declaration, the `tracker-states` mapping and the `main-commits` file. The orchestrator creates `initiatives-archive.md` when the registry grows too large. You create `main-commits` by hand, and only if you want a main-allowed repo. The orchestrator creates `tracker-states` the first time it asks you to map tracker states. Everything else belongs to one initiative and lives under `<slug>/`. Each initiative has its own `proposal.md`, `tasks.md`, `research/`, `verification/` and `memory/`. These sit inside a distinct `<slug>/` directory, so naming collisions between initiatives cannot happen.

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
`slug=` after your pick passes the checks below. It changes a marker that
already has content only to write the pick.

- **Creating** an initiative picks the new one for this session. It writes no
  `**ACTIVE**` marker in the registry.
- **Switching** changes the `slug=` line in this session's marker. **No files
  move.** The artefacts of every initiative stay where they are, under
  their own `<slug>/`.
- **Exit** deletes this session's marker. The next session picks again.

**Block on the same initiative.** Before it writes `slug=`, the orchestrator scans
the markers of the other sessions. Suppose another live session has the same `root=`
and `slug=`. Then the pick fails. The message names the initiative. Your marker does
not change. This holds for Create-pick and for Switch.

**Stale marker.** A crash can leave a marker behind. Suppose a block names a session
that has ended. Tell the orchestrator that the other session has ended. It
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
gives an advisory reminder. Type `/clear` or `/compact`, then re-invoke the
workspace and pick again. Below the threshold, the reminder stays silent. It also stays silent if
the session age can't be read. The verb then completes as normal.

**Guard checks on create/switch.** Create and switch both also run two guards. The
index-bloat guard checks the size of the newly-picked initiative's `memory/index.md`.
The Epic/granularity guard checks the entry count of its `memory/journal.md`.
Neither guard blocks or delays create or switch.
The index-bloat guard acts alone. Suppose the index is at or over its size limit. The
orchestrator then re-derives the index lean itself and reports one line. It asks no
y/n question.
The Epic/granularity guard is advisory only. It shows one line of notice. It
does not split the initiative, does not act, and asks no question.
If a check finds nothing, it stays silent.

## How the registry is stored

The registry is a single file that the orchestrator owns and a program can parse. It sits at the
`.workspace/` root: `.workspace/initiatives.md`. It records **every** initiative
in the project. Each entry has three fields:

- **slug** -- the initiative's `<slug>/` subfolder name.
- **one-line description** -- a short summary that a person can read.
- **status** -- the lifecycle state of the initiative.

The registry is the authoritative record of which initiatives exist. It does not
record which one a session works on. The session marker holds that. The **orchestrator is the only writer of registry content**. No
read-only agent writes the registry. The List verb reports from this
file: the slug, one-line description and status of every initiative.

If a project has no `.workspace/` at all, the orchestrator creates the directory
and an empty registry. It then guides you through the creation of the first initiative.
That step creates its `<slug>/` subtree.

## Removing an initiative (manual, not a built-in)

**There is no built-in delete or rename verb.** The orchestrator has three initiative verbs:
create, switch and list. Nothing removes an initiative for
you.

If you need to remove an initiative, do it **by hand**. It is not a command:

1. **Remove its row from the registry.** Edit `.workspace/initiatives.md` and
   delete the entry (slug, one-line description and status) for that initiative.
2. **Remove its directory.** Delete the `.workspace/<slug>/` subfolder. It
   holds the `proposal.md`, `tasks.md`, `research/`,
   `verification/` and `memory/` of that initiative.
3. **Check the session markers.** A marker whose session has ended
   can stay on disk. Delete it by hand from `~/.claude/.workspace-active/`.

`.workspace/` is under git, so a manual removal is versioned and you can revert it
like any other change. Removal is a hand edit of the registry plus a directory deletion. It is not a supported verb.
