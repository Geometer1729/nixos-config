import assert from "node:assert/strict"
import test from "node:test"

import { refreshQueue } from "./refresh.ts"

test("events during an in-flight snapshot force a fresh read without overlapping renders", async () => {
  const controller = new AbortController()
  const started = Promise.withResolvers<void>()
  const release = Promise.withResolvers<void>()
  let calls = 0
  let active = 0
  const queue = refreshQueue(async () => {
    assert.equal(++active, 1)
    if (++calls === 1) {
      started.resolve()
      await release.promise
    }
    active--
  }, controller.signal, (error) => assert.fail(String(error)), 0)
  queue.request()
  queue.request()
  await started.promise
  queue.request()
  queue.request()
  release.resolve()
  await queue.settled()
  assert.equal(calls, 2)
})

test("a failed snapshot is retried even when there is no subsequent event", async () => {
  let calls = 0
  const errors: unknown[] = []
  const queue = refreshQueue(async () => {
    if (++calls === 1) throw new Error("Server briefly unavailable")
  }, new AbortController().signal, (error) => errors.push(error), 0)
  queue.request()
  await queue.settled()
  assert.equal(calls, 2)
  assert.equal(errors.length, 1)
})

test("unloading cancels a queued refresh", async () => {
  const controller = new AbortController()
  let calls = 0
  const queue = refreshQueue(async () => { calls++ }, controller.signal, (error) => assert.fail(String(error)))
  queue.request()
  controller.abort()
  await queue.settled()
  queue.request()
  assert.equal(calls, 0)
})
