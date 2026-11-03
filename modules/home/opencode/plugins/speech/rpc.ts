import { Rpc } from "@opencode/plugin/rpc"

export type Mode = "replace" | "queue"

export interface Said {
  sessionID: string
  text: string
  mode: Mode
}

// The server's speak tool announces each message; a TUI showing that session plays it.
export const Speech = Rpc.define({
  id: "speech",
  methods: {},
  events: {
    said: {
      schema: {
        type: "object",
        properties: {
          sessionID: { type: "string" },
          text: { type: "string" },
          mode: { type: "string", enum: ["replace", "queue"] },
        },
        required: ["sessionID", "text", "mode"],
        additionalProperties: false,
      },
    },
  },
})
