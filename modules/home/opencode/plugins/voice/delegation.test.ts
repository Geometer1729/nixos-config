import assert from "node:assert/strict"
import { test } from "node:test"

import { isDelegation, parseModel, VoiceSessions, voiceWindowMs } from "./delegation.ts"

test("recognizes the phone apps' delegator prompts", () => {
  assert.ok(isDelegation("[Voice call active]\nThe user is on a live voice call\n\n[Voice delta]\nUser: hi"))
  assert.ok(isDelegation("[iPhone context] Viewing session \"Fix\" (ses_1)\n\n[Voice delta]\nUser: status?"))
  assert.ok(isDelegation("[Phone context] Viewing new session draft in conf"))
  assert.ok(isDelegation("[Outcome check] Did it send?"))
  assert.ok(!isDelegation("Voice delegation. The user is on a voice call with a voice agent"))
  assert.ok(!isDelegation("Please look at the [Voice delta] parser"))
})

test("voice mode lapses after the window", () => {
  const sessions = new VoiceSessions()
  sessions.mark("a", 0)
  assert.ok(sessions.has("a", voiceWindowMs))
  assert.ok(!sessions.has("a", voiceWindowMs + 1))
  assert.ok(!sessions.has("b", 0))
})

test("parses provider/model#variant", () => {
  assert.deepEqual(parseModel("openai/gpt-6-luna#low"), { providerID: "openai", id: "gpt-6-luna", variant: "low" })
  assert.deepEqual(parseModel("claude-agent/opus"), { providerID: "claude-agent", id: "opus" })
  assert.equal(parseModel("opus"), undefined)
  assert.equal(parseModel(undefined), undefined)
})
