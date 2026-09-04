---
name: Code Review
description: Review a branch, pull request, commit range, or worktree for correctness, regressions, security, missing tests, repository-standard violations, and divergence from its specification. Use when the user asks for a code review or review of changes.
license: MIT
---

# Code Review

Review changes against both the repository's engineering standards and the
change's intended behavior. Findings are the product. Do not modify code unless
the user separately asks for fixes.

## 1. Establish The Review Target

Use the fixed point, pull request, branch, tag, commit, or path supplied by the
user. Confirm every ref resolves before reviewing it.

If the user names no target, inspect `git status` and review the current
worktree, including staged, unstaged, and relevant untracked files. If the
worktree is clean, determine the current branch's merge-base with its upstream
or default branch. Ask only when more than one materially different target
remains plausible.

Record the exact commands that define the target. For a branch review, prefer
`git diff <base>...HEAD` and `git log <base>..HEAD --oneline`. Verify that the
result is non-empty.

## 2. Gather Review Evidence

Read the changed files in context, not only the diff hunks. Also find:

- repository instructions and coding standards;
- tests and callers around changed behavior;
- the originating issue, specification, ADR, or pull request description;
- generated-file or dependency constraints relevant to the change.

Infer intent from commit messages and nearby code when no specification
exists. State that limitation rather than inventing requirements.

## 3. Review Along Independent Axes

For a substantial change, run independent sub-agents in parallel so one line
of inquiry does not anchor the others. Give each agent the target commands,
changed-file list, relevant evidence paths, and a narrow brief. Useful axes are:

- **Correctness:** broken behavior, edge cases, security, concurrency, data
  loss, error handling, and compatibility.
- **Intent:** missing or partial requirements, incorrect implementation of a
  requirement, and unrequested scope.
- **Maintainability:** repository-standard violations and design problems that
  make the changed behavior unsafe to extend.
- **Tests:** missing regression coverage, assertions that cannot detect the
  failure, and important paths left unverified.

Use fewer axes for a small diff. Do not manufacture parallel work when one
focused pass can cover the target.

## 4. Apply Standards With Judgment

Repository instructions override generic preferences. Skip style issues that
formatters or linters enforce. Treat general code smells as heuristics, not
violations. Pay particular attention to:

- duplicated logic that can drift;
- a primitive standing in for a domain concept;
- repeated conditionals over the same variants;
- one behavior change scattered across unrelated modules;
- abstractions, hooks, or parameters not required by current behavior;
- wrappers that only delegate;
- dependencies on another object's internal data or long navigation chains.

Only report a maintainability concern when it creates a concrete cost or
failure mode in the reviewed change.

## 5. Validate Findings

Trace each candidate through callers, types, tests, and runtime behavior.
Run focused read-only checks when they can confirm or reject it. Do not run
commands with external side effects merely to support a review.

A finding must identify:

- the affected file and smallest useful line range;
- the concrete failure or maintenance cost;
- the conditions that trigger it;
- why existing tests or guards do not prevent it.

Drop speculative findings that cannot meet this bar. Distinguish confirmed
bugs from risks that require unavailable runtime evidence.

## 6. Report

List findings first, ordered by severity. Combine results from all axes into
one ranking so the user can act on the highest-risk issue first. Use concise
severity labels and file/line references.

After findings, list open questions or assumptions, then give a brief summary
only if useful. If there are no findings, say so and identify residual testing
or evidence gaps.

This skill is adapted from Matt Pocock's `code-review` skill. See `UPSTREAM.md`
and `LICENSE` in this skill directory.
