import assert from "node:assert/strict"
import test from "node:test"
import { setTimeout as sleep } from "node:timers/promises"
import type { OpenCodeClient } from "@opencode/client"

import { confirmedSnapshot, notification as render, relevantEvent, snapshot } from "./snapshot.ts"
import type { Session, Snapshot } from "./snapshot.ts"

const empty = { summary: "", body: "", key: "[]" }
const notification = (state: Snapshot) => render(state, new Set(state.sessions.map((session) => session.id)))

function session(id: string, overrides: Partial<Session> = {}): Session {
  return {
    id,
    title: id,
    location: { directory: "/repos/conf" },
    time: { created: 1, updated: 2, idle: 10 },
    outcome: "succeeded",
    ...overrides,
  }
}

function state(sessions: Session[], overrides: Partial<Snapshot> = {}): Snapshot {
  return { sessions, active: {}, permissions: [], forms: [], ...overrides }
}

test("a viewed response disappears, but viewing does not dismiss a pending request", () => {
  const ready = session("ses_ready")
  assert.match(notification(state([ready])).body, /ses_ready — ready/)
  const viewed = { ...ready, time: { ...ready.time, viewed: 10 } }
  assert.deepEqual(notification(state([viewed])), empty)
  assert.match(notification(state([viewed], { forms: [{ sessionID: viewed.id }] })).body, /— question/)
  assert.match(notification(state([viewed], { permissions: [{ sessionID: viewed.id }] })).body, /— approval needed/)
  assert.match(notification(state([{ ...viewed, time: { ...viewed.time, idle: 20 } }])).body, /— ready/)
})

test("running, archived, interrupted and child completions do not become ready rows", () => {
  const content = notification(state([
    session("ses_running"),
    session("ses_archived", { time: { created: 1, updated: 2, idle: 10, archived: 11 } }),
    session("ses_interrupted", { outcome: "interrupted" }),
    session("ses_child", { parentID: "ses_running" }),
    session("ses_failed", { outcome: "failed" }),
  ], { active: { ses_running: { type: "running" } } }))
  assert.equal(content.summary, "OpenCode · 1 session waiting")
  assert.equal(content.body, "! conf · ses_failed — failed")
})

test("nested child requests share the root row and take priority over its completion", () => {
  const sessions = [session("ses_root"), session("ses_child", { parentID: "ses_root" }), session("ses_grandchild", { parentID: "ses_child" })]
  const content = notification(state(sessions, {
    forms: [{ sessionID: "ses_child" }],
    permissions: [{ sessionID: "ses_grandchild" }, { sessionID: "ses_child" }],
  }))
  assert.equal(content.summary, "OpenCode · 1 session waiting")
  assert.equal(content.body, "🔐 conf · ses_root — approval needed")
  assert.match(notification(state(sessions, { forms: [{ sessionID: "ses_child" }] })).body, /— question/)
  assert.match(notification(state(sessions)).body, /— ready/)
})

test("rendering is deterministic, distinguishes duplicate titles, and escapes notification markup", () => {
  const sessions = [
    session("ses_bbb222", { title: "<b>Task &\n title</b>" }),
    session("ses_aaa111", { title: "<b>Task &\n title</b>" }),
    session("ses_priority", { title: "Approval" }),
  ]
  const content = notification(state(sessions, { permissions: [{ sessionID: "ses_priority" }] }))
  assert.deepEqual(content, notification(state(sessions.toReversed(), { permissions: [{ sessionID: "ses_priority" }] })))
  assert.match(content.body.split("\n")[0]!, /Approval — approval needed/)
  assert.match(content.body, /&lt;b&gt;Task &amp; title&lt;\/b&gt; \(aaa111\)/)
  assert.match(content.body, /\(bbb222\)/)
  assert.equal(content.body.split("\n").length, 3)
})

test("every snapshot re-reads all pages and pending requests in loaded locations", async () => {
  const seen: string[] = []
  let viewed = false
  let asked = true
  const location = { directory: "/repos/other" }
  const client = {
    session: {
      list: async ({ cursor }: { cursor?: string }) => {
        seen.push(cursor ?? "first")
        return cursor
          ? { data: [session("ses_second", { time: { created: 1, updated: 2, idle: 10, ...(viewed ? { viewed: 10 } : {}) } })], cursor: {} }
          : { data: [], cursor: { next: "next-page" } }
      },
      active: async () => ({}),
    },
    debug: { location: { list: async () => [location] } },
    permission: { request: { list: async (input: { location: unknown }) => {
      assert.deepEqual(input.location, location)
      return { data: asked ? [{ sessionID: "ses_second" }] : [] }
    } } },
    form: { list: async (input: { location: unknown }) => {
      assert.deepEqual(input.location, location)
      return { data: [] }
    } },
  } as unknown as OpenCodeClient
  const signal = new AbortController().signal
  assert.match(notification(await snapshot(client, signal)).body, /— approval needed/)
  viewed = true
  asked = false
  assert.deepEqual(notification(await snapshot(client, signal)), empty)
  assert.deepEqual(seen, ["first", "next-page", "first", "next-page"])
})

test("attention lifecycle events invalidate snapshots without refreshing for streamed tokens", () => {
  for (const type of [
    "server.connected", "server.instance.disposed", "session.viewed", "session.deleted", "session.renamed", "session.moved",
    "session.execution.started", "session.execution.succeeded", "session.execution.failed", "session.execution.interrupted",
    "permission.asked", "permission.replied", "form.created", "form.replied", "form.cancelled", "session.inbox.enqueued",
  ]) assert.equal(relevantEvent(type), true, type)
  for (const type of ["session.text.delta", "session.reasoning.delta", "session.usage.updated", "session.tool.progress"])
    assert.equal(relevantEvent(type), false, type)
})

test("approval confirmation suppresses Auto's short-lived requests and uses fresh session state", async () => {
  const running = state([session("ses_open")], {
    active: { ses_open: {} }, permissions: [{ sessionID: "ses_open", id: "per_auto" }],
  })
  const completed = state([session("ses_open", { title: "Finished during confirmation" })])
  let latest = running
  let reads = 0
  const result = confirmedSnapshot(async () => { reads++; return latest }, new AbortController().signal,
    () => assert.fail("No unconfirmed requests remain"))
  // The live Auto reply took 699 ms. It must disappear before confirmation.
  await sleep(700)
  assert.equal(reads, 1, "Do not confirm while Auto is still handling the request")
  latest = completed
  const current = await result
  assert.equal(reads, 2)
  assert.deepEqual(current.permissions, [])
  assert.match(notification(current).body, /Finished during confirmation — ready/)
})

test("persistent approvals are shown, while replacement requests get their own confirmation", async () => {
  const stable = { sessionID: "ses_open", id: "per_stable" }
  const old = { sessionID: "ses_open", id: "per_old" }
  const replacement = { sessionID: "ses_open", id: "per_new" }
  let current = state([session("ses_open")], { permissions: [stable, old] })
  let queued = 0
  const read = async () => current
  const first = confirmedSnapshot(read, new AbortController().signal, () => queued++)
  await Promise.resolve()
  current = { ...current, permissions: [stable, replacement] }
  const confirmed = await first
  assert.deepEqual(confirmed.permissions, [stable])
  assert.match(notification(confirmed).body, /— approval needed/)
  assert.equal(queued, 1)
  const next = confirmedSnapshot(read, new AbortController().signal, () => queued++)
  await Promise.resolve()
  assert.deepEqual((await next).permissions, [stable, replacement])
  assert.equal(queued, 1)
})

test("approval confirmation adds no delay without permissions and is cancelled on unload", async () => {
  const current = state([session("ses_open")])
  const controller = new AbortController()
  const request = () => assert.fail("No replacement request")
  assert.equal(await confirmedSnapshot(async () => current, controller.signal, request), current)
  const result = confirmedSnapshot(async () => ({ ...current, permissions: [{ sessionID: "ses_open", id: "per_wait" }] }), controller.signal, request)
  await Promise.resolve()
  controller.abort()
  await assert.rejects(result, { name: "AbortError" })
})

test("only attached roots appear, including their children's pending requests", () => {
  const snapshot = state([session("ses_old"), session("ses_open"), session("ses_child", { parentID: "ses_open" })], {
    forms: [{ sessionID: "ses_child", id: "frm_child" }],
    permissions: [{ sessionID: "ses_old", id: "per_old" }],
  })
  assert.deepEqual(render(snapshot, new Set()), empty)
  const content = render(snapshot, new Set(["ses_open"]))
  assert.equal(content.summary, "OpenCode · 1 session waiting")
  assert.equal(content.body, "❓ conf · ses_open — question")
  assert.deepEqual(render(snapshot, new Set()), empty, "last client detachment removes all statuses")
})

test("new completions and requests have distinct delivery identities even with identical text", () => {
  const first = notification(state([session("ses_open")]))
  const next = notification(state([session("ses_open", { time: { created: 1, updated: 2, idle: 20 } })]))
  assert.equal(first.body, next.body)
  assert.notEqual(first.key, next.key)
  const question = (id: string) => notification(state([session("ses_open")], { forms: [{ sessionID: "ses_open", id }] }))
  assert.equal(question("frm_first").body, question("frm_second").body)
  assert.notEqual(question("frm_first").key, question("frm_second").key)
  assert.equal(first.key, notification(state([session("ses_open"), session("ses_running")], {
    active: { ses_running: { type: "running" } },
  })).key, "unrelated activity does not reset dismissal")
})
