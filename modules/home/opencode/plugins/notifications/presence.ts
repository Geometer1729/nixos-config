import { createConnection, createServer } from "node:net"
import type { Socket } from "node:net"
import { join } from "node:path"
import { setTimeout as sleep } from "node:timers/promises"

export function socketPath(pid: number): string {
  if (!process.env.XDG_RUNTIME_DIR) throw new Error("XDG_RUNTIME_DIR is required for TUI presence")
  return join(process.env.XDG_RUNTIME_DIR, `opencode-notify-${pid}.sock`)
}

// The connection owns its full tab inventory. EOF (including a killed TUI)
// removes it; there are no persisted presence records or heartbeat expirations.
export async function presenceServer(path: string, changed: () => void) {
  const clients = new Map<Socket, readonly string[]>()
  const server = createServer((socket) => {
    clients.set(socket, [])
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
          const ids: unknown = JSON.parse(line)
          if (!Array.isArray(ids) || !ids.every((id) => typeof id === "string" && id.startsWith("ses_"))) {
            socket.destroy()
            return
          }
          clients.set(socket, ids)
          changed()
        } catch {
          socket.destroy()
          return
        }
      }
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
    sessions: () => new Set([...clients.values()].flat()),
    close: () => new Promise<void>((resolve, reject) => {
      for (const socket of clients.keys()) socket.destroy()
      server.close((error) => error ? reject(error) : resolve())
    }),
  }
}

export function presenceClient(path: () => Promise<string>) {
  const controller = new AbortController()
  let payload = "[]\n"
  let socket: Socket | undefined
  let connected = false
  const task = (async () => {
    while (!controller.signal.aborted) {
      try {
        const address = await path()
        if (controller.signal.aborted) break
        await new Promise<void>((resolve) => {
          socket = createConnection(address)
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
    update(ids: readonly string[]) {
      const next = JSON.stringify([...new Set(ids)].sort()) + "\n"
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
