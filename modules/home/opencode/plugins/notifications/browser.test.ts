import assert from "node:assert/strict"
import test from "node:test"
import { chmod, mkdtemp, rm, writeFile } from "node:fs/promises"
import { tmpdir } from "node:os"
import { join } from "node:path"

import { attribute, browseSession, implicitSessions, parseHandoffs, pendingHandoffs } from "./browser.ts"
import type { PendingHandoff, RunningTool } from "./browser.ts"

test("implicit browse sessions use browse's caller hash", () => {
  // printf %s ses_e292f7828ffertiYHDSNav9ue1 | sha256sum
  assert.equal(browseSession("ses_e292f7828ffertiYHDSNav9ue1"), "mcp-49348bdd")
})

test("session lists yield only waiting handoffs", () => {
  const output = JSON.stringify({ sessions: [
    { id: "waiting", handoff: { message: "Sign in", tabId: 1, startedAt: "2026-11-13T23:59:53.961Z" } },
    { id: "finished", handoff: null },
    { id: "idle" },
    { id: "no-time", handoff: { message: "Approve" } },
  ] })
  assert.deepEqual(parseHandoffs(output), [
    { session: "waiting", message: "Sign in", startedAt: "2026-11-13T23:59:53.961Z" },
    { session: "no-time", message: "Approve", startedAt: "" },
  ])
  assert.throws(() => parseHandoffs(JSON.stringify({ ok: false })), /Unexpected/)
})

test("the browse CLI is read without starting a relay, and a missing relay means nothing is waiting", async () => {
  const directory = await mkdtemp(join(tmpdir(), "oc-browse-"))
  const fake = async (body: string) => {
    const path = join(directory, `browse-${Math.random().toString(36).slice(2)}`)
    await writeFile(path, `#!${process.execPath}\n${body}\n`)
    await chmod(path, 0o755)
    return path
  }
  const signal = new AbortController().signal
  try {
    const listing = await fake(`
      if (process.env.OPENCODE_BROWSER_AUTOSTART !== "false") process.exit(3)
      if (process.argv.slice(2).join(" ") !== "session list --json") process.exit(4)
      console.log(JSON.stringify({ sessions: [{ id: "s", handoff: { message: "m", startedAt: "t" } }] }))`)
    assert.deepEqual(await pendingHandoffs(listing, signal), [{ session: "s", message: "m", startedAt: "t" }])
    const stopped = await fake(`
      console.log(JSON.stringify({ ok: false, error: { message: "Automatic relay startup is disabled; no relay is available at http://127.0.0.1:19988" } }))
      process.exit(1)`)
    assert.deepEqual(await pendingHandoffs(stopped, signal), [])
    const mismatched = await fake(`
      console.log(JSON.stringify({ ok: false, error: { message: "Running relay build a does not match CLI build b" } }))
      process.exit(1)`)
    await assert.rejects(pendingHandoffs(mismatched, signal))
  } finally {
    await rm(directory, { recursive: true })
  }
})

test("named sessions belong to the running browse call that quotes their name", () => {
  const pending = (session: string): PendingHandoff[] => [{ session, message: "m", startedAt: "t" }]
  const running = new Map<string, RunningTool[]>([
    ["ses_code", [{ name: "execute", input: { code: `await tools.browse.execute({ session: 'github-2', code: "..." })` } }]],
    ["ses_direct", [{ name: "browse_execute", input: { session: "loom", code: "await handoff('Upload')" } }]],
    ["ses_unrelated", [{ name: "shell", input: { command: "echo 'github' 'loom'" } }]],
  ])
  const implicit = implicitSessions(["ses_code", "ses_direct", "ses_unrelated"])
  const owners = (session: string) => attribute(pending(session), implicit, running).map((handoff) => handoff.sessionID)
  assert.deepEqual(owners("github-2"), ["ses_code"])
  assert.deepEqual(owners("loom"), ["ses_direct"])
  assert.deepEqual(owners("github"), [], "A name must match whole, not as part of another")
  assert.deepEqual(owners(browseSession("ses_unrelated")), ["ses_unrelated"], "Implicit sessions need no running call")
  assert.deepEqual(owners("elsewhere"), [])
})

test("a session browse renamed after session_delete is found by the handoff message in the running call", () => {
  const running = new Map<string, RunningTool[]>([
    ["ses_agent", [{ name: "execute", input: { code: `await tools.browse.execute({ code: "await handoff('Approve the payment in the bank app')" })` } }]],
    ["ses_other", [{ name: "execute", input: { code: `await tools.browse.execute({ code: "await handoff('Sign in')" })` } }]],
  ])
  const owners = (message: string) => attribute([{ session: "mcp-1a2b3c4d", message, startedAt: "t" }], new Map(), running)
    .map((handoff) => handoff.sessionID)
  assert.deepEqual(owners("Approve the payment in the bank app"), ["ses_agent"])
  assert.deepEqual(owners("Sign in"), [], "Short messages are too common to attribute")
})
