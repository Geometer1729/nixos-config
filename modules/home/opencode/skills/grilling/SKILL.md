---
name: Grilling
description: Grill the user relentlessly about a plan, decision, or idea. Use when the user wants to stress-test their thinking or uses a grill trigger phrase.
license: MIT
---

# Grilling

Interview the user until you reach a shared understanding. Model the subject as
a design tree: each settled decision can expose further decisions that depend
on it.

## Work In Rounds

The frontier is every unresolved decision whose prerequisites are already
settled. Ask the whole current frontier in one round, then wait for the user's
answers before recomputing it. Never ask a question whose answer depends on an
unsettled question in the same round.

Use the question tool for each round, with one question entry per frontier
item. Each question must:

- state the decision clearly and include enough context to answer it;
- offer concise choices when meaningful;
- put your recommended answer first and label it `(Recommended)`;
- explain the relevant tradeoff without pretending the recommendation is
  neutral;
- allow the user to supply another answer through the free-form option.

Do not turn one dependent chain into a batch merely to reduce the number of
rounds. A round contains independent decisions, not every question you can
imagine.

## Facts Are The Agent's Job

Do not ask the user for facts available from the environment, codebase,
documentation, issue tracker, or other tools. Investigate those facts yourself.
Use parallel subagents for independent research when useful. An unresolved
fact blocks only the decisions that depend on it; continue asking the rest of
the frontier while research runs.

The user decides goals, policy, priorities, acceptable tradeoffs, and product
behavior. Do not silently turn your recommendation into their decision.

## Control Scope

- If the subject is too large for one coherent interview, propose smaller
  scopes and ask which one to grill first.
- If a question can only be answered by experiencing appearance, interaction,
  performance, or feel, identify it as requiring a prototype or experiment
  rather than forcing a verbal answer.
- Treat `I don't know` as a valid result. Determine whether the uncertainty
  needs research, a prototype, an explicit default, or deferred judgment.
- Do not manufacture low-value questions to make the interview exhaustive.

## Finish

The interview is complete when the frontier is empty: the material branches
have been visited and no known consequential decision remains silently
assumed. This is a practical judgment, not proof of completeness.

Summarize:

1. settled decisions;
2. explicit defaults and assumptions;
3. rejected alternatives and why;
4. unresolved questions requiring research or a prototype;
5. agreed scope and out-of-scope work.

Use the question tool to ask whether the summary represents shared
understanding. Do not implement, create a specification, or modify files until
the user separately requests the next action.

This skill is adapted from Matt Pocock's `grilling` skill. See `UPSTREAM.md`
and `LICENSE` in this skill directory.
