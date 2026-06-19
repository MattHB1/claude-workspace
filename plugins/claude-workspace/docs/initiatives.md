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
- **Switch the active initiative** -- "switch to <name>", "make <name> active",
  "work on <name>".
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
which initiative is active.

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
  <slug>/              # one subfolder PER INITIATIVE -- non-colliding
    proposal.md        # this initiative's root of truth
    tasks.md           # this initiative's task list
    research/          # this initiative's research briefs
    verification/      # this initiative's check & verify reports
    memory/            # this initiative's working-memory + journal
```

Only three artefacts live at the `.workspace/` root and are shared across all of
a project's initiatives: the registry `initiatives.md`, the project-level
`file-structure.md`, and the project-level `namespaces` declaration. Everything
else is initiative-scoped under `<slug>/`. Because each initiative's
`proposal.md`, `tasks.md`, `research/`, `verification/`, and `memory/` resolve
inside a distinct `<slug>/` directory, naming collisions between initiatives
cannot happen by construction.

## How switching works (the ACTIVE marker)

The registry records which initiative is **ACTIVE**. The rule is strict:

> **Single-active rule:** whenever at least one initiative exists, exactly one is
> ACTIVE -- never zero, never more than one. The only time none is active is in an
> empty workspace before any initiative has been created.

- **Creating** an initiative marks the new one ACTIVE and demotes whichever was
  previously active, so exactly one stays active.
- **Switching** changes the ACTIVE marker in the registry to the named
  initiative's slug. **No files move** -- switching is purely a change of which
  slug is marked active. The artefacts of every initiative stay exactly where
  they are under their own `<slug>/`.

When the orchestrator enters a project it reads the registry first to learn which
initiative is ACTIVE, then operates under that initiative's
`.workspace/<active-slug>/` paths. The active initiative is what every later
action resolves against until you switch.

## How the registry is stored

The registry is a single, orchestrator-owned, parseable file at the
`.workspace/` root: `.workspace/initiatives.md`. It records **every** initiative
in the project. Each entry carries exactly three fields:

- **slug** -- the initiative's `<slug>/` subfolder name.
- **one-line description** -- a short human-readable summary of the initiative.
- **status** -- including which one is ACTIVE.

The registry is the authoritative record of which initiatives exist and which is
active. The **orchestrator is its sole content writer** -- no read-only agent
writes the registry. The List verb simply reports from this file: every
initiative's slug, one-line description, and status, highlighting the ACTIVE one.

If a project has no `.workspace/` at all, the orchestrator creates the directory
and an empty registry, then guides you through creating the first initiative
(which creates its `<slug>/` subtree and marks it ACTIVE).

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
3. **Re-point ACTIVE if needed.** If the initiative you removed was the ACTIVE
   one, the single-active rule still applies: while at least one initiative
   remains, exactly one must be ACTIVE. Update the registry so another remaining
   initiative is marked ACTIVE (or, if it was the last one, the workspace is once
   again empty with none active).

Because `.workspace/` is under git, a manual removal is versioned and revertible
like any other change. This manual path is the honest reality: removal is a hand
edit of the registry plus a directory deletion, not a supported verb.
