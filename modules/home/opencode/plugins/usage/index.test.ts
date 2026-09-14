import assert from "node:assert/strict"
import test from "node:test"
import { syncBuiltinESMExports } from "node:module"
import { Service } from "@opencode-ai/client/service"
import type { Plugin } from "@opencode-ai/plugin"

import usage from "./index.ts"

test("polling survives a newer generation unloading while older projects remain open", async (t) => {
  // Exercise real setup/cleanup and the polling loop without touching a server,
  // credentials, or the desktop. Count polls at the service-discovery boundary.
  let polls = 0
  t.mock.method(Service, "discover", async () => { polls++; return undefined })
  t.mock.timers.enable({ apis: ["setTimeout"] })
  syncBuiltinESMExports()
  t.after(() => { t.mock.timers.reset(); syncBuiltinESMExports() })
  const bus = process.env.DBUS_SESSION_BUS_ADDRESS
  const runtime = process.env.XDG_RUNTIME_DIR
  process.env.DBUS_SESSION_BUS_ADDRESS = "usage-lifecycle-test"
  process.env.XDG_RUNTIME_DIR = "/unused-usage-lifecycle-test"
  const cleanups = new Set<Plugin.Cleanup>()
  const settle = () => new Promise<void>((resolve) => setImmediate(resolve))
  const setup = async (plugin: Plugin.Plugin) => {
    const cleanup = await plugin.setup({ options: {} } as Plugin.Context)
    assert.ok(cleanup)
    cleanups.add(cleanup)
    await settle()
    return async () => { await cleanup(); cleanups.delete(cleanup); await settle() }
  }
  const nextPoll = async () => {
    t.mock.timers.tick(5 * 60_000)
    await settle()
  }
  try {
    const first = await setup(usage)
    const second = await setup(usage)
    assert.equal(polls, 1, "Projects share one polling loop")
    await nextPoll()
    assert.equal(polls, 2)

    const reloaded = (await import(new URL("./index.ts?usage-lifecycle-test", import.meta.url).href)).default as Plugin.Plugin
    const temporary = await setup(reloaded)
    assert.equal(polls, 3, "A new generation replaces the old loop and polls immediately")
    await temporary()
    await nextPoll()
    assert.equal(polls, 4, "Closing the newer project must not stop polling for older projects")

    await first()
    await nextPoll()
    assert.equal(polls, 5, "An older project's cleanup must retain the other older owner")
    await second()
    await nextPoll()
    assert.equal(polls, 5, "The last old owner must stop the replacement loop")
  } finally {
    for (const cleanup of cleanups) await cleanup()
    if (bus === undefined) delete process.env.DBUS_SESSION_BUS_ADDRESS
    else process.env.DBUS_SESSION_BUS_ADDRESS = bus
    if (runtime === undefined) delete process.env.XDG_RUNTIME_DIR
    else process.env.XDG_RUNTIME_DIR = runtime
  }
})
