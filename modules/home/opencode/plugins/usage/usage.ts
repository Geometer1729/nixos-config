export interface Window {
  label: string
  used: number
  resetsAt: number | null
}

export interface Usage {
  label: string
  windows: Window[]
  fetchedAt: number
}

export interface Reading {
  label: string
  usage?: Usage
  error?: string
  // Only a new sign-in can fix `error`.
  signIn?: boolean
}

export const interval = 5 * 60_000
// Readings older than this mark the bar incomplete. A single failed or
// backed-off poll is not enough; the tooltip still names the error.
export const staleAfter = 3 * interval
// A forced refresh (credentials changed, or the bar was clicked) still never
// polls the same source more often than this.
export const forceSpacing = 15_000

function object(value: unknown): Record<string, unknown> {
  return value !== null && typeof value === "object" && !Array.isArray(value)
    ? value as Record<string, unknown> : {}
}

function number(value: unknown): value is number {
  return typeof value === "number" && Number.isFinite(value) && value >= 0
}

function window(label: string, used: unknown, reset: unknown): Window[] {
  if (!number(used)) return []
  return [{ label, used, resetsAt: number(reset) ? reset : null }]
}

export function codexUsage(value: unknown, now: number): Usage {
  const raw = object(value)
  const windows: Window[] = []
  const add = (name: string, limits: unknown) => {
    const source = object(limits)
    for (const key of ["primary_window", "secondary_window"]) {
      const item = object(source[key])
      const duration = item.limit_window_seconds
      const label = duration === 18_000 ? "5-hour" : duration === 604_800 ? "Weekly"
        : number(duration) ? `${Math.round(duration / 60)}-minute` : key === "primary_window" ? "Primary" : "Secondary"
      windows.push(...window(`${name}${label}`, item.used_percent, number(item.reset_at) ? item.reset_at * 1000 : null))
    }
  }
  add("", raw.rate_limit)
  add("Code review · ", raw.code_review_rate_limit)
  if (Array.isArray(raw.additional_rate_limits)) {
    for (const value of raw.additional_rate_limits) {
      const item = object(value)
      add(`${typeof item.limit_name === "string" ? item.limit_name : "Additional limit"} · `, item.rate_limit)
    }
  }
  if (!windows.length) throw new Error("No usage windows returned")
  return { label: "Codex", windows, fetchedAt: now }
}

export function claudeUsage(value: unknown, label: string, now: number): Usage {
  const raw = object(value)
  const windows: Window[] = []
  const add = (name: string, used: unknown, reset: unknown) => {
    if (windows.some((item) => item.label.toLowerCase() === name.toLowerCase())) return
    windows.push(...window(name, used, typeof reset === "string" ? Date.parse(reset) : null))
  }
  for (const [key, value] of Object.entries(raw)) {
    const scope = /^seven_day_(.+)$/.exec(key)?.[1]
    const name = key === "five_hour" ? "5-hour" : key === "seven_day" ? "Weekly" : scope ? `Weekly · ${scope.replaceAll("_", " ")}` : undefined
    if (name) add(name, object(value).utilization, object(value).resets_at)
  }
  // Model-specific weekly limits are only reported in this list.
  if (Array.isArray(raw.limits)) {
    for (const value of raw.limits) {
      const item = object(value)
      const model = object(object(item.scope).model)
      const name = typeof model.display_name === "string" ? model.display_name : model.id
      if (item.kind === "weekly_scoped" && typeof name === "string") add(`Weekly · ${name}`, item.percent, item.resets_at)
    }
  }
  if (!windows.length) throw new Error("No usage windows returned")
  return { label, windows, fetchedAt: now }
}

export interface ClaudeProfile {
  name: string
  credentials: unknown
  config: unknown
}

export type ClaudeAccount = { label: string; id: string } & ({ token: string } | { error: string })

// Profiles signed into the same account share one quota, so they are read
// once, with whichever token Claude Code renewed last. Renewal is left to
// Claude Code: refreshing here could race its refresh-token rotation.
export function claudeAccounts(profiles: ClaudeProfile[], now: number): ClaudeAccount[] {
  const groups = new Map<string, { names: string[]; token?: string; expiresAt: number }>()
  for (const profile of profiles) {
    const oauth = object(object(profile.credentials).claudeAiOauth)
    const account = object(object(profile.config).oauthAccount).accountUuid
    const token = typeof oauth.accessToken === "string" ? oauth.accessToken : undefined
    const id = token && typeof account === "string" ? account : `signed-out:${profile.name}`
    const group = groups.get(id) ?? { names: [], expiresAt: 0 }
    group.names.push(profile.name)
    if (token && number(oauth.expiresAt) && oauth.expiresAt > group.expiresAt) {
      group.token = token
      group.expiresAt = oauth.expiresAt
    }
    groups.set(id, group)
  }
  return [...groups].map(([id, group]) => {
    const label = `Claude ${group.names.join(" + ")}`
    if (id.startsWith("signed-out:")) return { label, id, error: "Not signed in to Claude Code; click the bar to sign in" }
    if (!group.token || group.expiresAt <= now) return { label, id, error: "Sign-in expired; click the bar to renew" }
    return { label, id, token: group.token }
  })
}

// Errors whose message is safe to show. `signIn` marks failures that only a
// new sign-in can fix; clicking the bar (ai-usage-renew) offers one.
export class UsageError extends Error {
  readonly signIn: boolean
  constructor(message: string, signIn = false) {
    super(message)
    this.signIn = signIn
  }
}

export class FetchError extends UsageError {
  readonly status: number
  readonly retryAt: number
  constructor(status: number, retryAt = 0, message = `HTTP ${status}`, signIn = false) {
    super(message, signIn)
    this.status = status
    this.retryAt = retryAt
  }
}

export async function fetchJSON(url: string, signal: AbortSignal, headers?: Record<string, string>): Promise<unknown> {
  const response = await fetch(url, { signal, ...(headers ? { headers } : {}) })
  if (!response.ok) {
    const retry = response.headers.get("retry-after")
    const retryAt = retry === null ? 0 : /^\d+$/.test(retry) ? Date.now() + Number(retry) * 1000 : Date.parse(retry)
    throw new FetchError(response.status, Number.isFinite(retryAt) ? retryAt : 0)
  }
  return response.json()
}

// A local precondition failed (signed out, expired token) before any request
// was made. It costs nothing to re-check, so it never causes backoff.
export class Unavailable extends UsageError {}

// Keep the last good reading on transient failures, but never carry it into a
// different OpenCode account. Backoff is per source, not per Waybar/monitor.
export class Source {
  readonly label: string
  private key: string | undefined
  private reading: Reading
  private nextAttempt = 0
  private retryAt = 0
  private lastRequest = -Infinity
  private failures = 0

  constructor(label: string) {
    this.label = label
    this.reading = { label }
  }

  // `force` skips backoff (credentials just changed, or the user asked), but
  // still honours the server's Retry-After and a short minimum spacing.
  async read(key: string, fetch: () => Promise<Usage>, now = Date.now(), force = false): Promise<Reading> {
    if (this.key !== key) {
      this.key = key
      this.reading = { label: this.label }
      this.nextAttempt = 0
      this.retryAt = 0
      this.failures = 0
    }
    if (force) this.nextAttempt = Math.min(this.nextAttempt, Math.max(this.retryAt, this.lastRequest + forceSpacing))
    if (now < this.nextAttempt) return this.reading
    try {
      const usage = await fetch()
      this.reading = { label: this.label, usage }
      this.failures = 0
      this.retryAt = 0
      this.lastRequest = now
      this.nextAttempt = now + interval
    } catch (error) {
      if (error instanceof Unavailable) {
        this.nextAttempt = this.retryAt
      } else {
        this.failures++
        this.lastRequest = now
        this.retryAt = error instanceof FetchError ? error.retryAt : 0
        this.nextAttempt = Math.max(now + Math.min(interval * 2 ** (this.failures - 1), 30 * 60_000), this.retryAt)
      }
      // The sign-in flag describes this failure only; it outlives backoff but
      // not the next attempt.
      this.reading = {
        label: this.label,
        ...(this.reading.usage && { usage: this.reading.usage }),
        error: error instanceof UsageError ? error.message : "Usage unavailable",
        ...(error instanceof UsageError && error.signIn && { signIn: true }),
      }
    }
    return this.reading
  }
}

function escape(value: string): string {
  return value.replaceAll("&", "&amp;").replaceAll("<", "&lt;").replaceAll(">", "&gt;")
}

function duration(ms: number): string {
  const minutes = Math.max(1, Math.ceil(ms / 60_000))
  if (minutes < 60) return `${minutes}m`
  const hours = Math.floor(minutes / 60)
  if (hours < 24) return `${hours}h ${minutes % 60}m`
  return `${Math.floor(hours / 24)}d ${hours % 24}h`
}

// A window whose reset time has passed is known to be empty again; showing the
// pre-reset value would overstate usage until the next poll.
function current(window: Window, now: number): Window {
  return window.resetsAt !== null && window.resetsAt <= now ? { ...window, used: 0 } : window
}

export function render(readings: Reading[], now: number, timezone: string) {
  const date = new Intl.DateTimeFormat("en-US", { timeZone: timezone, weekday: "short", hour: "numeric", minute: "2-digit", timeZoneName: "short" })
  const candidates = readings.flatMap((reading) => (reading.usage?.windows ?? []).map((window) => ({ ...current(window, now), account: reading.label })))
  const highest = candidates.reduce<typeof candidates[number] | undefined>((best, item) => !best || item.used > best.used ? item : best, undefined)
  const stale = (usage: Usage) => now - usage.fetchedAt > staleAfter
  const incomplete = readings.some((reading) => !reading.usage || stale(reading.usage))
  const tooltip = [highest ? `Most used: ${highest.account} — ${highest.label} (${Math.round(highest.used)}%)` : "AI usage unavailable"]
  for (const reading of readings) {
    tooltip.push("", reading.label)
    if (reading.error || !reading.usage) tooltip.push(`  ${reading.error ?? "Waiting for usage"}${reading.usage ? " — showing last known values" : ""}`)
    if (!reading.usage) continue
    for (const window of reading.usage.windows) {
      const item = current(window, now)
      const reset = item.resetsAt === null ? "reset not reported" : item.resetsAt <= now ? `reset ${date.format(item.resetsAt)}`
        : `resets in ${duration(item.resetsAt - now)} (${date.format(item.resetsAt)})`
      tooltip.push(`  ${item.label}: ${Math.round(item.used)}% used · ${reset}`)
    }
    tooltip.push(`  Updated ${date.format(reading.usage.fetchedAt)}${stale(reading.usage) ? " (stale)" : ""}`)
  }
  if (incomplete) tooltip.push("", "? Some usage data is unavailable or stale.")
  tooltip.push("", "Click: renew sign-ins and refresh")
  return {
    text: highest ? `AI ${Math.round(highest.used)}%${incomplete ? " ?" : ""}` : "AI ?",
    tooltip: escape(tooltip.join("\n")),
    class: [highest && highest.used >= 95 ? "critical" : highest && highest.used >= 80 ? "warning" : "normal", ...(incomplete ? ["incomplete"] : [])],
    ...(highest ? { percentage: Math.min(100, Math.round(highest.used)) } : {}),
    // For ai-usage-renew, not Waybar: sources it should open a sign-in for.
    signIn: readings.filter((reading) => reading.signIn).map((reading) => reading.label),
    updatedAt: now,
  }
}
