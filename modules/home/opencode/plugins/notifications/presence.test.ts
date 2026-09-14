import assert from "node:assert/strict"
import { once } from "node:events"
import { mkdtemp, rm } from "node:fs/promises"
import { createConnection } from "node:net"
import { tmpdir } from "node:os"
import { join } from "node:path"
import { spawn } from "node:child_process"
import { setTimeout as sleep } from "node:timers/promises"
import test from "node:test"

import { presenceClient, presenceServer } from "./presence.ts"

async function until(predicate: () => boolean) {
  for (let i = 0; i < 200; i++) {
    if (predicate()) return
    await sleep(10)
  }
  assert.fail("Presence did not converge")
}

test("full tab snapshots merge across clients; closing the last owner removes attachment", async () => {
  const directory = await mkdtemp(join(tmpdir(), "oc-presence-"))
  const path = join(directory, "server.sock")
  const server = await presenceServer(path, () => undefined)
  const first = presenceClient(async () => path)
  const second = presenceClient(async () => path)
  try {
    first.update(["ses_a", "ses_background"])
    second.update(["ses_a"])
    await until(() => server.sessions().size === 2)
    first.update(["ses_background"])
    await until(() => server.sessions().has("ses_a"))
    await second.close()
    await until(() => !server.sessions().has("ses_a"))
    assert.deepEqual([...server.sessions()], ["ses_background"])
    first.update([])
    await until(() => server.sessions().size === 0)
  } finally {
    await first.close()
    await second.close()
    await server.close()
    await rm(directory, { recursive: true })
  }
})

test("a killed client leaves no stale attached session", async () => {
  const directory = await mkdtemp(join(tmpdir(), "oc-presence-"))
  const path = join(directory, "server.sock")
  const server = await presenceServer(path, () => undefined)
  const child = spawn(process.execPath, ["--input-type=module", "-e", `
    import {createConnection} from 'node:net'
    const socket = createConnection(${JSON.stringify(path)})
    socket.on('connect', () => socket.write('["ses_crash"]\\n'))
  `], { stdio: "ignore" })
  try {
    await until(() => server.sessions().has("ses_crash"))
    const exited = once(child, "exit")
    child.kill("SIGKILL")
    await exited
    await until(() => server.sessions().size === 0)
  } finally {
    child.kill()
    await server.close()
    await rm(directory, { recursive: true })
  }
})

test("reconnecting after a server restart reports the complete current tab list", async () => {
  const directory = await mkdtemp(join(tmpdir(), "oc-presence-"))
  const path = join(directory, "server.sock")
  let server = await presenceServer(path, () => undefined)
  const client = presenceClient(async () => path)
  try {
    client.update(["ses_before"])
    await until(() => server.sessions().has("ses_before"))
    await server.close()
    client.update(["ses_after"])
    server = await presenceServer(path, () => undefined)
    await until(() => server.sessions().has("ses_after"))
    assert.deepEqual([...server.sessions()], ["ses_after"])
    const invalid = createConnection(path)
    await once(invalid, "connect")
    const closed = once(invalid, "close")
    invalid.write('{"invalid":"inventory"}\n')
    await closed
    assert.deepEqual([...server.sessions()], ["ses_after"])
  } finally {
    await client.close()
    await server.close()
    await rm(directory, { recursive: true })
  }
})
