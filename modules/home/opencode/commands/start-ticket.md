---
description: Investigate a Linear ticket and propose next steps
agent: plan
---

Start by reading Linear issue $1 and its comments with
`linearis issues read $1 --with-comments`. Read its relations with
`linearis issues relations list $1`. Determine where implementation currently
stands; it is usually brand new, but check for existing commits, whether the
branch is pushed, any associated PR, and its review and check status. Inspect
the repository for the relevant implementation context, then propose the
appropriate next steps. Ask questions where requirements are unclear. Stay in
plan mode and do not edit files yet.
