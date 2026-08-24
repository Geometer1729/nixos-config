# Upstream

Adapted from:

- Repository: https://github.com/mattpocock/skills
- Files: `skills/productivity/grill-me/SKILL.md` and
  `skills/productivity/grilling/SKILL.md`
- Commit: `5b15a47f2d7150f545fbcacbfe381787fc0230dc`
- Copyright: Copyright (c) 2026 Matt Pocock
- License: MIT

OpenCode-specific changes:

- Replaced Claude's `disable-model-invocation` field with
  `metadata.opencode/autoinvoke: false` on the explicit `grill-me` entry point.
- Uses OpenCode's question tool for frontier rounds.
- Removed emoji-dependent formatting.
- Added explicit scope, prototype, uncertainty, completion, and no-action
  guidance based on the upstream documentation.
