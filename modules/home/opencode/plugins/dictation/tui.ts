import { Plugin } from "@opencode/plugin/tui"
import type { EditBufferRenderable } from "@opentui/core"
import { rmSync } from "node:fs"
import { createServer } from "node:net"

import { insertion, insertionPoint, socketPath } from "./insert.ts"

// Hex's dictate script writes a transcript to this TUI's socket, then reads
// "ok" once it is inserted. Keys are never sent, so it works while the
// terminal is unfocused and regardless of held modifiers or Vim mode.
export default Plugin.define({
  id: "local.dictation",
  async setup(context) {
    const pane = process.env.TMUX_PANE
    const runtimeDir = process.env.XDG_RUNTIME_DIR
    if (!pane || !runtimeDir) return
    const path = socketPath(runtimeDir, pane)

    // Whichever editor holds the TUI's focus: the prompt, or a dialog's input
    // such as a question's custom answer. A dialog without one has none.
    const editor = (): EditBufferRenderable | undefined => context.renderer.currentFocusedEditor ?? undefined

    const server = createServer((socket) => {
      const chunks: Buffer[] = []
      let size = 0
      socket.on("data", (chunk: Buffer) => {
        size += chunk.length
        if (size > 1_048_576) return socket.destroy()
        chunks.push(chunk)
      })
      socket.on("end", () => {
        const text = Buffer.concat(chunks).toString("utf8")
        const input = editor()
        if (!input || !text) return socket.end("unavailable\n")
        // The Vim plugin shows a status on the prompt outside insert mode.
        const normal = Boolean(input.traits.status)
        input.cursorOffset = insertionPoint(input.plainText, input.cursorOffset, normal)
        input.insertText(insertion(input.plainText.slice(0, input.cursorOffset), text))
        context.renderer.requestRender()
        socket.end("ok\n")
      })
      socket.on("error", () => socket.destroy())
    })
    // A TUI that died in this pane leaves its socket behind.
    rmSync(path, { force: true })
    await new Promise<void>((resolve, reject) => {
      server.once("error", reject)
      server.listen(path, () => {
        server.off("error", reject)
        resolve()
      })
    })
    return () => {
      server.close()
      rmSync(path, { force: true })
    }
  },
})
