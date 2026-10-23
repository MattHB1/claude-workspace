# Safety and compliance

Claude Workspace does real compliance work. It **blocks** you in three cases. A shipped output would leak something private.
Content would land where it must not be distributed. Or a piece of work cannot be shown
to meet its stated acceptance conditions. This is a **feature**, not a malfunction.
The gates make sure that the things you publish, share, or call "done" are the
things you meant to publish, share, or call done.

This page explains the four kinds of safety check you will meet. You then expect
a stop and are not surprised by it:

- **PII gates** - zero-match greps for private identifiers over outputs before
  they ship. PII means personally identifiable information, such as a name or an
  email address.
- **Distribution gates** - what may and may not be published, keeping personal
  and build artefacts out of distributable repos.
- **Repo-wide greps** - the deterministic search mechanism the gates run on.
- **Acceptance-criteria ("SAC-style") checks** - verifier-runnable conditions
  that must pass before something is "done". SAC means specific acceptance
  criteria.

These match the wider attitude of the system. It tracks provenance and records
scope. It **surfaces conflicts and does not merge them silently** (see
[design-principles.md](design-principles.md) and [memory.md](memory.md)).

See also:

- [why-it-refuses.md](why-it-refuses.md) for the reasons the system declines work.
- [troubleshooting.md](troubleshooting.md) for what to do when a gate stops you.
- [limitations.md](limitations.md) for what these checks do not promise.

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
gates require a network service, a scanner daemon, or any hosted infrastructure.
They run as plain, re-runnable searches and condition checks over local files.

---

## PII gates (zero-match greps over outputs before shipping)

A **PII gate** scans a set of outputs for private identifiers. It requires **zero
matches** before the content may ship. "Private
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

- You decide the pattern up front for the work in hand. It is specific to what
  counts as private for that material. Then you run it unchanged, so the result
  is reproducible.
- Public identifiers can be an explicit, documented exception. An example is a
  public install handle that must appear in install commands. These are
  deliberately **not** part of the forbidden pattern.
- The gate runs over the **outputs**, which are the files that ship. It does not
  run over your private scratch or working notes, which are not distributed.

The result is that shared material is scrubbed of private strings by a check
anyone can re-run, rather than by someone remembering to look.

---

## Distribution gates (what may and may not be published)

A **distribution gate** governs **what is allowed to leave**. It decides what may
be published into a distributable repository and what stays out. It separates
content that is meant to be shared from content that is personal, machine-local,
or a build artefact. The second kind must not ship.

Two ideas drive it:

- **Shared, not secret.** Distributed material is shared deliberately and with
  known recipients. Access on the repository itself governs it. Hope that a
  secret stays hidden does not. Anything that must stay secret does not belong in
  distributable content.
- **Keep personal and build artefacts out.** Keep these out of the
  distributable repo. They are per-project working state, personal notes, local
  configuration, build outputs, and anything tied to one machine. They live in their own
  non-distributed homes, for example per-initiative working state or
  machine-local memory. They are not mirrored into shared material.

The distribution gate and the PII gate work together. The PII gate makes sure no
private *string* rides along inside shippable content. The distribution gate
makes sure whole *files* that must not travel stay out of what ships. If either
gate fails, the content does not go out until you correct it.

---

## Repo-wide greps (the deterministic search the gates run on)

The gates above are implemented with **repo-wide greps** - plain, deterministic
keyword/pattern searches across the relevant files. The rest of the system uses
the same determinism-first approach. Retrieval and checking use **explicit path,
filename/directory convention, and `grep`/`glob`**. They never use similarity
ranking, embeddings, or semantic search.

Why greps specifically:

- **Reproducible.** The same pattern over the same files gives the same answer
  every time, on any machine, with no model in the loop. A gate result is
  therefore auditable and can be re-run by anyone.
- **Transparent.** You can read the exact pattern and the exact file set, so it
  is clear *what* is being checked and *why* a hit failed.
- **Zero infrastructure.** A grep needs no server, index build, or background
  service.

The tradeoff is plain: a keyword search catches only what its pattern describes.
A grep gate is a strong, mechanical floor against known categories of problem,
such as the named private strings and the disallowed files. It is **not** a
guarantee that nothing unexpected got through. Keep this expectation in mind - the
gates raise the floor; they do not promise completeness. See
[limitations.md](limitations.md).

---

## Acceptance-criteria ("SAC-style") checks (must pass before "done")

A **SAC-style check** is a **specific, verifier-runnable acceptance condition**
that must pass before a piece of work counts as done. SAC stands for **specific
acceptance criteria**. The system does not declare success by assertion. It ties
"done" to concrete conditions that a checker can run and observe.

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
reader knows when to re-check and when to trust. A SAC-style check turns an
asserted "it works" into a verified one. It does this by running the condition.

The safety gates on this page are themselves SAC-style checks. "The PII grep
returns zero matches" and "no disallowed file is present in the distributable
set" are specific, re-runnable conditions that gate "done".

---

## What this does and does not guarantee

To keep expectations accurate:

- The gates **reliably enforce the conditions they encode**. These are the named
  private patterns, the disallowed files, and the stated acceptance criteria. The
  gates enforce them the same way every time.
- They **do not** claim to detect every private string, every inappropriate file,
  or every defect. They are keyword and condition checks. They are not a
  certified data-loss-prevention product or a hosted compliance service.
- They **detect and block**; they do not auto-remediate. Correcting a failure is
  your (and the originating generator's) job, after which the gate is re-run.

Treat the safety checks as a strong, transparent floor for shared and "done"
work. Read [limitations.md](limitations.md) for the limits of that floor.
