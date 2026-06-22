# Cross-project memory tier — full rules

This file is loaded on demand by the orchestrator (see pointer in `SKILL.md`). It defines the full rule set for the `~/.claude/shared-memory/` tier.

---

## Overview

The per-initiative Memory layer in SKILL.md is episodic and per-initiative only — by construction it holds one initiative's history and references no other project. But some knowledge is **durable and recurring** across separate projects: stable facts about entities you work with, reusable how-to lessons, and durable preferences/conventions. The **cross-project memory tier** is a single, above-the-project home for exactly that knowledge, so it can be reused when you start a new project instead of being independently re-derived and duplicated.

This tier is a **bespoke flat-file** home — the same proven mechanics as the per-project layer, one level up. It is **explicitly not** native Claude Code auto-memory, and it references **no** database, vector/graph/embedding store, daemon, server, scheduler, or external service. It is **not auto-loaded**: **you (the orchestrator) read it explicitly** during bootstrap; nothing pulls it in for you.

## Layout

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

## Journal + index schemas (same mechanics as the per-project layer)

- **Shared journal (`shared-memory/journal.md`)** — **append-only** markdown with per-entry **YAML frontmatter**: a timestamped, attributed, **trust-marked** log of promotion events and shared decisions. Entries are **only appended** — never edited or deleted in place (consolidation rolls up into a *new* summary entry and moves detail to `archive/`; it never rewrites history).
- **Shared index (`shared-memory/index.md`)** — a small, machine-maintained **structured** file (YAML/frontmatter-list, JSON-like form) that you **overwrite** (not append) on each refresh. It is the state-of-world + table-of-contents: it stores **pointers (paths/anchors) and short summaries only — never the authoritative payload**. It is an allowed plain local structured text file, **not** a database, vector store, graph store, or similarity/embedding index.
  - **Rebuild from sources:** the index holds no unique authoritative data, so it is fully **regenerable** — delete and rebuild it from `journal.md` plus the namespace claim files. Regenerating loses nothing.

**Retrieval is index-first + `grep`/`glob`, keyword-only** over the files — never embeddings, vectors, similarity ranking, or semantic search. No shared-tier mechanism uses any such technique. Across unrelated projects the **keyword miss-rate is higher** than within one project; that higher miss-rate is an **accepted tradeoff** for determinism, auditability, and zero infra.

## Namespace taxonomy + per-project declaration

Shared knowledge is organised into a **two-level namespace taxonomy**: exactly one **`global/`** namespace (universal facts, preferences, and lessons that hold everywhere) plus **one namespace dir per project family** (e.g. `acme/`). There is **no tech-stack dimension, no per-org dimension, and no per-repo tagging dimension in this version** (one may be added later). Namespace dirs are the relevance filter.

Each project declares **which** shared namespaces it reads via a small **project-level declaration file at its `.workspace/` root** — `.workspace/namespaces` (filename non-load-bearing) — holding a parseable list of namespace names (always `global/`, plus zero or more project-family namespaces). This declaration is the project's cross-project membership and is **shared by all of the project's initiatives** — it is **not** duplicated per initiative (there is no `.workspace/<slug>/.../namespaces`), because cross-project membership is a property of the project/family, not of an individual initiative. This convention is **defined, not necessarily pre-created** — create it on demand when a project first reads the shared tier. Retrieval over the declared namespaces is index-first + `grep`/`glob`, keyword-only; the accepted higher miss-rate above applies.

## Shared-claim schema (type + provenance/scoping — all mandatory)

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

## Promotion protocol (manual / explicit / orchestrator-owned)

Knowledge enters the shared tier **only by an explicit promotion decision made by you, the orchestrator** — on the user's instruction or on a read-only agent's surfaced candidate. There is **no automatic / on-recurrence promotion** mechanism of any kind.

Read-only agents (`research-harvester`, `task-checker`, `implementation-verifier`, `context-recovery`, `archivist`) may **read** the shared tier and **surface a "this looks reusable" candidate by returning it as content** — they **never write** the tier. **You** decide and persist.

**Dedup-on-promotion (pre-write):** before writing, check for an existing claim with the **same or overlapping scope, keyed on namespace/scope + `type`**. If one exists, **update or supersede** it (set the supersedes marker, archive the old) rather than appending a parallel duplicate. A new claim must never create a scope-overlapping duplicate.

## Bootstrap — read the active initiative's memory AND the declared shared namespaces

When starting a project (after resolving the active initiative from the registry), your bootstrap reads **BOTH**:

1. the active initiative's **per-initiative `.workspace/<active-slug>/memory/`** (per the per-initiative Memory layer bootstrap in SKILL.md), **AND**
2. per the project's `.workspace/namespaces` declaration file, the **`global/`** namespace **plus its declared project-family namespace(s)** under `~/.claude/shared-memory/`.

These shared reads are **index-first + `grep`/`glob`, namespace-scoped, page-on-demand, with bounded read sizes** — read `shared-memory/index.md` first, then page in only the relevant claim files on demand. **Never "load every project's shared memory."** Omit none of: per-project memory, `global/`, or the declared family namespace(s).

## Read-time re-validation + surface-don't-merge

A shared claim is **evidence, not ground truth** — and it is evidence **gathered in another project's context**. Before acting on a shared claim consumed in a new project, **re-validate it in that project's context** (the higher stakes — a bad shared write affects every future project — make this more load-bearing, not less).

When a shared claim disagrees with anything, the conflict is **surfaced, never silently merged or auto-resolved by fiat**. This covers all conflict kinds:

- **shared-vs-live-tree** — a shared claim contradicts the current repository/working tree.
- **shared-vs-canonical-artefact** — a shared claim contradicts the active initiative's `proposal.md` / `tasks.md` / `verification/` / source.
- **shared-vs-per-initiative-memory** — a shared claim contradicts the active initiative's own `.workspace/<slug>/memory/`.
- **shared-A-vs-shared-B** — two shared claims contradict each other (the stale/superseded case included).

No instruction permits silently adopting or merging an unverified shared claim.

## Consolidation / pruning (orchestrator-owned, non-destructive, staleness-aware)

**You (the orchestrator) are the sole owner** of shared-tier consolidation/pruning. It is triggered by **either**:

- (a) a **size threshold — default 500 KB, configurable** (same default as the per-project layer), and
- (b) **explicit curation at promotion time**.

**Mechanism (non-destructive):** superseded/stale claims are **rolled up into a summary** and **moved to `shared-memory/archive/`** — **never hard-deleted**. Full history remains recoverable via **git**. **Staleness handling:** claims marked superseded/stale via the schema's supersedes/staleness marker are **pruned to the archive, not silently dropped**. `archivist` may perform the pure `mv` relocation of detail into `archive/` (relocation only, never content edits).

## Ownership — you (the orchestrator) are the sole writer of the shared tier

This tier adds **no new agent**: the agent set is still the **eight** roles of the routing table in SKILL.md. Each shared-tier artefact has **exactly one** content writer — **you**. Read-only agents may read the tier and surface candidates as returned content, but **never write** it.

| Shared-tier artefact | Single writer (content) | Notes |
|---|---|---|
| `~/.claude/shared-memory/index.md` | **orchestrator (you)** | Overwritten by you on refresh. |
| `~/.claude/shared-memory/journal.md` | **orchestrator (you)** | Appended to by you only. |
| `~/.claude/shared-memory/<namespace>/` claim files (`global/`, per-family dirs) | **orchestrator (you)** | Promotion writes; dedup/supersede before write. |
| `~/.claude/shared-memory/archive/` | **orchestrator (you)** | `archivist` may perform a pure `mv` to relocate detail here — relocation only, never content edits, so it is not a content *writer*. |
| `.workspace/namespaces` (project-level declaration, in the consuming project) | **orchestrator (you)** | Names which shared namespaces the project reads; shared by all the project's initiatives. |

No shared-tier file has zero, more than one, or a non-orchestrator content writer. The read-only agents remain tool-locked out of `Write`/`Edit` (and `Bash` where applicable) exactly as before; candidate-surfacing is returning content only, with you persisting.

## Three-system relationship

Three memory systems coexist, with no mirroring between them:

- **Per-initiative `.workspace/<slug>/memory/`** — **unchanged**; the home for an initiative's **episodic** history.
- **Native Claude Code auto-memory** — a **separate per-repository (cwd-keyed) system** that coexists, is **not mirrored** into or out of any other tier in either direction, and is **not** the cross-project tier.
- **This bespoke `~/.claude/shared-memory/` tier** — the **only** genuine cross-project tier for agent-accumulated knowledge.
