import assert from "node:assert/strict"
import test from "node:test"
import { chmod, mkdtemp, rm, writeFile } from "node:fs/promises"
import { tmpdir } from "node:os"
import { join } from "node:path"

import { attribute, parseHandoffs, pendingHandoffs } from "./browser.ts"
import type { PendingHandoff, RunningTool } from "./browser.ts"

test("tab lists yield only waiting handoffs", () => {
  // `browse tabs` from 0.1.6-dev.276, trimmed.
  const output = JSON.stringify({ tabs: [
    { tab: 1651470557, url: "about:blank", id: "oc-handoff-test", busy: true, handoff: { message: "Sign in", startedAt: "2026-11-24T20:39:50.712Z" }, group: "oc-test" },
    { tab: 2, busy: false },
    { tab: 3, handoff: { message: "Approve" } },
    { tab: "4", handoff: { message: "Not a tab id" } },
  ] })
  assert.deepEqual(parseHandoffs(output), [
    { tab: 1651470557, id: "oc-handoff-test", message: "Sign in", startedAt: "2026-11-24T20:39:50.712Z" },
    { tab: 3, message: "Approve", startedAt: "" },
  ])
  assert.throws(() => parseHandoffs(JSON.stringify({ sessions: [] })), /Unexpected/)
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
      if (process.argv.slice(2).join(" ") !== "tabs") process.exit(4)
      console.log(JSON.stringify({ tabs: [{ tab: 7, handoff: { message: "m", startedAt: "t" } }] }))`)
    assert.deepEqual(await pendingHandoffs(listing, signal), [{ tab: 7, message: "m", startedAt: "t" }])
    const stopped = await fake(`
      console.error("browse: automatic relay startup is disabled; no relay is running at http://127.0.0.1:19988")
      process.exit(4)`)
    assert.deepEqual(await pendingHandoffs(stopped, signal), [])
    const broken = await fake(`
      console.error("browse: the relay didn't answer")
      process.exit(1)`)
    await assert.rejects(pendingHandoffs(broken, signal))
  } finally {
    await rm(directory, { recursive: true })
  }
})

test("a handoff belongs to the running browse call that names its tab", () => {
  const pending = (tab: number, id?: string): PendingHandoff[] =>
    [{ tab, ...(id === undefined ? {} : { id }), message: "m", startedAt: "t" }]
  const running = new Map<string, RunningTool[]>([
    ["ses_direct", [{ name: "browse_handoff", input: { message: "m", tab: 1651470557 } }]],
    ["ses_code", [{ name: "execute", input: { code: `await tools.browse.execute({ tab: 'github-2', code: "await handoff('Upload')" })` } }]],
    ["ses_number", [{ name: "execute", input: { code: `await tools.browse.handoff({ message: "m", tab: 42 })` } }]],
    ["ses_cli", [{ name: "shell", input: { command: "browse handoff 'Sign in to GitHub' --tab 77" } }]],
    ["ses_unrelated", [{ name: "shell", input: { command: "echo 'github' 'tab: 42' --tab 77" } }]],
  ])
  const owners = (tab: number, id?: string) => attribute(pending(tab, id), running).map((handoff) => handoff.sessionID)
  assert.deepEqual(owners(1651470557), ["ses_direct"])
  assert.deepEqual(owners(5, "github-2"), ["ses_code"], "A named tab is found by its name")
  assert.deepEqual(owners(5, "github"), [], "A name must match whole, not as part of another")
  assert.deepEqual(owners(42), ["ses_number"])
  assert.deepEqual(owners(4), [], "A tab id must match whole")
  assert.deepEqual(owners(77), ["ses_cli"])
  assert.deepEqual(owners(99), [])
})

test("a tab an execute opened itself is found by the handoff message in the running call", () => {
  const running = new Map<string, RunningTool[]>([
    ["ses_agent", [{ name: "execute", input: { code: `await tools.browse.execute({ code: "await page.goto(url); await handoff('Approve the payment in the bank app')" })` } }]],
    ["ses_other", [{ name: "execute", input: { code: `await tools.browse.execute({ code: "await handoff('Sign in')" })` } }]],
  ])
  const owners = (message: string) => attribute([{ tab: 9, message, startedAt: "t" }], running)
    .map((handoff) => handoff.sessionID)
  assert.deepEqual(owners("Approve the payment in the bank app"), ["ses_agent"])
  assert.deepEqual(owners("Sign in"), [], "Short messages are too common to attribute")
})
