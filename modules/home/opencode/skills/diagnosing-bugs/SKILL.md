---
name: Diagnosing Bugs
description: Diagnose hard bugs and performance regressions with a tight reproduction loop, minimization, ranked falsifiable hypotheses, and targeted instrumentation. Use for bug reports, failing behavior, and requests to diagnose or debug.
license: MIT
---

# Diagnosing Bugs

Use a disciplined loop for hard bugs. Skip a phase only with an explicit
reason. Read repository instructions, domain documentation, and relevant ADRs
before investigating.

## Respect Intent

A bug report or request to diagnose is not permission to edit code. In
diagnosis-only work, reproduce with existing interfaces, inspect evidence, and
return a root-cause assessment plus a proposed fix and verification plan. Do
not add a test harness, instrumentation, or a fix without approval.

If the user explicitly asks for a fix, continue through regression test, fix,
and cleanup. When temporary edits are required merely to diagnose, explain
them and ask first.

## Redact

Redact secrets from commands, output, logs, and captured artifacts. Keep
credentials in environment variables. Quote only the lines carrying the
diagnostic signal. If redaction removes evidence required to proceed, explain
the limitation and ask the user for a safe way forward.

## 1. Build A Tight Feedback Loop

The core task is a repeatable pass/fail signal that goes red on this exact bug.
Before running it, identify the target environment and side effects. Prefer a
local, test, or disposable environment. A loop against an external system must
be demonstrably read-only; otherwise explain the possible mutations and ask
before the first run. Never repeatedly trigger payments, notifications,
deployments, destructive actions, or production event replays as a diagnostic
loop.

Prefer, in order:

1. an existing failing test at the correct public seam;
2. an HTTP or CLI invocation with a known expected result;
3. browser automation asserting on DOM, console, or network behavior;
4. replay of a redacted request, payload, trace, or event log;
5. a minimal harness around the affected subsystem;
6. a property, fuzz, bisection, or differential loop;
7. the supporting human-in-the-loop script as a last resort.

Tighten the loop until it is:

- red-capable: asserts the user's exact symptom;
- deterministic, or has a pinned high reproduction rate;
- fast enough for repeated use;
- runnable by the agent without hidden manual steps.

Run the command at least once and show its redacted signal. A nearby failure is
not the reported bug. If no safe loop can be built, stop and list what was
tried and what access or artifact is missing. Do not compensate by guessing.

## 2. Reproduce And Minimize

Run the loop repeatedly. Confirm that it captures the reported behavior, then
remove inputs, callers, optional configuration, fixture data, and steps one at
a time. Re-run after every reduction. Minimize copies or disposable fixtures;
do not delete or mutate persistent user or production data. Finish when every
remaining element is load-bearing.

In diagnosis-only work, minimize using existing controls. Propose rather than
create new fixtures or harnesses.

## 3. Rank Hypotheses

Generate three to five ranked hypotheses before testing one. Every hypothesis
must make a falsifiable prediction:

```text
If X is the cause, changing or observing Y will produce Z.
```

Discard hypotheses that cannot predict an observation. Present the ranked list
to the user when their domain knowledge could cheaply reorder it, but continue
with the ranking when they are unavailable and investigation was authorized.

## 4. Instrument One Prediction At A Time

Prefer debugger or REPL inspection, then narrowly targeted logs. Do not log
everything and grep afterward. Tag every temporary diagnostic line with a
unique marker such as `[DEBUG-a4f2]` so cleanup is mechanically verifiable.

For performance regressions, establish a measured baseline and use profiling,
query plans, or bisection instead of speculative logs.

At the end of diagnosis-only work, report:

- the tight reproduction command and observed symptom;
- the minimized case;
- hypotheses tested and evidence that ruled them in or out;
- the most likely root cause and confidence;
- the smallest proposed fix;
- the regression seam and verification plan;
- remaining uncertainty or missing access.

Stop here unless the user asked for a fix.

## 5. Regression Test And Fix

When fixing was requested, turn the minimized reproduction into a failing test
at the public seam that captures the real bug pattern. Watch it fail, apply the
smallest fix, watch it pass, then rerun the original unminimized loop.

If no correct seam exists, do not add a shallow test that provides false
confidence. Document the missing seam as an architectural limitation.

## 6. Cleanup

Before declaring the fix complete:

- rerun the original reproduction;
- run the regression test and relevant surrounding checks;
- remove every tagged debug line;
- remove throwaway artifacts or clearly identify retained diagnostics;
- state the verified root cause and why the fix addresses it.

This skill is adapted from Matt Pocock's `diagnosing-bugs` skill. See
`UPSTREAM.md` and `LICENSE`.
