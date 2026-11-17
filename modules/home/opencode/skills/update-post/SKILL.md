---
name: Update Post
description: Draft Brian's geoSurge FAPS update for #fap by reconstructing his work since his last post from GitHub, Linear, and Slack. Use when asked for a daily work update, FAP/FAPS post, or end-of-day post.
---

# Update Post

Draft an outcome-oriented update for the `#fap` Slack channel. Do not send it
or create a Slack draft unless Brian explicitly asks after reviewing the text.

## The Standard

A FAPS tells a colleague who doesn't know Brian's work what changed and why it
matters to the company. It reports outcomes, not activity. Cognivore (Jons,
`U08CNRV083H`) reviews these posts; this standard comes from their feedback.

Every bullet passes the **colleague test**: someone outside the project can
tell, in under 10 seconds and without opening the issue, what is now true and
why they should care.

- State the result, then its consequence in a few words. Cognivore: "6 extra
  words, 67% extra people understand what this is and why."
- Name the specific thing: which page, which customers, which connector.
- For a fix, say where it was confirmed ("confirmed in prod", "tested with a
  browser agent"). Replace "just works" with the observed behaviour.
- A meeting or discussion counts only through its result: a decision, a
  finding, or an open dependency. A meeting with no result is not an A.
- Drop what colleagues don't need. It is noise, not credit.
- State consequences plainly. Don't inflate scale or importance.
- Link where the details live (Loom, decision thread, PR) when a reader would
  need them. No evidence appendix or source citations.

### Sections

Sections are F, A, P, S, in that order. Omit empty sections.

```text
# F
- [COR-78] Kitchenix corpus still not handed to Pedro: blocked on the scrape rework

# A
- [COR-74] Fixed duplicated headings in the Elliptic mirror, confirmed in prod

# P
- [BRD-132] Connect a real Notion workspace on prod; close the issue if it works

# S
- [BRD-77] Meta connector untestable until Meta approves the app; only test accounts can connect
```

- **F**: items from the last post's P that didn't get done, then mistakes with
  real consequences (took a customer site down, told people wrong
  information). Not every bug found or test that failed along the way. Say it
  plainly; Cognivore wants failures reported openly, not every post all A.
- **A**: last post's P items that got done, plus unplanned results worth a
  colleague's attention. Unplanned work that keeps recurring is a planning
  problem; mention it to Brian rather than hiding it.
- **P**: the next workday's plan, each with a done condition someone could
  check tomorrow. Apply the **IDE check**: if opening the IDE and poking
  around would count as doing it, it is not a plan. "Continue", "try", "look
  into", "investigate", and "keep exploring" need the outcome that ends them.
  Keep tomorrow's outcome separate from longer-term goals. When the outcome
  can't be planned yet, say so and commit to when it will be: "Can't scope X
  until I know how Y works; will by Fri."
- **S**: waiting on an outside event, decision, or person. Name who or what,
  and what it unblocks.

### Rewrites From Real Feedback

| Before | After |
| --- | --- |
| inaugural data <> corpus meeting | Held the first data–corpus meeting; decided [decision]; next [follow-up] |
| Cut a release and generated some articles with GLM 5.3 in prod | GLM 5.3 now writes prod articles, so corpus is no longer watermarked ([evidence]) |
| Translations just work now unclear why added fallback | Translations [observed behaviour], checked by [how]; fallback [added / proposed] |
| P: continue trying to benchmark agents navigating customer sites | P: [N] FAQ questions about [site] scored against Claude's answers, results in [place] |
| Made topical voting recover from transient upstream failures and invalid candidate selections | Fixed topic generation crashes (we now retry) |

Brackets mark facts to find in the evidence or ask Brian for; never invent
them. A good example from Brian's own posts: "Privacy policy now covers Connect
(live next release). It was one of the blockers for launching Connect and for
Google's app review."

### Voice

Brian's voice: blunt, short, pragmatic, not corporate. Technical terms are
fine; padding and buzzwords are not. No emojis; Brian adds his own if he wants
them. Include a Linear identifier when known.

## Workflow

### 1. Read The Last Post

Find Brian's latest reply in the `#fap` weekly `[FAP]-[WEEK N]` thread
(`C08TFUS2MU5`; it may be in the previous week's thread). Brian's Slack user ID
is `U0A1F523448`. Also read replies to his last few posts and apply any
feedback not yet covered by the standard above. Cognivore sometimes sends FAP
feedback by DM; read it only with the DM permission described under Slack.

Done when you have the last post's time (the start of the evidence window) and
its P and S items as a checklist.

### 2. Gather Evidence

Cover the window from the last post to now. Don't re-report anything the last
post already took credit for, even if the work landed after it. When drafting
after missed days, use day labels only if they make the post clearer.

Gather sources in parallel. Treat results as clues, not accomplishments.
Exclude personal repositories and unrelated activity.

```bash
SINCE=YYYY-MM-DD   # date of the last post
TOMORROW=$(date -d tomorrow +%F)
```

**GitHub.** Brian's login is `Geometer1729`; work repos are in `geosurge-ai`.

```bash
gh search commits --author Geometer1729 --owner geosurge-ai \
  --author-date=">=$SINCE" --limit 100 --sort author-date --order asc \
  --json repository,sha,commit,url

gh search prs --author Geometer1729 --owner geosurge-ai \
  --updated=">=$SINCE" --limit 100 --sort updated --order asc \
  --json repository,number,title,state,updatedAt,closedAt,url
```

Use `gh pr view <url>` when the title and state don't establish the result.
Deduplicate a branch commit and its merge commit into one outcome. If work may
be unpushed, check repos and worktrees under `~/Code/work` with `git log` and
`git status`.

**Linear.** Brian's assignee is `brian@geosurge.ai`.

```bash
linearis issues list --assignee brian@geosurge.ai \
  --updated-after "$SINCE" --updated-before "$TOMORROW" --limit 100
linearis issues list --assignee brian@geosurge.ai \
  --completed-after "$SINCE" --completed-before "$TOMORROW" --limit 100
```

`updatedAt` alone doesn't prove Brian worked on an issue. Use
`linearis issues activity <identifier>` to find the actual transition,
comment, or decision, and read the issue when its title doesn't explain why it
matters. The issue description is often where the consequence for the
colleague test comes from.

**Slack.** Search Brian's messages and thread replies in the window for
decisions, debugging results, deployments, Looms, requests, and blockers.
Private-channel and DM search needs explicit permission; ask once if this
conversation hasn't granted it. Slack discussion doesn't prove Brian built
the discussed idea.

Done when every previous P item has evidence for or against it, or is marked
unknown.

### 3. Reconcile

1. Build a private evidence list with source and confidence per candidate.
2. Merge commits, PRs, Linear activity, and Slack threads that describe one
   outcome.
3. Resolve every previous P item: done (A), not done (F), waiting (S), or
   dropped (F if dropping it was a failure; otherwise omit).
4. Add unplanned results and consequential mistakes.
5. Draft P from the follow-ups the evidence points to.

Done when every bullet is supported by evidence and every previous P item is
accounted for.

### 4. Check Against The Standard

Check every bullet against the colleague test, and every P against the IDE
check. Where a consequence, a verification, or a P done condition can't be
inferred, ask Brian one concise batch of questions (for example "What should
the Notion test prove?"). Don't ask him to reconstruct the day.

### 5. Review With Brian

Show the draft, then use the question tool to review every bullet in one
dialog: one question per bullet, with the section and full bullet text, and
exactly the choices Keep, Drop, and Rephrase. For each Rephrase without
replacement text in the free-form answer, ask for the intended wording.

Return the revised Slack-ready post. Omit sections whose last item was
dropped. Mention material uncertainty separately and briefly.

## Disclosure

End the post with one plain-text line saying how Claude was involved, by
default `Claude helped write this.` If the review left every bullet in Brian's
own words, say `Claude gathered my activity; I wrote the text.` No per-bullet
markers.

## Slack Draft

When Brian asks for a draft, create it with `slack_send_message_draft` in
`#fap` as a reply in the thread that holds his latest `#fap` post (the
`thread_ts` in that post's permalink). Slack keeps one draft per thread, and
the tool can't edit or delete it. If a draft already exists, the tool still
answers "Draft created" but creates nothing; only a response with a
`draft_id` means it worked. Before creating a replacement, ask Brian to delete
the existing draft. Get the text right before creating one.
