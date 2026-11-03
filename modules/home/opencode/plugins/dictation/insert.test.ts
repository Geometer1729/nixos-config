import assert from "node:assert/strict"
import { test } from "node:test"

import { insertion, insertionPoint, socketPath } from "./insert.ts"

test("names the socket after the tmux pane", () => {
  assert.equal(socketPath("/run/user/1000", "%54"), "/run/user/1000/opencode-dictation-54.sock")
})

test("inserts at the cursor outside Vim NORMAL mode", () => {
  assert.equal(insertionPoint("Done.", 5, false), 5)
  assert.equal(insertionPoint("Done.", 4, false), 4)
})

test("inserts after the character under a NORMAL-mode cursor", () => {
  assert.equal(insertionPoint("Done.", 4, true), 5)
  assert.equal(insertionPoint("", 0, true), 0)
  // An empty line's cursor sits on its newline; stay on that line.
  assert.equal(insertionPoint("one\n\ntwo", 4, true), 4)
})

test("inserts into an empty prompt unchanged", () => {
  assert.equal(insertion("", "Hello there."), "Hello there.")
})

test("separates a dictation from the word before the cursor", () => {
  assert.equal(insertion("First sentence.", "Second one."), " Second one.")
})

test("does not double existing whitespace", () => {
  assert.equal(insertion("First sentence. ", "Second one."), "Second one.")
  assert.equal(insertion("First line\n", "Second one."), "Second one.")
  assert.equal(insertion("First", " second"), " second")
})
