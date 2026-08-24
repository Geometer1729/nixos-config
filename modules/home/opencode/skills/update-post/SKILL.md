---
name: Update Post
description: Draft Brian's daily geoSurge update post (FAPS) by reconstructing his work from GitHub, Linear, and Slack. Use when asked for a daily work update or end-of-day post.
---

# Update Post

Draft an evidence-based update for the `#fap` Slack channel. Do not send or
create a Slack draft unless Brian explicitly asks after reviewing the text.

## Format

The sections are Failure, Achievement, Planned, and Suspense.

```text
# F
- A meaningful mistake, failed attempt, or missed commitment

# A
- [NIN-123] A completed result or concrete progress

# P
- [COR-45] Work planned for the next workday

# S
- Work awaiting an external event, decision, or help
```

Omit empty sections. Usually A is the largest section. Keep each bullet terse
and outcome-oriented. Include a Linear identifier when known, but do not add
source citations or an evidence appendix to the post. Combine low-level
commits that produced one outcome. Do not claim that something shipped,
deployed, or was fixed unless the evidence supports that state.

F is not a list of every failed test or debugging attempt. Include only a
notable wrong turn, failed experiment, avoidable mistake, or commitment that
was not met. P is the concrete next work Brian plans to do, not a generic
backlog. S is for work in suspense because it awaits an event, decision, or
help from someone else.

## Evidence Window

Use today in the machine's local timezone unless the user supplies another
date or range.

```bash
DATE=$(date +%F)
NEXT_DATE=$(date -d "$DATE + 1 day" +%F)
```

When drafting after missed days, cover exactly the requested range and use the
day labels Brian uses only when they make the combined post clearer.

## Gather Evidence

Gather independent sources in parallel where possible. Treat all results as
clues, not accomplishments. Exclude personal repositories and unrelated
activity.

### GitHub

Brian's GitHub login is `Geometer1729`; work repositories are in the
`geosurge-ai` organization.

```bash
gh search commits \
  --author Geometer1729 \
  --author-date="$DATE" \
  --owner geosurge-ai \
  --limit 100 \
  --sort author-date \
  --order asc \
  --json repository,sha,commit,url

gh search prs \
  --author Geometer1729 \
  --owner geosurge-ai \
  --updated="$DATE" \
  --limit 100 \
  --sort updated \
  --order asc \
  --json repository,number,title,state,updatedAt,closedAt,url
```

Inspect relevant PRs with `gh pr view <url>` when the title and state do not
establish the result. Commit search can contain both a branch commit and its
merge commit; deduplicate those into one outcome. If work may be unpushed,
inspect likely repositories and worktrees under `~/Code/work` with `git log`
and `git status` rather than assuming GitHub is complete.

### Linear

Brian's Linear assignee is `brian@geosurge.ai`.

```bash
linearis issues list \
  --assignee brian@geosurge.ai \
  --updated-after "$DATE" \
  --updated-before "$NEXT_DATE" \
  --limit 100

linearis issues list \
  --assignee brian@geosurge.ai \
  --completed-after "$DATE" \
  --completed-before "$NEXT_DATE" \
  --limit 100
```

An issue's `updatedAt` alone does not prove Brian worked on it. Use
`linearis issues activity <identifier>` for candidate issues to identify the
actual transition, comment, or decision. Read the issue when its title is not
enough to describe the outcome. In-progress issues are candidates for P only
when today's evidence shows they were deferred or remain the immediate
follow-up.

### Slack

Brian's Slack user ID is `U0A1F523448`, and `#fap` is `C08TFUS2MU5`.

Search Brian's messages on the target date for decisions, debugging outcomes,
deployments, Looms, requests, and blockers. Search both messages and thread
replies. Private-channel and DM search requires explicit permission; if that
permission has not already been granted in the current conversation, ask once
before using it.

Also read Brian's latest posts in `#fap` to:

- avoid repeating an achievement already reported;
- carry a previous P forward only when it is still the immediate plan;
- match his terse wording and section ordering.

Slack discussion is not proof that Brian implemented the discussed idea.
Distinguish suggestions and plans from completed work.

## Reconcile And Draft

1. Build a private evidence list with the source and confidence for each
   candidate item.
2. Merge commits, PRs, Linear activity, and Slack discussion that describe the
   same outcome.
3. Classify only supported items into F, A, P, or S.
4. Ask one concise follow-up if important work is ambiguous or if F/P/S cannot
   be inferred. Do not ask Brian to reconstruct the entire day.
5. Show the initial draft, then use the question tool to review every bullet.
   Put all bullets in one question dialog, with one question per bullet and
   exactly these choices: Keep, Drop, and Rephrase. Include the section and
   full bullet text in each question so it can be judged independently.
6. Keep or remove bullets according to the answers. For every Rephrase answer,
   ask a short follow-up for the intended wording unless Brian supplied the
   replacement through the dialog's free-form answer.
7. Return the revised Slack-ready draft without an evidence appendix. Omit any
   section whose last item was dropped. Mention material uncertainty
   separately and briefly.

Never post the result automatically.
