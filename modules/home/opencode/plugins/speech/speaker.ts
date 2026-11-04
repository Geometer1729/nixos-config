import type { Mode } from "./rpc.ts"

export interface Playback {
  readonly done: Promise<void>
  stop(): void
}

// A message being made ready to play, from the moment it arrives.
export interface Clip {
  play(): Playback
  // Frees what it holds; called once, whether or not it played.
  discard(): void
}

interface Playing {
  sessionID: string
  clip: Clip
  playback: Playback
}

// Holds each session's messages until the user views that session, and plays
// them only while it stays viewed. Leaving it or stopping drops what is left.
export class Speaker {
  private readonly pending = new Map<string, Clip[]>()
  // The TUI in the focused terminal and the session it shows.
  private viewer: { client: string; sessionID: string } | undefined
  private current: Playing | undefined
  private readonly prepare: (text: string) => Clip
  private readonly speaking: (sessionID: string | undefined) => void

  constructor(prepare: (text: string) => Clip, speaking: (sessionID: string | undefined) => void = () => {}) {
    this.prepare = prepare
    this.speaking = speaking
  }

  add(sessionID: string, text: string, mode: Mode): void {
    const clip = this.prepare(text)
    if (mode === "replace") {
      // A replacement also supersedes the message playing now.
      if (this.current?.sessionID === sessionID) this.cut()
      this.drop(sessionID)
      this.pending.set(sessionID, [clip])
    } else {
      this.pending.set(sessionID, [...(this.pending.get(sessionID) ?? []), clip])
    }
    this.next()
  }

  // A TUI's session on screen in a focused terminal, or none. Focus moves
  // between TUIs with their reports in either order, so only the viewer's own
  // report clears it.
  view(client: string, sessionID: string | undefined): void {
    if (sessionID !== undefined) this.viewer = { client, sessionID }
    else if (this.viewer?.client === client) this.viewer = undefined
    else return
    if (this.current && this.current.sessionID !== this.viewer?.sessionID) this.stop()
    this.next()
  }

  stop(): void {
    const current = this.cut()
    if (current) this.drop(current.sessionID)
  }

  // Stops and drops every session's messages.
  close(): void {
    this.viewer = undefined
    this.cut()
    for (const sessionID of [...this.pending.keys()]) this.drop(sessionID)
  }

  private set(current: Playing | undefined): void {
    this.current = current
    this.speaking(current?.sessionID)
  }

  private cut() {
    const current = this.current
    if (!current) return undefined
    this.set(undefined)
    current.playback.stop()
    current.clip.discard()
    return current
  }

  private drop(sessionID: string): void {
    for (const clip of this.pending.get(sessionID) ?? []) clip.discard()
    this.pending.delete(sessionID)
  }

  private next(): void {
    if (this.current || this.viewer === undefined) return
    const sessionID = this.viewer.sessionID
    const queue = this.pending.get(sessionID)
    const clip = queue?.shift()
    if (clip === undefined) return
    if (queue!.length === 0) this.pending.delete(sessionID)
    const playback = clip.play()
    this.set({ sessionID, clip, playback })
    void playback.done.then(() => {
      if (this.current?.playback !== playback) return
      this.set(undefined)
      clip.discard()
      this.next()
    })
  }
}
