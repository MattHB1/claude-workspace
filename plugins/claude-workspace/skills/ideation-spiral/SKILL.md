---
name: ideation-spiral
description: Turn a vague idea or rough problem statement into a crisp, testable concept and a per-hypothesis test plan, captured as a durable ideation.md artefact. Use before research or proposal-writing, when the concept itself is not yet decided — "ideate on this", "spiral this", "let's refine the idea", "help me figure out what to build", "I have a rough idea, not sure what it should be yet", "explore this before we spec it". Runs an iterative Frame → Diverge → Challenge → Converge loop with an objective structural-completeness gate that blocks premature convergence. Self-contained: no dependency on other loose local skills.
---

# Ideation Spiral

A bounded, phased co-development loop that turns a vague idea into a crisp, testable concept and a
per-hypothesis test plan, captured in a durable `ideation.md` artefact. The loop mirrors the
`ideate`/`decide` discipline — Frame → Diverge → Challenge → Converge/Refine-loop — with the adversarial
challenge phase positioned distinctly between divergence and convergence. It is the front-of-pipeline
phase that prepares an idea for `proposal-writer` or `research-harvester`; it is NOT research and NOT
proposal-writing and NOT implementation.

**Self-containment (v1):** This skill internalises the Frame/Diverge/Challenge/Converge methodology in
its own text. It does NOT invoke or depend on the loose local `ideate`, `decide`, `plan`, or `reflect`
skills at runtime. A fresh plugin install can run this skill end-to-end with no loose local skills
present.

## Right-sizing the process (necessity invariant applied to the spiral itself)

The same necessity invariant that governs every artefact this workspace produces governs the spiral's own generative process: the smallest, simplest process that fully satisfies the real need. Three rules, applied to every run:

- **Divergence proportional to residual uncertainty.** How wide to diverge is set by how open/uncertain the problem actually is. A near-crisp idea earns a shallow pass through Phase 2; only a genuinely vague one earns wide divergence. The six-lens pass in Phase 2 is a ceiling, not a floor — use as much of it as residual uncertainty justifies, no more.
- **User short-circuit.** If the user states the answer, the invariant, or the concept directly, converge to it immediately and test it — do not re-mandate breadth or cycle back through earlier phases. The spiral helps the user reach a crisp concept; if they are already there, the job is to confirm it, not reopen it.
- **Conditional completeness gate.** The structural-completeness conditions (a)–(d) are the gate, but the gate passes when there is enough confidence given the residual uncertainty — not when maximal exploration is always complete. A near-crisp problem can satisfy the gate with a proportionately shallower pass than a genuinely open one.

Low cognitive load throughout: few options at a time, plain language, short turns. The process should feel like help, not homework.

## Triggers & Routing

**Invocation triggers** (these phrases invoke the spiral inline in the orchestrator's conversation):

- "ideate on this"
- "spiral this"
- "let's refine the idea"
- "help me figure out what to build"
- "I have a rough idea, not sure what it should be yet"
- "explore this before we spec it"

**Routing precedence — the spiral sits BEFORE the existing verbs:**

- "research this / look into…" → `research-harvester` (concept already chosen — unchanged)
- "spec it / write the proposal / define the problem" → `proposal-writer` (concept already crisp — unchanged)
- "plan it", "build task N", "verify it" → later pipeline phases (unchanged)

The spiral sits **before** "research this" and "spec it." When a user says "spec it" but the idea is
visibly vague, you may *offer* the spiral first — but routing precedence is unchanged and the user
decides. The spiral **never pre-empts or overrides** an explicit "research/spec it" instruction.

**Initiative scoping:** The spiral runs against the ACTIVE initiative and writes to its
`.workspace/<active-slug>/ideation.md`. It does **not create or switch initiatives** — those remain the
orchestrator's existing registry verbs. A user who wants a new initiative for an idea creates one first,
then spirals within it.

## Phase 1 — Frame (Socratic)

Before diverging, surface the real problem under the stated idea. Ask sharp, batched questions:

- **The real problem or opportunity.** What is the actual need underneath the stated idea? The brief is
  often a solution in disguise — find the need underneath it.
- **What would make a concept valuable here.** This names the filter that Phase 4 applies; capture it
  now.
- **Hard constraints and which to suspend.** Note the real limits, but identify which constraints are
  worth deliberately relaxing during divergence.
- **What has already been tried or considered.** Push past it rather than re-surfacing it.

Confirm the framing in one line before diverging.

## Phase 2 — Diverge (generate hypotheses / branches)

Generate a wide, varied set of candidate directions framed as **hypotheses**: "if we do X, then Y,
because Z." Defer all judgment — no direction gets killed in this phase. Force range across genuinely
different lenses:

- **The obvious ones** — get them out so you stop circling them.
- **Inverted** — what would guarantee the opposite outcome? Invert it into a direction.
- **Borrowed from an adjacent field** — how has a structurally similar problem been solved elsewhere?
- **Constraint-flipped** — what if the binding constraint were removed or reversed?
- **Combined** — fuse two earlier directions into a third.
- **The deliberately bold** — at least a couple that feel too bold. They are seeds, not commitments.

Aim for quantity and spread. Group loosely as you go so the landscape is visible, but do not prune yet.

## Phase 3 — Challenge (in-skill adversarial pass)

Attack the **set** — not to kill directions but to enforce structural completeness before converging.
This is the adversarial pass; it is internal to the skill, not a dispatched agent:

- **Anchoring.** Are most of these variations of a single underlying direction wearing different names?
  Name the underlying attractor.
- **Missing classes of approach.** What whole class of direction is not represented at all? Name it and
  generate into the gap.
- **Fake novelty.** Which "hypotheses" are just the status quo restated differently? Flag them.
- **The unexamined obvious-best.** The direction that feels like the clear winner — why might it be
  wrong, or why has nobody done it already? Pressure it.

This phase enforces the structural-completeness conditions that gate convergence (INV5, below). Re-loop
into Phase 2 to fill any gaps surfaced here before offering convergence.

## Phase 4 — Converge / Refine-loop

With the user's reactions, narrow the space, sharpen surviving hypotheses, and attach a cheap falsifying
test to each. Then check the **convergence gate**:

### Convergence Gate (must pass before convergence is offered)

Convergence is **blocked** until ALL four structural-completeness conditions hold. Evaluate them against residual uncertainty: a problem with low residual uncertainty can satisfy these conditions with a proportionately shallower pass; a genuinely open problem requires the full pass. The skill may only offer convergence — and the user's declaration of "done" may only take effect — when every condition below is satisfied:

- **(a) Hypotheses are MECE** — the explored hypotheses / idea-branches are mutually exclusive (no two
  are the same direction restated) and collectively exhaustive at the chosen frame (the challenge phase
  has named, and either filled or explicitly ruled out, each missing class of approach).
- **(b) Every hypothesis is falsifiable with a stated test** — each hypothesis carries at least one
  concrete, cheap test that could disconfirm it. "Untestable" or "test: TBD" fails the gate.
- **(c) The converged concept is crisp and testable** — the finalised concept is stated in one or two
  sentences with no unresolved either/or, and is expressed such that `proposal-writer` could derive
  objectively checkable acceptance criteria from it.
- **(d) Rejected branches are recorded with a reason** — divergence is not silently discarded; each
  explored-then-dropped branch has a one-line rejection rationale.

**If the gate is NOT met:** re-loop — return to Phase 2/3 for another, tighter pass. Each loop is
expected to be smaller than the last (a convergent spiral, not a divergent one).

**If the gate IS met:** offer convergence. The user declares "done" / "lock it in" to complete
convergence. On that declaration: state the crisp concept, the hypotheses explored (MECE-checked), the
per-hypothesis test plan, and the rejected branches. This content becomes the body of `ideation.md`.

### Bounded loop note

A single conversation is the v1 normal. If a session is interrupted, a paused spiral resumes by
re-reading the persisted `.workspace/<active-slug>/ideation.md` (and the initiative `journal.md`) — no
dedicated multi-session state machinery is needed. Multi-session resume falls out for free from the
persisted artefact.

## Output Contract: `ideation.md`

**The orchestrator persists the converged output** to `.workspace/<active-slug>/ideation.md`. The skill
produces structured content inline; it does not self-write the file. The orchestrator is the sole writer
of `ideation.md`, consistent with its existing artefact-saving role.

**Home:** `.workspace/<active-slug>/ideation.md` — per-initiative, alongside `proposal.md` and
`tasks.md`. Never at the `.workspace/` root, never duplicated per project.

**Five minimum sections (all required):**

1. **Finalised concept** — the crisp, testable concept statement (one or two sentences; no unresolved
   either/or; satisfies convergence gate condition (c)).
2. **Hypotheses / branches explored** — each as a falsifiable statement, marked MECE-checked (satisfies
   convergence gate conditions (a) and (b)).
3. **Per-hypothesis test plan** — for each surviving hypothesis, at least one cheap, concrete test that
   could disconfirm it.
4. **Rejected branches + reasons** — explored-then-dropped directions with a one-line rationale for each
   (satisfies convergence gate condition (d)).
5. **Provenance line** — who/when, and a pointer to the originating idea (e.g. `purpose.md`), matching
   the house artefact convention.

All artefact and memory access prescribed by this skill is by explicit path, `glob`, or `grep` — no
embeddings, vectors, similarity ranking, or semantic search.

## Downstream Seam & Handoff

`ideation.md` is the **front-of-pipeline input** the existing pipeline previously lacked. It **precedes
and supplements** the raw idea — it does not replace the raw idea; it upgrades it from vague to crisp.

**Reaching convergence never auto-dispatches a downstream agent.** The next step is surfaced to the user
as a one-line handoff, and the user chooses. The two options, neither forced:

- Feed `ideation.md` into **`proposal-writer`** directly (concept is crisp enough; no research phase
  needed).
- Feed `ideation.md` into **`research-harvester`** first (to investigate open hypotheses), then into
  `proposal-writer`. Research is **optional** on this seam — a routing choice, never mandatory.

**Portable export.** `ideation.md` is a self-describing, portable markdown artefact. Beyond the
in-workspace seam, a user may reuse or export it into other tools or workflows outside the workspace
(e.g. paste the finalised concept and test plan into an external tracker, brief, or doc/LLM). Its
five-section structure makes it a documented, first-class input elsewhere.

## Scope Boundary

The spiral does exactly one job: vague idea → crisp, testable concept + per-hypothesis test plan,
captured in `ideation.md`.

- It is **NOT research** — it surfaces questions; `research-harvester` answers them.
- It is **NOT proposal-writing** — it does not write acceptance criteria; that is `proposal-writer`.
- It is **NOT implementation** — no code is planned, built, or verified here.
- It adds **no new agent** and introduces no row in the routing table.
