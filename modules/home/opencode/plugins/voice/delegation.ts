// The OpenCode phone apps' session delegator (Settings › Experimental › OpenCode
// Session Delegator) steers each spoken request into a real session as a prompt
// built from these bracketed sections. iOS says "[iPhone context]" where Android
// says "[Phone context]". Reverse-engineered from opencode-android's
// VoiceSessionDelegator.formatPrompt; the apps don't document it.
const marker = /^\[(?:Voice delta|Voice call active|i?Phone context|Outcome check)\]/m

export function isDelegation(text: string): boolean {
  return marker.test(text)
}

/** Automatic mode finds or creates the delegator session by this exact title. */
export const automaticTitle = "Voice"

/** A delegator session stays in voice mode this long after the phone's last prompt. */
export const voiceWindowMs = 30 * 60_000

export class VoiceSessions {
  private seen = new Map<string, number>()

  mark(sessionID: string, now = Date.now()) {
    this.seen.set(sessionID, now)
  }

  has(sessionID: string, now = Date.now()): boolean {
    const last = this.seen.get(sessionID)
    if (last === undefined) return false
    if (now - last <= voiceWindowMs) return true
    this.seen.delete(sessionID)
    return false
  }
}

export interface ModelRef {
  providerID: string
  id: string
  variant?: string
}

/** `provider/model#variant`, as models are written in opencode.json. */
export function parseModel(value: unknown): ModelRef | undefined {
  if (typeof value !== "string") return undefined
  const match = /^([^/#]+)\/([^#]+)(?:#(.+))?$/.exec(value.trim())
  if (!match) return undefined
  const [, providerID, id, variant] = match
  return { providerID: providerID!, id: id!, ...(variant ? { variant } : {}) }
}
