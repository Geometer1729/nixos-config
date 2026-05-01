---
name: flake-update
description: Update flake inputs, analyze relevant upstream changes, build and test the config, and write the update report.
disable-model-invocation: true
---

# Flake Update Skill

### This skill is still in development!

If you encounter errors or limitations with any of the tools you use raise them and feel free to suggest changes to the skill.
If you get negative feedback about the report or any other part of using this skill feel free to suggest changes to the skill.

Update the NixOS flake inputs and analyze changes for relevance to this configuration.

## Quick Start

Run the flake update from the repository root:

```bash
flake-update ~/conf
```

## What This Does

1. **Backs up** the current `flake.lock` to `/tmp/flake-update/old-flake.lock`
2. **Runs** `nix flake update` to update all inputs
3. **Fetches** commit details from GitHub/GitLab for each changed input
4. **Analyzes nixpkgs** specially - filters ~14k commits to only those affecting packages in your config
5. **Generates** changelog files in `/tmp/flake-update/`

## Output Files

After running, these files are available:

- `/tmp/flake-update/changelog.json` - Full changelog for all inputs
- `/tmp/flake-update/nixpkgs-changelog.json` - nixpkgs changes filtered by your config
- `/tmp/flake-update/config-packages.txt` - List of packages extracted from your config
- `/tmp/flake-update/old-flake.lock` - Backup of previous lock file

## Analysis Workflow

### Step 1: Run the update and read results

```bash
flake-update ~/conf
```

Then read the output files.

### Step 2: Analyze relevance

For each input in the changelog with commits, spawn a Task agent to analyze relevance:

**For non-nixpkgs inputs:**
- Search for `inputs.<name>` references in the config
- Check if commit messages mention features/options used
- Look for breaking change keywords: "breaking", "deprecat", "remov", "migrat", "renam"

**For nixpkgs (already filtered):**
- The `nixpkgs-changelog.json` only contains commits affecting your packages
- Review PR descriptions for migration notes
- Check for breaking changes flagged as `"package": "BREAKING"`

### Step 2b: Scan unmatched nixpkgs commits

The `nixpkgs-changelog` script only matches commits by package name prefix. It misses NixOS module changes (e.g. `nixos/networking:`, `nixos/systemd:`), lib changes, and infrastructure changes that could affect the config.

To catch these, fetch the full commit list and scan the ones NOT already matched:

1. Get all nixpkgs commit messages between old and new rev:
   ```bash
   # Use the GitHub compare API or git log to get all commit messages
   gh api "repos/nixos/nixpkgs/compare/<old_rev>...<new_rev>" --paginate -q '.commits[].commit.message' > /tmp/flake-update/all-nixpkgs-commits.txt
   ```
   If this is too many for the API, use `git log --oneline <old_rev>..<new_rev>` from a local nixpkgs checkout if available, or paginate the API.

2. Remove commits already covered by `nixpkgs-changelog.json` (the package-matched ones).

3. Spawn parallel subagents to scan the remaining commits in batches of ~100. Each agent should:
   - Read its batch of commit messages
   - Look for anything potentially relevant: NixOS module changes (`nixos/`), changes to services/options used in the config, security fixes, infrastructure changes
   - Cross-reference against the actual NixOS modules and options used in `~/conf` (check `modules/nixos/`, `configurations/nixos/`, etc.)
   - Report back any commits worth flagging

4. Collect results from all agents and include relevant findings in the report.

### Step 3: Generate report

Include **all** relevant nixpkgs changes in the report — both the package-matched ones from `nixpkgs-changelog` and any NixOS module/infrastructure changes found by the subagent scan. Present all package updates affecting this config in a comprehensive table.

Summarize findings into categories:

1. **No action needed** - Updates that don't affect this config
2. **Worth reviewing** - New features or improvements you might want
3. **Action required** - Breaking changes that need config updates

Explore the existing config and use web search to add context.
If an option is deprecated check my config to see if I'm using it.
If a package has a significant upgrade check what changes were made.

### Step 4: Build and check for build errors

Run `nh os build` if it fails add the error to the report.
Provid related commits to add context.
Feel free to use web search and read the config to understand which commits are related.

### Step 5: Make fixes if needed

If breaking changes require config updates:
1. Show the specific changes needed
2. Make the edits
3. Run `nh os test` to verify the build works

### Step 6: Run checks and tests

Run `nix flake check` to verify the flake evaluates correctly.

After `nh os test` activates the new configuration, run these health checks:
- `just health` - System health checks
- `just vim-health` - Neovim health checks
- `just gnome-check` - make sure we haven't aquired a gnome dependency
- `just deploy` - Apply to am and torag, if torag is not up ask me to go do that.
- `just test-remote-builds` - Verify remote build infrastructure (am <-> torag) still works
- run all the above checks on torag too

Compare health check results against `~/conf/failures.md` which documents the known pre-existing failures baseline. Only flag **new** errors/warnings that aren't already in the baseline. Update `failures.md` if failures are resolved or new ones appear.

### Step 7: Write the report to `update-reports/`

Save the full report as `~/conf/update-reports/YYYY-MM-DD.md` (using today's date). Include:
- Build status (all commands run and their results)
- Table of all updated inputs with commit counts
- Table of **all** nixpkgs package changes affecting the config (not just highlights)
- Any BREAKING flags and whether they affect this config
- New/removed packages in the closure
- Notes on anything to monitor or follow up on

See existing reports in `update-reports/` for the format.

### Step 8: Suggest tests and concerns

Run a general websearch for breaking changes as well as websearches for any significant updates.
Based on the report suggest things that may be broken and suggest ways to verify they work.


## nixpkgs Analysis Details

The `nixpkgs-changelog` script:

1. **Extracts packages** from your config using `nix eval`:
   - `environment.systemPackages`
   - `home-manager.users.*.home.packages`

2. **Fetches commits** from the GitHub API

3. **Filters** commits to only those matching your packages:
   - Parses commit messages like `hyprland: fix substituteInPlace pattern (#480983)`
   - Matches the package name against your config

4. **Fetches PR details** for matched commits:
   - PR body with migration notes
   - Labels (breaking changes are often labeled)
   - Merge date

## Options

```bash
flake-update [--dry-run] [--no-fetch] [flake-path]
```

- `--dry-run` - Don't run `nix flake update`, just analyze current vs previous git commit
- `--no-fetch` - Skip fetching commits from GitHub/GitLab (faster, less detail)

## Standalone nixpkgs Analysis

To analyze nixpkgs changes without running a full update:

```bash
nixpkgs-changelog <old-rev> <new-rev> [--json]
```

Example:
```bash
nixpkgs-changelog a6531044f6d0bef691ea18d4d4ce44d0daa6e816 e4bae1bd10c9c57b2cf517953ab70060a828ee6f
```

## Troubleshooting

### Rate limiting
If GitHub API rate limits are hit, the scripts will:
- Show warnings in the output
- Return partial data where available
- Continue processing other inputs

Wait a few minutes and retry, or use `--no-fetch` for a quick overview.

### nix eval failures
If `nix eval` fails to extract packages (e.g., functions in config):
- The script falls back to grep-based extraction
- Some packages may be missed
- Check `/tmp/flake-update/config-packages.txt` to see what was extracted

### Missing matches
If you think commits were missed:
1. Check the package list: `cat /tmp/flake-update/config-packages.txt`
2. Verify the package name matches nixpkgs conventions
3. Some packages have different names in nixpkgs vs derivation output
