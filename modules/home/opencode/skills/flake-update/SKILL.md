---
name: Flake Update
description: Update flake inputs in an isolated worktree, analyze relevant upstream changes, test and deploy the configuration, and write the update report. Use explicitly for the full flake update workflow.
metadata:
  opencode/autoinvoke: false
---

# Flake Update

Update this repository's NixOS flake inputs and determine how upstream changes
affect the configuration. This workflow is still evolving. Report tool failures
and concrete limitations instead of silently weakening the checks.

## Worktree Contract

Never run an update in the primary `~/conf` worktree.

1. Read the current date with `date +%m-%d-%y`. Use branch
   `update-MM-DD-YY`.
2. Inspect `git worktree list --porcelain` and
   `git branch --list update-MM-DD-YY`.
3. Reuse the branch's registered worktree when it exists. Use the path reported
   by Git.
4. If the branch exists without a worktree, run:

   ```bash
   git worktree add /home/bbrian/Code/conf-update-MM-DD-YY update-MM-DD-YY
   ```

5. Otherwise, create the branch from the primary worktree's committed `HEAD`:

   ```bash
   git worktree add --no-track -b update-MM-DD-YY /home/bbrian/Code/conf-update-MM-DD-YY HEAD
   ```

For a new worktree, use `/home/bbrian/Code/conf-update-MM-DD-YY`. Use
`/tmp/flake-update/update-MM-DD-YY` for artifacts. Substitute the actual date
and any reused worktree path in every command.

After finding or creating the worktree:

- Run `direnv allow <worktree>` immediately after finding or creating it and
  before making any edits. The worktree starts from the already trusted
  committed `HEAD`; doing this up front avoids a blocked shell environment.
- Use it as `workdir` for every repository command.
- Pass its path explicitly to every `nh`, `nix`, and `nixos-rebuild` command.
  Do not rely on `NH_FLAKE`, which points at `~/conf`.
- Give every subagent the exact worktree and artifact paths. Never direct a
  subagent to use `~/conf`.
- Write all fixes and the report in the update worktree. Do not modify the
  primary worktree.
- Stage a newly created flake-relevant file before evaluation so Git-based
  flake discovery includes it. Do not stage unrelated files.

## 1. Update And Collect Evidence

Run:

```bash
flake-update --output-dir /tmp/flake-update/update-MM-DD-YY /home/bbrian/Code/conf-update-MM-DD-YY
```

The command updates `flake.lock`, backs up the old lock file, fetches commit
details, and performs an initial package-name filter over nixpkgs changes.
Read every generated artifact:

- `changelog.json`: changes for all inputs;
- `nixpkgs-changelog.json`: nixpkgs commits matched to configured packages;
- `all-nixpkgs-commits.txt`: every fetched nixpkgs commit in the range;
- `unmatched-nixpkgs-commits.txt`: commits not selected by the package filter;
- `nixpkgs-batches/`: complete review batches of about 100 unmatched commits;
- `config-packages.txt`: packages extracted from the configuration;
- `old-flake.lock`: the lock file before the update.

Confirm that the old lock file exists and that the changelog accounts for each
changed top-level input before continuing.

## 2. Analyze Every Input

For each changed non-nixpkgs input, use parallel `general` subagents when the
analyses are independent. Each prompt must include the exact worktree and
artifact paths. Ask each subagent to:

- find how the input is used in this configuration;
- inspect its commits and release notes;
- identify changes to features or options used here;
- flag breaking changes, deprecations, removals, migrations, and renames;
- return evidence and a relevance assessment for the report.

For nixpkgs, inspect all package-matched commits in
`nixpkgs-changelog.json`. Read linked pull request descriptions and migration
notes. Investigate every entry marked `"package": "BREAKING"` instead of
assuming the marker affects this configuration.

## 3. Scan Unmatched Nixpkgs Commits

The package-name filter misses NixOS modules, `lib`, and infrastructure changes.
Perform an exhaustive second scan.

1. Check `range_complete` in `nixpkgs-changelog.json`. When it is `true`, use
   the generated `all-nixpkgs-commits.txt`, `unmatched-nixpkgs-commits.txt`, and
   `nixpkgs-batches/` artifacts directly. Do not fetch or repartition them.
2. If `range_complete` is `false`, prepare a range repository and regenerate
   the complete commit and batch artifacts:

   ```bash
   flake-repo-checkout --no-worktrees nixos/nixpkgs <old_rev> <new_rev> /tmp/flake-update/update-MM-DD-YY/repos/nixpkgs
   ```

   Set the shell tool's `workdir` to the printed bare repository path and use
   `git log` there. Do not claim exhaustive coverage until the helper verifies
   the range and every commit is batched.
3. Spawn parallel
   `general` subagents for every batch. Do not sample or reduce the batch count.
4. Each subagent must cross-reference its messages against the update
   worktree's NixOS modules and options. It should report potentially relevant
   module, service, library, security, evaluation, and build-infrastructure
   changes with commit identifiers.
5. Investigate each candidate and include every relevant result in the report.

When source trees for other upstream repositories are needed, run:

```bash
flake-repo-checkout owner/repo <old_rev> <new_rev> /tmp/flake-update/update-MM-DD-YY/repos/name
```

Then use its `old` and `new` detached worktrees. In all cases:

- never clone an upstream repository into the update worktree.

The unmatched scan is complete only when every unmatched commit belongs to a
reviewed batch and every candidate has a relevance decision.

## 4. Review Every Overlay

Review every file under `overlays/`, even when its input did not change.

For each overlay:

- identify why it exists from its comments and overridden attributes;
- compare it with the updated nixpkgs or upstream package definition;
- decide whether to keep, refresh, or remove it;
- pay particular attention to version pins, temporary overrides, and
  compatibility patches.

When an overlay remains necessary, make sure its comments state the reason and,
when knowable, the condition for removal. Remove obsolete overlays and record
the evidence in the report.

## 5. Assess Relevance And Required Fixes

Organize findings into:

1. no action needed;
2. worth reviewing;
3. action required.

Include both package-matched and unmatched nixpkgs findings. Search the actual
configuration before claiming a deprecated option or breaking package change
applies. Use upstream documentation and targeted web searches for significant
version changes or unclear migration notes.

Apply the smallest configuration fixes required by the update. Explain any
uncertainty that cannot be resolved from the repository or upstream evidence.

## 6. Build, Activate, And Check

Build the exact update worktree:

```bash
nh os build /home/bbrian/Code/conf-update-MM-DD-YY --out-link /tmp/flake-update/update-MM-DD-YY/result
```

If the build fails, diagnose it against relevant upstream commits and apply
required fixes. Then run all mandatory validation:

```bash
nh os test /home/bbrian/Code/conf-update-MM-DD-YY
nix flake check /home/bbrian/Code/conf-update-MM-DD-YY
just health
just vim-health
just gnome-check
just test-remote-builds
```

`nh os test` must activate the update worktree even when no configuration fix
was needed. Compare results with `failures.md`. Report only new failures or
warnings, and update that baseline when a known failure appears or disappears.

After local checks pass, run `just deploy` from the update worktree. This must
deploy the update worktree directly to `am` and `torag`. Then run these checks
on torag:

```bash
ssh torag just health
ssh torag just vim-health
ssh torag just gnome-check
ssh torag just test-remote-builds
```

Do not run `just deploy` again on torag. If torag is unavailable, ask the user
whether to wait or skip its deployment and checks. An explicit skip counts as
completion but must be recorded in the report.

## 7. Write The Report

Write the report to
`/home/bbrian/Code/conf-update-MM-DD-YY/update-reports/YYYY-MM-DD.md`. Follow the
format of existing reports and include:

- every command run and its result;
- every updated input and its commit count;
- all nixpkgs package changes affecting this configuration;
- relevant unmatched NixOS module, library, security, and infrastructure
  changes;
- the result for every local overlay: kept, updated, or removed;
- every breaking marker and whether it applies here;
- packages added to or removed from the closure;
- deployment and local and remote health-check results;
- remaining risks, suggested manual tests, and follow-up work.

Run a general web search for reported breaking changes and targeted searches
for significant updates. Use the results to propose concrete checks for
behavior that automated tests may not cover.

## 8. Commit After Deployment

After deployment and all reachable checks finish:

1. Finalize the report with actual results.
2. Inspect `git status`, `git diff`, and recent `git log` in the update
   worktree.
3. Stage only the update's lock file, required fixes, failure-baseline changes,
   and report.
4. Commit them on the update branch with an update-specific message.

Wait for my go ahead to merge.

## Command Reference

```text
flake-update [--dry-run] [--no-fetch] [--output-dir dir] [flake-path]
```

- `--dry-run`: analyze the current lock file against the previous commit
  without updating it.
- `--no-fetch`: skip GitHub and GitLab commit fetching.
- `--output-dir`: choose the artifact directory.

To analyze a nixpkgs range separately:

```bash
nixpkgs-changelog <old-rev> <new-rev> [--json]
```

If API rate limiting produces partial data, retain the artifacts and retry or
use a local checkout. If package extraction falls back to grep, inspect
`config-packages.txt` and state that package matching may be incomplete.
