import type { OpenCodeClient } from "@opencode/client"
import { OpenCode } from "@opencode/client"
import { Service } from "@opencode/client/service"

import { type Pending, rows, type Row, type SessionLike, truncate } from "./overview.ts"

type SessionInfo = Awaited<ReturnType<OpenCodeClient["session"]["get"]>>

// Server plugins can't read the active-session, permission and form inventory
// through their context, so use the documented authenticated client, as the
// notifications plugin does. Only this process's own server is accepted.
let shared: Promise<OpenCodeClient> | undefined

export function client(): Promise<OpenCodeClient> {
  shared ??= (async () => {
    const endpoint = await Service.discover()
    if (!endpoint) throw new Error("The local OpenCode service is not ready")
    const headers = Service.headers({ url: endpoint.url, ...(endpoint.auth ? { auth: endpoint.auth } : {}) })
    const made = OpenCode.make({ baseUrl: endpoint.url, headers: headers ?? {} })
    const info = await made.server.info({ signal: AbortSignal.timeout(5000) })
    if (info.pid !== process.pid) throw new Error("Voice tools only work on the shared OpenCode service")
    return made
  })()
  shared.catch(() => { shared = undefined })
  return shared
}

export interface State {
  rows: Row[]
  /** Every session read along the way, including children, by ID. */
  sessions: Map<string, SessionInfo>
}

/**
 * Recent root sessions plus every root that is running or waiting on the user.
 * Activity and requests in child sessions (subagents) count for their root.
 */
export async function readState(
  api: OpenCodeClient,
  signal: AbortSignal,
  options: { limit: number; include?: readonly string[] },
): Promise<State> {
  const request = { signal }
  const [recent, active, locations] = await Promise.all([
    options.limit > 0
      ? api.session.list({ limit: options.limit, parentID: null, archived: false }, request).then((page) => page.data)
      : Promise.resolve([]),
    api.session.active(request),
    api.debug.location.list(request),
  ])
  const sessions = new Map<string, SessionInfo>(recent.map((session) => [session.id, session]))
  const load = async (id: string): Promise<SessionInfo | undefined> => {
    const known = sessions.get(id)
    if (known) return known
    const session = await api.session.get({ sessionID: id }, request).catch(() => undefined)
    if (session) sessions.set(id, session)
    return session
  }
  const root = async (id: string): Promise<SessionInfo | undefined> => {
    let session = await load(id)
    const visited = new Set<string>()
    while (session?.parentID && !visited.has(session.id)) {
      visited.add(session.id)
      const parent = await load(session.parentID)
      if (!parent) break
      session = parent
    }
    return session
  }

  // Pending permissions and forms live in location-scoped memory: read the loaded
  // locations rather than activating every historical worktree to look for them.
  const requests = await Promise.all(locations.map(async (location) => {
    const [permissions, forms] = await Promise.all([
      api.permission.request.list({ location }, request).then((page) => page.data, () => []),
      api.form.list({ location }, request).then((page) => page.data, () => []),
    ])
    return [
      ...permissions.map((permission) => ({
        sessionID: permission.sessionID,
        kind: "approval" as const,
        detail: truncate(`${permission.action}: ${permission.message ?? permission.resources.join(", ")}`, 100),
      })),
      ...forms.map((form) => ({ sessionID: form.sessionID, kind: "question" as const, detail: form.title })),
    ]
  }))

  const pending = new Map<string, Pending[]>()
  for (const item of requests.flat()) {
    const owner = await root(item.sessionID)
    if (!owner) continue
    pending.set(owner.id, [...(pending.get(owner.id) ?? []), { kind: item.kind, detail: item.detail }])
  }
  const running = new Set<string>()
  for (const id of Object.keys(active)) {
    const owner = await root(id)
    if (owner) running.add(owner.id)
  }
  for (const id of options.include ?? []) await load(id)

  const listed = new Set([...recent.map((session) => session.id), ...pending.keys(), ...running, ...(options.include ?? [])])
  const roots = [...listed].flatMap((id) => {
    const session = sessions.get(id)
    return session ? [session as SessionLike] : []
  })
  return { rows: rows(roots, running, pending), sessions }
}

/** The root session's row, for a session that may not be a root itself. */
export function rowFor(state: State, sessionID: string): Row | undefined {
  return state.rows.find((row) => row.id === sessionID)
}
