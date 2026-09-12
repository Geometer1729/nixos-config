---
name: Failure Baseline
description: Maintain this NixOS configuration repository's failures.md baseline. Use when checking whether warnings or failures are tracked, recording new findings, reconciling check results, or removing resolved entries from the baseline.
---

# Failure Baseline

Keep `failures.md` an evidence-backed inventory of outstanding warnings and
failures, including evaluation, build, activation, and runtime checks.
Repository paths below refer to the active configuration worktree.

## 1. Establish Scope And Evidence

Read that worktree's `failures.md`, repository instructions, and the health/test
command definitions in `justfile` and the calling workflow. Map every required
check to the structure below; extend it when the commands change. Inspect recent
`update-reports/` entries when they may explain a regression or historical
finding.

- For a coverage question, compare the reported findings with the file and
  answer which are tracked. Edit it when maintenance is requested or another
  workflow calls for reconciliation.
- Reuse results already collected for the configuration under review. Record
  which host/configuration, check, and revision or generation each result covers.
- Run only the missing checks needed for the requested scope. When called by
  another workflow, that workflow owns its required checks and deployments.
  Maintaining the baseline alone does not require updating inputs or deploying.
- Historical reports establish context; they do not prove a failure still
  occurs or has been fixed. Keep unavailable hosts and unrun checks unverified.

Before reconciling, identify the findings being compared, their evidence, and
the portions of the baseline that were actually checked.

## 2. Reconcile Findings

Compare against the baseline at the start of the calling workflow, or this
standalone maintenance pass. Keep that comparison fixed across local and remote
batches:

- **New:** an observed warning or failure has no matching entry.
- **Changed:** the signature, affected scope, impact, or follow-up differs.
- **Unchanged:** the observation matches an existing entry.
- **Resolved:** the relevant check now passes under conditions that exercise
  the original failure. A quiet journal slice alone does not resolve an
  intermittent or boot-time issue.
- **Unverified:** the relevant check, host, or reproduction conditions were
  unavailable. Preserve the entry and state the verification gap.

Group repeated messages by root cause when supported by evidence, retaining
their affected hosts/configurations and profiles. Distinguish a command's exit
status from warnings in its output: a passing check can still produce findings.
State unknown causes as unknown rather than inferring that a warning is harmless.

Recording a new failure does not make it an accepted baseline exception for the
current workflow. Report it as new against the starting baseline and preserve
the originating workflow's failure and escalation requirements.

## 3. Maintain The File

Use this structure, retaining applicable sections even when clean or unverified:

| Section | Evidence to record |
| --- | --- |
| `## Evaluation warnings` — mandatory | Warnings from flake evaluation, builds, and activation commands. Deduplicate by cause and identify affected configurations/profiles, including installer-only findings. |
| `## Flake checks` | `nix flake check`: failing check derivations, covered systems, and whether checks were built. `--no-build` verifies evaluation only. Keep its evaluation warnings in the mandatory section above. |
| `## <host>` → `### Build and activation` | `nh os build` / `just build`, and `nh os test` / `nixos-rebuild test`; include deployment activation results when available. Distinguish a successful build from successful activation. |
| `## <host>` → `### just health` | Results from every component of the current recipe: failed systemd units, boot-journal errors, filesystem usage, and Syncthing checks. |
| `## <host>` → `### just vim-health` | Neovim health warnings and errors, including diagnostics printed by a command that exits successfully. |
| `## <host>` → `### just gnome-check` | Findings from `got-gnomed`, as invoked by the recipe. |
| `## <host>` → `### Post-deployment boot checks` | When the workflow requires a reboot: expected configuration, running kernel, and `systemctl --failed` after boot. |
| `## Remote builds (just test-remote-builds)` | Results of the remote-build checks, identifying the initiating host and affected build direction. |

Use the health-command subsections on each host where those checks apply.
Place wrapper commands such as `just test` and `just deploy` under their
underlying checks rather than duplicating findings. Retain the exact commands
and target hosts in verification notes, including remote invocations.

The evaluation section must explicitly say `Clean` with verification evidence
when there are no warnings, or `Unverified` when evaluation was not checked.
Other sections likewise need findings, a dated passing result, or an explicit
verification gap. Historical passing results must retain their original date.

For each new or changed entry, include:

- a recognizable, concise message or signature;
- the affected scope and producing check;
- the known impact or cause, distinguishing evidence from uncertainty;
- the next action, or an evidence-backed reason no action is needed.

Remove resolved entries from the outstanding inventory after verification.
Keep unchecked entries intact. Date the checked scope and include its revision
or generation when needed to identify the tested configuration; advance a
file-wide baseline stamp only after checking everything it covers. Keep raw
logs and detailed history in the calling workflow's artifacts or report.

## Completion

- Coverage-only answers identify tracked and untracked findings without
  implying fresh verification.
- After maintenance, every finding in scope is matched to an entry or
  accounted for as resolved.
- Every addition, change, and removal has supporting evidence for its scope.
- `Evaluation warnings` exists, and every health/test command in scope maps to
  a section with findings or an explicit verification status.
- Unchecked hosts and checks remain visibly unverified, not implicitly clean.
- Review the diff for accidental changes to unrelated baseline entries.
- Summarize new, changed, and resolved findings plus verification gaps. Avoid
  replaying unchanged baseline noise; retain any still-blocking result.
