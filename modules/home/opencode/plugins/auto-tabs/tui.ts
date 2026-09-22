import { Plugin } from "@opencode/plugin/tui"

export default Plugin.define({
  id: "local.auto-tabs",
  setup(context) {
    const directory = context.data.location.default().directory
    return context.data.on("session.created", ({ data }) => {
      if (data.parentID || data.location.directory !== directory) return
      // Open in the background, preserving the current session and its draft.
      context.ui.tabs.open(data.sessionID)
    })
  },
})
