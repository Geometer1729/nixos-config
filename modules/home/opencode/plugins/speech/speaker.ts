import type { Mode } from "./rpc.ts"

export interface Playback {
  readonly done: Promise<void>
  stop(): void
}

// Holds each session's messages until the user views that session, and plays
// them only while it stays viewed. Leaving it or stopping drops what is left.
export class Speaker {
  private readonly pending = new Map<string, string[]>()
  private viewed: string | undefined
  private current: { sessionID: string; playback: Playback } | undefined
  private readonly play: (text: string) => Playback

  constructor(play: (text: string) => Playback) {
    this.play = play
  }

  get speaking(): boolean {
    return this.current !== undefined
  }

  add(sessionID: string, text: string, mode: Mode): void {
    if (mode === "replace") {
      // A replacement also supersedes the message playing now.
      if (this.current?.sessionID === sessionID) this.cut()
      this.pending.set(sessionID, [text])
    } else {
      this.pending.set(sessionID, [...(this.pending.get(sessionID) ?? []), text])
    }
    this.next()
  }

  // The session on screen in a focused terminal, if any.
  view(sessionID: string | undefined): void {
    if (sessionID === this.viewed) return
    this.viewed = sessionID
    if (this.current && this.current.sessionID !== sessionID) this.stop()
    this.next()
  }

  stop(): void {
    const current = this.cut()
    if (current) this.pending.delete(current.sessionID)
  }

  private cut() {
    const current = this.current
    this.current = undefined
    current?.playback.stop()
    return current
  }

  private next(): void {
    if (this.current || this.viewed === undefined) return
    const sessionID = this.viewed
    const queue = this.pending.get(sessionID)
    const text = queue?.shift()
    if (text === undefined) return
    if (queue!.length === 0) this.pending.delete(sessionID)
    const playback = this.play(text)
    this.current = { sessionID, playback }
    void playback.done.then(() => {
      if (this.current?.playback !== playback) return
      this.current = undefined
      this.next()
    })
  }
}
