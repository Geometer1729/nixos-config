import { setTimeout as sleep } from "node:timers/promises"

import type { OpenCodeClient } from "@opencode/client"

import { voiceWindowMs } from "./delegation.ts"
import { excerpts, line, type MessageLike, type Row, type Status } from "./overview.ts"
import { client, readState } from "./state.ts"

// During a call, tells the voice session when another session finishes or starts
// waiting on the user, by waking it with a synthetic [Session update] message; it
// then speaks the update with ios_voice_say. The phone itself only announces
// sessions it was asked to watch, and never approvals or questions.

/** Client MCP servers the phone apps host only while a call is live. */
const phoneServers = new Set(["ios", "android"])
/** Until a phone's tools have shown up in this server's MCP list, assume a call lasts this long after the user's last words. */
const fallbackCallMs = 10 * 60_000
/** Let a burst of events settle, and the TUI mark a session viewed, before comparing. */
const settleMs = 3000

const report = (error: unknown) => console.error("OpenCode voice monitor:", error)

/** Rows worth interrupting the call for, compared with the previous check. */
export function changes(
  previous: ReadonlyMap<string, Status>,
  current: readonly Row[],
  since: number,
  skip: (row: Row) => boolean,
): Row[] {
  return current.filter((row) => {
    const before = previous.get(row.id)
    if (before === row.status || skip(row)) return false
    if (row.status === "approval" || row.status === "question") return true
    if (row.status !== "finished" && row.status !== "failed") return false
    // A session new to the list counts only if it finished since the last check.
    return before !== undefined || row.updated >= since
  })
}

export function updateText(rows: readonly Row[], replies: readonly (string | undefined)[]): string {
  return [
    "[Session update] Not from the user: while they were on the call,",
    ...rows.map((row, index) => {
      const reply = replies[index]
      return line(row) + (reply ? ` Latest: ${reply}` : "")
    }),
    "Tell the user right away with ios_voice_say, in one or two short sentences covering all of these, then end your turn without another reply.",
  ].join("\n")
}

export class Monitor {
  private readonly stop = new AbortController()
  private started = false
  private voice: { sessionID: string; at: number } | undefined
  private ended = 0
  private baseline: { statuses: Map<string, Status>; at: number } | undefined
  /** Sessions the phone will announce itself (ios_voice_watch_session), until their next result. */
  private readonly watched = new Set<string>()
  /** Sessions a voice_wait is on: the wait reports them. */
  private readonly waiting = new Map<string, number>()
  private phoneListed = false
  private timer: ReturnType<typeof setTimeout> | undefined
  private checking = Promise.resolve()

  /** The phone just sent the user's words to this delegator session. */
  heard(sessionID: string) {
    this.voice = { sessionID, at: Date.now() }
    if (!this.started) {
      this.started = true
      void this.run()
    }
    this.schedule()
  }

  /** ios_voice_end_call: the call is over. */
  hungUp() {
    this.ended = Date.now()
    this.baseline = undefined
  }

  watch(sessionID: string) {
    this.watched.add(sessionID)
  }

  wait(ids: readonly string[]): () => void {
    for (const id of ids) this.waiting.set(id, (this.waiting.get(id) ?? 0) + 1)
    return () => {
      for (const id of ids) {
        const count = (this.waiting.get(id) ?? 1) - 1
        if (count > 0) this.waiting.set(id, count)
        else this.waiting.delete(id)
      }
    }
  }

  close() {
    this.stop.abort()
    clearTimeout(this.timer)
  }

  private schedule() {
    clearTimeout(this.timer)
    this.timer = setTimeout(() => {
      this.checking = this.checking.then(() => this.check()).catch(report)
    }, settleMs)
  }

  private async run() {
    const signal = this.stop.signal
    const types = [
      "session.idle", "session.execution.started", "session.execution.succeeded", "session.execution.failed",
      "session.execution.interrupted", "permission.asked", "permission.replied", "form.created", "form.replied",
    ] as const
    while (!signal.aborted) {
      try {
        const api = await client()
        for await (const event of api.event.subscribe({ types, signal })) {
          if (event.type !== "server.connected" && this.voice) this.schedule()
        }
      } catch (error) {
        if (!signal.aborted) report(error)
      }
      await sleep(2000, undefined, { signal }).catch(() => undefined)
    }
  }

  private async live(api: OpenCodeClient, heardAt: number, signal: AbortSignal): Promise<boolean> {
    const locations = await api.debug.location.list({ signal })
    const lists = await Promise.all(locations.map((location) =>
      api.mcp.list({ location: { directory: location.directory } }, { signal }).catch(() => undefined)))
    const phone = lists.some((list) =>
      list?.data.some((server) => phoneServers.has(server.name) && server.status.status === "connected"))
    if (phone && !this.phoneListed) console.error("OpenCode voice monitor: the phone's tools show a live call")
    this.phoneListed ||= phone
    if (this.phoneListed) return phone
    return heardAt > this.ended && Date.now() - heardAt < fallbackCallMs
  }

  private async check() {
    const voice = this.voice
    if (!voice || Date.now() - voice.at > voiceWindowMs) {
      this.baseline = undefined
      return
    }
    const signal = AbortSignal.any([this.stop.signal, AbortSignal.timeout(15_000)])
    const api = await client()
    if (!await this.live(api, voice.at, signal)) {
      this.baseline = undefined
      return
    }
    const state = await readState(api, signal, { limit: 25 })
    const rows = state.rows.filter((row) => row.id !== voice.sessionID)
    const previous = this.baseline
    this.baseline = { statuses: new Map(rows.map((row) => [row.id, row.status])), at: Date.now() }
    if (!previous) return

    const found = changes(previous.statuses, rows, previous.at, (row) => {
      if (this.waiting.has(row.id)) return true
      const result = row.status === "finished" || row.status === "failed"
      return result && this.watched.delete(row.id)
    })
    if (!found.length) return
    const replies = await Promise.all(found.map(async (row) => {
      if (row.status !== "finished" && row.status !== "failed") return undefined
      const page = await api.message.list({ sessionID: row.id, limit: 5, order: "desc", type: "assistant" }, { signal })
        .catch(() => undefined)
      return page && excerpts(page.data as unknown as MessageLike[], 300).find((text) => !text.startsWith("Agent: (no text)"))
    }))
    // Steered: a queued update would wait out a running voice_wait, which ends on
    // its arrival so the next step reads it. Resumed, so an idle session wakes.
    await api.session.synthetic({
      sessionID: voice.sessionID,
      text: updateText(found, replies),
      description: "Session update",
      delivery: "steer",
      resume: true,
    }, { signal })
  }
}

// One monitor per server process; global plugins are instantiated per location.
// A code reload replaces it.
const generation = Symbol("voice monitor generation")
const host = globalThis as typeof globalThis & { __confOpenCodeVoiceMonitor?: { generation: symbol; monitor: Monitor } }

export function monitor(): Monitor {
  const existing = host.__confOpenCodeVoiceMonitor
  if (existing?.generation === generation) return existing.monitor
  existing?.monitor.close()
  const created = new Monitor()
  host.__confOpenCodeVoiceMonitor = { generation, monitor: created }
  return created
}
