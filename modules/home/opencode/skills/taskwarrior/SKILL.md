---
name: Taskwarrior
description: Add Taskwarrior tasks with Markdown notes discoverable by taskopen, or search for tasks and read their linked notes.
---

# Taskwarrior

Read `~/.taskopenrc` to resolve the note path template in `notes.command` and
the annotation matched by `notes.regex` (e.g. `Notes` for `^Notes`). Use the
task's full UUID for `$UUID`. The interactive opener is `taskopen <UUID>`;
agents should read and write the Markdown file directly.

## Add a task with a note

1. Run `task add "Description"`, adding project, tags, or dates as requested.
2. Capture the ID from `Created task <ID>.`, then resolve its full UUID with
   `task _get <ID>.uuid`. Use that UUID for subsequent operations rather than
   `+LATEST`, which could select another task added concurrently.
3. Create the resolved note file and any missing parent directory. Start with
   `# Description`, then the requested Markdown content. Preserve existing
   content if the file already exists.
4. Run `task <UUID> annotate Notes` (adjust the marker to match the config).
5. Verify `task rc.context= <UUID> export` contains the matching annotation and
   read back the note. Report the task ID, UUID, and note path.

## Find a task and read its note

1. Search descriptions:
   ```sh
   task rc.context= status:pending description.has:"keyword" export
   ```
   Add `project:<project>` or `+tag` to narrow the search. `rc.context=` bypasses
   the current context for this command only. Remove `status:pending` to include
   completed, waiting, or deleted tasks when needed.
2. Select the intended task from the exported descriptions, projects, and UUIDs.
   If several remain plausible, show the candidates and ask which one.
3. Read the resolved Markdown path using its full UUID, even if the task has no
   annotation: the configured no-annotation hook also supports these notes.
   If it contains `[Redirect](path#anchor)`, read the linked document's relevant
   section and locate the `CHECKLIST:` item when present.
4. Return the relevant note content with the task identity and source path.
   If the note is absent, report that rather than invoking the interactive
   opener, which could create an empty note.
