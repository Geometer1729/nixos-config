import { Rpc } from "@opencode/plugin/rpc"

export type Mode = "replace" | "queue"

export interface Said {
  sessionID: string
}

export interface Speaking {
  sessionID?: string
}

export interface View {
  client: string
  sessionID?: string
}

const empty = { type: "object", additionalProperties: false } as const

// The server queues, synthesizes, and plays each message; each TUI reports the
// session it shows while its terminal has focus.
export const Speech = Rpc.define({
  id: "speech",
  methods: {
    // From a TUI: the session it shows in a focused terminal, or none.
    view: {
      input: {
        type: "object",
        properties: {
          client: { type: "string" },
          sessionID: { type: "string" },
        },
        required: ["client"],
        additionalProperties: false,
      },
      output: empty,
    },
    // Stops the message playing and drops the rest of its session's.
    stop: { input: empty, output: empty },
  },
  events: {
    // A message arrived. TUIs report their view again, in case the server lost it.
    said: {
      schema: {
        type: "object",
        properties: { sessionID: { type: "string" } },
        required: ["sessionID"],
        additionalProperties: false,
      },
    },
    // The session whose message is playing, or none.
    speaking: {
      schema: {
        type: "object",
        properties: { sessionID: { type: "string" } },
        additionalProperties: false,
      },
    },
  },
})
