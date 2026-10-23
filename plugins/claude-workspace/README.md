# claude-workspace

![version](https://img.shields.io/badge/version-1.21.0-brightgreen)

Claude Workspace turns any folder into a place where ideas get built right. You talk to it in plain language. It researches your idea and turns it into a spec. It plans the work and builds it. Independent, adversarial checks catch a plan or build that drifts from what you agreed, before you ship. Every decision lands in a plain file that you can read, search and revert. The work stays traceable and does not drift. Even a multi-day project picks up where you left off.

**Build the right thing, and prove it.**

---

## What it's good for

- **"The AI confidently built the wrong thing."** Claude Workspace refuses to guess. It stops and asks. It traces every step back to a written spec. It flags a build that does not match what you agreed on, before you ship.
- **"I lose the thread on a multi-day project."** Plans, decisions and progress live in plain files on disk. You can drop a project for days and reload it where you left off, with no re-explaining.
- **"The plan quietly drifted from the spec."** The proposal is the root of truth. Every task traces to it. An adversarial checker flags drift before anyone builds a single line.
- **"I can't trust the output, and there's no way to check."** Every decision is a versioned file with one named owner. The agents that review your work have read-only tools. They cannot edit what they review.

---

## Why not just prompt Claude directly?

Prompting Claude is a conversation. Claude Workspace is a conversation with a memory, a spec, an auditor and a paper trail.

Raw prompting has predictable failure modes. This is how Claude Workspace addresses each one:

- **Drifts over a long session.** Chat loses early decisions. Claude Workspace keeps a written proposal as the single root of truth. Every agent answers to the proposal, not to the current conversation.
- **Guesses when uncertain.** One agent improvises. Claude Workspace refuses to guess by design. Agents stop and surface the ambiguity. They do not invent an answer.
- **No audit trail.** A transcript is not a record. Every decision is a plain file that you can search and revert. The git history is the audit trail.
- **Marks its own homework.** The same agent that writes the plan checks the plan. In Claude Workspace, the checkers are separate agents with read-only tools. A FAIL goes back to the agent that owns the work. Nobody can patch it in silence.
- **Forgets between sessions.** You re-explain every time. The per-initiative journal and index reload only what matters. You pick up where you left off.

A caveat: the determinism here comes from conventions and discipline, plus a few real tool locks. It is not a sandboxed runtime. Claude Workspace reduces and surfaces errors. It does not guarantee correct output. It does not replace human review.

---

## How it feels to use

You invoke the orchestrator with `/claude-workspace:workspace` and then talk to it. The orchestrator follows a plain-voice rule. It uses short sentences and common words. It explains each term before it uses the term. It batches its questions with the `ask` skill. Your own style instructions win over this rule.

Say "research this idea". The Researcher agent reads the relevant context and surfaces what it finds. Then say "spec it out". The Spec Writer turns the research into a written proposal that you agree on. Next, say "plan the work". The Planner breaks the spec into a task list that traces back to it.

Before the Planner starts, say "check the proposal". The Task Checker is a separate agent with read-only tools. It flags anything in the proposal that is missing or unclear. If it finds a problem, the failure goes back to the Spec Writer.

Now you build. Say "implement task 1". The Implementation agent writes the code to spec. Then say "verify it". The Verifier also has read-only tools. It checks the build against the task definition. If it finds a gap, the failure goes back to the Implementation agent to fix. The Verifier does not patch it.

You run only the stages you need. It is a map, not a track.

---

## Tickets, branches, and your tracker

An initiative starts from a ticket. You give the orchestrator the ticket identifier. That identifier becomes the initiative slug. A number is a valid slug. The orchestrator reads the ticket with your tracker tool if one is connected. If none is connected, it asks you to paste the ticket text. In both cases the text is saved into the `research/` folder of the initiative.

The branch name comes from one of two places, and the orchestrator does not guess between them. It uses the name that your tracker supplies. If the tracker supplies none, it uses the initiative slug. The orchestrator never invents a branch name from the ticket title.

Git actions belong to the orchestrator. An agent never runs them. After a task passes verification, the orchestrator commits without asking. Before it pushes, it asks you a one-line `y/n` question. It asks again before it opens a pull request. Those two actions leave your machine, and your team can see them.

Your tracker gets an update at two moments only. The first moment is when work starts. The second is when the pull request opens. Each one is a `y/n` prompt. Nothing is written to the tracker unless you say yes.

The plugin holds no state names of its own. It reads the real states from your tracker the first time you are asked. It records your choice for the project and does not ask again. If no tracker tool is connected, the plugin skips every tracker step in silence. You see no prompt, no notice and no error.

The plugin proposes no close or Done transition. Closing a ticket follows review and merge. Another person makes that decision.

---

## What you get that you can trust

- **Detect-only checkers with read-only tools.** The agents that review your proposal and build cannot edit what they review. A failure goes back to the agent that made the work. Nobody patches it in silence.
- **Single writer and a git audit trail.** Every decision is a versioned file with one named owner. The git history is the audit trail. You can attribute and revert every change.
- **Proposal as root of truth.** One spec is the authority for everything. "Done" means the same thing at every stage. Traceability is part of the structure. You do not need to hope that people follow a convention.
- **Artefacts win over chat.** Your written record stays stable across session resets and context compaction. The artefact is the source of truth. The transcript is a byproduct.
- **No infrastructure to maintain.** Everything is flat markdown files in git. You install the plugin and do nothing else to run or maintain it.
- **Refuses to guess.** When an agent hits an ambiguity that it cannot resolve from the artefacts, it stops and asks. It does not invent an answer.

---

## The agents

Each agent has a single job. The read-only agents have tool locks, so they cannot write to your codebase even if you ask them to. See [docs/workflow.md](docs/workflow.md) for the full intent and command table.

| Agent | What it does for you |
|---|---|
| `research-harvester` | Reads and surfaces relevant context, such as docs, existing code and prior decisions, so the spec has a firm base. |
| `proposal-writer` | Turns research into a written proposal that you agree on. This proposal is the root of truth for every later step. |
| `task-planner` | Breaks the proposal into a traceable task list. Each task maps back to an acceptance criterion in the proposal. |
| `task-checker` | Read-only tools. Checks the proposal before planning starts. A failure goes to the `proposal-writer`. |
| `implementer` | Builds to spec, one task at a time. The proposal and the task definition are the only authorities. |
| `implementation-verifier` | Read-only tools. Checks the build against the task definition after implementation. A failure goes back to the implementer. A "spec requires break" finding goes to you. |
| `context-recovery` | Rebuilds project state when context is lost or drifting. It is read-only and reports only what exists. |
| `archivist` | Keeps the file tree clean and predictable. It moves and renames files and creates directories. It never edits file content. |

---

## Skills

The table below lists nine skills. Invoke them directly in a Claude Code session. The orchestrator skill, `/claude-workspace:workspace`, is the tenth skill.

| Skill | What it does |
|---|---|
| `/claude-workspace:ideate` | Structured ideation: Frame → Diverge → Adversarial-challenge → Converge. |
| `/claude-workspace:ideation-spiral` | Turns a vague idea into a clear, testable concept and a test plan for each hypothesis. The skill gives the result. The orchestrator saves it to `ideation.md` in the initiative folder. |
| `/claude-workspace:decide` | Decision process: list the options, test each one hard, and settle on a recorded choice. |
| `/claude-workspace:plan` | Planning method: split a goal into a task structure that you can trace and review. |
| `/claude-workspace:reflect` | Reflection method: review what happened, pull out the lessons, and record them. |
| `/claude-workspace:ask` | Sets the format for questions, so you can read and answer them with ease. |
| `/claude-workspace:write-issue` | Writes or updates an issue in your tracker, with a short title, a short problem statement and checkable acceptance criteria. |
| `/claude-workspace:plain` | Rewrites the last output in plain words. Only you start this skill, when the last output is hard to read. |
| `/claude-workspace:code-quality` | Checks code, or the acceptance criteria of a proposal, against the code-quality rules of your project. Each finding gives file:line evidence. It only reports and changes no file. It asks you when code and a rule disagree. |

The skills `ideate`, `decide`, `plan` and `reflect` are general-purpose method skills. They need no initiative. The skill `ideation-spiral` runs in the initiative that this session picked.

---

## What this is NOT

- **Not a sandboxed runtime.** The determinism here comes from conventions and discipline, plus a few real tool locks on the read-only agents. Nothing isolates the full build. It reduces and surfaces errors. It does not guarantee correctness.
- **Not a substitute for human review.** Adversarial checks catch common failure modes. They do not catch everything. You still review the output.
- **Not total recall.** Session memory has a limit. The journal reloads about the most recent entries, plus an index. Retrieval matches keywords, as grep does. There is no semantic search.
- **One initiative per session, no built-in delete.** Each session picks one initiative. Two sessions cannot pick the same initiative in the same repo. You close an initiative by hand.
- **No automatic cross-project learning.** Promoting a pattern from one project to another is a deliberate, manual step. Nothing propagates automatically. You choose what carries over and you check it again.
- **Closed to modification.** The author maintains this plugin centrally. Do not modify your local copy, because an update overwrites local changes. The plugin accepts no contributions, pull requests or forks. Updating is a different matter. See below.

---

## Quickstart

The full setup guide is in [docs/install.md](docs/install.md). It covers auth, permissions, per-agent models and the distribution model. Here is the short version.

In a Claude Code session, run the three install commands:

```
/plugin marketplace add vitalsignssolutionsltd/claude-workspace
/plugin install claude-workspace@pocdoc-workspace
/reload-plugins
```

Then start the orchestrator:

```
/claude-workspace:workspace
```

### Staying current

The author maintains this plugin centrally. To stay current, run:

```
/plugin marketplace update pocdoc-workspace
/reload-plugins
```

We encourage updates, because new versions fix issues and improve agents. We discourage changes to your local copy. An update overwrites local changes. The plugin accepts no contributions, pull requests or forks. The intended workflow is install, use, update.

---

## Documentation

The full guide is split into focused pages under `docs/`:

| Page | What it covers |
|---|---|
| [docs/concepts.md](docs/concepts.md) | Glossary of core terms. How a project differs from an initiative, and how the registry maps them. |
| [docs/design-principles.md](docs/design-principles.md) | The six invariants. They are the contract that explains why the system behaves and refuses as it does. |
| [docs/why-it-refuses.md](docs/why-it-refuses.md) | What the system will NOT do (unsafe, ambiguous and non-deterministic requests), and why refusal is expected. |
| [docs/workflow.md](docs/workflow.md) | The intent and command table (what you say, and which agent acts), and the optional stage flow. |
| [docs/initiatives.md](docs/initiatives.md) | Initiative naming, slugs, switching, the registry, the session pick, and manual deletion. |
| [docs/memory.md](docs/memory.md) | The per-initiative and cross-project memory tiers. When to use them, how to promote and inspect, and how to opt out of a namespace. |
| [docs/safety-and-compliance.md](docs/safety-and-compliance.md) | The safety rules as a feature: gates for personal data, distribution gates, repo-wide searches, and checks against specific acceptance criteria. |
| [docs/install.md](docs/install.md) | Full operational guide: private marketplace add, auth, manual and background updates, permissions, distribution. Each agent has its own model, set in its agent file. See the section [Per-agent models / cost](docs/install.md#per-agent-models--cost). It also has override and fallback steps. |
| [docs/statusline.md](docs/statusline.md) | Opt-in statusline that shows the initiative of this session in your Claude Code prompt. |
| [docs/troubleshooting.md](docs/troubleshooting.md) | Fixes for permission errors, missing tools, marketplace auth, and the two "why did it refuse" cases. |
| [docs/limitations.md](docs/limitations.md) | Known gaps and what the system is NOT (no semantic retrieval, no auto-promotion, no built-in delete, and more). |
| [docs/ideation-spiral.md](docs/ideation-spiral.md) | How to use the ideation spiral: its triggers, the Frame→Diverge→Challenge→Converge loop and the convergence gate. It also covers its limits, and how to pass `ideation.md` on to the pipeline or export it. |
| [CHANGELOG.md](../../CHANGELOG.md) | Release history and notable changes per version. |
