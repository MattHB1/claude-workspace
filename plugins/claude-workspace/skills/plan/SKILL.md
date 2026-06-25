---
name: plan
description: Turn a goal, problem, or vague intent into a stress-tested, actionable plan. Use when the user wants to plan an initiative, project, feature, decision, migration, or any effort — especially when the objective is fuzzy, the path is uncertain, or constraints compete. Runs a Socratic intake to pin down the real objective and constraints, drafts a structured plan, then adversarially pre-mortems it before finalizing. This is a thinking process, not a template-filler.
---

# Plan

A four-phase process for turning intent into a plan you can actually trust. Work through the phases
in order. **Do not skip Phase 1, and do not skip Phase 3** — those two are what separate this from a
generic to-do list. Move briskly; this is a working session, not a form.

The deliverable is a written plan. But the value is in the questioning and the attack that happen
before it — a plan that hasn't been interrogated and stress-tested is just a guess in list form.

## Phase 1 — Understand (Socratic)

Before proposing anything, find the *real* objective and the constraints. The first framing the user
gives is rarely the one worth planning against. Ask sharp, specific questions — batch them, don't
interrogate one at a time — until you can state, in one sentence, what success actually looks like.

Probe for:
- **The real goal behind the stated goal.** Why this, why now? What changes if it works? What's the
  thing they actually care about that this is a proxy for?
- **Definition of done.** What observable outcome means "finished"? How will they know?
- **Hard constraints vs. preferences.** Deadline, budget, people, tech, politics. Which are immovable?
- **What's already been tried or decided**, and what's deliberately out of scope.
- **The unknowns.** What don't they know yet that the plan depends on? These become early steps.

Reflect the goal back in your own words and get confirmation before moving on. If the goal is
incoherent or rests on a shaky assumption, say so now — don't plan around a flaw.

## Phase 2 — Generate (structured)

Draft the plan. Structure it; don't ramble. Adapt the shape to the task, but cover:

- **Objective** — the one-sentence success definition from Phase 1.
- **Approach** — the strategy in a few lines. If there are genuinely different strategies, name the
  alternatives and say why you chose this one (don't bury the road not taken).
- **Phases / milestones** — sequenced, with clear dependencies (what must finish before what).
- **Concrete next actions** — specific enough to start on Monday. No "research the space" filler.
- **Risks & unknowns** — carried from Phase 1, each with a mitigation or a probe to resolve it.
- **Open questions** — what still needs a decision, and from whom.

Prefer the smallest plan that reaches the goal. Sequence to de-risk early: front-load the steps that
resolve the biggest unknowns, so a wrong assumption surfaces cheaply rather than late.

## Phase 3 — Stress-test (adversarial pre-mortem)

Now turn on the plan and try to break it. Be a genuine adversary, not a polite reviewer. Imagine it's
the deadline and the plan **failed** — write the story of how. Specifically attack:

- **Hidden assumptions.** What is the plan quietly assuming is true, available, or easy? What if it isn't?
- **The critical path.** Which single step, if it slips or fails, sinks everything? Is it de-risked early?
- **Optimism.** Where are the estimates fantasy? What's the step that always takes 3× longer?
- **Dependencies on others.** Where does it rely on someone else acting? What if they don't?
- **The thing not in the plan.** What real work is missing because it was unglamorous or unnoticed?

Surface the strongest 3–5 objections plainly. For each, either fix the plan or consciously accept the
risk with a reason. Don't defend the plan reflexively — if an objection lands, the plan changes.

## Phase 4 — Refine & deliver

Revise the plan against the objections that landed. Then deliver the final version. Offer to save it
to a markdown file (suggest a sensible path/name in the current working directory, e.g.
`plan-<slug>.md`). Keep the final artifact tight — the plan, the key risks, the next actions. The
abandoned ideas and the full critique don't need to ship unless the user wants the audit trail.
