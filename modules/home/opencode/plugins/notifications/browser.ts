import { execFile } from "node:child_process"
import { createHash } from "node:crypto"
import { promisify } from "node:util"

const exec = promisify(execFile)

/** A browse session's `handoff()`, waiting for the user in a browser tab. */
export interface PendingHandoff {
  session: string
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

/** The browse session an OpenCode agent uses unless it names one (`callerSessionId` in browse's mcp/registry.ts). */
export function browseSession(sessionID: string): string {
  return `mcp-${createHash("sha256").update(sessionID).digest("hex").slice(0, 8)}`
}

const record = (value: unknown): value is Record<string, unknown> => typeof value === "object" && value !== null

/** Waiting handoffs from `browse session list --json`. A finished handoff is `null` or absent. */
export function parseHandoffs(output: string): PendingHandoff[] {
  const parsed: unknown = JSON.parse(output)
  if (!record(parsed) || !Array.isArray(parsed.sessions)) throw new Error("Unexpected `browse session list --json` output")
  return parsed.sessions.flatMap((session: unknown) => {
    if (!record(session) || typeof session.id !== "string" || !record(session.handoff)) return []
    const { message, startedAt } = session.handoff
    if (typeof message !== "string") return []
    return [{ session: session.id, message, startedAt: typeof startedAt === "string" ? startedAt : "" }]
  })
}

const noRelay = "Automatic relay startup is disabled"

export async function pendingHandoffs(command: string, signal: AbortSignal): Promise<PendingHandoff[]> {
  try {
    // Reading must never start a relay; without one, nothing can be waiting.
    const { stdout } = await exec(command, ["session", "list", "--json"], {
      signal, env: { ...process.env, OPENCODE_BROWSER_AUTOSTART: "false" },
    })
    return parseHandoffs(stdout)
  } catch (error) {
    const stdout = record(error) && typeof error.stdout === "string" ? error.stdout : ""
    if (stdout.includes(noRelay)) return []
    throw error
  }
}

function strings(value: unknown): string[] {
  if (typeof value === "string") return [value]
  if (Array.isArray(value)) return value.flatMap(strings)
  return record(value) ? Object.values(value).flatMap(strings) : []
}

const minimumMessage = 12

function escapeRegExp(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")
}

/** Browse's implicit session IDs, mapped back to their OpenCode sessions: the MCP server's, and the CLI's
 * (`oc-` + the lowercased OPENCODE_SESSION_ID, browse's cli/context.ts). */
export function implicitSessions(sessionIDs: Iterable<string>): Map<string, string> {
  return new Map([...sessionIDs].flatMap((id) => [[browseSession(id), id], [`oc-${id.toLowerCase()}`, id]] as const))
}

/**
 * The implicit session ID identifies its agent exactly. Other sessions, named by the
 * agent (`session_new`) or random after `session_delete`, are attributed to an active
 * session whose running browse call names the session (directly or as a quoted string
 * in Code Mode's script) or contains the handoff's message.
 */
export function attribute(
  pending: readonly PendingHandoff[],
  implicit: ReadonlyMap<string, string>,
  running: ReadonlyMap<string, readonly RunningTool[]>,
): Handoff[] {
  return pending.flatMap((handoff) => {
    const owner = implicit.get(handoff.session)
    if (owner) return [{ ...handoff, sessionID: owner }]
    const quoted = new RegExp(`["'\`]${escapeRegExp(handoff.session)}["'\`]`)
    // Short messages ("Sign in") are too common to identify a call.
    const message = handoff.message.length >= minimumMessage ? handoff.message : undefined
    return [...running].filter(([, tools]) => tools.some((tool) => {
      const values = strings(tool.input)
      return (tool.name.includes("browse") || values.some((value) => value.includes("browse")))
        && values.some((value) => value === handoff.session || quoted.test(value) || (message !== undefined && value.includes(message)))
    })).map(([sessionID]) => ({ ...handoff, sessionID }))
  })
}
