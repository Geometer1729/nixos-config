import { Plugin } from "@opencode/plugin/tui"
import { Service } from "@opencode/client/service"
import { createEffect, onCleanup } from "solid-js"
import { execFile } from "node:child_process"
import { promisify } from "node:util"

import { presenceClient, socketPath } from "./presence.ts"

const exec = promisify(execFile)

// A wildcard-bound service is discovered at 0.0.0.0 but reports its interface addresses.
function sameService(serverURL: string, localURL: string): boolean {
  const local = new URL(localURL)
  if (local.hostname !== "0.0.0.0" && local.hostname !== "[::]") return serverURL === localURL
  const server = new URL(serverURL)
  return server.protocol === local.protocol && server.port === local.port
}

export default Plugin.define({
  id: "local.notifications.presence",
  setup(context) {
    // Server-discovered TUI entrypoints do not inherit the server's options.
    if (!process.env.XDG_RUNTIME_DIR || !process.env.DBUS_SESSION_BUS_ADDRESS) return
    const focusCommand = context.options.focusCommand
    return context.ui.slot({
      append: "app",
      render() {
        const client = presenceClient(async () => {
          const options = { signal: AbortSignal.timeout(5000) }
          const [local, server] = await Promise.all([
            Service.discover(), context.client.server.info(options),
          ])
          // Presence is for this desktop's managed service, including after its
          // port/PID changes. A TUI connected to a remote server is excluded.
          if (!local || !server.urls.some((url) => sameService(url, local.url))) throw new Error("Not the local service")
          return socketPath(server.pid)
        }, (sessionID) => {
          if (typeof focusCommand !== "string") return
          void exec(focusCommand, [], { timeout: 5000 }).then(() => {
            if (context.ui.tabs.enabled()) context.ui.tabs.focus(sessionID)
            else context.ui.router.navigate({ type: "session", sessionID })
          }).catch((error) => console.error("OpenCode notification focus:", error))
        })
        createEffect(() => {
          const route = context.ui.router.current()
          const ids = context.ui.tabs.enabled() ? context.ui.tabs.list().map((tab) => tab.sessionID) : []
          if (route.type === "session" && route.sessionID !== "dummy") {
            ids.push(context.data.session.root(route.sessionID))
          }
          client.update(ids, process.env.TMUX_PANE)
        })
        onCleanup(() => { void client.close() })
        return null
      },
    })
  },
})
