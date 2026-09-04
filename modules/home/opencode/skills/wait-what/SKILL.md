---
name: Wait What
description: Re-pitch the previous explanation with enough context, plain language, and the repository's own terms. Use explicitly when the last explanation did not land.
license: MIT
metadata:
  opencode/autoinvoke: false
---

# Wait What

Stop the current line of explanation and re-pitch the last message.

1. State the task or question being discussed.
2. State what has happened so far and where the work now stands.
3. Explain the key point in ASD-STE100-style Simplified Technical English:
   short sentences, one idea per sentence, common words, active voice, and
   explicit actors.
4. Use the repository's domain terms. If the repository has `CONTEXT.md` or a
   `CONTEXT-MAP.md`, read the relevant context before replying.
5. Define any technical term that the user may not know from the conversation.
6. State the decision, blocker, or next action plainly.

Do not merely shorten the previous answer. Supply the missing context and
change the explanation until it can stand on its own. Do not perform the next
action unless the user also requested it.

This skill is adapted from Matt Pocock's `wait-what` skill. See `UPSTREAM.md`
and `LICENSE` in this skill directory.
