import assert from "node:assert/strict"
import { readFileSync, realpathSync, writeFileSync } from "node:fs"
import path from "node:path"
import { pathToFileURL } from "node:url"

// Run inside the pinned OpenCode loader, so import failures (including TUI
// dependencies) fail the check. Vim's editing engine has separate unit tests.
export default {
  id: "test.plugin-load",
  async setup() {
    const entries = JSON.parse(readFileSync(process.env.OPENCODE_CHECK_ENTRIES, "utf8"))
    assert.ok(entries.length > 0)
    const expected = []
    for (const entry of entries) {
      const file = path.join(process.env.XDG_CONFIG_HOME, "opencode/plugins", entry.path)
      if (!entry.server) {
        assert.equal(realpathSync(Bun.resolveSync("./tui", path.dirname(file))), realpathSync(file))
      }
      const plugin = (await import(pathToFileURL(file).href)).default
      assert.equal(typeof plugin.id, "string", file)
      assert.ok(typeof plugin.setup === "function" || typeof plugin.effect === "function", file)
      expected.push({ id: plugin.id, server: entry.server })
    }
    writeFileSync(process.env.OPENCODE_CHECK_EXPECTED, JSON.stringify(expected))
  },
}
