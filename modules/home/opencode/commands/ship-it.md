---
description: Commit, push, open a PR, and merge when checks approve
---

Ship the current work end-to-end:

- Inspect the repository status, diff, current branch, and contribution
  conventions. Do not discard existing changes.
- Run the relevant tests or checks. If there are uncommitted changes, create a
  suitable branch when needed, stage the intended changes, and commit them with
  an appropriate message.
- Push the branch and set its upstream if necessary.
- Find the pull request for the branch. Open a non-draft pull request with an
  accurate title and description if one does not exist.
- Monitor required CI checks and automated review feedback. If a check fails or
  an automated reviewer identifies an actionable problem, investigate it, make
  the appropriate fix, test it, commit it, push it, and repeat.
- Merge the pull request using the repository's expected merge method only
  after required CI passes and automated reviews approve or have no unresolved
  actionable feedback. Do not bypass branch protections or merge with pending
  or failing checks.
- Report the resulting commit and pull request. If human input or approval is
  required, report the blocker instead of bypassing it.

Follow any additional constraints below.

$ARGUMENTS
