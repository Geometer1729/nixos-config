import type { Status } from "./overview.ts"

export type Outcome<T> = { type: "result"; result: T } | { type: "user_spoke" } | { type: "update" } | { type: "timeout" }

/** Something arrived in the waiting session's own inbox: the user's words, or a [Session update]. */
export type Interruption = "user_spoke" | "update"

/** How long work sent just before a wait may take to start before an idle session counts as done. */
export const sendGraceMs = 60_000

/**
 * Whether a waited-on session has something to report. `status` is undefined for
 * an unknown session, which is reported rather than waited on.
 */
export function settles(status: Status | undefined, at: {
  /** When the session last went idle. */
  idle: number | undefined
  /** Whether a check during this wait saw it running. */
  ran: boolean
  /** When the wait started. */
  started: number
  /** When voice_send_message last sent it work. */
  sent: number | undefined
  now: number
}): boolean {
  if (status === undefined || status === "approval" || status === "question") return true
  if (status === "running") return false
  // Work sent just before the wait may already be done, or not started yet.
  if (at.ran || (at.idle ?? 0) >= Math.min(at.started, at.sent ?? at.started)) return true
  return at.sent === undefined || at.now - at.sent >= sendGraceMs
}

/**
 * Re-runs `check` whenever `wakes` reports a relevant event (and at least every
 * `pollMs`, in case the stream drops one) until it returns a result, the user
 * speaks on the call, the deadline passes, or `signal` aborts.
 */
export async function waitUntil<T>(options: {
  check: (first: boolean) => Promise<T | undefined>
  wakes: (signal: AbortSignal, wake: (interruption?: Interruption) => void) => Promise<void>
  timeoutMs: number
  pollMs: number
  signal: AbortSignal
}): Promise<Outcome<T>> {
  const stop = new AbortController()
  const signal = AbortSignal.any([options.signal, stop.signal])
  let dirty = true
  let interrupted: Interruption | undefined
  let release: (() => void) | undefined
  const wake = (interruption?: Interruption) => {
    // The user's words win over an update that arrived alongside them.
    if (interruption && interrupted !== "user_spoke") interrupted = interruption
    dirty = true
    release?.()
  }
  const pump = options.wakes(signal, wake).catch(() => undefined)
  const deadline = Date.now() + options.timeoutMs
  let first = true
  try {
    while (true) {
      options.signal.throwIfAborted()
      if (interrupted) return { type: interrupted }
      if (dirty) {
        dirty = false
        const result = await options.check(first)
        first = false
        if (result !== undefined) return { type: "result", result }
        continue
      }
      const remaining = deadline - Date.now()
      if (remaining <= 0) return { type: "timeout" }
      await new Promise<void>((resolve) => {
        const timer = setTimeout(() => {
          dirty = true
          done()
        }, Math.min(remaining, options.pollMs))
        const done = () => {
          clearTimeout(timer)
          options.signal.removeEventListener("abort", done)
          release = undefined
          resolve()
        }
        release = done
        options.signal.addEventListener("abort", done, { once: true })
      })
    }
  } finally {
    stop.abort()
    await pump
  }
}
