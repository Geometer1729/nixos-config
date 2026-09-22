import { Plugin } from "@opencode/plugin/tui"
import { Service } from "@opencode/client/service"
import { createEffect, onCleanup } from "solid-js"

import { presenceClient, socketPath } from "./presence.ts"

export default Plugin.define({
  id: "local.notifications.presence",
  setup(context) {
    // Server-discovered TUI entrypoints do not inherit the server's options.
    if (!process.env.XDG_RUNTIME_DIR || !process.env.DBUS_SESSION_BUS_ADDRESS) return
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
          if (!local || !server.urls.includes(local.url)) throw new Error("Not the local service")
          return socketPath(server.pid)
        })
        createEffect(() => {
          const route = context.ui.router.current()
          const ids = context.ui.tabs.enabled() ? context.ui.tabs.list().map((tab) => tab.sessionID) : []
          if (route.type === "session" && route.sessionID !== "dummy") {
            ids.push(context.data.session.root(route.sessionID))
          }
          client.update(ids)
        })
        onCleanup(() => { void client.close() })
        return null
      },
    })
  },
})
