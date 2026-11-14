import { execFile } from "node:child_process"
import { watch } from "node:fs"
import { basename, dirname } from "node:path"
import { setTimeout as sleep } from "node:timers/promises"
import { promisify } from "node:util"

import { OpenCode } from "@opencode/client"
import { Service } from "@opencode/client/service"
import { Plugin } from "@opencode/plugin"

import { refreshQueue } from "./refresh.ts"
import { confirmedSnapshot, notification, relevantEvent, snapshot } from "./snapshot.ts"
import { pendingHandoffs } from "./browser.ts"
import type { PendingHandoff } from "./browser.ts"
import { presenceServer, socketPath } from "./presence.ts"
import { inside, muteFile, mutedUntil } from "./mute.ts"

const exec = promisify(execFile)
const report = (error: unknown) => console.error("OpenCode waiting notification:", error)
const moduleID = Symbol("notification plugin generation")
// browse's relay has no events; poll it while an agent could be blocked in handoff().
const handoffPollMs = 3000

interface Options {
  command: string
  focusCommand: string
  browseCommand?: string
  workDirectory?: string
}

async function run({ command, focusCommand, browseCommand, workDirectory }: Options, shared: Shared): Promise<void> {
  const signal = shared.controller.signal
  if (signal.aborted) return
  // A broken browse must not hide other rows or log every poll.
  let browseError = ""
  const readHandoffs = browseCommand === undefined ? undefined : async (timeout: AbortSignal): Promise<PendingHandoff[]> => {
    try {
      const handoffs = await pendingHandoffs(browseCommand, timeout)
      browseError = ""
      return handoffs
    } catch (error) {
      if (timeout.aborted) throw error
      if (String(error) !== browseError) report(error)
      browseError = String(error)
      return []
    }
  }
  const presence = await presenceServer(socketPath(process.pid), () => shared.request())
  const mute = muteFile()
  const muteWatcher = watch(dirname(mute), (_, name) => { if (name === basename(mute)) shared.request() })
  muteWatcher.on("error", report)
  try {
    while (!signal.aborted) {
      const connection = new AbortController()
      const connected = AbortSignal.any([signal, connection.signal])
      let unmuteScheduled: number | undefined
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

        let busy = false
        const queue = refreshQueue(async () => {
          const timeout = AbortSignal.any([connected, AbortSignal.timeout(15_000)])
          const state = await confirmedSnapshot(() => snapshot(client, timeout, readHandoffs), timeout, shared.request)
          busy = Object.keys(state.active).length > 0
          const attached = presence.sessions()
          const workspaces = new Map(await Promise.all([...new Set(attached.values())].filter(Boolean).map(async (pane) => {
            const workspace = await exec(focusCommand, ["--workspace", pane], { signal: timeout })
              .then(({ stdout }) => stdout.trim()).catch(() => "")
            return [pane, workspace] as const
          })))
          const locations = new Map([...attached].map(([id, pane]) => [id, workspaces.get(pane) ?? ""]))
          const until = workDirectory === undefined ? undefined : await mutedUntil(mute)
          if (until !== undefined && until !== unmuteScheduled) {
            unmuteScheduled = until
            void sleep(until - Date.now(), undefined, { signal: connected }).then(() => shared.request(), () => undefined)
          }
          const muted = new Set(until === undefined ? [] : state.sessions
            .filter((session) => inside(session.location.directory, workDirectory!)).map((session) => session.id))
          const content = notification(state, new Set([...attached.keys()].filter((id) => !muted.has(id))), locations)
          await exec(command, [
            content.summary, content.body, content.key, content.sessionID, socketPath(process.pid), content.browser, browseCommand ?? "",
          ], { signal: timeout })
        }, connected, report)
        shared.request = queue.request
        queue.request()
        // Only a change in browse's pending handoffs needs a refresh.
        const poll = readHandoffs && (async () => {
          let seen = ""
          while (!connected.aborted) {
            await sleep(handoffPollMs, undefined, { signal: connected })
            if (!busy) continue
            const current = await readHandoffs(AbortSignal.any([connected, AbortSignal.timeout(15_000)]))
              .then((handoffs) => JSON.stringify(handoffs), () => seen)
            if (current !== seen) queue.request()
            seen = current
          }
        })().catch(() => undefined)
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
          await poll
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
    muteWatcher.close()
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
    const focusCommand = context.options.focusCommand
    const workDirectory = typeof context.options.workDirectory === "string" ? context.options.workDirectory : undefined
    const browseCommand = typeof context.options.browseCommand === "string" ? context.options.browseCommand : undefined
    if (typeof command !== "string" || typeof focusCommand !== "string" || !process.env.DBUS_SESSION_BUS_ADDRESS || !process.env.XDG_RUNTIME_DIR) return
    const options: Options = {
      command, focusCommand,
      ...(browseCommand === undefined ? {} : { browseCommand }),
      ...(workDirectory === undefined ? {} : { workDirectory }),
    }

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
      state.task = previous.then(() => run(options, state)).catch(report)
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
