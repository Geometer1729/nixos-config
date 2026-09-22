import type { OpenCodeClient } from "@opencode/client"
import { basename } from "node:path"
import { setTimeout as sleep } from "node:timers/promises"

type SessionInfo = Awaited<ReturnType<OpenCodeClient["session"]["get"]>>
export type Session = Pick<SessionInfo, "id" | "parentID" | "title" | "location" | "time" | "outcome">

export interface Snapshot {
  sessions: readonly Session[]
  active: Readonly<Record<string, unknown>>
  permissions: readonly { sessionID: string; id?: string }[]
  forms: readonly { sessionID: string; id?: string }[]
}

export interface Notification {
  summary: string
  body: string
  key: string
  sessionID: string
}

export async function snapshot(client: OpenCodeClient, signal: AbortSignal): Promise<Snapshot> {
  const options = { signal }
  const sessions = new Map<string, Session>()
  let cursor: string | undefined
  do {
    const page = await client.session.list({ limit: 500, cursor }, options)
    for (const session of page.data) sessions.set(session.id, session)
    cursor = page.cursor.next ?? undefined
  } while (cursor)

  const [active, locations] = await Promise.all([
    client.session.active(options),
    client.debug.location.list(options),
  ])
  // Pending forms and permissions live in location-scoped memory. Inspect loaded
  // locations rather than activating every historical worktree to look for them.
  const requests = await Promise.all(locations.map(async (location) => {
    const [permissions, forms] = await Promise.all([
      client.permission.request.list({ location }, options),
      client.form.list({ location }, options),
    ])
    return { permissions: permissions.data, forms: forms.data }
  }))

  return {
    sessions: [...sessions.values()],
    active,
    permissions: requests.flatMap((request) => request.permissions),
    forms: requests.flatMap((request) => request.forms),
  }
}

export async function confirmedSnapshot(
  read: () => Promise<Snapshot>,
  signal: AbortSignal,
  request: () => void,
): Promise<Snapshot> {
  const first = await read()
  if (!first.permissions.length) return first
  // Auto approvals briefly appear in the same pending inventory as human
  // prompts. Confirm against a fresh snapshot; keep no waiting-session cache.
  const identity = (permission: Snapshot["permissions"][number]) => JSON.stringify([permission.sessionID, permission.id])
  const candidates = new Set(first.permissions.map(identity))
  await sleep(1000, undefined, { signal })
  const current = await read()
  const permissions = current.permissions.filter((permission) => candidates.has(identity(permission)))
  // Requests born during confirmation need their own full grace period, even
  // when their event arrived before this read or the stream missed that event.
  if (permissions.length !== current.permissions.length) request()
  return { ...current, permissions }
}

const statuses = {
  permission: { order: 0, icon: "🔐", label: "approval needed" },
  question: { order: 1, icon: "❓", label: "question" },
  failed: { order: 2, icon: "!", label: "failed" },
  ready: { order: 3, icon: "✓", label: "ready" },
} as const
type Kind = keyof typeof statuses

function text(value: string): string {
  return value.replace(/[\x00-\x1f\x7f]/g, " ").replace(/\s+/g, " ").trim()
}

function escape(value: string): string {
  return value.replaceAll("&", "&amp;").replaceAll("<", "&lt;").replaceAll(">", "&gt;")
}

export function notification(state: Snapshot, attached: ReadonlySet<string>): Notification {
  const sessions = new Map(state.sessions.map((session) => [session.id, session]))
  const waiting = new Map<string, { session: Session; kind: Kind; reasons: Set<string> }>()
  const root = (id: string): Session | undefined => {
    let session = sessions.get(id)
    const visited = new Set<string>()
    while (session?.parentID && !visited.has(session.id)) {
      visited.add(session.id)
      const parent = sessions.get(session.parentID)
      if (!parent) break
      session = parent
    }
    return session
  }
  const add = (session: Session | undefined, kind: Kind, reason: string) => {
    if (!session || !attached.has(session.id) || session.time.archived !== undefined) return
    const previous = waiting.get(session.id)
    const reasons = previous?.reasons ?? new Set<string>()
    reasons.add(reason)
    if (!previous || statuses[kind].order < statuses[previous.kind].order) {
      waiting.set(session.id, { session, kind, reasons })
    }
  }

  for (const session of sessions.values()) {
    if (session.parentID || state.active[session.id] || session.outcome === "interrupted") continue
    if (session.time.idle !== undefined && session.time.idle > (session.time.viewed ?? 0)) {
      add(session, session.outcome === "failed" ? "failed" : "ready", `idle:${session.time.idle}`)
    }
  }
  // Child requests need the user's attention too, but belong on their parent's row.
  for (const form of state.forms) add(root(form.sessionID), "question", `form:${form.id}`)
  for (const permission of state.permissions) add(root(permission.sessionID), "permission", `permission:${permission.id}`)

  const rows = [...waiting.values()].map(({ session, kind, reasons }) => {
    const project = text(basename(session.location.directory) || session.location.directory)
    const title = text(session.title ?? session.id)
    return { id: session.id, kind, reasons: [...reasons].sort(), label: `${project} · ${title}` }
  }).sort((a, b) => statuses[a.kind].order - statuses[b.kind].order || a.label.localeCompare(b.label) || a.id.localeCompare(b.id))
  const labels = new Map<string, number>()
  for (const row of rows) labels.set(row.label, (labels.get(row.label) ?? 0) + 1)

  return {
    sessionID: rows[0]?.id ?? "",
    key: JSON.stringify(rows.map(({ id, reasons }) => [id, reasons])),
    summary: rows.length ? `OpenCode · ${rows.length} session${rows.length === 1 ? "" : "s"} waiting` : "",
    body: rows.map((row) => {
      const status = statuses[row.kind]
      const suffix = labels.get(row.label)! > 1 ? ` (${row.id.slice(-6)})` : ""
      return `${status.icon} ${escape(row.label + suffix)} — ${status.label}`
    }).join("\n"),
  }
}

export function relevantEvent(type: string): boolean {
  return /^(server\.connected|server\.instance\.disposed|permission\.(asked|replied)|form\.(created|replied|cancelled)|session\.(created|deleted|renamed|moved|viewed|forked|updated|idle|status|execution\.(started|succeeded|failed|interrupted)|inbox\.(enqueued|delivered|cancelled|delivery\.changed)))$/.test(type)
}
