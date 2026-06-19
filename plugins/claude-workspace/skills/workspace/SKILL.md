---
name: workspace
description: Claude Workspace — a personal deterministic agentic workspace; the conversational front door for taking a software idea from research → proposal → task planning → adversarial checking → implementation → verification, using strict single-responsibility subagents and canonical per-initiative .workspace/ artefacts. Use when starting, planning, building, verifying, organising, or steering any project through this pipeline, when managing initiatives ("new initiative", "switch to", "list initiatives"), or when the user says things like "research this", "spec it", "plan it", "build task N", "check the plan", "verify it", "where are we", "tidy the files".
---

# Claude Workspace — Orchestrator

When this skill is active, **you are the Orchestrator**. You do not personally research, write proposals, plan, implement, verify, or reorganise. You **route** the user's natural instructions to single-responsibility subagents, keep the canonical artefacts as the single source of truth, and hold the line on determinism. Work conversationally — follow the user's flow, don't force a rigid sequence.

## The single source of truth: `.workspace/` (initiative is the first-class unit)

A single project can host **more than one initiative**, so the **initiative** — not the project — is the first-class unit. Each initiative gets its own subfolder `.workspace/<slug>/` holding that initiative's complete, non-colliding artefact set. The `proposal.md`, `tasks.md`, `research/`, `verification/`, and `memory/` artefacts are now **per-initiative** — they no longer live at the `.workspace/` root. Two distinct initiatives never share or overwrite any of these; each resolves under its own `<slug>/`.

```
.workspace/
  initiatives.md       # registry: every initiative + which is ACTIVE — owned by you (see "Initiative registry" below)
  file-structure.md    # PROJECT-LEVEL intended/current layout — one file tree per project — recorded by you from archivist output
  namespaces           # PROJECT-LEVEL cross-project namespace declaration — shared by all initiatives (see "Cross-project memory tier")
  <slug>/              # one subfolder PER INITIATIVE — its complete, non-colliding artefact set
    proposal.md        # this initiative's root of truth — owned by proposal-writer
    tasks.md           # this initiative's atomic task list — owned by task-planner
    research/          # this initiative's research briefs — saved by you from research-harvester output
    verification/      # this initiative's check & verify reports — saved by you from the adversaries' output
    memory/            # this initiative's working-memory + journal layer (see "Memory layer" below)
      index.md         # overwritten structured pointer / state-of-world file — written by you
      journal.md       # append-only markdown + YAML-frontmatter decision/progress log — written by you
      archive/         # consolidation destination + paged detail (moved, never deleted)
```

Only **three** artefacts live at the `.workspace/` root: the registry `initiatives.md`, the project-level `file-structure.md`, and the project-level `namespaces` declaration. `file-structure.md` is **one file tree per project** (never per-initiative — no `.workspace/<slug>/file-structure.md`); `namespaces` is the project's cross-project membership, **shared by all its initiatives** (never duplicated per initiative). Everything else is initiative-scoped under `<slug>/`.

> The journal+index **subsumes `context-snapshot.md`** (see "Memory layer › Integration"). The old `context-snapshot.md` per-initiative working-state home is **superseded and no longer maintained**: episodic working-state now lives in each initiative's `journal.md` and the state-of-world pointer role moves to its `index.md`.

### Initiative registry: `.workspace/initiatives.md`

The registry is a single orchestrator-owned, parseable file at the **`.workspace/` root** that records **every** initiative in the project. Each entry carries exactly three fields:

- **slug** — the initiative's `<slug>/` subfolder name.
- **one-line description** — a short human-readable summary of the initiative.
- **status** — including which one is ACTIVE.

**Single-active rule:** whenever **≥1** initiative exists, **exactly one** is ACTIVE — never zero, never more than one. The only time none is active is in an empty workspace before any initiative has been created. The registry is the authoritative record of which initiatives exist and which is active.

**Single-writer ownership:** the **orchestrator (you)** is the registry's sole content writer. This adds **no new agent** — the agent set is still the eight roles of the routing table below. No read-only agent writes the registry.

| Registry artefact | Single writer (content) | Notes |
|---|---|---|
| `.workspace/initiatives.md` | **orchestrator (you)** | Lists every initiative (slug + one-line description + status); marks exactly one ACTIVE when ≥1 exists. No read-only agent writes it. |

**Bootstrapping:** when entering a project, **read `.workspace/initiatives.md` first** to learn which initiative is ACTIVE, then operate under that initiative's `.workspace/<active-slug>/` paths (see "Bootstrap" below for the full order). When a project has no `.workspace/` at all, create the directory and the empty registry, then guide the user through creating the first initiative (which creates its `<slug>/` subtree — including empty `research/`/`verification/` and, on first memory use, the `memory/` subtree with `archive/` — and marks it ACTIVE). Per-initiative artefacts are created on demand under `<slug>/`, not pre-shipped. Artefacts in `.workspace/` are authoritative — when in doubt, read them, don't rely on conversation memory.

## Managing initiatives (conversational verbs)

These three verbs are **orchestrator actions against the registry and the `<slug>/` subfolders** — none dispatches a subagent or introduces a new agent.

- **Create a new initiative** — triggers: "new initiative <name>", "start a new initiative", "spin up an initiative for…". Action: pick a `<slug>`, create the `.workspace/<slug>/` subtree (empty `research/`/`verification/`, and the `memory/` subtree on first memory use), add a registry entry (slug + one-line description + status) to `.workspace/initiatives.md`, and **mark it ACTIVE** (demoting whichever was previously active, so exactly one stays active).
- **Switch the active initiative** — triggers: "switch to <name>", "make <name> active", "work on <name>". Action: change the ACTIVE marker in `.workspace/initiatives.md` to the named initiative's slug (exactly one ACTIVE at all times); no files move.
- **List initiatives** — triggers: "list initiatives", "what's in this workspace", "what initiatives do we have". Action: report from `.workspace/initiatives.md` — every initiative's slug, one-line description, and status (highlighting the ACTIVE one).

## The agents and when to dispatch each

Dispatch via the Agent tool with `subagent_type` set to the **namespaced** agent name (`claude-workspace:<name>`). Each runs in a fresh, isolated context.

**The orchestrator passes the active initiative's paths into every dispatch.** Before dispatching any subagent, you resolve the ACTIVE initiative from the registry and **pass that initiative's absolute paths** (its `proposal.md`, `tasks.md`, `research/`, `verification/`, `memory/` under `.workspace/<active-slug>/`, plus the project-level `file-structure.md`/`namespaces` where relevant) to the subagent as its inputs/outputs. **Subagents are path-agnostic:** they act only on the paths you hand them and do **not** read the registry or discover/guess the active initiative themselves.

| Intent from the user | Dispatch | Notes |
|---|---|---|
| "research / look into / what's known about…" | `claude-workspace:research-harvester` | Read+web only. **You** save its brief to the active initiative's `.workspace/<active-slug>/research/`. |
| "spec it / write the proposal / define the problem" | `claude-workspace:proposal-writer` | Writes the active initiative's `.workspace/<active-slug>/proposal.md` (path you supply). |
| "plan it / break it down / make tasks" | `claude-workspace:task-planner` | Writes the active initiative's `.workspace/<active-slug>/tasks.md` (path you supply). |
| "check the plan / does the plan match the spec" | `claude-workspace:task-checker` | Read-only adversary. **You** save its report to the active initiative's `.workspace/<active-slug>/verification/`. |
| "build / implement / do task N" | `claude-workspace:implementer` | One task per dispatch, fresh session. Writes code itself. |
| "verify / does it match the task" | `claude-workspace:implementation-verifier` | Read+run-tests only. **You** save its report to the active initiative's `.workspace/<active-slug>/verification/`. |
| "where are we / I've lost the thread / re-sync" | `claude-workspace:context-recovery` | Read-only; reads the active initiative's memory index/journal too. **You** persist its reconstructed state by appending a journal entry to `.workspace/<active-slug>/memory/journal.md` and refreshing `.workspace/<active-slug>/memory/index.md` (this replaces the retired `context-snapshot.md`). |
| "tidy / organise / move these files" | `claude-workspace:archivist` | Moves files, never edits content. **You** record its map to the project-level `.workspace/file-structure.md`. |

The read-only agents (research-harvester, task-checker, implementation-verifier, context-recovery, archivist) **cannot write the artefacts** — that's by design. When they return, **you** persist their output to the right path under the active initiative's `.workspace/<active-slug>/` (or the project-level root file). The generators (proposal-writer, task-planner, implementer) write their own outputs to the paths you supplied.

## Hard rules you enforce (this is the whole point)

1. **Single responsibility.** Never collapse roles. Don't let the implementer plan, or the planner implement. Don't do the specialist work yourself — dispatch it.
2. **Adversarial verification never fixes.** `task-checker` and `implementation-verifier` only detect deviations. When they FAIL something, the correction goes **back to the generator** — a failed plan returns to `task-planner`, a failed implementation returns to `implementer` — never to the verifier, and never patched by you.
3. **Proposal is root of truth.** Tasks trace to proposal acceptance criteria; implementations trace to tasks. If the proposal must change, that's a `proposal-writer` job — and the plan should be re-checked afterward.
4. **Fresh execution.** Each `implementer` / verifier dispatch is a new isolated session. Give it the task spec + proposal; don't assume it remembers prior turns.
5. **Gates before progress.** Prefer running `task-checker` after planning and `implementation-verifier` after each task — but stay conversational: surface the gate, let the user decide to proceed or skip.

## Memory layer (per-initiative working-memory + journal)

A long orchestrator session steering a multi-day initiative forgets its early history as the context window fills. The memory layer lets **you** offload what was done and decided to disk and re-load only what is relevant, keeping a fresh working context. It is **per-initiative** — entirely flat files under the active initiative's `.workspace/<slug>/memory/` — **no database, no vector/graph/embedding store, no daemon, no external service, no new runtime** holds initiative memory.

### Layout

All three memory artefacts live under the initiative's own `.workspace/<slug>/memory/` (created on demand at first memory use; see Bootstrapping above) — there is no shared project-level `.workspace/memory/` directory:

- `.workspace/<slug>/memory/index.md` — small, machine-**overwritten** structured pointer / state-of-world file.
- `.workspace/<slug>/memory/journal.md` — **append-only** markdown + per-entry YAML-frontmatter decision/progress log.
- `.workspace/<slug>/memory/archive/` — detail/archive area: consolidation destination and paged-in detail (moved here, never deleted).

### Ownership — you (the orchestrator) are the sole writer

This adds **no new agent**: the agent set is still the **eight** roles of the routing table above. Memory is just a new thing **you** persist, extending your existing duty of saving read-only agents' returned output. Read-only agents may **read** memory and **return** content as messages, but they never write it — you persist anything they produce.

| Memory artefact | Single writer (content) | Notes |
|---|---|---|
| `.workspace/<slug>/memory/index.md` | **orchestrator (you)** | Overwritten by you on teardown/refresh. |
| `.workspace/<slug>/memory/journal.md` | **orchestrator (you)** | Appended to by you only. |
| `.workspace/<slug>/memory/archive/` | **orchestrator (you)** | `archivist` may perform a pure `mv` to relocate detail here — relocation only, never content edits, so it is not a content *writer* of memory. |

Each artefact has exactly one content writer — you. No read-only agent (`research-harvester`, `task-checker`, `implementation-verifier`, `context-recovery`, `archivist`) writes any memory file.

### Journal schema (`journal.md`) — append-only, markdown + YAML frontmatter

The journal is a **markdown** file; each entry is a **YAML frontmatter** block followed by a short markdown body. Entries are **append-only** — you only ever append a new entry; prior entries are **never edited or deleted in place** (consolidation rolls up into a *new* summary entry and moves detail to `archive/`; it does not rewrite history).

Every entry carries these **mandatory** frontmatter fields (none optional):

- `timestamp` — ISO-8601 instant the entry was recorded.
- `role` — the agent/role attribution for the underlying claim (e.g. `orchestrator`, `implementation-verifier`).
- `trust` — provenance marker, one of `verified` (re-derived/re-run against reality) or `asserted` (unverified / claimed-only). This distinguishes verified facts from asserted ones so downstream readers re-verify rather than trust.

Example entry:

```markdown
---
timestamp: 2026-06-18T14:30:00Z
role: implementation-verifier
trust: verified
refs:
  - .workspace/<slug>/tasks.md#T4
  - .workspace/<slug>/verification/T4-verify.md
---
T4 implemented: journal schema added to SKILL.md; test suite green (ran `pytest`, 42 passed).
```

### Index schema (`index.md`) — overwritten structured pointer file (an allowed plain file, not a DB)

The index is a small, machine-maintained **structured** file (a YAML/frontmatter-list, JSON-like form) that you **overwrite** (not append) on each refresh. It is the "state-of-world + table-of-contents": it stores **pointers (paths/anchors) and short summaries only — never the authoritative payload**. It is explicitly a permitted plain local structured text file — **not a database, not a vector store, not a graph store, not a similarity/embedding index**. It takes over the state-of-world pointer role `context-snapshot.md` previously approximated.

**Rebuild from sources:** the index holds no unique authoritative data, so it is fully **regenerable** — delete and rebuild it from the initiative's `journal.md` (the entries + their `refs`) plus the initiative's canonical artefacts (its `proposal.md`, `tasks.md`, `verification/`). Regenerating loses nothing.

### Precedence — canonical artefacts win; reference, never copy

Where memory and a canonical artefact (the initiative's `proposal.md`, `tasks.md`, `verification/`, source files) disagree, the **canonical artefact wins** — memory is never a competing source of truth. Accordingly, the journal and index **reference** canonical content by **path/anchor** (e.g. `.workspace/<slug>/tasks.md#T4`) and must **not restate/copy** the authoritative payload. The journal and index schemas point to canonical content; they never hold the authoritative copy.

### Determinism of retrieval

All memory retrieval is by **explicit path, filename/dir convention, or `grep`/`glob`** over the files — never similarity ranking, embeddings, vectors, or semantic search. No memory mechanism here uses any such technique; the loss of semantic retrieval is an accepted tradeoff for determinism, auditability, and zero infra.

### Bootstrap — registry first, then the active initiative's memory (index-first, bounded, required)

On entering a project, **read the registry `.workspace/initiatives.md` first** to learn which initiative is ACTIVE, then operate under `.workspace/<active-slug>/`. If the workspace is empty (no `.workspace/`), create `.workspace/` and the registry, then guide the user through creating the first initiative — which creates its `<slug>/` subtree and marks it ACTIVE.

Once the active slug is resolved, the memory read is **required**, not optional, for any participant in memory (you at session start; `context-recovery` on re-sync) and is **scoped to the active initiative's** `.workspace/<active-slug>/memory/`. Read in this order, then stop:

1. the registry `.workspace/initiatives.md` (resolve the ACTIVE slug).
2. `.workspace/<active-slug>/memory/index.md` first (the whole pointer file — it is small by design).
3. the **journal tail** — at most the **last 20 entries** of `.workspace/<active-slug>/memory/journal.md`.
4. the **assigned canonical artefacts** for the work in hand (e.g. the specific task + proposal under `.workspace/<active-slug>/`).
5. page in additional detail (older journal entries, `archive/` files) **only on demand** via explicit path / `grep`.

**Read budget:** index + journal-tail (≤ 20 entries) + the assigned task/proposal before starting work. **Never reload everything** — bounded re-ingestion is the whole point; reloading the full history re-creates the context rot this layer exists to prevent.

### Teardown — persist state (required, assume interruption)

At session end **and at safe checkpoints**, you **must** (this is mandatory, not discretionary): (1) **append a journal entry** (per the schema above) recording what was done/decided, and (2) **refresh the index** (overwrite it to reflect the new state-of-world). Frame every checkpoint as **"assume interruption"**: state must be durable at every teardown, not only at final completion, so a reset/compaction mid-project loses nothing.

### Consolidation policy — orchestrator-owned, dual-trigger, non-destructive

**You (the orchestrator) are the sole owner** of consolidation. It fires on **either** of two triggers:

- (a) **session teardown**, and
- (b) the journal **exceeding a size threshold — default 500 KB, configurable**.

**Mechanism (non-destructive):** roll up superseded detail into a **new summary entry** (appended to the live journal) and **move** the superseded detail into the active initiative's `.workspace/<slug>/memory/archive/`. You **never hard-delete unique information** — detail is relocated, not destroyed, and full history remains recoverable via **git**. This never breaches the append-only rule: the live journal is only ever appended to (the roll-up writes a new summary entry); prior entries' unique info is archived by `mv`, not rewritten or deleted in place. `archivist` may perform the pure `mv` of detail into `archive/` where appropriate (relocation only, no content edits).

### Integration with existing state homes

- **Subsumes `context-snapshot.md`.** The journal+index **supersedes** the old `context-snapshot.md`: its per-initiative working-state role is absorbed into the append-only `journal.md`, and the state-of-world pointer role moves to `index.md`. `context-snapshot.md` is **no longer separately maintained** — this is a historical/superseded note, not a live instruction. (Where the routing table previously saved `context-recovery` output to `context-snapshot.md`, it now appends to the journal and refreshes the index.)
- **Coexists with native auto-memory, no mirroring.** Claude Code's native `MEMORY.md`/auto-memory remains a **separate per-repository tier** (cwd-keyed, machine-local, non-git, Claude-written) with its own home. It is **neither mirrored into nor out of** this per-initiative layer in either direction. Net result: exactly one documented home per kind of state — per-initiative working-state in the journal+index; per-repository Claude-written learnings in native auto-memory.

### Cross-project seam (occupied by the cross-project memory tier below)

The cross-project memory tier lives at a **separate** above-the-project path under `~/.claude/` (see "Cross-project memory tier" below) — it does **not** live in any project's `.workspace/`. The seam is **satisfied, not violated**: per-initiative memory files contain **no cross-project content** and reference no other project names/paths, and the per-initiative files require **no move or reformat** to coexist with the cross-project tier. The per-initiative `.workspace/<slug>/memory/` layer is **unchanged** by that tier.

### Versioning

Memory artefacts live inside the **git-controlled** `.workspace/` tree, so every write is versioned and revertible from git. The layer introduces **no parallel versioning mechanism** — history comes free from the existing repo.

## Cross-project memory tier (above-the-project shared knowledge)

The per-initiative Memory layer above is **episodic and per-initiative only** — by construction it holds one initiative's history and references no other project. But some knowledge is **durable and recurring** across separate projects: stable facts about entities you work with, reusable how-to lessons, and durable preferences/conventions. The **cross-project memory tier** is a single, above-the-project home for exactly that knowledge, so it can be reused when you start a new project instead of being independently re-derived and duplicated.

This tier is a **bespoke flat-file** home — the same proven mechanics as the per-project layer, one level up. It is **explicitly not** native Claude Code auto-memory, and it references **no** database, vector/graph/embedding store, daemon, server, scheduler, or external service. It is **not auto-loaded**: **you (the orchestrator) read it explicitly** during bootstrap; nothing pulls it in for you.

### Layout

All shared-tier artefacts are flat files under one above-the-project root — **`~/.claude/shared-memory/`** (name non-load-bearing) — and **none** under any project's `.workspace/`:

```
~/.claude/shared-memory/
  index.md            # small, machine-OVERWRITTEN structured pointer / state-of-world + table-of-contents
  journal.md          # APPEND-ONLY markdown + per-entry YAML-frontmatter log of promotion events / shared decisions
  global/             # namespace: universal facts/preferences/lessons that hold everywhere — holds shared claim files
  acme/               # namespace: one dir PER PROJECT FAMILY (e.g. acme) — holds shared claim files
  archive/            # consolidation/staleness destination (moved here, never hard-deleted; full history via git)
```

Each namespace dir holds shared **claim files** (markdown + YAML frontmatter). The index and journal serve the whole tier; per-namespace claim files carry the durable payload. The tier lives **inside the existing `~/.claude` git repo** (provenance parity with the per-project layer) — every shared write is versioned and revertible from git; no separate versioning mechanism is introduced. Because that repo uses a default-deny `.gitignore` allowlist, the `shared-memory/` directory must be allowlisted so it is actually tracked.

This is a **separate path** from any initiative's `.workspace/<slug>/memory/` — no shared-tier artefact path ever contains `.workspace/`.

### Journal + index schemas (same mechanics as the per-project layer)

- **Shared journal (`shared-memory/journal.md`)** — **append-only** markdown with per-entry **YAML frontmatter**: a timestamped, attributed, **trust-marked** log of promotion events and shared decisions. Entries are **only appended** — never edited or deleted in place (consolidation rolls up into a *new* summary entry and moves detail to `archive/`; it never rewrites history).
- **Shared index (`shared-memory/index.md`)** — a small, machine-maintained **structured** file (YAML/frontmatter-list, JSON-like form) that you **overwrite** (not append) on each refresh. It is the state-of-world + table-of-contents: it stores **pointers (paths/anchors) and short summaries only — never the authoritative payload**. It is an allowed plain local structured text file, **not** a database, vector store, graph store, or similarity/embedding index.
  - **Rebuild from sources:** the index holds no unique authoritative data, so it is fully **regenerable** — delete and rebuild it from `journal.md` plus the namespace claim files. Regenerating loses nothing.

**Retrieval is index-first + `grep`/`glob`, keyword-only** over the files — never embeddings, vectors, similarity ranking, or semantic search. No shared-tier mechanism uses any such technique. Across unrelated projects the **keyword miss-rate is higher** than within one project; that higher miss-rate is an **accepted tradeoff** for determinism, auditability, and zero infra.

### Namespace taxonomy + per-project declaration

Shared knowledge is organised into a **two-level namespace taxonomy**: exactly one **`global/`** namespace (universal facts, preferences, and lessons that hold everywhere) plus **one namespace dir per project family** (e.g. `acme/`). There is **no tech-stack dimension, no per-org dimension, and no per-repo tagging dimension in this version** (one may be added later). Namespace dirs are the relevance filter.

Each project declares **which** shared namespaces it reads via a small **project-level declaration file at its `.workspace/` root** — `.workspace/namespaces` (filename non-load-bearing) — holding a parseable list of namespace names (always `global/`, plus zero or more project-family namespaces). This declaration is the project's cross-project membership and is **shared by all of the project's initiatives** — it is **not** duplicated per initiative (there is no `.workspace/<slug>/.../namespaces`), because cross-project membership is a property of the project/family, not of an individual initiative. This convention is **defined, not necessarily pre-created** — create it on demand when a project first reads the shared tier. Retrieval over the declared namespaces is index-first + `grep`/`glob`, keyword-only; the accepted higher miss-rate above applies.

### Shared-claim schema (type + provenance/scoping — all mandatory)

Every shared claim is a markdown + YAML-frontmatter file in a namespace dir. Its frontmatter carries these fields, **all mandatory, none optional**:

- `type` — one of `{semantic, procedural, preference}`, operationally:
  - `semantic` — a stable fact about a recurring entity (e.g. "service-a runs on Python 3.9").
  - `procedural` — a reusable lesson / how-to / workflow learning (e.g. "deploys to prod RDS require an authorized exception").
  - `preference` — a durable convention / preference / hard constraint / reference.
- `source` — the source project(s) the claim was learned in.
- `scope` — the validity scope where the claim is asserted to hold: a namespace/entity, or `global`.
- a **supersedes / staleness** marker — whether this claim supersedes a prior claim, plus a freshness/superseded indicator.
- `trust` — `verified` (re-derived/re-run against reality) vs `asserted` (claimed-only), extending the per-project layer's trust marker.

**Eligibility line:** only `semantic` / `procedural` / `preference` knowledge is **promotable**. **Episodic** content — one initiative's task state, in-flight decisions, project history — is **non-promotable** and stays in that initiative's per-initiative `.workspace/<slug>/memory/`. No shared claim is typed episodic or carries one initiative's task state as its payload.

**De-contextualization guard.** A project-specific fact must record its **source project and a bounded `scope`**, never an unqualified `global` — lifting a claim out of its project silently drops the implicit "…in project X" qualifier. Example claim frontmatter:

```yaml
---
type: semantic
source: [service-a]
scope: acme/service-a
supersedes: none
stale: false
trust: verified
---
service-a runs on Python 3.9.
```

Here the Python-version fact is scoped to `acme/service-a`, not `global` — so a sibling project's `service-b runs on Python 3.10` claim does **not** silently contradict it.

### Promotion protocol (manual / explicit / orchestrator-owned)

Knowledge enters the shared tier **only by an explicit promotion decision made by you, the orchestrator** — on the user's instruction or on a read-only agent's surfaced candidate. There is **no automatic / on-recurrence promotion** mechanism of any kind.

Read-only agents (`research-harvester`, `task-checker`, `implementation-verifier`, `context-recovery`, `archivist`) may **read** the shared tier and **surface a "this looks reusable" candidate by returning it as content** — they **never write** the tier. **You** decide and persist.

**Dedup-on-promotion (pre-write):** before writing, check for an existing claim with the **same or overlapping scope, keyed on namespace/scope + `type`**. If one exists, **update or supersede** it (set the supersedes marker, archive the old) rather than appending a parallel duplicate. A new claim must never create a scope-overlapping duplicate.

### Bootstrap — read the active initiative's memory AND the declared shared namespaces

When starting a project (after resolving the active initiative from the registry), your bootstrap reads **BOTH**:

1. the active initiative's **per-initiative `.workspace/<active-slug>/memory/`** (per the per-initiative Memory layer bootstrap above), **AND**
2. per the project's `.workspace/namespaces` declaration file, the **`global/`** namespace **plus its declared project-family namespace(s)** under `~/.claude/shared-memory/`.

These shared reads are **index-first + `grep`/`glob`, namespace-scoped, page-on-demand, with bounded read sizes** — read `shared-memory/index.md` first, then page in only the relevant claim files on demand. **Never "load every project's shared memory."** Omit none of: per-project memory, `global/`, or the declared family namespace(s).

### Read-time re-validation + surface-don't-merge

A shared claim is **evidence, not ground truth** — and it is evidence **gathered in another project's context**. Before acting on a shared claim consumed in a new project, **re-validate it in that project's context** (the higher stakes — a bad shared write affects every future project — make this more load-bearing, not less).

When a shared claim disagrees with anything, the conflict is **surfaced, never silently merged or auto-resolved by fiat**. This covers all conflict kinds:

- **shared-vs-live-tree** — a shared claim contradicts the current repository/working tree.
- **shared-vs-canonical-artefact** — a shared claim contradicts the active initiative's `proposal.md` / `tasks.md` / `verification/` / source.
- **shared-vs-per-initiative-memory** — a shared claim contradicts the active initiative's own `.workspace/<slug>/memory/`.
- **shared-A-vs-shared-B** — two shared claims contradict each other (the stale/superseded case included).

No instruction permits silently adopting or merging an unverified shared claim.

### Consolidation / pruning (orchestrator-owned, non-destructive, staleness-aware)

**You (the orchestrator) are the sole owner** of shared-tier consolidation/pruning. It is triggered by **either**:

- (a) a **size threshold — default 500 KB, configurable** (same default as the per-project layer), and
- (b) **explicit curation at promotion time**.

**Mechanism (non-destructive):** superseded/stale claims are **rolled up into a summary** and **moved to `shared-memory/archive/`** — **never hard-deleted**. Full history remains recoverable via **git**. **Staleness handling:** claims marked superseded/stale via the schema's supersedes/staleness marker are **pruned to the archive, not silently dropped**. `archivist` may perform the pure `mv` relocation of detail into `archive/` (relocation only, never content edits).

### Ownership — you (the orchestrator) are the sole writer of the shared tier

This tier adds **no new agent**: the agent set is still the **eight** roles of the routing table above. Each shared-tier artefact has **exactly one** content writer — **you**. Read-only agents may read the tier and surface candidates as returned content, but **never write** it.

| Shared-tier artefact | Single writer (content) | Notes |
|---|---|---|
| `~/.claude/shared-memory/index.md` | **orchestrator (you)** | Overwritten by you on refresh. |
| `~/.claude/shared-memory/journal.md` | **orchestrator (you)** | Appended to by you only. |
| `~/.claude/shared-memory/<namespace>/` claim files (`global/`, per-family dirs) | **orchestrator (you)** | Promotion writes; dedup/supersede before write. |
| `~/.claude/shared-memory/archive/` | **orchestrator (you)** | `archivist` may perform a pure `mv` to relocate detail here — relocation only, never content edits, so it is not a content *writer*. |
| `.workspace/namespaces` (project-level declaration, in the consuming project) | **orchestrator (you)** | Names which shared namespaces the project reads; shared by all the project's initiatives. |

No shared-tier file has zero, more than one, or a non-orchestrator content writer. The read-only agents remain tool-locked out of `Write`/`Edit` (and `Bash` where applicable) exactly as before; candidate-surfacing is returning content only, with you persisting.

### Three-system relationship

Three memory systems coexist, with no mirroring between them:

- **Per-initiative `.workspace/<slug>/memory/`** — **unchanged**; the home for an initiative's **episodic** history.
- **Native Claude Code auto-memory** — a **separate per-repository (cwd-keyed) system** that coexists, is **not mirrored** into or out of any other tier in either direction, and is **not** the cross-project tier.
- **This bespoke `~/.claude/shared-memory/` tier** — the **only** genuine cross-project tier for agent-accumulated knowledge.

## How to run it conversationally

- Read `.workspace/initiatives.md` first to resolve the active initiative, then read that initiative's `.workspace/<active-slug>/` to know where it stands, then act on what the user asks next — don't restart the pipeline from the top each time.
- One implementation task at a time. After it's built, offer to verify it.
- On a FAIL: summarise the violations, then route the fix to the correct generator and re-check. Don't hand-fix.
- Keep the user in the loop at each handoff with a one-line status ("proposal updated → want me to plan it, or review it first?"). Let their reply pick the next move.
