import assert from "node:assert/strict"
import { mkdtemp, writeFile } from "node:fs/promises"
import { tmpdir } from "node:os"
import { join } from "node:path"
import test from "node:test"

import { inside, mutedUntil } from "./mute.ts"

test("only a future unmute time mutes work sessions", async () => {
  const path = join(await mkdtemp(join(tmpdir(), "mute-")), "work-muted-until")
  assert.equal(await mutedUntil(path), undefined, "missing file")
  await writeFile(path, "2000\n")
  assert.equal(await mutedUntil(path, 1_999_000), 2_000_000)
  assert.equal(await mutedUntil(path, 2_000_000), undefined, "expired")
  await writeFile(path, "garbage")
  assert.equal(await mutedUntil(path, 0), undefined)
})

test("work directories include the root and its descendants only", () => {
  assert.equal(inside("/home/u/Code/work", "/home/u/Code/work"), true)
  assert.equal(inside("/home/u/Code/work/wts/GEO-1", "/home/u/Code/work"), true)
  assert.equal(inside("/home/u/Code/work-old", "/home/u/Code/work"), false)
  assert.equal(inside("/home/u/conf", "/home/u/Code/work"), false)
  assert.equal(inside("/home/u/Code/work/..foo", "/home/u/Code/work"), true)
})
