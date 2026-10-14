---
name: code-quality
description: Check code, or a proposal's acceptance criteria against the live code, for breaks of the project's code-quality rules. Report only. Start it with /claude-workspace:code-quality, or let a checking agent read it for the rules and the method.
---

# Code quality check

This skill holds the method only. It changes no file. It chooses no fix.

## 1. Find the rules

The project has clear rules when its root `CLAUDE.md` has a heading with the text "Code quality". The heading can have any level and any case. The section under it must have at least one list item.

- Each list item is a rule.
- A file that the section names also holds rules. Those rules count.
- Each rule in the report names its source file.

## 2. Rule precedence

The repo owner has the final say.

- When the project has clear rules (step 1), use those rules only.
- When it does not, use these two fallback principles only:
  1. **Single source of truth.** Each stored fact has one master. Other places derive it. A break is a second place that stores the same fact as its own copy. Show the file:line of the master and of the copy.
  2. **DRY, for data and for code.** No second stored copy of a fact. No copied logic. A break is two places that hold the same data or the same logic. Show the file:line of both places.
- State in the report which set you used: the project rules or the two fallback principles.

## 3. Check

Check the target against each rule. The target is code lines, or a proposal's acceptance criteria against the live code.

- Each finding gives the rule, its source, and the file:line evidence of each place that the rule names.
- A duplicate finding cites both places. It also cites the line that shows they hold the same fact. For example, a write that copies one into the other.
- When you cannot cite that evidence, the item is a question for the user (step 5). Give no FAIL for it.

## 4. Report only

Change no file. Choose no fix. Give the findings and stop.

## 5. Ask

Raise a question for the user in these cases:

- Code and a rule disagree.
- The decision needs an intent that the code does not show.
- You cannot cite the evidence that step 3 needs.
