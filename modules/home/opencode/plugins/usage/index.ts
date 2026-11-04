import { readFile, rename, writeFile } from "node:fs/promises"
import { join } from "node:path"
import { setTimeout as sleep } from "node:timers/promises"

import { OpenCode } from "@opencode/client"
import { Service } from "@opencode/client/service"
import { Plugin } from "@opencode/plugin"

import { claudeAccounts, claudeUsage, codexUsage, FetchError, fetchJSON, interval, render, Source } from "./usage.ts"

const readJSON = (file: string): Promise<unknown> => readFile(file, "utf8").then(JSON.parse).catch(() => undefined)

const generation = Symbol("AI usage plugin generation")
interface Shared {
  generation: symbol
  contexts: Set<Plugin.Context>
  controller: AbortController
  task: Promise<void>
}
const host = globalThis as typeof globalThis & { __confAIUsage?: Shared }

async function run(shared: Shared, file: string, timezone: string, profiles: Record<string, string>) {
  const signal = shared.controller.signal
  const codex = new Source("Codex")
  const claude = new Map<string, Source>()
  async function update() {
    const context = shared.contexts.values().next().value
    if (!context) return
    const timeout = AbortSignal.any([signal, AbortSignal.timeout(45_000)])
    // Standalone/test servers must not overwrite the managed server's meter.
    const endpoint = await Service.discover()
    if (!endpoint) return
    const headers = Service.headers({ url: endpoint.url, ...(endpoint.auth ? { auth: endpoint.auth } : {}) })
    const client = OpenCode.make({ baseUrl: endpoint.url, headers: headers ?? {} })
    if ((await client.server.info({ signal: timeout })).pid !== process.pid) return
    // Tokens come from the files Claude Code keeps current. No raw credentials
    // or upstream responses go into the cache.
    const accounts = claudeAccounts(await Promise.all(Object.entries(profiles).map(async ([name, directory]) => ({
      name,
      credentials: await readJSON(join(directory, ".credentials.json")),
      config: await readJSON(join(directory, ".claude.json")),
    }))), Date.now())
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
      ...accounts.map((account) => {
        const source = claude.get(account.label) ?? new Source(account.label)
        claude.set(account.label, source)
        return source.read(account.id, async () => {
          if ("error" in account) throw new FetchError(account.error)
          const raw = await fetchJSON("https://api.anthropic.com/api/oauth/usage", timeout, {
            Authorization: `Bearer ${account.token}`,
            "anthropic-beta": "oauth-2025-04-20",
            Accept: "application/json",
          })
          return claudeUsage(raw, account.label, Date.now())
        })
      }),
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
    const claude = context.options.claude
    // Profile name -> CLAUDE_CONFIG_DIR.
    const profiles = claude !== null && typeof claude === "object" && !Array.isArray(claude)
      ? Object.fromEntries(Object.entries(claude).filter((entry): entry is [string, string] => typeof entry[1] === "string")) : {}
    // Ownership spans code generations: a short-lived location can load a new
    // copy while older projects remain open. Keep their contexts, and let their
    // cleanup release the current poller rather than the retired generation.
    const contexts = host.__confAIUsage?.contexts ?? new Set<Plugin.Context>()
    let previous = Promise.resolve()
    if (host.__confAIUsage && (host.__confAIUsage.generation !== generation || host.__confAIUsage.controller.signal.aborted)) {
      host.__confAIUsage.controller.abort()
      previous = host.__confAIUsage.task
      delete host.__confAIUsage
    }
    const shared = host.__confAIUsage ??= (() => {
      const state: Shared = { generation, contexts, controller: new AbortController(), task: Promise.resolve() }
      state.task = previous.then(() => run(state, join(runtime, "opencode-ai-usage.json"), timezone, profiles))
        .catch(() => console.error("AI usage monitor stopped; Waybar will mark its last reading stale"))
      return state
    })()
    shared.contexts.add(context)
    return async () => {
      if (!shared.contexts.delete(context) || shared.contexts.size !== 0) return
      const current = host.__confAIUsage
      if (current?.contexts !== shared.contexts) return
      current.controller.abort()
      await current.task
      if (host.__confAIUsage === current) delete host.__confAIUsage
    }
  },
})
