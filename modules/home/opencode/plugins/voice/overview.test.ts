import assert from "node:assert/strict"
import { test } from "node:test"

import { excerpts, overview, rows, search, type SessionLike } from "./overview.ts"

const session = (id: string, extra: Partial<SessionLike> = {}): SessionLike => ({
  id,
  title: `Title ${id}`,
  location: { directory: `/home/user/Code/${id}` },
  time: { updated: 1000 },
  ...extra,
})

test("orders waiting sessions before working, finished and idle ones", () => {
  const all = rows([
    session("idle", { time: { updated: 9000, idle: 5, viewed: 10 } }),
    session("done", { time: { updated: 2000, idle: 20, viewed: 10 } }),
    session("busy"),
    session("ask"),
    session("broke", { outcome: "failed", time: { updated: 1500, idle: 20 } }),
    session("seen", { outcome: "failed", time: { updated: 1400, idle: 20, viewed: 30 } }),
  ], new Set(["busy", "ask"]), new Map([["ask", [{ kind: "approval" as const, detail: "shell: git push" }]]]))
  assert.deepEqual(all.map((row) => [row.id, row.status]), [
    ["ask", "approval"], ["busy", "running"], ["broke", "failed"], ["done", "finished"], ["idle", "idle"], ["seen", "idle"],
  ])
  assert.equal(all[0]?.detail, "shell: git push")
})

test("drops children and archived sessions", () => {
  const all = rows([
    session("root"),
    session("child", { parentID: "root" }),
    session("old", { time: { updated: 1, archived: 2 } }),
  ], new Set(), new Map())
  assert.deepEqual(all.map((row) => row.id), ["root"])
})

test("overview keeps every urgent session and caps quiet ones", () => {
  const all = rows(
    [session("busy"), ...Array.from({ length: 12 }, (_, index) => session(`quiet${index}`))],
    new Set(["busy"]),
    new Map(),
  )
  const text = overview(all, 4)
  assert.match(text, /working: "Title busy" in busy \[busy\]/)
  assert.equal(text.split("\n").filter((line) => line.startsWith("- idle")).length, 3)
  assert.match(text, /\(9 more quiet sessions/)
  assert.doesNotMatch(text, /ago/)
})

test("search forgives word order and partial words", () => {
  const all = rows([
    session("a", { title: "Fix the login bug" }),
    session("b", { title: "Voice plugin", location: { directory: "/x/conf" } }),
  ], new Set(), new Map())
  assert.deepEqual(search(all, "plugin voice").map((row) => row.id), ["b"])
  assert.deepEqual(search(all, "conf").map((row) => row.id), ["b"])
  assert.deepEqual(search(all, "log").map((row) => row.id), ["a"])
  assert.deepEqual(search(all, "nothing here").map((row) => row.id), [])
})

test("excerpts keep text, note tools and skip bookkeeping", () => {
  assert.deepEqual(excerpts([
    { type: "user", text: "please fix it" },
    { type: "agent-switched" },
    {
      type: "assistant",
      content: [
        { type: "reasoning", text: "thinking" },
        { type: "text", text: "Fixed\nthe bug." },
        { type: "tool", name: "edit", state: { status: "completed" } },
        { type: "tool", name: "shell", state: { status: "running" } },
      ],
    },
    { type: "idle", outcome: "succeeded" },
  ]), [
    "User: please fix it",
    "Agent: Fixed the bug. [tools: edit, shell, one still running]",
    "(finished: succeeded)",
  ])
})
