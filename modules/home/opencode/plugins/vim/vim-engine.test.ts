import assert from "node:assert/strict"
import test from "node:test"
import { VimEngine, type VimUpdate } from "./vim-engine.ts"

const fixture = (text: string, cursor = 0) => {
  const engine = new VimEngine()
  engine.sync(text, cursor)
  engine.handle("Escape")
  engine.sync(text, cursor)
  let update: VimUpdate
  return {
    engine,
    get update() {
      return update
    },
    keys(sequence: string[]) {
      for (const key of sequence) update = engine.handle(key)
      return update
    },
  }
}

test("supports WORD end and backward word-end motions", () => {
  const forward = fixture("one.two three")
  assert.equal(forward.keys(["E"]).cursor, 6)

  const backward = fixture("one.two three", 11)
  assert.equal(backward.keys(["g", "e"]).cursor, 6)
  assert.equal(fixture("one.two three", 11).keys(["g", "E"]).cursor, 6)
})

test("multiplies counts before and after an operator", () => {
  const input = fixture("one two three four five six seven")
  assert.equal(input.keys(["2", "d", "3", "w"]).text, "seven")
})

test("keeps zero as an operator motion", () => {
  assert.equal(fixture("hello world", 6).keys(["d", "0"]).text, "world")
})

test("supports backward word-end operator motions", () => {
  const input = fixture("one two three", 12)
  assert.equal(input.keys(["d", "g", "e"]).text, "one tw")
})

test("supports shell-compatible edit aliases", () => {
  assert.equal(fixture("abc", 1).keys(["X"]).text, "bc")
  assert.equal(fixture("abc", 1).keys(["Y"]).text, "abc")

  const substitute = fixture("abc", 1).keys(["s"])
  assert.equal(substitute.text, "ac")
  assert.equal(substitute.mode, "insert")

  const line = fixture("one\ntwo", 0).keys(["S"])
  assert.equal(line.text, "\ntwo")
  assert.equal(line.mode, "insert")

  assert.equal(fixture("one\ntwo").keys(["Y", "j", "p"]).text, "one\ntwo\none")
  assert.equal(fixture("one\ntwo").keys(["J"]).text, "one two")
  assert.equal(fixture("aBc").keys(["3", "~"]).text, "AbC")
})

test("supports reverse find and repeating find", () => {
  const input = fixture("a-b-c-b", 6)
  assert.equal(input.keys(["F", "b"]).cursor, 2)
  assert.equal(input.keys([","]).cursor, 6)
  assert.equal(input.keys([";"]).cursor, 2)
})

test("preserves OpenCode tab motions", () => {
  assert.deepEqual(fixture("").keys(["g", "t"]).actions, [
    { type: "command", command: "session.tab.next" },
  ])
  assert.deepEqual(fixture("").keys(["g", "T"]).actions, [
    { type: "command", command: "session.tab.previous" },
  ])
})

test("reports visual and visual-line selections", () => {
  const visual = fixture("abc\ndef", 1)
  assert.deepEqual(visual.keys(["v", "l"]).selection, { start: 1, end: 3 })

  const line = fixture("abc\ndef", 1)
  assert.deepEqual(line.keys(["V", "j"]).selection, { start: 0, end: 7 })
})

test("supports search, matching delimiters, columns, and marks", () => {
  const search = fixture("one (two) three")
  assert.equal(search.keys(["/", "t", "h", "r", "e", "e", "Enter"]).cursor, 10)

  const match = fixture("one (two) three", 4)
  assert.equal(match.keys(["%"]).cursor, 8)

  const column = fixture("abcdef")
  assert.equal(column.keys(["4", "|"]).cursor, 3)

  const mark = fixture("abc\ndef", 1)
  mark.keys(["m", "a", "j", "l"])
  assert.equal(mark.keys(["`", "a"]).cursor, 1)
})

test("dot repeats native insert text synchronized by the host", () => {
  const input = fixture("ab", 1)
  assert.equal(input.keys(["i"]).mode, "insert")
  input.engine.sync("aXb", 2)
  assert.equal(input.keys(["Escape"]).mode, "normal")
  assert.equal(input.keys(["$"]).cursor, 2)
  assert.equal(input.keys(["."]).text, "aXXb")
})

test("dot repeats adapter motions and changes", () => {
  const deletion = fixture("one.two three four")
  assert.equal(deletion.keys(["d", "E"]).text, " three four")
  assert.equal(deletion.keys(["."]).text, " four")

  const substitute = fixture("abcdef", 1)
  assert.equal(substitute.keys(["s"]).text, "acdef")
  substitute.engine.sync("aXcdef", 2)
  substitute.keys(["Escape", "$"])
  assert.equal(substitute.keys(["."]).text, "aXcdeX")
})

test("the newest change wins across adapter and core repeat paths", () => {
  const native = fixture("one.two three four five")
  native.keys(["d", "E", "x"])
  assert.equal(native.keys(["."]).text, "hree four five")

  const insert = fixture("one.two three")
  insert.keys(["d", "E", "i"])
  insert.engine.sync("hi three", 2)
  insert.keys(["Escape", "0"])
  assert.equal(insert.keys(["."]).text, "hihi three")

  const cancelledReplace = fixture("abc", 1)
  cancelledReplace.keys(["s"])
  cancelledReplace.engine.sync("aZc", 2)
  cancelledReplace.keys(["Escape", "R", "Escape", "$"])
  assert.equal(cancelledReplace.keys(["."]).text, "aZZ")
})

test("substitute on an empty line does not join lines", () => {
  const input = fixture("ab\n\ncd", 3).keys(["s"])
  assert.equal(input.text, "ab\n\ncd")
  assert.equal(input.mode, "insert")
})

test("external normal-mode edits remain undoable", () => {
  const input = fixture("abc")
  assert.equal(input.keys(["x"]).text, "bc")
  input.engine.sync("bc!", 2)
  assert.equal(input.keys(["u"]).text, "bc")
  assert.equal(input.keys(["u"]).text, "abc")
})

test("starts in insert mode", () => {
  assert.equal(new VimEngine().mode, "insert")
})

test("replace mode overwrites text and is dot-repeatable", () => {
  const input = fixture("abcdef", 1)
  assert.equal(input.keys(["R"]).mode, "replace")
  assert.equal(input.engine.idle, false)
  assert.equal(input.keys(["X", "Y", "Escape"]).text, "aXYdef")
  assert.equal(input.keys(["$"]).cursor, 5)
  assert.equal(input.keys(["."]).text, "aXYdeXY")
})
