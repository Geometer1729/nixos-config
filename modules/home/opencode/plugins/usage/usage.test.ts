import assert from "node:assert/strict"
import { test } from "node:test"

import { claudeUsage, codexUsage, FetchError, interval, render, Source } from "./usage.ts"
import type { Usage } from "./usage.ts"

const now = Date.parse("2026-09-14T17:00:00Z")
const reset = now + 3_600_000
const usage = (label: string, used: number): Usage => ({ label, fetchedAt: now, windows: [{ label: "Weekly", used, resetsAt: reset }] })

test("the bar shows the fullest window across all accounts and the tooltip names it", () => {
  const codex = codexUsage({
    rate_limit: {
      primary_window: { used_percent: 18, limit_window_seconds: 18_000, reset_at: reset / 1000 },
      secondary_window: { used_percent: 36, limit_window_seconds: 604_800, reset_at: reset / 1000 },
    },
  }, now)
  const result = render([
    { label: "Claude work", usage: usage("Claude work", 84) },
    { label: "Claude personal", usage: usage("Claude personal", 21) },
    { label: "Codex", usage: codex },
  ], now, "America/New_York")
  assert.equal(result.text, "AI 84%")
  assert.equal(result.percentage, 84)
  assert.deepEqual(result.class, ["warning"])
  assert.match(result.tooltip, /Most used: Claude work — Weekly \(84%\)/)
  assert.match(result.tooltip, /5-hour: 18% used/)
  assert.match(result.tooltip, /2:00 PM EDT/)
})

test("model-specific and code-review limits are included; missing values are not zero", () => {
  const result = codexUsage({
    rate_limit: { primary_window: { used_percent: null } },
    code_review_rate_limit: { primary_window: { used_percent: 3 } },
    additional_rate_limits: [{ limit_name: "Model <large>", rate_limit: { primary_window: { used_percent: 97 } } }],
  }, now)
  assert.equal(result.windows.length, 2)
  const bar = render([{ label: "Codex", usage: result }], now, "America/New_York")
  assert.equal(bar.text, "AI 97%")
  assert.deepEqual(bar.class, ["critical"])
  assert.match(bar.tooltip, /Model &lt;large&gt;/)
  assert.throws(() => codexUsage({ rate_limit: null }, now), /No usage windows/)
})

test("Claude fractional utilization is converted and only the requested profile is read", () => {
  const result = claudeUsage({ profiles: [
    { id: "personal", windows: [{ type: "seven_day", utilization: 0.99 }], fetchedAt: now },
    { id: "default", windows: [{ type: "five_hour", utilization: 0.42, resetsAt: reset }, { type: "seven_day_fable", utilization: 0.84 }], fetchedAt: now },
  ] }, "default", "Claude work")
  assert.deepEqual(result.windows.map((item) => item.used), [42, 84])
  assert.equal(result.windows[1]?.label, "Weekly · fable")
  assert.throws(() => claudeUsage({ profiles: [{ id: "default", error: "no_token" }] }, "default", "Work"), /Quota unavailable/)
})

test("a failed account cannot make a partial result look complete", () => {
  const result = render([{ label: "Work", error: "Unavailable" }, { label: "Codex", usage: usage("Codex", 18) }], now, "America/New_York")
  assert.equal(result.text, "AI 18% ?")
  assert.match(result.tooltip, /Work\n  Unavailable/)
  assert.equal(render([{ label: "Codex", error: "Unavailable" }], now, "America/New_York").text, "AI ?")
})

test("stale readings and elapsed resets keep the last known maximum with a warning", () => {
  const readings = [{ label: "Work", usage: usage("Work", 99) }]
  assert.equal(render(readings, now + interval * 3, "America/New_York").text, "AI 99% ?")
  assert.match(render(readings, reset, "America/New_York").tooltip, /reset passed; awaiting fresh data/)
})

test("outages retain the last success and Retry-After prevents repeated requests", async () => {
  const source = new Source("Codex")
  const good = await source.read("account-a", async () => usage("Codex", 84), now)
  const failed = await source.read("account-a", async () => { throw new FetchError("HTTP 429", now + interval * 4) }, now + interval)
  assert.equal(failed.usage, good.usage)
  assert.equal(failed.error, "HTTP 429")
  const backedOff = await source.read("account-a", async () => { assert.fail("must respect Retry-After") }, now + interval * 2)
  assert.equal(backedOff, failed)
  const recovered = await source.read("account-a", async () => usage("Codex", 12), now + interval * 4)
  assert.equal(recovered.error, undefined)
  assert.equal(recovered.usage?.windows[0]?.used, 12)
})

test("switching or disconnecting accounts discards the previous account's cached quota", async () => {
  const source = new Source("Codex")
  await source.read("account-a", async () => usage("Codex", 99), now)
  const result = await source.read("account-b", async () => { throw new Error("private error must not leak") }, now + 1)
  assert.equal(result.usage, undefined)
  assert.equal(result.error, "Usage unavailable")
})
