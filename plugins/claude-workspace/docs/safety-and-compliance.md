# Safety and compliance

Claude Workspace does real compliance work. It is built to **block** you when a
shipped output would leak something private, when content would land in a place
it should not be distributed, or when a piece of work cannot be shown to satisfy
its stated acceptance conditions. This is a **feature**, not a malfunction: the
gates exist so that the things you publish, share, or call "done" are exactly the
things you meant to publish, share, or call done.

This page explains the four kinds of safety check you will meet so that being
stopped by one is expected rather than surprising:

- **PII gates** - zero-match greps for private identifiers over outputs before
  they ship.
- **Distribution gates** - what may and may not be published, keeping personal
  and build artefacts out of distributable repos.
- **Repo-wide greps** - the deterministic search mechanism the gates run on.
- **Acceptance-criteria ("SAC-style") checks** - verifier-runnable conditions
  that must pass before something is "done".

These align with the system's broader posture: provenance is tracked, scope is
recorded, and conflicts are **surfaced rather than silently merged** (see
[design-principles.md](design-principles.md) and [memory.md](memory.md)).

See also: [why-it-refuses.md](why-it-refuses.md) for the conceptual reasons the
system declines work, [troubleshooting.md](troubleshooting.md) for what to do
when a gate stops you, and [limitations.md](limitations.md) for what these checks
deliberately do not promise.

---

## Why gates exist (expect to be blocked)

The whole point of the workspace is non-drifting, auditable work. A check that
**only detects** and refuses to proceed is more trustworthy than one that quietly
"fixes" a problem behind your back. So when a gate fails, the system stops and
reports the violation rather than guessing a repair. You are expected to be
blocked sometimes - that is the gate doing its job. The fix is to correct the
underlying content and re-run the gate, not to bypass it.

A useful framing: a gate is a deterministic, repeatable question with a
pass/fail answer. If the answer is "fail", the work is not done. None of these
gates require a network service, a scanner daemon, or any hosted infrastructure
- they run as plain, re-runnable searches and condition checks over local files.

---

## PII gates (zero-match greps over outputs before shipping)

A **PII gate** is a check that scans a set of outputs for private identifiers and
requires **zero matches** before the content is allowed to ship. "Private
identifier" here means the kinds of strings that should never leak into shared or
published material, for example:

- internal or personal project and service names,
- personal email addresses,
- absolute local home-directory paths that identify a specific machine or user.

The gate is expressed as a deterministic search: the agreed pattern is run over
the candidate files, and the only acceptable result is **no hits**. A single hit
is a fail, and the content does not ship until the offending string is removed or
replaced with a safe, generic equivalent.

How to think about it in practice:

- The pattern is decided up front for the work in hand (it is specific to what
  counts as private for that material), then run unchanged so the result is
  reproducible.
- Genuinely public identifiers - for example a public install handle that must
  appear in real install commands - can be defined as an explicit, documented
  exception, so they are deliberately **not** part of the forbidden pattern.
- The gate runs over the **outputs** (the files that will actually be shipped),
  not over your private scratch or working notes, which are not distributed.

The result is that shared material is scrubbed of private strings by a check
anyone can re-run, rather than by someone remembering to look.

---

## Distribution gates (what may and may not be published)

A **distribution gate** governs **what is allowed to leave** - what may be
published into a distributable repository and what must be kept out. The
distinction it enforces is between content that is meant to be shared and content
that is personal, machine-local, or a build artefact and therefore must not be.

Two ideas drive it:

- **Shared, not secret.** Material that is distributed is shared deliberately and
  with known recipients; it is governed by access on the repository itself, not by
  hoping a secret stays hidden. Anything that genuinely must stay secret does not
  belong in distributable content in the first place.
- **Keep personal and build artefacts out.** Per-project working state, personal
  notes, local configuration, generated or build outputs, and anything tied to a
  specific machine are kept out of the distributable repo. They live in their own,
  non-distributed homes (for example per-initiative working state, or
  machine-local memory) and are not mirrored into shared material.

In practice the distribution gate and the PII gate reinforce each other: the PII
gate ensures no private *string* rides along inside otherwise-shippable content,
and the distribution gate ensures whole *files* that should not travel are not
included in what ships. A failure of either means the content does not go out
until corrected.

---

## Repo-wide greps (the deterministic search the gates run on)

The gates above are implemented with **repo-wide greps** - plain, deterministic
keyword/pattern searches across the relevant files. This is the same
determinism-first philosophy the rest of the system uses: retrieval and checking
are done by **explicit path, filename/directory convention, and `grep`/`glob`**,
never by similarity ranking, embeddings, or semantic search.

Why greps specifically:

- **Reproducible.** The same pattern over the same files gives the same answer
  every time, on any machine, with no model in the loop. A gate result is
  therefore auditable and can be re-run by anyone.
- **Transparent.** You can read the exact pattern and the exact file set, so it
  is clear *what* is being checked and *why* a hit failed.
- **Zero infrastructure.** A grep needs no server, index build, or background
  service.

The tradeoff is honest: a keyword search can only catch what its pattern
describes. A grep gate is a strong, mechanical floor against known categories of
problem (the named private strings, the disallowed files), **not** a guarantee
that nothing unanticipated slipped through. Keep this expectation in mind - the
gates raise the floor; they do not promise completeness. See
[limitations.md](limitations.md).

---

## Acceptance-criteria ("SAC-style") checks (must pass before "done")

A **SAC-style check** is a **specific, verifier-runnable acceptance condition**
that must pass before a piece of work is considered done. SAC stands for
**specific acceptance criteria**: rather than declaring success by assertion, the
system ties "done" to concrete conditions a checker can actually run and observe.

This mirrors how the workspace defines done across the pipeline:

- A proposal's acceptance criteria are written as concrete, **verifier-runnable**
  conditions - not vague goals.
- Tasks trace to those acceptance criteria, and an implementation traces to its
  task; the adversarial checkers re-run the conditions against reality.
- The checkers are **detect-only**: they confirm whether each condition holds and
  report pass/fail. They never "fix" a failure - a failed result routes back to
  the generator that produced the work, never patched by the checker (see
  [design-principles.md](design-principles.md)).

Trust markers reinforce this. Recorded claims distinguish **verified**
(re-derived or re-run against reality) from **asserted** (claimed only), so a
reader knows when to re-check rather than to trust. A SAC-style check is the act
of turning an asserted "it works" into a verified one by running the condition.

The safety gates on this page are themselves SAC-style checks: "the PII grep
returns zero matches" and "no disallowed file is present in the distributable
set" are exactly the kind of specific, re-runnable conditions that gate "done".

---

## What this does and does not guarantee

To keep expectations accurate:

- The gates **reliably enforce the conditions they encode** - the named private
  patterns, the disallowed files, the stated acceptance criteria - and do so
  deterministically and repeatably.
- They **do not** claim to detect every possible private string, every
  inappropriate file, or every defect. They are keyword/condition checks, not a
  certified data-loss-prevention product, and not a hosted compliance service.
- They **detect and block**; they do not auto-remediate. Correcting a failure is
  your (and the originating generator's) job, after which the gate is re-run.

Treat the safety posture as a strong, transparent floor that makes shared and
"done" work trustworthy by construction - and read [limitations.md](limitations.md)
for the boundaries that floor does not cross.
