import assert from "node:assert/strict"
import test from "node:test"
import { mkdtemp, rm } from "node:fs/promises"
import { tmpdir } from "node:os"
import { join } from "node:path"
import { Service } from "@opencode-ai/client/service"
import type { Plugin } from "@opencode-ai/plugin"

import notifications from "./index.ts"

test("locations share a reader, setup refreshes it, and code reload cannot be stopped by an old owner", async (t) => {
  // Keep this lifecycle test off the real server and desktop.
  t.mock.method(Service, "discover", async () => undefined)
  t.mock.method(console, "error", () => undefined)
  const bus = process.env.DBUS_SESSION_BUS_ADDRESS
  const runtime = process.env.XDG_RUNTIME_DIR
  const directory = await mkdtemp(join(tmpdir(), "oc-presence-"))
  process.env.XDG_RUNTIME_DIR = directory
  process.env.DBUS_SESSION_BUS_ADDRESS = "notification-lifecycle-test"
  const context = { options: { command: "unused-test-notifier" } } as unknown as Plugin.Context
  const host = globalThis as typeof globalThis & {
    __confOpenCodeWaiting?: { controller: AbortController; request(): void; users: number }
  }
  const cleanups: Plugin.Cleanup[] = []
  try {
    const first = await notifications.setup(context)
    const second = await notifications.setup(context)
    assert.ok(first && second)
    cleanups.push(first, second)
    const original = host.__confOpenCodeWaiting
    assert.ok(original)
    assert.equal(original.users, 2)
    await first()
    cleanups.shift()
    assert.equal(original.controller.signal.aborted, false)

    const reloaded = (await import(new URL("./index.ts?lifecycle-test", import.meta.url).href)).default as Plugin.Plugin
    const replacement = await reloaded.setup(context)
    assert.ok(replacement)
    cleanups.push(replacement)
    const current = host.__confOpenCodeWaiting
    assert.ok(current)
    assert.notEqual(current, original)
    assert.equal(original.controller.signal.aborted, true)
    await second()
    cleanups.shift()
    assert.equal(host.__confOpenCodeWaiting, current)
    assert.equal(current.controller.signal.aborted, false)

    let refreshes = 0
    current.request = () => { refreshes++ }
    const added = await reloaded.setup(context)
    assert.ok(added)
    cleanups.push(added)
    assert.equal(refreshes, 1, "Adding a location immediately requests a new snapshot")
  } finally {
    for (const cleanup of cleanups) await cleanup()
    if (bus === undefined) delete process.env.DBUS_SESSION_BUS_ADDRESS
    else process.env.DBUS_SESSION_BUS_ADDRESS = bus
    if (runtime === undefined) delete process.env.XDG_RUNTIME_DIR
    else process.env.XDG_RUNTIME_DIR = runtime
    await rm(directory, { recursive: true })
  }
  assert.equal(host.__confOpenCodeWaiting, undefined)
})
