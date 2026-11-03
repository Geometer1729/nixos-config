import { Plugin } from "@opencode/plugin/tui"
import { jsx } from "@opentui/solid/jsx-runtime"
import { execFile, spawn } from "node:child_process"
import { createEffect } from "solid-js"

import { type Said, Speech } from "./rpc.ts"
import { type Playback, Speaker } from "./speaker.ts"

// `speak` synthesizes and plays; its process group is stopped as a whole.
function play(text: string): Playback {
  const child = spawn("speak", [], { detached: true, stdio: ["pipe", "ignore", "ignore"] })
  const done = new Promise<void>((resolve) => {
    child.once("exit", () => resolve())
    child.once("error", (error) => {
      console.error("OpenCode speech:", error)
      resolve()
    })
  })
  child.stdin.once("error", () => {})
  child.stdin.end(text)
  return {
    done,
    stop: () => {
      if (child.pid === undefined || child.exitCode !== null || child.signalCode !== null) return
      try {
        process.kill(-child.pid, "SIGTERM")
      } catch {}
    },
  }
}

export default Plugin.define({
  id: "local.speech.tui",
  setup(context) {
    const speaker = new Speaker(play)
    // tmux reports focus changes but not the focus a TUI (or a reloaded plugin)
    // starts with, so until the first report, ask which pane the focused window shows.
    let reported: boolean | null = null
    let checked = false
    let session: string | undefined
    const update = () => speaker.view((reported ?? checked) ? session : undefined)
    const check = () => {
      const pane = process.env.TMUX_PANE
      if (reported !== null || !pane) return
      execFile("focused-pane", [], { timeout: 5000 }, (error, stdout) => {
        checked = !error && stdout.trim() === pane
        update()
      })
    }
    const onFocus = () => {
      reported = true
      update()
    }
    const onBlur = () => {
      reported = false
      update()
    }
    context.renderer.on("focus", onFocus)
    context.renderer.on("blur", onBlur)

    const unsubscribe = context.client.rpc(Speech).events.on("said", (event) => {
      const { sessionID, text, mode } = event.data as unknown as Said
      speaker.add(sessionID, text, mode)
      check()
    })
    check()

    const Controller = () => {
      createEffect(() => {
        const route = context.ui.router.current()
        session = route.type === "session" && route.sessionID !== "dummy"
          ? context.data.session.root(route.sessionID)
          : undefined
        update()
      })
      context.keymap.layer(() => ({
        mode: "global",
        // Above the Vim plugin, so Escape only stops the speech.
        priority: 2000,
        commands: [{ bind: "escape", enabled: () => speaker.speaking, run: () => speaker.stop() }],
      }))
      return jsx("box", { height: 0 })
    }
    const removeSlot = context.ui.slot({ append: "app", render: () => jsx(Controller) })

    return () => {
      removeSlot()
      unsubscribe()
      context.renderer.off("focus", onFocus)
      context.renderer.off("blur", onBlur)
      speaker.view(undefined)
    }
  },
})
