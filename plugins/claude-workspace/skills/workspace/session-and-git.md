# Session, git, and verbs

Load this file when you create, switch, list, or exit an initiative, or you pick, branch, worktree, merge-check, push, open a PR, or write the tracker. Do not load it on any other turn.

`<base>` is the workspace skill directory the harness showed. Scripts are `<base>/../../scripts/`. Run each script as its own Bash call. Replace each `<...>` before you run a command that still has one. The scripts take arguments. They contain no placeholders.

## Session pick

The pick lives in `~/.claude/.workspace-active/<session_id>` (`$CLAUDE_CODE_SESSION_ID`): `root=`, `checkout=`, `slug=`. "The active initiative" means this session's `slug=`. The registry does not set it. Step 0 of Bootstrap wrote `root=` and `checkout=`. Do not compute the shared root.

Run the check before you write a slug, for a pick and for Switch:

`bash "<base>/../../scripts/session-pick-check.sh" "<slug>"`

- `NO-ROOT`: stop. Tell the user the same-initiative check and the one-session check cannot run. Ask what to do. Do not guess the root.
- `BLOCK same-initiative`: another marker has this `root=` and this slug. Name the initiative. Do not change this session's marker.
- `BLOCK one-session`: `<root>/.workspace/main-commits` is the word `allowed`, and another marker has this `root=`. Say the repo allows one live session. Write no slug. A repo with no such file is not main-allowed. The script prints `MAIN-ALLOWED` in that case.
- `SAME-CHECKOUT`: another marker has this `root=` and this checkout. Step 1 of worktree start reads it. A marker with no `checkout=` counts as the main checkout.
- `LIVE-CHECKOUT`: every other marker with this `root=`. The merge check reads these lines. Step 1 ignores them.
- A marker with no `root=` matches no root.
- **Stale marker.** Delete another marker only when the user says that session has ended. Otherwise the block stays.

When the check passes, write the marker. Pass the worktree path when one is used:

`bash "<base>/../../scripts/session-marker-write.sh" "<slug>" ["<worktree path>"]`

The status line and `autolog.py` read `slug=` from this marker. No pick: no slug, and `autolog.py` logs nothing.

## Worktree and branch start

After the pick check passes, before any branch command. Read `root=` and `checkout=` from this session's marker.

**1. Is a worktree needed?** Only when the repo is main-locked and another live marker has the same `root=` and the same checkout. A main-allowed repo (`MAIN-ALLOWED`) never gets a worktree. Do not copy the marker scan. Use the pick-check script. `MAIN-ALLOWED`: no worktree. Otherwise any `SAME-CHECKOUT` line: a worktree is needed. Neither: no worktree.

**2. Use an existing worktree.** Skip in a main-allowed repo. In a main-locked repo, run this even when step 1 says no worktree is needed. If it prints a path, that path is the worktree. Do not check the branch out in the main checkout. Go to step 6.

`bash "<base>/../../scripts/worktree-for-branch.sh" "<root>" "<branch>"`

**3. Start point for a new branch.** `<start>` is the script's `START=` value. Never move the local default branch. Never start from the current HEAD. `NO-DEFAULT`: stop and ask the user. `FETCH-FAILED`: stop and report. Continue from the local default only when the user says so. A line that says there was no fetch, or that origin has no default: tell the user, and use the printed `START`.

`bash "<base>/../../scripts/branch-start.sh" "<root>"`

**4. Keep worktrees out of git status.** Before the first `git worktree add`. It changes no tracked file.

`bash "<base>/../../scripts/worktree-exclude.sh" "<root>"`

**5. Create the branch.** Name from the branch rule. If `git -C "<root>" show-ref --verify --quiet refs/heads/<branch>` succeeds, use the existing-branch form.
- Worktree needed, new branch: `git -C "<root>" worktree add --no-track -b "<branch>" "<root>/.claude/worktrees/<slug>" "<start>"`. This is the only branch command. The main checkout stays on its branch.
- Worktree needed, existing branch: `git -C "<root>" worktree add "<root>/.claude/worktrees/<slug>" "<branch>"`.
- No worktree needed, new branch: `git branch --no-track "<branch>" "<start>"`, then `git switch "<branch>"`.
- No worktree needed, existing branch: `git switch "<branch>"`. If git refuses because a linked worktree holds the branch, stop and report this to the user (AC9). Do not enter that worktree.

`--no-track` leaves no upstream. The first push, after `push <branch> to origin? y/n`, is `git push -u origin <branch>`. Create does no push. If git refuses the worktree, stop and report. Never `--force`, `--ignore-other-worktrees`, or `EnterWorktree`.

**6. Enter the worktree.** When step 2 or step 5 used a worktree, run `cd "<worktree path>"` in its own Bash call. Then pass that path to the marker-write script. `.workspace/` paths stay at `<root>/.workspace/`. Code paths and the project root for the quality check are the worktree path. Add a working-directory line to each brief for `implementer`, `implementation-verifier` and `archivist`. The line gives the worktree path and says: "Run `cd <worktree path>` in each command, or use absolute paths." With no worktree, the working directory is this session's checkout.

## Merge check

Runs at Bootstrap once, after the marker write that records the slug (an existing pick or a new initiative), and at Switch, after its marker write. Exit has no merge check. It covers every linked worktree of `<root>`. It deletes no branch. It writes nothing to the tracker.

**1. List.** Do not build a path from `<root>/.claude/worktrees/<slug>`. This prints `<branch>`, a tab, then `<path>` for each linked worktree. It skips the main checkout and any detached worktree.

```
git -C "<root>" worktree list --porcelain | awk '/^worktree /{n++; p=substr($0,10)} n>1 && /^branch refs\/heads\//{print substr($0,19) "\t" p}'
```

**2. Merged?** `gh pr view "<branch>" --json state --jq .state`. Only `MERGED` continues. Any other output, and any failure, is a skip with no prompt, no notice, and no error.

**3. Skip a merged worktree, in order.** No `cd`. Do not write this session's marker.
- `<path>` equals this session's `checkout=`: no prompt.
- Another live session uses `<path>`: read `LIVE-CHECKOUT` from the pick-check script. Do not copy the marker scan. If a line has `checkout=<path>`, no prompt, and name that marker file. The stale-marker rule stands.
- `git -C "<path>" status --porcelain` prints any line: no prompt. One line to the user: `<path>` has uncommitted or untracked files and stays.

**4. Ask, then remove.** Git-ignored files do not stop the prompt. List them first. This prints the first 10 ignored entries (an ignored directory is one entry), then `and <N> more` when there are more than 10, or nothing when there are none.

```
git -C "<path>" status --porcelain --ignored --untracked-files=normal | awk '/^!! /{n++; if(n<=10) print substr($0,4)} END{if(n>10) print "and " n-10 " more"}'
```

When that prints anything, first say `<path>` has git-ignored files that the removal deletes, then print the lines. When it prints nothing, print only the prompt. The prompt is `remove worktree <path>? y/n`, and it comes last. On "y": `git -C "<root>" worktree remove "<path>"`. Any other answer: do nothing. If git refuses, stop that removal and report git's message. Never `--force`.

## PR body decisions

When you open a PR, ask `open PR? y/n` and write only on "y". If `.workspace/<slug>/decisions.md` exists, the PR body has a `## Decisions` section. Write one line for each ruling in `decisions.md`. Put each low-confidence DECIDED item first, under "Worth a glance".

## Tracker write-back

Two moments, and no more: **work started**, and **PR opened**. Each is one line, `move <slug> to <mapped state>? y/n`, and writes only on "y". No close and no Done. The plugin hardcodes no state name. Read the tracker's states at mapping time.

`.workspace/tracker-states` is project-level, two lines, `work-started` and `pr-opened`, each `key: state name`. On the first write-back in a project, read the tracker's states, ask which state each key maps to, and record the answers. After that, read the file and do not ask again. The file appears when the user first answers. No tracker tool: skip with no prompt, no notice, and no error.

## Verbs

These dispatch no agent.

**Create** — "new initiative <name>", "start a new initiative", "spin up an initiative for…". The ticket id is the `<slug>` (digits are valid). Ticket text: read it with the tracker tool, or ask the user to paste it. Save `.workspace/<slug>/research/ticket.md`. Resolve the branch name (tracker, else slug) and create the branch with the worktree steps above. Create `.workspace/<slug>/` with empty `research/` and `verification/`. Create `memory/` on first memory use. Add the registry row (see SKILL.md). Run the pick check. On a pass, run the worktree steps, then the marker write (pass the worktree path when there is one). Do not mark a row ACTIVE. Then run **Session-age /clear nudge** in SKILL.md. Then load `memory-maintenance.md` and run the guard rows that name Create. A new initiative has an empty index and no journal entries, so those rows do not trip.

**Switch** — "switch to <name>", "work on <name>". Pick check for that slug. On a pass, worktree steps for the existing branch (step 2 in a main-locked repo even when step 1 says no worktree), `cd` when a worktree is used, then the marker write. No `**ACTIVE**`. No `.workspace/` file moves. Then the merge check. Then **Session-age /clear nudge**. Then the guard rows that name Switch (index-bloat and the epic notice). Do not read the journal tail or the proposal here. That read is Bootstrap.

**List** — "list initiatives", "what's in this workspace", "what initiatives do we have". Report each slug, one-line description, and status from `.workspace/initiatives.md`.

**Exit** — "exit the workspace", "leave the workspace", "drop out of the orchestrator", "stop orchestrating", "I'm done here".

1. Load `memory-maintenance.md` and run Teardown before you confirm.
2. One line: the initiative is checkpointed, and state is in the git-controlled `.workspace/` tree.
3. You cannot clear your own context. Tell the user to type `/clear` (fresh start) or `/compact` (keeps a summary). A later `/workspace` lists the open initiatives and waits for a pick, then reads the index and the journal tail.
4. `rm -f ~/.claude/.workspace-active/"$CLAUDE_CODE_SESSION_ID"`. You do this. No hook runs on the exit verb. `SessionEnd` deletes the marker on a normal end. A crash leaves it for the 24-hour sweep. Either miss is not an error.

Exit moves no file and creates no initiative. The registry stays as it is. There is no merge check.
