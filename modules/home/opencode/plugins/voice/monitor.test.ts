import assert from "node:assert/strict"
import { test } from "node:test"

import { changes, updateText } from "./monitor.ts"
import type { Row, Status } from "./overview.ts"

const row = (id: string, status: Status, updated = 0): Row =>
  ({ id, title: `Title ${id}`, project: "conf", directory: "/conf", status, updated })

test("announces results and new requests, not steady or quiet states", () => {
  const before = new Map<string, Status>([
    ["done", "running"], ["broke", "running"], ["ask", "running"], ["same", "finished"], ["seen", "finished"], ["busy", "idle"],
  ])
  const found = changes(before, [
    row("done", "finished"), row("broke", "failed"), row("ask", "approval"), row("same", "finished"),
    row("seen", "idle"), row("busy", "running"),
  ], 100, () => false)
  assert.deepEqual(found.map((item) => item.id), ["done", "broke", "ask"])
})

test("a session new to the list counts only if it finished since the last check", () => {
  const found = changes(new Map(), [row("old", "finished", 50), row("fresh", "finished", 150), row("q", "question", 0)], 100, () => false)
  assert.deepEqual(found.map((item) => item.id), ["fresh", "q"])
})

test("skipped sessions stay quiet", () => {
  const found = changes(new Map([["w", "running" as Status]]), [row("w", "finished")], 0, (item) => item.id === "w")
  assert.deepEqual(found, [])
})

test("the update says it is not from the user and how to deliver it", () => {
  const text = updateText([row("a", "finished"), row("b", "approval")], ["Agent: All tests pass.", undefined])
  assert.match(text, /^\[Session update\] Not from the user/)
  assert.match(text, /finished, reply not read yet: "Title a" in conf \[a\] Latest: Agent: All tests pass\./)
  assert.match(text, /needs approval: "Title b"/)
  assert.match(text, /ios_voice_say/)
})
