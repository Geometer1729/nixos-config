import { randomUUID } from "node:crypto"
import { isAbsolute, relative } from "node:path"

import { Plugin } from "@opencode/plugin"

const inside = (directory: string, root: string) => {
  const path = relative(root, directory)
  return path !== ".." && !path.startsWith("../") && !isAbsolute(path)
}

// V2 adapter for Meridian's V1 chat.headers plugin. Provider configuration
// still owns proxy routing; this supplies tracking and model-tier metadata.
export default Plugin.define({
  id: "bbrian.meridian",
  async setup(context) {
    const { workDirectory, workProfile, personalProfile } = context.options
    // Plugins are instantiated per location. Worktrees can live outside the
    // checkout, so the canonical checkout also decides which account pays.
    const work = typeof workDirectory === "string"
      && [context.location.directory, context.location.project.canonical].some((directory) => inside(directory, workDirectory))
    const profile = work ? workProfile : personalProfile
    await context.session.hook("http.request", async (event) => {
      const { data: agent } = await context.agent.get({ agentID: event.agent })
      // Auxiliary requests can carry the primary agent's ID in V2.
      const auxiliary = event.kind !== "primary"
      // Meridian resumes whichever request last stored a session ID, so a title
      // finishing after the first turn would replace the conversation. Compaction
      // continues the conversation and keeps its ID.
      const detached = event.kind === "title" || event.kind === "generate"
      const headers = event.request.headers
      headers.set("x-opencode-session", detached ? `${event.sessionID}:${event.kind}` : event.sessionID)
      // The V2 HTTP hook has no message ID; identify each physical request.
      headers.set("x-opencode-request", randomUUID())
      headers.set("x-opencode-agent-mode", auxiliary || agent.mode === "subagent" ? "subagent" : "primary")
      headers.set("x-opencode-agent-name", event.agent.replace(/[^\x20-\x7E]/g, "").trim() || "unknown")
      if (typeof profile === "string") headers.set("x-meridian-profile", profile)
    }, { providerID: "anthropic" })
  },
})
