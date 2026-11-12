---
name: browse
description: Drive the user's Brave through the browse MCP server (`tools.browse.*`). Load before the first browse call; it lists the traps agents on this machine keep hitting and the cleanup that doesn't close other agents' tabs.
---

# browse

These traps come from past sessions' failed browse calls. The browse MCP
instructions cover the basics; `browse skill` prints the full upstream
reference for handoffs, network capture and recording.

## Parameters

Unknown keys are silently ignored, so a wrong name fails late or not at all.
Check a signature with `search({ namespace: "browse" })` before guessing.

- `execute` takes `timeoutMs`, not `timeout`. The default is 60 s; pass more
  for anything that visits several pages.
- `session_new` and `session_allowlist` take `allowedOrigins`.
- `handoff(message, { timeoutMs })` has its own 10-minute default. The execute
  timeout pauses during a handoff, so only the handoff's own value matters.
  Give it 30 minutes when the user may be away.

## Sessions and tabs

- Read-only sessions can't open a tab (`Target.createTarget is blocked`), so a
  fresh one can't navigate anywhere, despite the read-only example in
  `browse skill`. For inspection, use a normal session with `allowedOrigins`.
- An allowlist breaks SSO: "Continue with Google" passes through
  `accounts.google.com` and the site's own OIDC host, and a blocked redirect
  just spins. Leave the allowlist off until the user has signed in.
- Agent tabs close after 10 minutes untouched. After a longer gap, expect
  `about:blank` or "Target page, context or browser has been closed" and
  `page.goto` the URL again.
- When the user must act in a tab, use `handoff()`: it keeps the tab open while
  it waits. A tab you only mention in chat can close under the user. If a
  handoff times out, start a new one.
- `page.bringToFront()` is blocked; `handoff()` is how you show the user a tab.
- `status` and `session_list` don't start the relay, so "browse relay is not
  reachable" from them only means nothing has started it yet. `session_new` or
  `execute` starts it. Under this Nix install the CLI's `browse status` also
  reports "Setup: not installed" and "MCP: not configured"; both are expected.

## Execute code

Most failed calls were a 30 s Playwright timeout on a page that wasn't what the
script assumed: a modal over the button, an error page, a stale `ref()`. The
next call was always a snapshot. Fail fast and return the page with the error:

```js
page.setDefaultTimeout(8000)
try {
  // actions
} catch (e) {
  return { error: String(e).slice(0, 500), url: page.url(), snap: await snapshot() }
}
```

Playwright errors quote element HTML and hrefs. When URLs carry secrets, redact
them in the `catch` before returning.

`page.request` and `context.request` don't exist. Use
`page.evaluate(() => fetch(...))` for requests with the page's cookies; when the
page's CSP blocks that, use `curl` from the shell for URLs that need no login.

## Cleanup

Finish with `session_delete` on every session you created; it closes that
session's tabs. Don't call `tabs_cleanup({ idleMinutes: 0 })`, even though the
MCP instructions suggest it: it closes every idle agent tab, including other
agents' sessions, and once closed a tab the user was about to sign in to.
