---
name: Writing For Agents
description: Write or revise skills, AGENTS.md, CLAUDE.md, and referenced agent instructions for reliable invocation, low context load, and checkable completion.
license: MIT
---

# Writing For Agents

Use this reference for documents consumed by agents. Packaging differs, but
the goal is consistent: make the agent follow a predictable process without
forcing identical output.

When writing a skill, also read `SKILL-MECHANICS.md`.

## Context Pointers

A context pointer names out-of-context material and states when to load it. A
skill description is a pointer; an instruction in `AGENTS.md` naming another
file is the same mechanism.

A strong pointer:

- begins with the material or action users naturally mention;
- names each genuinely distinct trigger branch once;
- says what the target contains;
- omits identity and explanation already present in the target.

A required document behind a weak pointer is a reliability bug. Improve the
pointer before inlining the entire target.

## Two Loads

- Context load is material present on every turn, including global instructions
  and advertised skill descriptions.
- Cognitive load is what the human must remember exists and invoke manually.

Spend context load on behavior the agent must discover autonomously. Spend
cognitive load where human judgment should decide whether the workflow runs.

## Information Hierarchy

Arrange content by when the agent needs it:

1. ordered in-file steps;
2. in-file reference consulted during those steps;
3. disclosed supporting files loaded only by a clear pointer.

Inline what every execution path needs. Move branch-specific reference behind
a pointer. Keep each concept's definition, rules, and caveats together rather
than scattering them through the document.

Progressive disclosure protects attention, not merely token count. Too little
disclosure buries steps in reference. Too much hides requirements the agent
must always follow.

## Completion Criteria

Every consequential step needs a condition that distinguishes done from not
done. Strong criteria are:

- observable by the agent;
- specific enough to resist premature completion;
- exhaustive over the material that matters.

Prefer `every changed file has diagnostics checked` to `check diagnostics`.
Do not split a workflow merely to hide later work unless observing premature
completion justifies the additional handoff.

## Leading Words

Use compact concepts already present in the model's vocabulary to anchor
behavior: `frontier`, `tight loop`, `red`, `tracer bullet`, `seam`. Define a
coined term once, then repeat the term rather than its full explanation.

Prefer positive target behavior over repeated prohibitions. A prohibition
earns its place when it guards a real hazard that cannot be stated positively;
pair it with the desired behavior.

## Pruning

- Keep each rule in one authoritative location.
- Treat the environment as a source of truth. Do not cache commands, paths, or
  configuration that the agent can cheaply inspect and that may drift.
- Delete stale exposition and branches that no longer affect execution.
- Remove instructions that do not change model behavior from the default.
- Split genuine branches; do not create files merely to make the main file
  look shorter.

## Review Procedure

When creating or revising agent instructions:

1. Identify who should invoke the document and from which trigger branches.
2. Rewrite the pointer or description first.
3. Extract the ordered process and give each step a completion criterion.
4. Group reference by concept and disclose branch-specific material.
5. Replace repeated explanations with a defined leading word where useful.
6. Remove duplicated environment facts, stale sediment, and no-op advice.
7. Check that every referenced file exists and every path is relative where
   portability requires it.
8. Validate the actual platform's discovery and invocation semantics rather
   than assuming Claude, Codex, or OpenCode behave alike.

This skill is adapted from Matt Pocock's `writing-for-agents` skill. See
`UPSTREAM.md` and `LICENSE`.
