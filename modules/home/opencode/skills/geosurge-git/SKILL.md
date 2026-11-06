---
name: geoSurge Git
description: Apply geoSurge Git, release, and dependency workflow conventions. Use when working in a geosurge-ai repository on branches, rebasing, pull requests, merging, or releases and deploys, or on changes involving GRIM and DSF.
---

# geoSurge Git

Apply these conventions in `geosurge-ai` repositories:

- Rebase feature branches onto their target branch. Do not merge the target
  branch into the feature branch.
- Merge pull requests with a merge commit. Do not squash-merge or rebase-merge
  them.
- Not stricly geosurge but github has stacked prs now! If a pr is too big
  to really be reviewable suggest spliting it.

If repository-specific instructions conflict with these conventions, surface
the conflict and ask which rule applies rather than silently choosing one.

