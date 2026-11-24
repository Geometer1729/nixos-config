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
  directory?: string
}

function focusRequest(message: unknown): { session: string, directory?: string } | undefined {
  if (typeof message === "string" && message.startsWith("ses_")) return { session: message }
  if (message && typeof message === "object" && "session" in message && typeof message.session === "string"
    && message.session.startsWith("ses_")
    && (!("directory" in message) || typeof message.directory === "string")) {
    return { session: message.session, ...("directory" in message ? { directory: message.directory as string } : {}) }
  }
  return undefined
}

// Objects report a TUI's tab inventory, tmux pane and directory. A session ID,
// or {session, directory}, requests focus: the TUI with that tab gets it, else
// the first TUI started in that directory, which opens it as a tab. The
// requester gets back whether any TUI took it.
// EOF (including a killed TUI) removes its inventory.
export async function presenceServer(path: string, changed: () => void) {
  const clients = new Map<Socket, Presence>()
  // server.close() waits for every open connection, including ones that have
  // not reported yet. A connection missed here would stall the next generation.
  const sockets = new Set<Socket>()
  const server = createServer((socket) => {
    sockets.add(socket)
    messages(socket, (message) => {
      const request = focusRequest(message)
      if (request) {
        const entries = [...clients]
        const owner = entries.find(([, { sessions }]) => sessions.includes(request.session))?.[0]
          ?? (request.directory === undefined ? undefined
            : entries.find(([, { directory }]) => directory === request.directory)?.[0])
        owner?.write(JSON.stringify(request.session) + "\n")
        socket.end(JSON.stringify(owner !== undefined) + "\n")
      } else if (message && typeof message === "object" && "sessions" in message && "pane" in message
        && Array.isArray(message.sessions) && message.sessions.every((id) => typeof id === "string" && id.startsWith("ses_"))
        && typeof message.pane === "string"
        && (!("directory" in message) || typeof message.directory === "string")) {
        clients.set(socket, {
          sessions: message.sessions, pane: message.pane,
          ...("directory" in message ? { directory: message.directory as string } : {}),
        })
      } else {
        socket.destroy()
        return
      }
      changed()
    })
    socket.on("error", () => socket.destroy())
    socket.on("close", () => {
      sockets.delete(socket)
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
      server.close((error) => error ? reject(error) : resolve())
      for (const socket of sockets) socket.destroy()
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
          // The server only routes a session here if this TUI has its tab or
          // shares its directory.
          messages(socket, (message) => {
            if (typeof message === "string" && message.startsWith("ses_")) focus(message)
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
    update(ids: readonly string[], pane = "", directory?: string) {
      const next = JSON.stringify({
        sessions: [...new Set(ids)].sort(), pane, ...(directory === undefined ? {} : { directory }),
      }) + "\n"
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
