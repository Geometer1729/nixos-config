import assert from "node:assert/strict"
import { test } from "node:test"

import { Speaker } from "./speaker.ts"

// Records what plays; finish() ends the current message as the player would.
function fixture() {
  const played: string[] = []
  const stopped: string[] = []
  let finish = () => {}
  const speaker = new Speaker((text) => {
    played.push(text)
    let resolve = () => {}
    const done = new Promise<void>((settle) => (resolve = settle))
    finish = resolve
    return {
      done,
      stop: () => {
        stopped.push(text)
        resolve()
      },
    }
  })
  const tick = () => new Promise((resolve) => setImmediate(resolve))
  return { speaker, played, stopped, finish: async () => (finish(), await tick()), tick }
}

test("plays at once in the viewed session", () => {
  const { speaker, played } = fixture()
  speaker.view("a")
  speaker.add("a", "done", "replace")
  assert.deepEqual(played, ["done"])
  assert.equal(speaker.speaking, true)
})

test("holds another session's message until it is viewed", () => {
  const { speaker, played } = fixture()
  speaker.view("a")
  speaker.add("b", "waiting", "replace")
  assert.deepEqual(played, [])
  speaker.view("b")
  assert.deepEqual(played, ["waiting"])
})

test("stays silent while the terminal is unfocused", () => {
  const { speaker, played } = fixture()
  speaker.add("a", "waiting", "replace")
  speaker.view(undefined)
  assert.deepEqual(played, [])
})

test("replace keeps only the newest waiting message", () => {
  const { speaker, played } = fixture()
  speaker.add("a", "old", "replace")
  speaker.add("a", "new", "replace")
  speaker.view("a")
  assert.deepEqual(played, ["new"])
})

test("queue plays every waiting message in order", async () => {
  const { speaker, played, finish } = fixture()
  speaker.add("a", "one", "queue")
  speaker.add("a", "two", "queue")
  speaker.view("a")
  await finish()
  assert.deepEqual(played, ["one", "two"])
  await finish()
  assert.equal(speaker.speaking, false)
})

test("replace cuts off the session's current message", () => {
  const { speaker, played, stopped } = fixture()
  speaker.view("a")
  speaker.add("a", "starting", "replace")
  speaker.add("a", "failed", "replace")
  assert.deepEqual(stopped, ["starting"])
  assert.deepEqual(played, ["starting", "failed"])
})

test("leaving the session stops it and drops the rest", async () => {
  const { speaker, played, stopped, tick } = fixture()
  speaker.view("a")
  speaker.add("a", "one", "queue")
  speaker.add("a", "two", "queue")
  speaker.view(undefined)
  assert.deepEqual(stopped, ["one"])
  await tick()
  speaker.view("a")
  assert.deepEqual(played, ["one"])
})

test("stop drops the rest but later messages still play", async () => {
  const { speaker, played, tick } = fixture()
  speaker.view("a")
  speaker.add("a", "one", "queue")
  speaker.add("a", "two", "queue")
  speaker.stop()
  await tick()
  assert.equal(speaker.speaking, false)
  speaker.add("a", "three", "queue")
  assert.deepEqual(played, ["one", "three"])
})

test("switching sessions plays the newly viewed one", () => {
  const { speaker, played, stopped } = fixture()
  speaker.add("b", "for b", "replace")
  speaker.view("a")
  speaker.add("a", "for a", "replace")
  speaker.view("b")
  assert.deepEqual(stopped, ["for a"])
  assert.deepEqual(played, ["for a", "for b"])
})
