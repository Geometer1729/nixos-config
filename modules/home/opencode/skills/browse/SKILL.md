---
name: browse
description: Drive the user's Brave through the browse MCP server (`tools.browse.*`). Load before the first browse call; it lists the traps agents on this machine keep hitting and the cleanup that doesn't close other agents' tabs.
---

# browse

The browse MCP instructions cover the basics: tabs are the handle, `navigate`
without `tab` opens one, `handoff` waits for the user. These are the traps on
top of them. browse 0.1 replaced sessions with tabs; advice that mentions
`session_new` or `session_delete` is from the old version.

## Parameters

Check a signature with `search({ namespace: "browse" })` before guessing a
parameter name.

- `handoff` takes `timeoutSeconds` (default 600). Give it 1800 when the user
  may be away. If it times out, start a new one.
- Write the `tab` in a `handoff` call as a literal (`tab: 1651470557` or
  `tab: "work-mail"`), and its `message` as a literal sentence. The desktop
  notification finds the waiting agent by either one in the running call.

## Tabs

- Give every tab you open the same `group` label, unique to your task
  (`tabs` with `action: "new"`, `group`). It's how you close them at the end
  without touching other agents' tabs.
- An `allowedOrigins` list breaks SSO: "Continue with Google" passes through
  `accounts.google.com` and the site's own OIDC host, and a blocked redirect
  just spins. Leave it off until the user has signed in.
- Agent tabs close after 10 minutes untouched. Open a tab with
  `keepOpen: true` when the user may take longer, or expect `about:blank` or a
  missing tab and navigate again.
- When the user must act in a tab, use `handoff`: it keeps the tab open while
  it waits. A tab you only mention in chat can close under the user.
- Under this Nix install `browse status` reports "Setup: not installed" and no
  MCP config; both are expected.

## Page requests

Use the `eval` tool to `fetch` with the page's cookies. When the page's CSP
blocks that, use `curl` from the shell for URLs that need no login.

## Cleanup

Finish with `tabs` `action: "close"` and your `group`, or the `tab` ids you
opened. A tab the user lent goes back to them instead of closing.
