import { execFile } from "node:child_process"
import { promisify } from "node:util"

const exec = promisify(execFile)

/** A browse tab where a call waits for the user in `handoff()`. */
export interface PendingHandoff {
  tab: number
  /** The name an agent gave the tab (`tabs new` with `id`), which it can pass as `tab` instead. */
  id?: string
  message: string
  startedAt: string
}

/** A pending handoff and the OpenCode session blocked on it. */
export interface Handoff extends PendingHandoff {
  sessionID: string
}

/** A running tool call of an active session: what it was called with. */
export interface RunningTool {
  name: string
  input: unknown
}

const record = (value: unknown): value is Record<string, unknown> => typeof value === "object" && value !== null

/** Waiting handoffs from `browse tabs`. A tab without one has no `handoff` field. */
export function parseHandoffs(output: string): PendingHandoff[] {
  const parsed: unknown = JSON.parse(output)
  if (!record(parsed) || !Array.isArray(parsed.tabs)) throw new Error("Unexpected `browse tabs` output")
  return parsed.tabs.flatMap((tab: unknown) => {
    if (!record(tab) || typeof tab.tab !== "number" || !record(tab.handoff)) return []
    const { message, startedAt } = tab.handoff
    if (typeof message !== "string") return []
    return [{
      tab: tab.tab,
      ...(typeof tab.id === "string" ? { id: tab.id } : {}),
      message,
      startedAt: typeof startedAt === "string" ? startedAt : "",
    }]
  })
}

const noRelay = /automatic relay startup is disabled/i

export async function pendingHandoffs(command: string, signal: AbortSignal): Promise<PendingHandoff[]> {
  try {
    // Reading must never start a relay; without one, nothing can be waiting.
    const { stdout } = await exec(command, ["tabs"], {
      signal, env: { ...process.env, OPENCODE_BROWSER_AUTOSTART: "false" },
    })
    return parseHandoffs(stdout)
  } catch (error) {
    const output = record(error) ? `${String(error.stdout ?? "")}\n${String(error.stderr ?? "")}` : ""
    if (noRelay.test(output)) return []
    throw error
  }
}

function values(value: unknown): (string | number)[] {
  if (typeof value === "string" || typeof value === "number") return [value]
  if (Array.isArray(value)) return value.flatMap(values)
  return record(value) ? Object.values(value).flatMap(values) : []
}

const minimumMessage = 12

function escapeRegExp(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")
}

/**
 * browse doesn't record which agent opened a tab, so a handoff belongs to the active
 * session whose running browse call names its tab: as the `tab` argument of a direct
 * call, as `tab: <id>` in Code Mode's script, or as `--tab <id>` on the CLI. A call that
 * opened the tab itself (`execute` without `tab`) is found by the handoff's message.
 */
export function attribute(
  pending: readonly PendingHandoff[],
  running: ReadonlyMap<string, readonly RunningTool[]>,
): Handoff[] {
  return pending.flatMap((handoff) => {
    const names = [String(handoff.tab), ...(handoff.id === undefined ? [] : [handoff.id])]
    const mention = new RegExp(`(?:\\btab["']?\\s*[:=]|--tab[\\s=])\\s*["'\`]?(?:${names.map(escapeRegExp).join("|")})(?![\\w-])`)
    // Short messages ("Sign in") are too common to identify a call.
    const message = handoff.message.length >= minimumMessage ? handoff.message : undefined
    return [...running].filter(([, tools]) => tools.some((tool) => {
      const found = values(tool.input)
      return (tool.name.includes("browse") || found.some((value) => typeof value === "string" && value.includes("browse")))
        && found.some((value) => names.includes(String(value))
          || (typeof value === "string" && (mention.test(value) || (message !== undefined && value.includes(message)))))
    })).map(([sessionID]) => ({ ...handoff, sessionID }))
  })
}
