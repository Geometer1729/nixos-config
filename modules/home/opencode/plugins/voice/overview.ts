import { basename } from "node:path"

// What the voice delegator needs to know about the user's other sessions, as
// plain data so the formatting can be tested without a server.

export type Status = "approval" | "question" | "running" | "failed" | "finished" | "interrupted" | "idle"

export interface SessionLike {
  id: string
  parentID?: string | undefined
  title?: string | undefined
  outcome?: "succeeded" | "failed" | "interrupted" | undefined
  time: { updated: number; idle?: number | undefined; viewed?: number | undefined; archived?: number | undefined }
  location: { directory: string }
}

/** A permission prompt or question waiting on the user, already attributed to its root session. */
export interface Pending {
  kind: "approval" | "question"
  detail: string
}

export interface Row {
  id: string
  title: string
  project: string
  directory: string
  status: Status
  detail?: string
  updated: number
}

const order: Record<Status, number> = {
  approval: 0, question: 1, running: 2, failed: 3, finished: 4, interrupted: 5, idle: 6,
}

const labels: Record<Status, string> = {
  approval: "needs approval",
  question: "asked the user a question",
  running: "working",
  failed: "failed",
  finished: "finished, reply not read yet",
  interrupted: "stopped",
  idle: "idle",
}

export function clean(value: string): string {
  return value.replace(/[\x00-\x1f\x7f]/g, " ").replace(/\s+/g, " ").trim()
}

export function truncate(value: string, length: number): string {
  return value.length > length ? value.slice(0, length - 1) + "…" : value
}

export function project(directory: string): string {
  return basename(directory) || directory
}

export function status(session: SessionLike, running: boolean, pending: readonly Pending[]): Status {
  const first = pending.find((item) => item.kind === "approval") ?? pending[0]
  if (first) return first.kind
  if (running) return "running"
  // Like the desktop notifications: a result stays news until the user has looked at the session.
  const unread = session.time.idle !== undefined && session.time.idle > (session.time.viewed ?? 0)
  if (session.outcome === "interrupted") return "interrupted"
  if (!unread) return "idle"
  return session.outcome === "failed" ? "failed" : "finished"
}

/** Root sessions, most urgent first, then most recently updated. */
export function rows(
  sessions: readonly SessionLike[],
  running: ReadonlySet<string>,
  pending: ReadonlyMap<string, readonly Pending[]>,
): Row[] {
  return sessions
    .filter((session) => !session.parentID && session.time.archived === undefined)
    .map((session) => {
      const waiting = pending.get(session.id) ?? []
      const kind = status(session, running.has(session.id), waiting)
      const detail = waiting.filter((item) => item.kind === kind).map((item) => item.detail).join("; ")
      return {
        id: session.id,
        title: clean(session.title ?? "Untitled"),
        project: clean(project(session.location.directory)),
        directory: session.location.directory,
        status: kind,
        ...(detail ? { detail: truncate(clean(detail), 120) } : {}),
        updated: session.time.updated,
      }
    })
    .sort((a, b) => order[a.status] - order[b.status] || b.updated - a.updated)
}

export function line(row: Row): string {
  const detail = row.detail ? ` (${row.detail})` : ""
  return `- ${labels[row.status]}${detail}: "${row.title}" in ${row.project} [${row.id}]`
}

/**
 * The overview the delegator reads at the start of each turn. It has no relative
 * times, so it only changes, and is only re-announced, when a session does.
 */
export function overview(all: readonly Row[], idleLimit = 8): string {
  const urgent = all.filter((row) => row.status !== "idle" && row.status !== "interrupted")
  const quiet = all.filter((row) => row.status === "idle" || row.status === "interrupted")
  const shown = [...urgent, ...quiet.slice(0, Math.max(0, idleLimit - urgent.length))]
  const hidden = all.length - shown.length
  return [
    "The user's other OpenCode sessions on this computer, most urgent first, as of their latest words.",
    "Bracketed session IDs are for tools; never read them aloud.",
    ...(shown.length ? shown.map(line) : ["- none"]),
    ...(hidden > 0 ? [`(${hidden} more quiet sessions; voice_sessions lists or searches them.)`] : []),
  ].join("\n")
}

export function minutesAgo(time: number, now: number): number {
  return Math.max(0, Math.round((now - time) / 60_000))
}

/** Words from the title or project, forgiving order and partial words: best match first, no match dropped. */
export function search(all: readonly Row[], query: string): Row[] {
  const words = query.toLowerCase().split(/[^\p{L}\p{N}]+/u).filter((word) => word.length > 1)
  if (!words.length) return [...all]
  const score = (row: Row) => {
    const haystack = `${row.title} ${row.project}`.toLowerCase()
    return words.filter((word) => haystack.includes(word)).length
  }
  return all
    .map((row, index) => ({ row, index, score: score(row) }))
    .filter((entry) => entry.score > 0)
    .sort((a, b) => b.score - a.score || a.index - b.index)
    .map((entry) => entry.row)
}

export interface MessageLike {
  type: string
  text?: string
  outcome?: string
  content?: readonly { type: string; text?: string; name?: string; state?: { status?: string } }[]
}

/** Text-only excerpts of a session's messages, oldest first, for the delegator to summarize aloud. */
export function excerpts(messages: readonly MessageLike[], length = 600): string[] {
  return messages.flatMap((message): string[] => {
    if (message.type === "user" && message.text) return [`User: ${truncate(clean(message.text), length)}`]
    if (message.type === "synthetic" && message.text) return [`Note: ${truncate(clean(message.text), length / 2)}`]
    if (message.type === "idle") return [`(finished: ${message.outcome ?? "unknown"})`]
    if (message.type !== "assistant") return []
    const parts = message.content ?? []
    const text = clean(parts.flatMap((part) => part.type === "text" && part.text ? [part.text] : []).join(" "))
    const tools = [...new Set(parts.flatMap((part) => part.type === "tool" && part.name ? [part.name] : []))]
    const running = parts.some((part) => part.type === "tool" && part.state?.status === "running")
    if (!text && !tools.length) return []
    const used = tools.length ? ` [tools: ${tools.join(", ")}${running ? ", one still running" : ""}]` : ""
    return [`Agent: ${text ? truncate(text, length) : "(no text)"}${used}`]
  })
}
