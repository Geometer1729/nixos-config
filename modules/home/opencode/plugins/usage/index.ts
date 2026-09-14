import { rename, writeFile } from "node:fs/promises"
import { join } from "node:path"
import { setTimeout as sleep } from "node:timers/promises"

import { OpenCode } from "@opencode-ai/client"
import { Service } from "@opencode-ai/client/service"
import { Plugin } from "@opencode-ai/plugin"

import { claudeUsage, codexUsage, fetchJSON, interval, render, Source } from "./usage.ts"

const generation = Symbol("AI usage plugin generation")
interface Shared {
  generation: symbol
  contexts: Set<Plugin.Context>
  controller: AbortController
  task: Promise<void>
}
const host = globalThis as typeof globalThis & { __confAIUsage?: Shared }

async function run(shared: Shared, file: string, timezone: string) {
  const signal = shared.controller.signal
  const codex = new Source("Codex")
  const work = new Source("Claude work")
  const personal = new Source("Claude personal")
  async function update() {
    const context = shared.contexts.values().next().value
    if (!context) return
    const timeout = AbortSignal.any([signal, AbortSignal.timeout(45_000)])
    // Standalone/test servers must not overwrite the managed server's meter.
    const endpoint = await Service.discover()
    if (!endpoint) return
    const headers = Service.headers({ url: endpoint.url, ...(endpoint.auth ? { auth: endpoint.auth } : {}) })
    const client = OpenCode.make({ baseUrl: endpoint.url, headers: headers ?? {} })
    if ((await client.health.get({ signal: timeout })).pid !== process.pid) return
    // One request covers both Claude profiles, including token renewal handled
    // by Meridian. No raw credentials or upstream responses go into the cache.
    let meridian: Promise<unknown> | undefined
    const claude = () => meridian ??= fetchJSON("http://127.0.0.1:3456/v1/usage/quota/all", timeout)
    const readings = await Promise.all([
      (async () => {
        const connection = await context.integration.connection.active("openai")
        const key = connection?.type === "credential" ? connection.id : "disconnected"
        return codex.read(key, async () => {
          if (!connection || connection.type !== "credential") throw new Error("Connect ChatGPT in OpenCode")
          const credential = await context.integration.connection.resolve(connection)
          if (credential?.type !== "oauth") throw new Error("Connect ChatGPT in OpenCode")
          const accountID = credential.metadata?.accountID
          if (typeof accountID !== "string") throw new Error("OpenCode account ID unavailable")
          const raw = await fetchJSON("https://chatgpt.com/backend-api/wham/usage", timeout, {
            Authorization: `Bearer ${credential.access}`,
            "ChatGPT-Account-Id": accountID,
            Accept: "application/json",
          })
          return codexUsage(raw, Date.now())
        })
      })().catch(() => ({ label: "Codex", error: "OpenCode connection unavailable" })),
      work.read("default", async () => claudeUsage(await claude(), "default", work.label)),
      personal.read("personal", async () => claudeUsage(await claude(), "personal", personal.label)),
    ])
    if (signal.aborted) return
    const temporary = `${file}.${process.pid}.tmp`
    await writeFile(temporary, JSON.stringify(render(readings, Date.now(), timezone)), { mode: 0o600 })
    await rename(temporary, file)
  }
  while (!signal.aborted) {
    try {
      await update()
    } catch {
      if (!signal.aborted) console.error("AI usage update failed; retrying after five minutes")
    }
    await sleep(interval, undefined, { signal }).catch(() => undefined)
  }
}

export default Plugin.define({
  id: "local.ai-usage",
  setup(context) {
    const runtime = process.env.XDG_RUNTIME_DIR
    if (!runtime || !process.env.DBUS_SESSION_BUS_ADDRESS) return
    const timezone = typeof context.options.timezone === "string" ? context.options.timezone : "America/New_York"
    // Global plugins load once per location; share one poller across them, as
    // with the notification plugin. A reload drains the previous generation.
    let previous = Promise.resolve()
    if (host.__confAIUsage && (host.__confAIUsage.generation !== generation || host.__confAIUsage.controller.signal.aborted)) {
      host.__confAIUsage.controller.abort()
      previous = host.__confAIUsage.task
      delete host.__confAIUsage
    }
    const shared = host.__confAIUsage ??= (() => {
      const state: Shared = { generation, contexts: new Set<Plugin.Context>(), controller: new AbortController(), task: Promise.resolve() }
      state.task = previous.then(() => run(state, join(runtime, "opencode-ai-usage.json"), timezone))
        .catch(() => console.error("AI usage monitor stopped; Waybar will mark its last reading stale"))
      return state
    })()
    shared.contexts.add(context)
    return async () => {
      shared.contexts.delete(context)
      if (shared.contexts.size !== 0) return
      shared.controller.abort()
      await shared.task
      if (host.__confAIUsage === shared) delete host.__confAIUsage
    }
  },
})
