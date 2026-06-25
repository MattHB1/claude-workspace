# Ideation Spiral

The ideation spiral is the front-of-pipeline phase that turns a vague idea or rough problem
statement into a crisp, testable concept and a per-hypothesis test plan. It runs **before**
research or proposal-writing — for the moments when you know you want to build *something* but
have not yet decided *what*. The output is a durable `ideation.md` artefact that feeds the rest
of the workspace pipeline or stands alone as a portable markdown document.

---

## How to use it

### Trigger phrases

Say any of the following in your workspace conversation to invoke the spiral inline:

- "ideate on this"
- "spiral this"
- "let's refine the idea"
- "help me figure out what to build"
- "I have a rough idea, not sure what it should be yet"
- "explore this before we spec it"

These sit **before** the existing pipeline verbs. If you say "spec it" or "research this" with a
concept that is already crisp, those verbs still route normally — the spiral never pre-empts an
explicit "research/spec it" instruction. If the idea is visibly vague, the orchestrator may
*offer* the spiral first, but you decide.

The spiral runs against the **active initiative** and writes to its `.workspace/<active-slug>/`
folder. It does not create or switch initiatives — create the initiative first, then spiral
within it.

### What a session looks like

A spiral session moves through four ordered phases:

**Phase 1 — Frame (Socratic).** The orchestrator surfaces the real problem under your stated
idea: the actual need, what would make a concept valuable, which constraints are worth relaxing,
and what has already been tried. It confirms the framing in one line before moving on.

**Phase 2 — Diverge.** Candidate directions are generated as *hypotheses* ("if we do X, then Y,
because Z"), spanning the obvious, the inverted, approaches borrowed from adjacent fields,
constraint-flipped angles, and combinations. No direction is killed in this phase.

**Phase 3 — Challenge (adversarial pass).** The set is attacked to enforce structural
completeness: anchoring (multiple directions that are really one in disguise), missing classes of
approach, fake novelty, and the unexamined obvious-best. This phase is internal to the skill —
it is not a dispatched agent.

**Phase 4 — Converge / re-loop.** With your reactions, the space narrows, surviving hypotheses
sharpen, and a cheap falsifying test is attached to each. If the convergence gate (below) is not
yet met, the loop returns to Phase 2/3 for a tighter pass. Each loop is expected to be smaller
than the last.

### How convergence is reached

Convergence is user-declared but **blocked** until the objective structural-completeness gate
passes. You declare "done" or "lock it in" — but that declaration only takes effect when ALL
four conditions hold:

- **(a) Hypotheses are MECE** — mutually exclusive (no two directions are the same restated) and
  collectively exhaustive at the chosen frame (every missing class of approach has been named and
  either filled or explicitly ruled out).
- **(b) Every hypothesis is falsifiable with a stated test** — each carries at least one cheap,
  concrete test that could disconfirm it. "Test: TBD" fails the gate.
- **(c) The converged concept is crisp and testable** — stated in one or two sentences with no
  unresolved either/or, expressed such that `proposal-writer` could derive objectively checkable
  acceptance criteria from it.
- **(d) Rejected branches are recorded with a reason** — each explored-then-dropped direction
  carries a one-line rejection rationale; divergence is not silently discarded.

"Feels done" with the gate unmet does not converge. The gate is the floor; your judgment sits on
top of it.

---

## Capabilities and boundaries

### What the spiral is for

The spiral solves the gap that exists **before** research or proposal-writing: deciding *what* to
build before *how* to build it. It is the right tool when the concept itself is not yet decided
— when you have a vague idea, a rough problem statement, or a space you want to explore before
committing the pipeline to it.

### What it produces

The spiral produces one `ideation.md` artefact per session, containing:

- A **crisp, testable concept** — one or two sentences with no unresolved either/or.
- **MECE falsifiable hypotheses** — the full set of explored directions, each as a falsifiable
  statement, marked MECE-checked.
- A **per-hypothesis test plan** — for each surviving hypothesis, at least one cheap, concrete
  test that could disconfirm it.
- **Rejected branches with reasons** — every explored-then-dropped direction and why it was
  dropped.

### What it is NOT

- **NOT research.** The spiral surfaces the questions worth investigating; `research-harvester`
  answers them.
- **NOT proposal-writing.** The spiral produces a crisp concept; `proposal-writer` turns that
  concept into a proposal with acceptance criteria.
- **NOT implementation.** No code is planned, built, or verified here.

The spiral adds no new agent and introduces no row in the orchestrator's routing table.

---

## Threading the result downstream

### `ideation.md` structure (five minimum sections)

The orchestrator writes `ideation.md` to `.workspace/<active-slug>/ideation.md` — per-initiative,
alongside `proposal.md` and `tasks.md`. The skill never self-writes it. The five required
sections are:

1. **Finalised concept** — the crisp, testable concept statement (satisfies gate condition (c)).
2. **Hypotheses / branches explored** — each as a falsifiable statement, marked MECE-checked
   (satisfies gate conditions (a) and (b)).
3. **Per-hypothesis test plan** — for each surviving hypothesis, at least one cheap, concrete
   test that could disconfirm it.
4. **Rejected branches + reasons** — explored-then-dropped directions with a one-line rationale
   (satisfies gate condition (d)).
5. **Provenance line** — who/when, and a pointer to the originating idea (e.g. `purpose.md`),
   matching the house artefact convention.

### In-workspace: feeding the pipeline

`ideation.md` is the **front-of-pipeline input** the existing pipeline previously lacked. It
precedes and supplements the raw idea — it does not replace it; it upgrades it from vague to
crisp. **Reaching convergence never auto-dispatches a downstream agent.** The next step is
surfaced to you as a one-line handoff; you choose what comes next.

Two paths, neither forced:

- **`proposal-writer` directly** — when the concept is crisp enough to write acceptance criteria
  without additional research. Hand the orchestrator your `ideation.md` and say "spec it."
- **`research-harvester` first, then `proposal-writer`** — when the open hypotheses benefit from
  prior art or domain knowledge before committing to a proposal. The per-hypothesis test plan in
  `ideation.md` is exactly the set of decided questions for research to investigate.

Research is **optional** on this seam — a routing choice you make, never a mandatory step.

### External: portable export

`ideation.md` is a self-describing, portable markdown artefact. You can reuse or export it
outside the workspace into any tool or workflow:

- **Paste the finalised concept + test plan** into an external issue tracker, product brief, or
  design doc to give downstream contributors a crisp starting point.
- **Drop it into another LLM conversation** as a structured brief — the five-section format
  carries its own context and requires no explanation.
- **Archive it as a decision record** alongside a codebase, RFC, or ADR process — the rejected
  branches + reasons section documents why alternatives were not chosen.

The five-section structure makes `ideation.md` a documented, first-class input anywhere — not
only inside the workspace pipeline.
