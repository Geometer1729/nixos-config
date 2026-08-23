export const NotificationPlugin = async ({ directory }) => {
  const notify = (eventType) => {
    Bun.spawn({
      cmd: ["opencode-notify", eventType, directory],
      stdout: "ignore",
      stderr: "ignore",
    })
  }

  return {
    event: async ({ event }) => {
      if (event.type === "session.idle") notify("ready")
      if (event.type === "permission.asked") notify("permission")
    },
  }
}
