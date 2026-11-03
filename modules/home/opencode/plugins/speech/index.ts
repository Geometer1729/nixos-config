import { Plugin } from "@opencode/plugin"

import { type Mode, Speech } from "./rpc.ts"

const description = [
  "Say a short message aloud to the user, who often runs several agents at once and may not be reading this session.",
  "Use it at the moments they would want to look over: you finished a substantial piece of work, you need their decision or input, or you are blocked.",
  "Speak as you would to a colleague across the room: one or two plain sentences with the gist, not a recap of your written reply.",
  "Never speak code, file paths, URLs, command output, or lists, and do not narrate routine progress or speak every turn.",
  "It plays only while the user is viewing this session in a focused terminal: right away if they are, otherwise when they switch to it.",
  "Switching away or pressing Escape stops it. Returns immediately.",
].join(" ")

export default Plugin.define({
  id: "local.speech",
  async setup(ctx) {
    const speech = await ctx.rpc.register(Speech, {})

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
          await speech.events.emit("said", {
            sessionID: await root(toolContext.sessionID),
            text: input.text,
            mode: input.mode ?? "replace",
          })
          return { content: "Queued to play while the user is viewing this session." }
        },
      })
    })
  },
})
