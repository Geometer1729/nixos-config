import assert from "node:assert/strict"
import { chmod, mkdir, mkdtemp, readFile, rm, writeFile } from "node:fs/promises"
import { tmpdir } from "node:os"
import path from "node:path"
import test from "node:test"

import { Plugin } from "@opencode-ai/plugin"

import lspPlugin from "./lsp-v2.ts"

interface LspTool {
  execute(input: { file: string; operation: string }, context: { sessionID: string }): Promise<unknown>
}

async function eventually(check: () => boolean | Promise<boolean>, timeout = 3_000): Promise<void> {
  const deadline = Date.now() + timeout
  while (Date.now() < deadline) {
    if (await check()) return
    await new Promise((resolve) => setTimeout(resolve, 20))
  }
  assert.fail("condition was not met before timeout")
}

test("idle language servers are shut down and terminated", async (t) => {
  const directory = await mkdtemp(path.join(tmpdir(), "opencode-lsp-test-"))
  const bin = path.join(directory, "bin")
  const source = path.join(directory, "example.fake")
  const log = path.join(directory, "server.log")
  const pidFile = path.join(directory, "server.pid")
  const server = path.join(directory, "server.mjs")
  const originalPath = process.env.PATH
  let cleanup: (() => Promise<void> | void) | undefined

  t.after(async () => {
    if (cleanup) await cleanup()
    process.env.PATH = originalPath
    await rm(directory, { recursive: true, force: true })
  })

  await mkdir(bin)
  await writeFile(path.join(bin, "direnv"), "#!/bin/sh\nprintf '{}\\n'\n")
  await chmod(path.join(bin, "direnv"), 0o755)
  await writeFile(source, "test\n")
  await writeFile(
    server,
    String.raw`import { appendFileSync, writeFileSync } from "node:fs"

const log = process.argv[2]
const pidFile = process.argv[3]
let buffer = Buffer.alloc(0)
writeFileSync(pidFile, String(process.pid))

function send(message) {
  const body = JSON.stringify(message)
  process.stdout.write("Content-Length: " + Buffer.byteLength(body) + "\r\n\r\n" + body)
}

process.stdin.on("data", (chunk) => {
  buffer = Buffer.concat([buffer, chunk])
  while (true) {
    const headerEnd = buffer.indexOf("\r\n\r\n")
    if (headerEnd < 0) return
    const length = Number(/content-length:\s*(\d+)/i.exec(buffer.subarray(0, headerEnd).toString())?.[1])
    const bodyStart = headerEnd + 4
    if (buffer.length < bodyStart + length) return
    const message = JSON.parse(buffer.subarray(bodyStart, bodyStart + length).toString())
    buffer = buffer.subarray(bodyStart + length)
    if (message.method === "initialize") send({ jsonrpc: "2.0", id: message.id, result: { capabilities: {} } })
    if (message.method === "textDocument/didOpen") {
      send({ jsonrpc: "2.0", method: "textDocument/publishDiagnostics", params: { uri: message.params.textDocument.uri, diagnostics: [] } })
    }
    if (message.method === "shutdown") {
      appendFileSync(log, "shutdown\n")
      send({ jsonrpc: "2.0", id: message.id, result: null })
    }
    if (message.method === "exit") {
      appendFileSync(log, "exit\n")
      process.exit(0)
    }
  }
})
`,
  )
  process.env.PATH = `${bin}:${originalPath}`

  let lspTool: LspTool | undefined
  const ctx = {
    options: {
      idleTimeoutMs: 100,
      servers: { fake: { command: [process.execPath, server, log, pidFile], extensions: [".fake"] } },
    },
    session: { get: async () => ({ location: { directory } }) },
    shell: { hook: async () => undefined },
    tool: {
      hook: async () => undefined,
      transform: async (transform: (tools: { add(tool: LspTool): void }) => void) =>
        transform({
          add: (tool) => {
            lspTool = tool
          },
        }),
    },
  }

  cleanup = (await lspPlugin.setup(ctx as unknown as Plugin.Context)) ?? undefined
  assert.ok(lspTool)
  await lspTool.execute({ operation: "diagnostics", file: source }, { sessionID: "test" })
  const pid = Number(await readFile(pidFile, "utf8"))

  await eventually(async () => (await readFile(log, "utf8").catch(() => "")) === "shutdown\nexit\n")
  await eventually(() => {
    try {
      process.kill(pid, 0)
      return false
    } catch (error: unknown) {
      return error instanceof Error && "code" in error && error.code === "ESRCH"
    }
  })
})
