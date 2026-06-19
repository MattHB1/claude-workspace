# Memory

Claude Workspace keeps memory in flat files you can read, grep, and revert from
git. There is no database, vector store, graph store, embedding index, daemon, or
external service anywhere in the memory design. Retrieval is always index-first
plus `grep`/`glob` over the files (keyword-only) -- never similarity ranking or
semantic search. Losing semantic retrieval is the accepted tradeoff for
determinism, auditability, and zero infrastructure.

Three memory systems coexist, with **no mirroring between them**:

1. **Per-initiative memory** -- one initiative's episodic working history.
2. **Cross-project shared memory** -- durable knowledge reused across separate
   projects (the power feature this page makes usable).
3. **Native Claude Code auto-memory** -- a separate per-repository tier that the
   workspace neither reads from nor writes to.

The orchestrator (you, when the skill is active) is the **sole content writer** of
the first two tiers. Read-only agents may read memory and return content as
messages, but they never write it.

---

## Tier 1: per-initiative memory (episodic)

Each initiative gets its own memory under its `.workspace/<slug>/memory/`
subfolder. This tier is **episodic and scoped to a single initiative**: it records
what that initiative did and decided, and references no other project. It exists so
a long, multi-day orchestrator session can offload its early history to disk and
reload only what is relevant, keeping a fresh working context instead of letting
the window fill with rot.

It is created on demand the first time an initiative uses memory.

### What the two files are for

```
.workspace/<slug>/memory/
  index.md      # state-of-world pointer + table of contents (OVERWRITTEN on refresh)
  journal.md    # append-only decision/progress log (markdown + YAML frontmatter)
  archive/      # consolidation destination + paged-in detail (moved here, never deleted)
```

- **`journal.md` -- the append-only log.** Each entry is a YAML frontmatter block
  (mandatory `timestamp`, `role`, and `trust` fields) followed by a short markdown
  body. You only ever **append** new entries; prior entries are never edited or
  deleted in place. The `trust` marker is `verified` (re-derived or re-run against
  reality) or `asserted` (claimed only), so readers know what to re-check rather
  than blindly trust.
- **`index.md` -- the overwritten pointer.** A small, machine-maintained structured
  file (a YAML/frontmatter list, JSON-like) that you **overwrite** on each refresh.
  It holds **pointers (paths/anchors) and short summaries only -- never the
  authoritative payload**. It is fully regenerable: delete it and rebuild it from
  `journal.md` plus the initiative's canonical artefacts (`proposal.md`,
  `tasks.md`, `verification/`). Regenerating loses nothing.

**Canonical artefacts win.** Where memory and a canonical artefact disagree, the
artefact is authoritative. Memory therefore **references** canonical content by
path/anchor (for example `.workspace/<slug>/tasks.md#T4`) and never restates or
copies the payload.

### When it loads and persists

- **Bootstrap (read):** after resolving the active initiative from the registry,
  read `index.md` first (it is small by design), then the **journal tail -- at most
  the last 20 entries** -- then the specific task/proposal for the work in hand.
  Page in older entries or `archive/` files only on demand via explicit path or
  `grep`. Never reload the full history; bounded re-ingestion is the whole point.
- **Teardown (write):** at session end and at safe checkpoints, append a journal
  entry and refresh the index. Treat every checkpoint as "assume interruption" so a
  reset mid-project loses nothing.

It all lives inside the git-controlled `.workspace/` tree, so every write is
versioned and revertible from git -- no parallel versioning mechanism.

---

## Tier 2: cross-project shared memory (durable, reusable)

Per-initiative memory is episodic by construction and references no other project.
Some knowledge, though, is **durable and recurring across separate projects**:
stable facts about entities you work with, reusable how-to lessons, and durable
preferences or conventions. The cross-project shared tier is a single,
above-the-project home for exactly that knowledge, so you can reuse it on a new
project instead of re-deriving and duplicating it.

It is a bespoke flat-file home one level up from any project, under
`~/.claude/shared-memory/`. It is **not** native Claude Code auto-memory and
involves no database, vector/graph/embedding store, daemon, server, scheduler, or
external service. It is **not auto-loaded** -- you read it explicitly during
bootstrap; nothing pulls it in for you.

```
~/.claude/shared-memory/
  index.md        # state-of-world pointer + table of contents (OVERWRITTEN on refresh)
  journal.md      # append-only log of promotion events / shared decisions
  global/         # namespace: facts/preferences/lessons that hold everywhere
  acme/           # namespace: one dir PER PROJECT FAMILY -- holds shared claim files
  archive/        # consolidation/staleness destination (moved here, never deleted)
```

The `index.md` and `journal.md` use the same mechanics as the per-initiative tier
(overwritten index; append-only, trust-marked journal). The durable payload lives
in the **per-namespace claim files**.

### When to use shared memory

Shared memory is for knowledge that is **durable and will recur on other
projects** -- not one initiative's task state. Only three kinds of knowledge are
eligible (promotable):

- **semantic** -- a stable fact about a recurring entity.
- **procedural** -- a reusable lesson, how-to, or workflow learning.
- **preference** -- a durable convention, preference, hard constraint, or
  reference.

**Episodic** content -- an initiative's task state, in-flight decisions, or project
history -- is **not promotable** and stays in that initiative's per-initiative
`.workspace/<slug>/memory/`.

Treat a shared claim as **evidence gathered in another project's context, not
ground truth**. Before acting on one in a new project, re-validate it in that
project's context. If it disagrees with the live tree, a canonical artefact,
per-initiative memory, or another shared claim, the conflict is **surfaced, never
silently merged or auto-resolved**.

### How to promote a lesson (manual, explicit, orchestrator-owned)

Knowledge enters the shared tier **only by an explicit promotion decision made by
the orchestrator** -- on the user's instruction or on a read-only agent's surfaced
candidate. There is **no automatic, on-recurrence, or background promotion** of any
kind.

- **Read-only agents may only suggest.** `research-harvester`, `task-checker`,
  `implementation-verifier`, `context-recovery`, and `archivist` may read the
  shared tier and surface a "this looks reusable" candidate by **returning it as
  content**. They never write the tier. The orchestrator decides and persists.
- **Every claim is a markdown + YAML-frontmatter file** in a namespace dir, with
  these mandatory fields: `type` (`semantic` / `procedural` / `preference`),
  `source` (the project(s) it was learned in), `scope` (the validity scope -- a
  namespace/entity, or `global`), a **supersedes / staleness** marker, and `trust`
  (`verified` vs `asserted`).
- **De-contextualization guard.** A project-specific fact must record its source
  project and a bounded `scope`, never an unqualified `global` -- otherwise lifting
  it out of its project silently drops the implicit "...in project X" qualifier.
  For example, a build-tool fact learned in one project should be scoped to that
  project family (such as `scope: acme/service-x`), not to `global`.
- **Dedup before writing.** Check for an existing claim with the same or
  overlapping scope, keyed on namespace/scope plus `type`. If one exists,
  **update or supersede** it (set the supersedes marker, archive the old) rather
  than appending a parallel duplicate.

Consolidation and pruning are also orchestrator-owned and non-destructive:
superseded or stale claims are rolled up into a summary and **moved to
`archive/`**, never hard-deleted; full history stays recoverable via git.

### How to inspect it

The shared tier is **plain files under `~/.claude/shared-memory/`** -- read and
`grep` them directly:

- **Start at the index:** read `~/.claude/shared-memory/index.md`. It is the
  state-of-world and table of contents (pointers and short summaries only), so it
  tells you what exists and where without loading everything.
- **Skim the journal:** `~/.claude/shared-memory/journal.md` is the append-only log
  of promotion events and shared decisions.
- **Read the namespace claim files:** open the `global/` directory plus any
  project-family namespace dir (for example `acme/`) and read the individual claim
  files; each carries its `type`, `source`, `scope`, staleness marker, and `trust`
  in frontmatter.
- **Grep across them:** keyword search is the supported retrieval, for example
  `grep -ri "<keyword>" ~/.claude/shared-memory/`. Because it is keyword-only,
  the miss rate across unrelated projects is higher than within one project -- an
  accepted tradeoff for determinism and auditability.

The tier lives inside the existing `~/.claude` git repo, so every shared write is
versioned and revertible from git. (Because that repo uses a default-deny
`.gitignore` allowlist, the `shared-memory/` directory must be allowlisted to be
tracked.)

### How to disable / opt out

There is **no separate disable command or toggle** -- shared memory is **opt-in
through the project's namespace declaration**, so opting out is simply not opting
in.

A project reads the shared tier only if it **declares which namespaces it reads** in
a small project-level file at its `.workspace/` root: `.workspace/namespaces`
(filename non-load-bearing). That file holds a parseable list of namespace names
(always `global/`, plus zero or more project-family namespaces). It is the
project's cross-project membership and is **shared by all the project's
initiatives** -- it is not duplicated per initiative. The convention is defined,
not necessarily pre-created: it is created on demand the first time a project reads
the shared tier.

So to control participation:

- **Opt in:** create `.workspace/namespaces` and list the namespaces the project
  should read. Bootstrap then reads `global/` plus the declared project-family
  namespace(s) from `~/.claude/shared-memory/`, index-first and page-on-demand.
- **Opt out / disable:** **do not declare the namespaces** -- omit
  `.workspace/namespaces`, or remove the file, or remove a specific namespace from
  it. A project that declares no namespaces reads no shared tier. Removing a
  namespace entry stops that project reading that namespace. This is the real and
  only opt-out mechanism; there is no invented disable switch.

---

## Tier 3: native Claude Code auto-memory (separate, not mirrored)

Claude Code's native auto-memory (its `MEMORY.md`/auto-memory) is a **separate
per-repository tier**: cwd-keyed, machine-local, non-git, and Claude-written, with
its own home. It coexists with the two workspace tiers but is **not mirrored** into
or out of either one in either direction, and it is **not** the cross-project tier.

The net result is exactly one documented home per kind of state: per-initiative
working state in the journal+index, durable cross-project knowledge in
`~/.claude/shared-memory/`, and per-repository Claude-written learnings in native
auto-memory.

---

## Related

- [concepts.md](concepts.md) -- glossary, including the memory tiers.
- [initiatives.md](initiatives.md) -- the registry and the active initiative whose
  memory loads at bootstrap.
- [design-principles.md](design-principles.md) -- the invariants that make memory
  deterministic and auditable.
- [limitations.md](limitations.md) -- keyword-only retrieval and no automatic
  promotion as accepted tradeoffs.
