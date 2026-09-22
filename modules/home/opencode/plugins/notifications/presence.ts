import { createConnection, createServer } from "node:net"
import type { Socket } from "node:net"
import { join } from "node:path"
import { setTimeout as sleep } from "node:timers/promises"

export function socketPath(pid: number): string {
  if (!process.env.XDG_RUNTIME_DIR) throw new Error("XDG_RUNTIME_DIR is required for TUI presence")
  return join(process.env.XDG_RUNTIME_DIR, `opencode-notify-${pid}.sock`)
}

function messages(socket: Socket, receive: (message: unknown) => void) {
  let buffer = ""
  socket.setEncoding("utf8")
  socket.on("data", (chunk) => {
    buffer += chunk
    if (buffer.length > 65_536) return socket.destroy()
    let end: number
    while ((end = buffer.indexOf("\n")) !== -1) {
      const line = buffer.slice(0, end)
      buffer = buffer.slice(end + 1)
      try {
        receive(JSON.parse(line))
      } catch {
        socket.destroy()
        return
      }
    }
  })
}

interface Presence {
  sessions: readonly string[]
  pane: string
}

// Objects report a TUI's tab inventory and tmux pane; a session ID requests focus.
// EOF (including a killed TUI) removes its inventory.
export async function presenceServer(path: string, changed: () => void) {
  const clients = new Map<Socket, Presence>()
  const server = createServer((socket) => {
    messages(socket, (message) => {
      if (typeof message === "string" && message.startsWith("ses_")) {
        const owner = [...clients].find(([, { sessions }]) => sessions.includes(message))?.[0]
        owner?.write(JSON.stringify(message) + "\n")
        socket.end()
      } else if (message && typeof message === "object" && "sessions" in message && "pane" in message
        && Array.isArray(message.sessions) && message.sessions.every((id) => typeof id === "string" && id.startsWith("ses_"))
        && typeof message.pane === "string") {
        clients.set(socket, { sessions: message.sessions, pane: message.pane })
      } else {
        socket.destroy()
        return
      }
      changed()
    })
    socket.on("error", () => socket.destroy())
    socket.on("close", () => {
      clients.delete(socket)
      changed()
    })
  })
  await new Promise<void>((resolve, reject) => {
    server.once("error", reject)
    server.listen(path, () => { server.off("error", reject); resolve() })
  })
  return {
    sessions: () => {
      const panes = new Map<string, string>()
      // Match click routing: the first attached TUI owns the displayed workspace.
      for (const { sessions, pane } of clients.values()) {
        for (const id of sessions) if (!panes.has(id)) panes.set(id, pane)
      }
      return panes
    },
    close: () => new Promise<void>((resolve, reject) => {
      for (const socket of clients.keys()) socket.destroy()
      server.close((error) => error ? reject(error) : resolve())
    }),
  }
}

export function presenceClient(path: () => Promise<string>, focus: (sessionID: string) => void = () => undefined) {
  const controller = new AbortController()
  let payload = '{"sessions":[],"pane":""}\n'
  let socket: Socket | undefined
  let connected = false
  const task = (async () => {
    while (!controller.signal.aborted) {
      try {
        const address = await path()
        if (controller.signal.aborted) break
        await new Promise<void>((resolve) => {
          socket = createConnection(address)
          messages(socket, (message) => {
            if (typeof message === "string" && JSON.parse(payload).sessions.includes(message)) focus(message)
          })
          socket.once("connect", () => { connected = true; socket!.write(payload) })
          socket.on("error", () => socket?.destroy())
          socket.once("close", () => { connected = false; resolve() })
        })
      } catch {
        // The server/plugin can be restarting. Resolve its address again.
      }
      await sleep(1000, undefined, { signal: controller.signal }).catch(() => undefined)
    }
  })()
  return {
    update(ids: readonly string[], pane = "") {
      const next = JSON.stringify({ sessions: [...new Set(ids)].sort(), pane }) + "\n"
      if (next === payload) return
      payload = next
      if (connected) socket!.write(payload)
    },
    async close() {
      controller.abort()
      socket?.destroy()
      await task
    },
  }
}
