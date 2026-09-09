import { randomUUID } from "node:crypto"

import { Plugin } from "@opencode-ai/plugin"

// V2 adapter for Meridian's V1 chat.headers plugin. Provider configuration
// still owns proxy routing; this supplies tracking and model-tier metadata.
export default Plugin.define({
  id: "bbrian.meridian",
  async setup(context) {
    await context.session.hook("http.request", async (event) => {
      const { data: agent } = await context.agent.get({ agentID: event.agent })
      // Auxiliary requests can carry the primary agent's ID in V2.
      const kind = (event as typeof event & { kind?: string }).kind
      const auxiliary = kind === "title" || kind === "compaction"
      const headers = event.request.headers
      headers.set("x-opencode-session", event.sessionID)
      // The V2 HTTP hook has no message ID; identify each physical request.
      headers.set("x-opencode-request", randomUUID())
      headers.set("x-opencode-agent-mode", auxiliary || agent.mode === "subagent" ? "subagent" : "primary")
      headers.set("x-opencode-agent-name", event.agent.replace(/[^\x20-\x7E]/g, "").trim() || "unknown")
    }, { providerID: "anthropic" })
  },
})
