import { Plugin } from "@opencode/plugin/tui"
import { jsx } from "@opentui/solid/jsx-runtime"
import { execFile } from "node:child_process"
import { randomUUID } from "node:crypto"
import { createEffect, createSignal, untrack } from "solid-js"

import { type Speaking, Speech } from "./rpc.ts"

const report = (error: unknown) => console.error("OpenCode speech:", error)

// The server plays the speech; this tells it which session is on screen while
// the terminal has focus, and stops the speech on Escape.
export default Plugin.define({
  id: "local.speech.tui",
  setup(context) {
    const client = randomUUID()
    // The client changes when the server restarts.
    const speech = () => context.client.rpc(Speech)

    // tmux reports focus changes but not the focus a TUI (or a reloaded plugin)
    // starts with, so until the first report, ask which pane the focused window shows.
    let reported: boolean | null = null
    let checked = false
    const [session, setSession] = createSignal<string>()
    const [speaking, setSpeaking] = createSignal<string>()

    // Reports go out in order, each only once the last has arrived.
    let sent: string | undefined
    let reports = Promise.resolve()
    const update = (force = false) => {
      const sessionID = (reported ?? checked) ? session() : undefined
      if (!force && sessionID === sent) return
      sent = sessionID
      reports = reports
        .then(() => speech().view(sessionID === undefined ? { client } : { client, sessionID }))
        .then(() => {}, report)
    }
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

    const unsubscribeSaid = speech().events.on("said", () => {
      check()
      update(true)
    })
    const unsubscribeSpeaking = speech().events.on("speaking", (event) => {
      setSpeaking((event.data as unknown as Speaking).sessionID)
    })
    check()

    const Controller = () => {
      createEffect(() => {
        const route = context.ui.router.current()
        setSession(route.type === "session" && route.sessionID !== "dummy"
          ? context.data.session.root(route.sessionID)
          : undefined)
        untrack(() => update())
      })
      context.keymap.layer(() => ({
        mode: "global",
        // Above the Vim plugin, so Escape only stops the speech.
        priority: 2000,
        commands: [{
          bind: "escape",
          enabled: () => speaking() !== undefined && speaking() === session(),
          run: () => {
            setSpeaking(undefined)
            void speech().stop({}).catch(report)
          },
        }],
      }))
      return jsx("box", { height: 0 })
    }
    const removeSlot = context.ui.slot({ append: "app", render: () => jsx(Controller) })

    return () => {
      removeSlot()
      unsubscribeSaid()
      unsubscribeSpeaking()
      context.renderer.off("focus", onFocus)
      context.renderer.off("blur", onBlur)
      reported = false
      update()
    }
  },
})
