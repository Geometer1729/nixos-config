import { mkdtempSync, rmSync } from "node:fs"
import { tmpdir } from "node:os"
import { join } from "node:path"

import { Plugin } from "@opencode/plugin"

import { type Mode, Speech, type View } from "./rpc.ts"
import { Speaker } from "./speaker.ts"
import { type Commands, prepare } from "./voice.ts"

const description = [
  "Say a short message aloud to the user, who often runs several agents at once and may not be reading this session.",
  "Use it at the moments they would want to look over: you finished a substantial piece of work, you need their decision or input, or you are blocked.",
  "Speak as you would to a colleague across the room: one or two plain sentences with the gist, not a recap of your written reply.",
  "Never speak code, file paths, URLs, command output, or lists, and do not narrate routine progress or speak every turn.",
  "It plays only while the user is viewing this session in a focused terminal: right away if they are, otherwise when they switch to it.",
  "Switching away or pressing Escape stops it. Returns immediately.",
].join(" ")

const generation = Symbol("speech plugin generation")
const loaded = performance.now()

// Global plugins run once per location, but every location shares this process's
// Speaker, so each message is synthesized once and waits here for any TUI to view
// its session. A code reload replaces it; an older module never replaces a newer one.
// It plays on the server's machine, so a TUI attached from another machine would
// make it speak here. Supporting that means sending that TUI the audio instead.
interface Shared {
  generation: symbol
  loaded: number
  speaker: Speaker
  // Each location's emitter; an event from any of them reaches every TUI.
  emitters: Set<(sessionID: string | undefined) => void>
  close(): void
}
const host = globalThis as typeof globalThis & { __confOpenCodeSpeech?: Shared }

function shared(commands: Commands): Shared {
  const existing = host.__confOpenCodeSpeech
  if (existing && (existing.generation === generation || existing.loaded > loaded)) return existing
  existing?.close()
  const directory = mkdtempSync(join(tmpdir(), "opencode-speech-"))
  const emitters = new Set<(sessionID: string | undefined) => void>()
  const speaker = new Speaker(
    (text) => prepare(commands, directory, text),
    (sessionID) => {
      const [emit] = emitters
      emit?.(sessionID)
    },
  )
  return (host.__confOpenCodeSpeech = {
    generation,
    loaded,
    speaker,
    emitters,
    close: () => {
      speaker.close()
      rmSync(directory, { recursive: true, force: true })
    },
  })
}

export default Plugin.define({
  id: "local.speech",
  async setup(ctx) {
    const { synthesize, play } = ctx.options
    if (typeof synthesize !== "string" || typeof play !== "string") return
    const speaker = () => shared({ synthesize, play }).speaker

    const speech = await ctx.rpc.register(Speech, {
      view: async (input) => {
        const { client, sessionID } = input as View
        speaker().view(client, sessionID)
        return {}
      },
      stop: async () => {
        speaker().stop()
        return {}
      },
    })
    const emit = (sessionID: string | undefined) => {
      speech.events.emit("speaking", sessionID === undefined ? {} : { sessionID })
        .catch((error) => console.error("OpenCode speech:", error))
    }
    shared({ synthesize, play }).emitters.add(emit)

    // A subagent speaks for the session the user has open.
    const root = async (sessionID: string): Promise<string> => {
      let session = await ctx.session.get({ sessionID })
      while (session.parentID) session = await ctx.session.get({ sessionID: session.parentID })
      return session.id
    }

    await ctx.tool.transform((tools) => {
      tools.add({
        name: "speak",
        description,
        input: {
          type: "object",
          properties: {
            text: { type: "string", minLength: 1, description: "What to say, written to be heard" },
            mode: {
              type: "string",
              enum: ["replace", "queue"],
              description:
                "replace (default) discards this session's earlier messages that have not played, when the new one supersedes them; queue plays after them",
            },
          },
          required: ["text"],
          additionalProperties: false,
        },
        options: { codemode: false, permission: "speak" },
        execute: async (rawInput, toolContext) => {
          const input = rawInput as { text: string; mode?: Mode }
          const sessionID = await root(toolContext.sessionID)
          speaker().add(sessionID, input.text, input.mode ?? "replace")
          await speech.events.emit("said", { sessionID })
          return { content: "Queued to play while the user is viewing this session." }
        },
      })
    })

    return () => {
      host.__confOpenCodeSpeech?.emitters.delete(emit)
    }
  },
})
