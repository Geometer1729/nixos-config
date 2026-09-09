import assert from "node:assert/strict"
import test from "node:test"

import { Plugin } from "@opencode-ai/plugin"

import meridian from "./index.ts"

test("Meridian scopes headers to Anthropic and classifies V2 auxiliary requests", async () => {
  type Event = { agent: string; sessionID: string; request: Request; kind: string }
  let hook: ((event: Event) => Promise<void>) | undefined
  const modes: Record<string, string> = { build: "primary", expert: "subagent", "custom\u200b": "all" }
  const context = {
    agent: { get: async ({ agentID }: { agentID: string }) => ({ data: { mode: modes[agentID] } }) },
    session: {
      hook: async (name: string, callback: typeof hook, options: { providerID: string }) => {
        assert.equal(name, "http.request")
        assert.deepEqual(options, { providerID: "anthropic" })
        hook = callback
      },
    },
  }
  await meridian.setup(context as unknown as Plugin.Context)
  assert.ok(hook)
  const requests = new Set<string>()
  for (const [agent, kind, mode, name] of [
    ["build", "primary", "primary", "build"],
    ["expert", "primary", "subagent", "expert"],
    ["build", "title", "subagent", "build"],
    ["build", "compaction", "subagent", "build"],
    ["custom\u200b", "primary", "primary", "custom"],
  ] as const) {
    const request = new Request("http://localhost/v1/messages", { headers: { "x-existing": "preserved" } })
    await hook({ agent, kind, request, sessionID: "ses_test" })
    assert.equal(request.headers.get("x-opencode-session"), "ses_test")
    assert.equal(request.headers.get("x-opencode-agent-mode"), mode)
    assert.equal(request.headers.get("x-opencode-agent-name"), name)
    assert.equal(request.headers.get("x-existing"), "preserved")
    const id = request.headers.get("x-opencode-request")
    assert.ok(id)
    assert.ok(!requests.has(id))
    requests.add(id)
  }
})
