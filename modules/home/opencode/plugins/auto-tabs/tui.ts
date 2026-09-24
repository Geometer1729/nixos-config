import { Plugin } from "@opencode/plugin/tui"

export default Plugin.define({
  id: "local.auto-tabs",
  setup(context) {
    const directory = context.data.location.default().directory
    return context.data.on("session.created", ({ data }) => {
      if (data.parentID || data.location.directory !== directory) return
      context.ui.tabs.focus(data.sessionID)
    })
  },
})
