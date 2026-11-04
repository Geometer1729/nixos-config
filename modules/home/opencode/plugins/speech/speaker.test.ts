import assert from "node:assert/strict"
import { test } from "node:test"

import { Speaker } from "./speaker.ts"

// Records what is prepared, plays, and is freed; finish() ends the current
// message as the player would. TUIs "t" and "u" report what they show.
function fixture() {
  const prepared: string[] = []
  const played: string[] = []
  const stopped: string[] = []
  const discarded: string[] = []
  const speaking: (string | undefined)[] = []
  let finish = () => {}
  const speaker = new Speaker((text) => {
    prepared.push(text)
    return {
      play: () => {
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
      },
      discard: () => discarded.push(text),
    }
  }, (sessionID) => speaking.push(sessionID))
  const tick = () => new Promise((resolve) => setImmediate(resolve))
  return {
    speaker, prepared, played, stopped, discarded, speaking,
    finish: async () => (finish(), await tick()),
    tick,
  }
}

test("plays at once in the viewed session", () => {
  const { speaker, played } = fixture()
  speaker.view("t", "a")
  speaker.add("a", "done", "replace")
  assert.deepEqual(played, ["done"])
})

test("prepares a message before its session is viewed", () => {
  const { speaker, prepared, played } = fixture()
  speaker.add("a", "waiting", "replace")
  assert.deepEqual(prepared, ["waiting"])
  assert.deepEqual(played, [])
})

test("holds another session's message until it is viewed", () => {
  const { speaker, played } = fixture()
  speaker.view("t", "a")
  speaker.add("b", "waiting", "replace")
  assert.deepEqual(played, [])
  speaker.view("t", "b")
  assert.deepEqual(played, ["waiting"])
})

test("stays silent while no terminal is focused", () => {
  const { speaker, played } = fixture()
  speaker.add("a", "waiting", "replace")
  speaker.view("t", undefined)
  assert.deepEqual(played, [])
})

test("plays in whichever TUI is viewing the session", () => {
  const { speaker, played } = fixture()
  speaker.view("t", "a")
  speaker.add("b", "for b", "replace")
  speaker.view("u", "b")
  assert.deepEqual(played, ["for b"])
})

test("focus moving between TUIs works with reports in either order", () => {
  const { speaker, played, stopped } = fixture()
  speaker.view("t", "a")
  speaker.add("a", "for a", "replace")
  // u reports its focus before t reports losing it.
  speaker.view("u", "b")
  speaker.view("t", undefined)
  speaker.add("b", "for b", "replace")
  assert.deepEqual(stopped, ["for a"])
  assert.deepEqual(played, ["for a", "for b"])
})

test("another TUI losing focus leaves the viewer alone", () => {
  const { speaker, played } = fixture()
  speaker.view("t", "a")
  speaker.view("u", undefined)
  speaker.add("a", "done", "replace")
  assert.deepEqual(played, ["done"])
})

test("replace keeps only the newest waiting message", () => {
  const { speaker, played, discarded } = fixture()
  speaker.add("a", "old", "replace")
  speaker.add("a", "new", "replace")
  assert.deepEqual(discarded, ["old"])
  speaker.view("t", "a")
  assert.deepEqual(played, ["new"])
})

test("queue plays every waiting message in order", async () => {
  const { speaker, played, discarded, finish } = fixture()
  speaker.add("a", "one", "queue")
  speaker.add("a", "two", "queue")
  speaker.view("t", "a")
  await finish()
  assert.deepEqual(played, ["one", "two"])
  assert.deepEqual(discarded, ["one"])
  await finish()
  assert.deepEqual(discarded, ["one", "two"])
})

test("replace cuts off the session's current message", () => {
  const { speaker, played, stopped, discarded } = fixture()
  speaker.view("t", "a")
  speaker.add("a", "starting", "replace")
  speaker.add("a", "failed", "replace")
  assert.deepEqual(stopped, ["starting"])
  assert.deepEqual(discarded, ["starting"])
  assert.deepEqual(played, ["starting", "failed"])
})

test("leaving the session stops it and drops the rest", async () => {
  const { speaker, played, stopped, discarded, tick } = fixture()
  speaker.view("t", "a")
  speaker.add("a", "one", "queue")
  speaker.add("a", "two", "queue")
  speaker.view("t", undefined)
  assert.deepEqual(stopped, ["one"])
  assert.deepEqual(discarded, ["one", "two"])
  await tick()
  speaker.view("t", "a")
  assert.deepEqual(played, ["one"])
})

test("stop drops the rest but later messages still play", async () => {
  const { speaker, played, discarded, tick } = fixture()
  speaker.view("t", "a")
  speaker.add("a", "one", "queue")
  speaker.add("a", "two", "queue")
  speaker.stop()
  await tick()
  assert.deepEqual(discarded, ["one", "two"])
  speaker.add("a", "three", "queue")
  assert.deepEqual(played, ["one", "three"])
})

test("switching sessions plays the newly viewed one", () => {
  const { speaker, played, stopped } = fixture()
  speaker.add("b", "for b", "replace")
  speaker.view("t", "a")
  speaker.add("a", "for a", "replace")
  speaker.view("t", "b")
  assert.deepEqual(stopped, ["for a"])
  assert.deepEqual(played, ["for a", "for b"])
})

test("reports which session is speaking", async () => {
  const { speaker, speaking, finish } = fixture()
  speaker.view("t", "a")
  speaker.add("a", "one", "queue")
  speaker.add("a", "two", "queue")
  await finish()
  speaker.stop()
  assert.deepEqual(speaking, ["a", undefined, "a", undefined])
})

test("close stops and frees every session's messages", async () => {
  const { speaker, played, stopped, discarded, tick } = fixture()
  speaker.add("b", "for b", "replace")
  speaker.view("t", "a")
  speaker.add("a", "for a", "replace")
  speaker.close()
  assert.deepEqual(stopped, ["for a"])
  assert.deepEqual(discarded.sort(), ["for a", "for b"])
  await tick()
  speaker.view("t", "b")
  assert.deepEqual(played, ["for a"])
})
