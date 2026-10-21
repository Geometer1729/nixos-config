import { readFile } from "node:fs/promises"
import { isAbsolute, join, relative } from "node:path"

// Written by `notification-center work`: the epoch second when work sessions unmute.
export function muteFile(): string {
  if (!process.env.XDG_RUNTIME_DIR) throw new Error("XDG_RUNTIME_DIR is required for the work mute")
  return join(process.env.XDG_RUNTIME_DIR, "work-muted-until")
}

export async function mutedUntil(path: string, now = Date.now()): Promise<number | undefined> {
  const until = Number((await readFile(path, "utf8").catch(() => "")).trim()) * 1000
  return Number.isFinite(until) && until > now ? until : undefined
}

export function inside(directory: string, root: string): boolean {
  const path = relative(root, directory)
  return path !== ".." && !path.startsWith("../") && !isAbsolute(path)
}
