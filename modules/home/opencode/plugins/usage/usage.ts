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
}

export const interval = 5 * 60_000

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

const claudeLabels: Record<string, string> = {
  five_hour: "5-hour",
  seven_day: "Weekly",
}

export function claudeUsage(value: unknown, id: string, label: string): Usage {
  const raw = object(value)
  const profile = (Array.isArray(raw.profiles) ? raw.profiles : []).map(object).find((item) => item.id === id)
  // Meridian calls any upstream failure "no_token", including rate limiting.
  if (!profile || profile.error || !number(profile.fetchedAt)) throw new Error("Quota unavailable in Meridian")
  const windows = (Array.isArray(profile.windows) ? profile.windows : []).flatMap((value) => {
    const item = object(value)
    if (typeof item.type !== "string") return []
    const name = claudeLabels[item.type] ?? item.type.replace(/^seven_day_/, "Weekly · ").replaceAll("_", " ")
    return window(name, number(item.utilization) ? item.utilization * 100 : null, item.resetsAt)
  })
  if (!windows.length) throw new Error("No usage windows returned")
  return { label, windows, fetchedAt: profile.fetchedAt }
}

export class FetchError extends Error {
  readonly retryAt: number
  constructor(message: string, retryAt = 0) {
    super(message)
    this.retryAt = retryAt
  }
}

export async function fetchJSON(url: string, signal: AbortSignal, headers?: Record<string, string>): Promise<unknown> {
  const response = await fetch(url, { signal, ...(headers ? { headers } : {}) })
  if (!response.ok) {
    const retry = response.headers.get("retry-after")
    const retryAt = retry === null ? 0 : /^\d+$/.test(retry) ? Date.now() + Number(retry) * 1000 : Date.parse(retry)
    throw new FetchError(`HTTP ${response.status}`, Number.isFinite(retryAt) ? retryAt : 0)
  }
  return response.json()
}

// Keep the last good reading on transient failures, but never carry it into a
// different OpenCode account. Backoff is per source, not per Waybar/monitor.
export class Source {
  readonly label: string
  private key: string | undefined
  private reading: Reading
  private nextAttempt = 0
  private failures = 0

  constructor(label: string) {
    this.label = label
    this.reading = { label }
  }

  async read(key: string, fetch: () => Promise<Usage>, now = Date.now()): Promise<Reading> {
    if (this.key !== key) {
      this.key = key
      this.reading = { label: this.label }
      this.nextAttempt = 0
      this.failures = 0
    }
    if (now < this.nextAttempt) return this.reading
    try {
      this.reading = { label: this.label, usage: await fetch() }
      this.failures = 0
      this.nextAttempt = now + interval
    } catch (error) {
      this.failures++
      this.nextAttempt = Math.max(now + Math.min(interval * 2 ** (this.failures - 1), 30 * 60_000), error instanceof FetchError ? error.retryAt : 0)
      this.reading = { ...this.reading, error: error instanceof FetchError ? error.message : "Usage unavailable" }
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

export function render(readings: Reading[], now: number, timezone: string) {
  const date = new Intl.DateTimeFormat("en-US", { timeZone: timezone, weekday: "short", hour: "numeric", minute: "2-digit", timeZoneName: "short" })
  const candidates = readings.flatMap((reading) => (reading.usage?.windows ?? []).map((window) => ({ ...window, account: reading.label })))
  const highest = candidates.reduce<typeof candidates[number] | undefined>((best, item) => !best || item.used > best.used ? item : best, undefined)
  const incomplete = readings.some((reading) => !reading.usage || reading.error || now - reading.usage.fetchedAt > interval * 2
    || reading.usage.windows.some((window) => window.resetsAt !== null && window.resetsAt <= now))
  const tooltip = [highest ? `Most used: ${highest.account} — ${highest.label} (${Math.round(highest.used)}%)` : "AI usage unavailable"]
  for (const reading of readings) {
    tooltip.push("", reading.label)
    if (reading.error || !reading.usage) tooltip.push(`  ${reading.error ?? "Waiting for usage"}${reading.usage ? " — showing last known values" : ""}`)
    if (!reading.usage) continue
    for (const item of reading.usage.windows) {
      const reset = item.resetsAt === null ? "reset not reported" : item.resetsAt <= now ? "reset passed; awaiting fresh data"
        : `resets in ${duration(item.resetsAt - now)} (${date.format(item.resetsAt)})`
      tooltip.push(`  ${item.label}: ${Math.round(item.used)}% used · ${reset}`)
    }
    tooltip.push(`  Updated ${date.format(reading.usage.fetchedAt)}${now - reading.usage.fetchedAt > interval * 2 ? " (stale)" : ""}`)
  }
  if (incomplete) tooltip.push("", "? Some usage data is unavailable or stale.")
  return {
    text: highest ? `AI ${Math.round(highest.used)}%${incomplete ? " ?" : ""}` : "AI ?",
    tooltip: escape(tooltip.join("\n")),
    class: [highest && highest.used >= 95 ? "critical" : highest && highest.used >= 80 ? "warning" : "normal", ...(incomplete ? ["incomplete"] : [])],
    ...(highest ? { percentage: Math.min(100, Math.round(highest.used)) } : {}),
    updatedAt: now,
  }
}
