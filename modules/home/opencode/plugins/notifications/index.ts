import { execFile } from "node:child_process"
import { setTimeout as sleep } from "node:timers/promises"
import { promisify } from "node:util"

import { OpenCode } from "@opencode/client"
import { Service } from "@opencode/client/service"
import { Plugin } from "@opencode/plugin"

import { refreshQueue } from "./refresh.ts"
import { confirmedSnapshot, notification, relevantEvent, snapshot } from "./snapshot.ts"
import { presenceServer, socketPath } from "./presence.ts"

const exec = promisify(execFile)
const report = (error: unknown) => console.error("OpenCode waiting notification:", error)
const moduleID = Symbol("notification plugin generation")

async function run(command: string, shared: Shared): Promise<void> {
  const signal = shared.controller.signal
  if (signal.aborted) return
  const presence = await presenceServer(socketPath(process.pid), () => shared.request())
  try {
    while (!signal.aborted) {
      const connection = new AbortController()
      const connected = AbortSignal.any([signal, connection.signal])
      try {
        // Server plugins expose events but not the complete session/form inventory.
        // Use the documented authenticated client for those snapshot reads.
        const endpoint = await Service.discover()
        if (!endpoint) throw new Error("Local OpenCode service is not ready")
        const headers = Service.headers({ url: endpoint.url, ...(endpoint.auth ? { auth: endpoint.auth } : {}) })
        const client = OpenCode.make({ baseUrl: endpoint.url, headers: headers ?? {} })
        const health = await client.server.info({ signal: connected })
        // A standalone server must never render another server's waiting sessions.
        if (health.pid !== process.pid) return

        const queue = refreshQueue(async () => {
          const timeout = AbortSignal.any([connected, AbortSignal.timeout(15_000)])
          const state = await confirmedSnapshot(() => snapshot(client, timeout), timeout, shared.request)
          const content = notification(state, presence.sessions())
          await exec(command, [content.summary, content.body, content.key, content.sessionID, socketPath(process.pid)], { signal: timeout })
        }, connected, report)
        shared.request = queue.request
        queue.request()
        try {
          // Each connection marker also invalidates state after a reconnect.
          for await (const event of client.event.subscribe({ signal: connected })) {
            if (relevantEvent(event.type)) queue.request()
          }
          if (!signal.aborted) throw new Error("Notification event stream ended")
        } finally {
          shared.request = () => undefined
          connection.abort()
          await queue.settled()
        }
      } catch (error) {
        if (!signal.aborted) {
          report(error)
          await sleep(1000, undefined, { signal }).catch(() => undefined)
        }
      } finally {
        connection.abort()
      }
    }
  } finally {
    await presence.close()
  }
}

interface Shared {
  moduleID: symbol
  owners: Set<symbol>
  controller: AbortController
  task: Promise<void>
  request(): void
}
const host = globalThis as typeof globalThis & { __confOpenCodeWaiting?: Shared }

export default Plugin.define({
  id: "local.notifications",
  setup(context) {
    const command = context.options.command
    if (typeof command !== "string" || !process.env.DBUS_SESSION_BUS_ADDRESS || !process.env.XDG_RUNTIME_DIR) return

    // Global plugins are instantiated once per location. They share one reader
    // and renderer; a code reload replaces that reader. No session state is cached.
    // Ownership spans code generations: older projects can outlive the location
    // that first loads a new module. Their cleanup must release the current reader.
    const owners = host.__confOpenCodeWaiting?.owners ?? new Set<symbol>()
    let previous = Promise.resolve()
    if (host.__confOpenCodeWaiting && (host.__confOpenCodeWaiting.moduleID !== moduleID || host.__confOpenCodeWaiting.controller.signal.aborted)) {
      previous = host.__confOpenCodeWaiting.task
      host.__confOpenCodeWaiting.controller.abort()
      delete host.__confOpenCodeWaiting
    }
    const shared = host.__confOpenCodeWaiting ??= (() => {
      const state: Shared = {
        moduleID, owners, controller: new AbortController(), task: Promise.resolve(), request: () => undefined,
      }
      state.task = previous.then(() => run(command, state)).catch(report)
      return state
    })()
    const owner = Symbol()
    shared.owners.add(owner)
    shared.request()
    return async () => {
      if (!shared.owners.delete(owner) || shared.owners.size !== 0) return
      const current = host.__confOpenCodeWaiting
      if (current?.owners !== shared.owners) return
      current.controller.abort()
      await current.task
      if (host.__confOpenCodeWaiting === current) delete host.__confOpenCodeWaiting
    }
  },
})
