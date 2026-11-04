# Agent.md

This machine uses NixOS.
Your shell uses direnv automagically.

Feel free to use `nix-shell -p` when you want a new tool.

gh and linearis are usefull clis, for slack you have an mcp server.

Do not be afraid to raise limitations or possible mistakes I missed.
If you need to fundamentally change the plan from what I said tell me why.

Questions are usually not rhetorical.
"What's wrong with x?" does not mean fix x.

Sometimes the best solution is to ask me to solve something.
If the commit sign fails maybe I need to plug in the yubikey.
If the gcloud token is stale just run `gcloud auth login` and ask me to approve it.

When I say "let me know", notify me with `notify-send --expire-time=300000` when the requested work or wait is complete.

Use the speak tool whenever you hand control back to me with finished work, a question, or a blocker. Try to really condense the important points.

Value your dev env!
When a tool you are supposed to have does not work (a CLI, MCP server, LSP, or OpenCode itself), triage it:
- Blocking: the current task can't be finished correctly without it. Fix it inline, in `~/conf`, then continue.
- Non-blocking: a workaround leaves the task's result intact. Before continuing, file the breakage as a Taskwarrior task tagged `+agent +@computer` with a note (see the taskwarrior skill) written for a new agent that will fix it with none of your context: the exact symptom and errors, where and when it happened, how to reproduce it, what you ruled out, and where to look. Then work around it, finish the task, and give the task ID in your final reply.

When you decide to make something more complicated to fix a problem flag that.
Explain the problem and the solution and get my input on the tradeoff.

Report times in the time zone of the user.

Responsible disclosure:
When writting text other humans are likely to assume is human written disclose that it is ai written.
This does include:
- Slack messages
- linear issues
- pr descriptions
But not:
- Code comments
- Commit messages
- Factual updates to markdown files in a git repository
