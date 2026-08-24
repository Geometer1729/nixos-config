---
name: To Spec
description: Synthesize the current conversation and codebase understanding into a durable implementation specification without reopening settled decisions.
license: MIT
metadata:
  opencode/autoinvoke: false
---

# To Spec

Turn the current conversation into a specification. This is synthesis, not a
new interview. Do not reopen decisions settled during grilling or invent
requirements to make the document look complete.

## Destination

Determine the destination from the user's request or repository instructions:

- a draft in the conversation;
- a named file in the repository;
- an existing Linear issue;
- a new Linear issue in a specified team or project.

If no destination was requested, return a draft in the conversation. Do not
write a file or publish to Linear implicitly. If publication was requested but
the team, project, or issue is ambiguous, ask one focused destination question
before writing.

## Process

1. Re-read the conversation and list settled decisions, assumptions, rejected
   alternatives, explicit scope, and unresolved prototype or research work.
2. Explore the current codebase enough to describe existing behavior and
   relevant module interfaces. Use repository vocabulary and respect applicable
   ADRs. Do not turn current file paths into durable requirements.
3. Identify the highest existing public seam through which the behavior can be
   verified. Prefer one seam over several. Propose a new seam only when no
   existing seam can test the behavior without coupling to implementation.
4. Use the question tool for one checkpoint on the proposed testing seams.
   This checkpoint may correct a seam but must not restart requirements
   discovery.
5. Write the specification using only established conversation and codebase
   evidence. Mark unresolved items instead of guessing.
6. Present the draft before writing a repository file or publishing externally.
   Write or publish only after the user approves both the text and destination.

## Template

```markdown
# <Feature or change>

## Problem

The observable problem from the affected user's perspective.

## Outcome

The behavior and capability that will exist when the work succeeds.

## User Stories

Numbered stories in the form: As an <actor>, I want <capability>, so that
<benefit>. Include only stories supported by the discussion.

## Implementation Decisions

Settled module responsibilities, interfaces, data or schema changes, contracts,
interactions, defaults, and rejected alternatives. Avoid volatile file paths
and speculative code snippets.

## Testing Decisions

The agreed public seams, observable behaviors, relevant prior test patterns,
and what constitutes sufficient verification.

## Out Of Scope

Explicit exclusions and deferred work.

## Open Questions

Only questions deliberately left for research, a prototype, or a later
decision. Do not hide uncertainty elsewhere in the spec.

## Notes

Supporting context that does not belong in the sections above.
```

When targeting Linear, preserve the repository's issue conventions and include
the approved spec in the issue description. Never guess a team or project and
never mutate issue state beyond what the user requested.

This skill is adapted from Matt Pocock's `to-spec` skill. See `UPSTREAM.md` and
`LICENSE`.
