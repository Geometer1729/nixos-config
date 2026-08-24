# OpenCode Skill Mechanics

## Invocation

OpenCode advertises skills that have a description and do not set
`metadata.opencode/autoinvoke: false`, subject to the selected agent's ordered
`skill` permission rules. A denied skill is neither advertised nor loadable;
an `ask` rule can require approval when the skill is loaded.

Use a model-invoked skill when the agent must discover it from natural-language
triggers or another workflow needs to load it. Its description remains a small
context pointer on model turns, so include distinct trigger branches and cut
everything else.

Use an explicit-only skill when the human should decide when it runs:

```yaml
metadata:
  opencode/autoinvoke: false
```

The skill remains registered and can still be loaded explicitly by exact ID
unless a permission rule denies it. Keep its human-facing description concise.

## IDs And Layout

Use one lowercase kebab-case directory per skill with a `SKILL.md`. The skill
ID comes from the directory, not the frontmatter name. Keep supporting scripts
and reference files inside the directory and reference them relatively.

Avoid duplicate IDs unless an override is intentional. Project OpenCode skills
override global skills with the same ID.

## Router Skills

When explicit skills become difficult to remember, add one explicit router
that describes when each should be used. A router should recommend a skill,
not reproduce its instructions. Verify that the target skill can be loaded by
exact ID in the active OpenCode version.
