---
name: Unslop
description: Rewrite prose to remove AI writing tells while preserving its meaning and intended tone. Use when the user asks to unslop, de-AI, humanize, or tighten writing.
license: MIT
metadata:
  opencode/autoinvoke: false
---

# Unslop

Edit prose to sound direct, specific, and human. Preserve its meaning and match
the intended audience and tone.

## Process

1. Scan for the patterns below.
2. Rewrite the text, not merely the flagged words.
3. Restore a human voice where cleanup made the prose sterile.
4. Ask: "What still makes this obviously AI-generated?" Fix those tells.

## Add A Human Voice

- Have opinions when the author is meant to have one. React instead of
  mechanically listing pros and cons.
- Vary rhythm. Mix short sentences with longer ones.
- Acknowledge real complexity instead of flattening every conclusion.
- Use first person when it fits the author and audience.
- Allow slight irregularity. Perfectly repeated structure reads as generated.
- Prefer concrete facts, mechanisms, examples, and numbers.

Do not invent personality, facts, certainty, or opinions that the source does
not support.

## Content Tells

- Cut puffery such as "pivotal moment", "testament to", "evolving landscape",
  "setting the stage for", and "indelible mark". State what happened.
- Replace promotional adjectives with neutral, specific descriptions.
- Name sources behind vague claims such as "experts believe", or remove the
  unsupported attribution.
- Delete superficial participle phrases such as "highlighting", "showcasing",
  and "fostering", or expand them into a concrete claim.
- Replace formulaic "despite challenges" conclusions with the relevant facts.
- Do not name-drop publications, people, or products without explaining why
  they matter.

## Language Tells

- Prefer plain words. Replace words such as "delve", "utilize", "leverage",
  "facilitate", "intricate", "pivotal", "tapestry", "underscore", and
  abstract uses of "landscape".
- Use "is" and "has" instead of "serves as", "stands as", "boasts", or
  "features" when they mean the same thing.
- State the point directly instead of using "not just X, but Y".
- Do not force ideas into groups of three.
- Pick one term for a concept instead of cycling through synonyms.
- Use "from X to Y" only when X and Y form a meaningful range.
- Replace abstract technical metaphors with the concrete mechanism. Common
  offenders include substrate, vector, locus, nexus, primitive, harness,
  surface, scaffolding, paradigm, ratchet, endgame, north star, and flywheel.

## Style Tells

- Avoid em dashes. Split the sentence or use a comma.
- Use colons for lists or examples, not as routine sentence connectors.
- Do not bold every proper noun, acronym, or bullet label.
- Avoid inline-header lists where a bold label merely repeats the sentence.
- Use sentence case for headings.
- Remove decorative emoji.
- Match the document's quote style; default to straight quotes.

## Chat Tells

- Remove stock phrases such as "I hope this helps", "Of course", "Certainly",
  "Let me know if", and "Found the smoking gun".
- Remove cutoff disclaimers. Find the missing facts or omit the claim.
- Respond directly instead of praising the prompt or agreeing
  sycophantically.

## Filler And Clarity

- Shorten filler: "in order to" becomes "to" and "due to the fact that"
  becomes "because". Delete "it is important to note that".
- Reduce stacked hedges to the minimum uncertainty the evidence requires.
- Replace generic conclusions with specific facts, decisions, or next steps.
- Say what something does, not how it feels. If a sentence could appear
  unchanged in another project's docs, make it specific or cut it.
- Split sentences that require backtracking. Prefer one idea per sentence.
- Prefer active voice when the actor matters or is known.
- Cut adverbs that prop up weak verbs. Use the stronger verb or measured fact.

This skill is adapted from Lauren Tan's `unslop` skill. See `UPSTREAM.md` and
`LICENSE` in this skill directory.
