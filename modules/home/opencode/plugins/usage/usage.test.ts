import assert from "node:assert/strict"
import { test } from "node:test"

import { claudeAccounts, claudeUsage, codexUsage, FetchError, forceSpacing, interval, render, Source, staleAfter, Unavailable } from "./usage.ts"
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

test("Claude percentages and model-scoped weekly limits are read; unset windows are skipped", () => {
  const resetsAt = new Date(reset).toISOString()
  const result = claudeUsage({
    five_hour: null,
    seven_day: { utilization: 9, resets_at: resetsAt },
    seven_day_opus: { utilization: 40, resets_at: null },
    seven_day_breakdown: { rows: [] },
    limits: [
      { kind: "weekly_all", percent: 9, resets_at: resetsAt },
      { kind: "weekly_scoped", percent: 2, resets_at: resetsAt, scope: { model: { display_name: "Fable" } } },
      { kind: "weekly_scoped", percent: 41, scope: { model: { display_name: "Opus" } } },
    ],
  }, "Claude work", now)
  assert.deepEqual(result.windows, [
    { label: "Weekly", used: 9, resetsAt: reset },
    { label: "Weekly · opus", used: 40, resetsAt: null },
    { label: "Weekly · Fable", used: 2, resetsAt: reset },
  ])
  assert.throws(() => claudeUsage({ five_hour: null, limits: [] }, "Claude work", now), /No usage windows/)
})

test("Claude profiles on one account are read once with the freshest token", () => {
  const profile = (name: string, account: string, token: string, expiresAt: number) => ({
    name,
    credentials: { claudeAiOauth: { accessToken: token, expiresAt } },
    config: { oauthAccount: { accountUuid: account } },
  })
  assert.deepEqual(claudeAccounts([
    profile("work", "a", "stale", now - 1),
    profile("personal", "a", "fresh", now + 1),
    profile("other", "b", "expired", now),
    { name: "new", credentials: undefined, config: { oauthAccount: { accountUuid: "c" } } },
  ], now), [
    { label: "Claude work + personal", id: "a", token: "fresh" },
    { label: "Claude other", id: "b", error: "Sign-in expired; click the bar to renew" },
    { label: "Claude new", id: "signed-out:new", error: "Not signed in to Claude Code; click the bar to sign in" },
  ])
})

test("a failed account cannot make a partial result look complete", () => {
  const result = render([{ label: "Work", error: "Unavailable" }, { label: "Codex", usage: usage("Codex", 18) }], now, "America/New_York")
  assert.equal(result.text, "AI 18% ?")
  assert.match(result.tooltip, /Work\n  Unavailable/)
  assert.equal(render([{ label: "Codex", error: "Unavailable" }], now, "America/New_York").text, "AI ?")
})

test("stale readings keep the last known maximum with a warning", () => {
  const readings = [{ label: "Work", usage: usage("Work", 99) }]
  assert.equal(render(readings, now + staleAfter, "America/New_York").text, "AI 99%")
  assert.equal(render(readings, now + staleAfter + 1, "America/New_York").text, "AI 99% ?")
})

test("a recent reading with a fresh error is shown without the incomplete marker", () => {
  const result = render([{ label: "Work", usage: usage("Work", 40), error: "Sign-in expired; click the bar to renew" }], now + interval, "America/New_York")
  assert.equal(result.text, "AI 40%")
  assert.match(result.tooltip, /Sign-in expired; click the bar to renew — showing last known values/)
  assert.match(result.tooltip, /Click: renew sign-ins and refresh/)
})

test("an elapsed reset counts as empty rather than incomplete", () => {
  const readings = [{ label: "Work", usage: { ...usage("Work", 99), windows: [
    { label: "5-hour", used: 99, resetsAt: now + 60_000 },
    { label: "Weekly", used: 30, resetsAt: reset },
  ] } }]
  const result = render(readings, now + 120_000, "America/New_York")
  assert.equal(result.text, "AI 30%")
  assert.match(result.tooltip, /5-hour: 0% used · reset /)
})

test("outages retain the last success and Retry-After prevents repeated requests", async () => {
  const source = new Source("Codex")
  const good = await source.read("account-a", async () => usage("Codex", 84), now)
  const failed = await source.read("account-a", async () => { throw new FetchError(429, now + interval * 4) }, now + interval)
  assert.equal(failed.usage, good.usage)
  assert.equal(failed.error, "HTTP 429")
  const backedOff = await source.read("account-a", async () => { assert.fail("must respect Retry-After") }, now + interval * 2)
  assert.equal(backedOff, failed)
  const recovered = await source.read("account-a", async () => usage("Codex", 12), now + interval * 4)
  assert.equal(recovered.error, undefined)
  assert.equal(recovered.usage?.windows[0]?.used, 12)
})

test("a forced read skips backoff but not Retry-After or the minimum spacing", async () => {
  const source = new Source("Claude")
  const fail = async (): Promise<Usage> => { throw new FetchError(500) }
  await source.read("a", fail, now)
  await source.read("a", fail, now + interval)
  // Two failures: the next unforced attempt is ten minutes out.
  const waiting = await source.read("a", async () => assert.fail("still backing off"), now + interval + 60_000)
  assert.equal(waiting.error, "HTTP 500")
  await source.read("a", async () => assert.fail("too soon after the last request"), now + interval + forceSpacing - 1, true)
  const forced = await source.read("a", async () => usage("Claude", 5), now + interval + forceSpacing, true)
  assert.equal(forced.usage?.windows[0]?.used, 5)

  const limited = new Source("Claude")
  await limited.read("a", async () => { throw new FetchError(429, now + interval * 6) }, now)
  await limited.read("a", async () => assert.fail("must respect Retry-After even when forced"), now + interval, true)
  const after = await limited.read("a", async () => usage("Claude", 7), now + interval * 6, true)
  assert.equal(after.usage?.windows[0]?.used, 7)
})

test("a local precondition failure is re-checked every poll without backoff", async () => {
  const source = new Source("Claude")
  await source.read("a", async () => usage("Claude", 20), now)
  const expired = await source.read("a", async () => { throw new Unavailable("Sign-in expired") }, now + interval)
  assert.equal(expired.error, "Sign-in expired")
  assert.equal(expired.usage?.windows[0]?.used, 20, "Keeps the last good reading")
  const renewed = await source.read("a", async () => usage("Claude", 21), now + interval + 1)
  assert.equal(renewed.error, undefined)
  assert.equal(renewed.usage?.windows[0]?.used, 21)
})

test("a sign-in failure is reported for the click until an attempt succeeds", async () => {
  const source = new Source("Codex")
  const rejected = await source.read("a", async () => { throw new FetchError(401, 0, "Rejected", true) }, now)
  assert.equal(rejected.signIn, true)
  assert.deepEqual(render([rejected, { label: "Claude", usage: usage("Claude", 3) }], now, "America/New_York").signIn, ["Codex"])
  const backedOff = await source.read("a", async () => assert.fail("still backing off"), now + 1)
  assert.equal(backedOff.signIn, true, "Backoff keeps the flag")
  const other = await source.read("a", async () => { throw new FetchError(500) }, now + interval)
  assert.equal(other.signIn, undefined, "A different failure clears it")
  const recovered = await source.read("a", async () => usage("Codex", 4), now + interval * 3)
  assert.equal(recovered.signIn, undefined)
  assert.deepEqual(render([recovered], now, "America/New_York").signIn, [])
})

test("switching or disconnecting accounts discards the previous account's cached quota", async () => {
  const source = new Source("Codex")
  await source.read("account-a", async () => usage("Codex", 99), now)
  const result = await source.read("account-b", async () => { throw new Error("private error must not leak") }, now + 1)
  assert.equal(result.usage, undefined)
  assert.equal(result.error, "Usage unavailable")
})
