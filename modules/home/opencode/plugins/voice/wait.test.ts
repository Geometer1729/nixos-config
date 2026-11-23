import assert from "node:assert/strict"
import { test } from "node:test"

import { sendGraceMs, settles, waitUntil } from "./wait.ts"

test("a session settles once its sent work is done, not before it starts", () => {
  const base = { idle: 100, ran: false, started: 1000, sent: undefined, now: 1000 }
  assert.ok(settles(undefined, base), "unknown sessions are reported")
  assert.ok(settles("approval", base))
  assert.ok(!settles("running", base))
  assert.ok(settles("idle", base), "idle with nothing sent: report it now")
  // Sent at 900 and finished at 950, before the wait began at 1000 (the bug this guards).
  assert.ok(settles("finished", { ...base, sent: 900, idle: 950 }))
  // Sent at 900 but still idle from 100: it hasn't started yet.
  assert.ok(!settles("idle", { ...base, sent: 900 }))
  assert.ok(settles("idle", { ...base, sent: 900, now: 900 + sendGraceMs }), "gives up on work that never starts")
  assert.ok(settles("finished", { ...base, sent: 900, ran: true }))
})

const never = (signal: AbortSignal) => new Promise<void>((resolve) => signal.addEventListener("abort", () => resolve()))

test("returns the first result, checking again on each wake", async () => {
  let checks = 0
  const outcome = await waitUntil({
    signal: new AbortController().signal,
    timeoutMs: 5000,
    pollMs: 5000,
    wakes: async (signal, wake) => {
      setTimeout(() => wake(), 10)
      await never(signal)
    },
    check: async () => ++checks >= 2 ? "done" : undefined,
  })
  assert.deepEqual(outcome, { type: "result", result: "done" })
  assert.equal(checks, 2)
})

test("stops when the user speaks", async () => {
  const outcome = await waitUntil({
    signal: new AbortController().signal,
    timeoutMs: 5000,
    pollMs: 5000,
    wakes: async (signal, wake) => {
      setTimeout(() => {
        wake("update")
        wake("user_spoke")
        wake("update")
      }, 10)
      await never(signal)
    },
    check: async () => undefined,
  })
  assert.deepEqual(outcome, { type: "user_spoke" })
})

test("stops for a session update", async () => {
  const outcome = await waitUntil({
    signal: new AbortController().signal,
    timeoutMs: 5000,
    pollMs: 5000,
    wakes: async (signal, wake) => {
      setTimeout(() => wake("update"), 10)
      await never(signal)
    },
    check: async () => undefined,
  })
  assert.deepEqual(outcome, { type: "update" })
})

test("times out after a last check, and passes first only once", async () => {
  const firsts: boolean[] = []
  const outcome = await waitUntil({
    signal: new AbortController().signal,
    timeoutMs: 30,
    pollMs: 10,
    wakes: never,
    check: async (first) => {
      firsts.push(first)
      return undefined
    },
  })
  assert.deepEqual(outcome, { type: "timeout" })
  assert.equal(firsts[0], true)
  assert.ok(firsts.length >= 3 && firsts.slice(1).every((first) => !first))
})

test("rejects when aborted and stops the event pump", async () => {
  const controller = new AbortController()
  let pumpStopped = false
  const waiting = waitUntil({
    signal: controller.signal,
    timeoutMs: 5000,
    pollMs: 5000,
    wakes: async (signal) => {
      await never(signal)
      pumpStopped = true
    },
    check: async () => undefined,
  })
  setTimeout(() => controller.abort(), 10)
  await assert.rejects(waiting)
  assert.ok(pumpStopped)
})
