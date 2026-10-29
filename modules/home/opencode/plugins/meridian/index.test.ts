import assert from "node:assert/strict"
import test from "node:test"

import { Plugin } from "@opencode/plugin"

import meridian from "./index.ts"

type Event = { agent: string; sessionID: string; request: Request; kind: string }

async function setup(directory: string, canonical = directory, options: Record<string, unknown> = {
  workDirectory: "/home/user/Code/work",
  workProfile: "default",
  personalProfile: "personal",
}) {
  let hook: ((event: Event) => Promise<void>) | undefined
  const modes: Record<string, string> = { build: "primary", expert: "subagent", "custom\u200b": "all" }
  const context = {
    options,
    location: { directory, project: { canonical } },
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
  return hook
}

test("Meridian scopes headers to Anthropic and classifies V2 auxiliary requests", async () => {
  const hook = await setup("/home/user/conf")
  const requests = new Set<string>()
  for (const [agent, kind, mode, name, session] of [
    ["build", "primary", "primary", "build", "ses_test"],
    ["expert", "primary", "subagent", "expert", "ses_test"],
    ["build", "title", "subagent", "build", "ses_test:title"],
    ["build", "generate", "subagent", "build", "ses_test:generate"],
    ["build", "compaction", "subagent", "build", "ses_test"],
    ["custom\u200b", "primary", "primary", "custom", "ses_test"],
  ] as const) {
    const request = new Request("http://localhost/v1/messages", { headers: { "x-existing": "preserved" } })
    await hook({ agent, kind, request, sessionID: "ses_test" })
    assert.equal(request.headers.get("x-opencode-session"), session)
    assert.equal(request.headers.get("x-opencode-agent-mode"), mode)
    assert.equal(request.headers.get("x-opencode-agent-name"), name)
    assert.equal(request.headers.get("x-existing"), "preserved")
    const id = request.headers.get("x-opencode-request")
    assert.ok(id)
    assert.ok(!requests.has(id))
    requests.add(id)
  }
})

test("Meridian profile follows the location's work directory", async () => {
  for (const [directory, canonical, profile] of [
    ["/home/user/Code/work", "/home/user/Code/work", "default"],
    ["/home/user/Code/work/grim/src", "/home/user/Code/work/grim", "default"],
    ["/home/user/.local/share/opencode/worktree/abc/fix", "/home/user/Code/work/grim", "default"],
    ["/home/user/Code/workshop", "/home/user/Code/workshop", "personal"],
    ["/home/user/conf", "/home/user/conf", "personal"],
  ] as const) {
    const hook = await setup(directory, canonical)
    const request = new Request("http://localhost/v1/messages")
    await hook({ agent: "build", kind: "primary", request, sessionID: "ses_test" })
    assert.equal(request.headers.get("x-meridian-profile"), profile, directory)
  }
})

test("Meridian leaves profile selection to the proxy without options", async () => {
  const hook = await setup("/home/user/conf", "/home/user/conf", {})
  const request = new Request("http://localhost/v1/messages")
  await hook({ agent: "build", kind: "primary", request, sessionID: "ses_test" })
  assert.equal(request.headers.get("x-meridian-profile"), null)
})
