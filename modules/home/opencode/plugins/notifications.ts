import { spawn } from "node:child_process"

import { Plugin } from "@opencode-ai/plugin"

type NotificationKind = "permission" | "ready"

function notify(kind: NotificationKind, directory: string): void {
  const child = spawn("opencode-notify", [kind, directory], {
    detached: true,
    stdio: "ignore",
  })
  child.on("error", () => undefined)
  child.unref()
}

export default Plugin.define({
  id: "local.notifications",
  setup(context) {
    const location = (context as typeof context & { location: { directory: string } }).location
    const controller = new AbortController()
    const task = (async () => {
      for await (const event of context.event.subscribe({ signal: controller.signal })) {
        if (event.type !== "session.idle" && event.type !== "permission.asked") continue
        const directory =
          event.location?.directory ??
          (await context.session.get({ sessionID: event.data.sessionID })).location.directory
        if (directory !== location.directory) continue
        notify(event.type === "session.idle" ? "ready" : "permission", directory)
      }
    })()

    void task.catch((error: unknown) => {
      if (!controller.signal.aborted) console.error("notification event subscription failed", error)
    })

    return async () => {
      controller.abort()
      await task.catch(() => undefined)
    }
  },
})
