import assert from "node:assert/strict"
import { chmod, mkdir, mkdtemp, readFile, rm, writeFile } from "node:fs/promises"
import { tmpdir } from "node:os"
import path from "node:path"
import test from "node:test"

import { Plugin } from "@opencode/plugin"

import lspPlugin from "./index.ts"

interface LspTool {
  execute(input: { file: string; operation: string }, context: { sessionID: string }): Promise<unknown>
}

interface ShellInvocation {
  cwd: string
  env: NodeJS.ProcessEnv
}

interface ToolInvocation {
  input: unknown
  sessionID: string
  tool: string
}

// A temporary directory whose bin/ comes first on PATH, with a direnv that changes nothing.
async function sandbox(t: test.TestContext): Promise<{ bin: string; directory: string }> {
  const directory = await mkdtemp(path.join(tmpdir(), "opencode-lsp-test-"))
  const bin = path.join(directory, "bin")
  const originalPath = process.env.PATH
  t.after(async () => {
    process.env.PATH = originalPath
    await rm(directory, { recursive: true, force: true })
  })
  await mkdir(bin)
  await writeFile(path.join(bin, "direnv"), "#!/bin/sh\nprintf '{}\\n'\n")
  await chmod(path.join(bin, "direnv"), 0o755)
  process.env.PATH = `${bin}:${originalPath}`
  return { bin, directory }
}

async function setupTool(t: test.TestContext, directory: string, options: Record<string, unknown>): Promise<LspTool> {
  let lspTool: LspTool | undefined
  const ctx = {
    options,
    session: { get: async () => ({ location: { directory } }) },
    shell: { hook: async () => {} },
    tool: {
      hook: async () => {},
      transform: async (transform: (tools: { add(tool: LspTool): void }) => void) =>
        transform({
          add: (tool) => {
            lspTool = tool
          },
        }),
    },
  }
  const cleanup = await lspPlugin.setup(ctx as unknown as Plugin.Context)
  t.after(async () => {
    if (cleanup) await cleanup()
  })
  assert.ok(lspTool)
  return lspTool
}

const serverPrelude = String.raw`let buffer = Buffer.alloc(0)

function send(message) {
  const body = JSON.stringify(message)
  process.stdout.write("Content-Length: " + Buffer.byteLength(body) + "\r\n\r\n" + body)
}

function listen(handle) {
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
      if (message.method === "shutdown") send({ jsonrpc: "2.0", id: message.id, result: null })
      else if (message.method === "exit") process.exit(0)
      else handle(message)
    }
  })
}
`

async function eventually(check: () => boolean | Promise<boolean>, timeout = 3_000): Promise<void> {
  const deadline = Date.now() + timeout
  while (Date.now() < deadline) {
    if (await check()) return
    await new Promise((resolve) => setTimeout(resolve, 20))
  }
  assert.fail("condition was not met before timeout")
}

test("shell environments retain the tmux guard after direnv rolls it back", async (t) => {
  const directory = await mkdtemp(path.join(tmpdir(), "opencode-direnv-test-"))
  t.after(() => rm(directory, { recursive: true, force: true }))
  await writeFile(
    path.join(directory, "direnv"),
    '#!/bin/sh\nprintf \'{"DIRENV_NO_TMUX_RENAME":null,"PROJECT_ENV":"loaded","REMOVED":null}\\n\'\n',
  )
  await chmod(path.join(directory, "direnv"), 0o755)

  let shellHook: ((invocation: ShellInvocation) => Promise<void> | void) | undefined
  const cleanup = await lspPlugin.setup({
    options: {},
    shell: {
      hook: async (_name: string, hook: typeof shellHook) => {
        shellHook = hook
      },
    },
    tool: { hook: async () => {}, transform: async () => {} },
  } as unknown as Plugin.Context)
  t.after(async () => {
    if (cleanup) await cleanup()
  })

  assert.ok(shellHook)
  const invocation: ShellInvocation = {
    cwd: directory,
    env: { PATH: directory, DIRENV_NO_TMUX_RENAME: "true", REMOVED: "old" },
  }
  await shellHook(invocation)
  assert.equal(invocation.env.PROJECT_ENV, "loaded")
  assert.equal(invocation.env.REMOVED, undefined)
  assert.equal(invocation.env.DIRENV_NO_TMUX_RENAME, "1")
})

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
  await writeFile(
    path.join(bin, "direnv"),
    "#!/bin/sh\nprintf '{\"DIRENV_TEST_CWD\":\"%s\",\"DIRENV_NO_TMUX_RENAME\":null}\\n' \"$PWD\"\n",
  )
  await chmod(path.join(bin, "direnv"), 0o755)
  await writeFile(source, "test\n")
  await writeFile(
    server,
    String.raw`import { appendFileSync, writeFileSync } from "node:fs"

const log = process.argv[2]
const pidFile = process.argv[3]
let buffer = Buffer.alloc(0)
writeFileSync(pidFile, String(process.pid))
writeFileSync(pidFile + ".tmux-guard", process.env.DIRENV_NO_TMUX_RENAME ?? "<unset>")

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
  let shellHook: ((invocation: ShellInvocation) => Promise<void> | void) | undefined
  let toolHook: ((invocation: ToolInvocation) => Promise<void> | void) | undefined
  const ctx = {
    options: {
      idleTimeoutMs: 100,
      servers: { fake: { command: [process.execPath, server, log, pidFile], extensions: [".fake"] } },
    },
    session: { get: async () => ({ location: { directory } }) },
    shell: {
      hook: async (_name: string, hook: (invocation: ShellInvocation) => Promise<void> | void) => {
        shellHook = hook
      },
    },
    tool: {
      hook: async (name: string, hook: (invocation: ToolInvocation) => Promise<void> | void) => {
        if (name === "execute.before") toolHook = hook
      },
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
  assert.ok(shellHook)
  assert.ok(toolHook)
  const toolInvocation: ToolInvocation = { tool: "shell", sessionID: "test", input: { workdir: "." } }
  await toolHook(toolInvocation)
  assert.deepEqual(toolInvocation.input, { workdir: directory })
  const shellInvocation: ShellInvocation = { cwd: directory, env: { PATH: process.env.PATH } }
  await shellHook(shellInvocation)
  assert.equal(shellInvocation.env.DIRENV_TEST_CWD, directory)
  await lspTool.execute({ operation: "diagnostics", file: source }, { sessionID: "test" })
  const pid = Number(await readFile(pidFile, "utf8"))
  assert.equal(await readFile(pidFile + ".tmux-guard", "utf8"), "1")

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

for (const mode of ["push", "pull"]) {
  test(`${mode} diagnostics clear once a broken file is fixed`, async (t) => {
    const directory = await mkdtemp(path.join(tmpdir(), "opencode-lsp-test-"))
    const source = path.join(directory, "example.fake")
    const server = path.join(directory, "server.mjs")
    const originalPath = process.env.PATH
    let cleanup: (() => Promise<void> | void) | undefined

    t.after(async () => {
      if (cleanup) await cleanup()
      process.env.PATH = originalPath
      await rm(directory, { recursive: true, force: true })
    })

    await writeFile(path.join(directory, "direnv"), "#!/bin/sh\nprintf '{}\\n'\n")
    await chmod(path.join(directory, "direnv"), 0o755)
    await writeFile(
      server,
      String.raw`const mode = process.argv[2]
const texts = new Map()
let buffer = Buffer.alloc(0)
let cancelled = false

function send(message) {
  const body = JSON.stringify(message)
  process.stdout.write("Content-Length: " + Buffer.byteLength(body) + "\r\n\r\n" + body)
}

function diagnostic(message) {
  return { message, severity: 1, range: { start: { line: 0, character: 0 }, end: { line: 0, character: 1 } } }
}

function current(uri) {
  return texts.get(uri).includes("broken") ? [diagnostic("broken")] : []
}

process.stdin.on("data", (chunk) => {
  buffer = Buffer.concat([buffer, chunk])
  while (true) {
    const headerEnd = buffer.indexOf("\r\n\r\n")
    if (headerEnd < 0) return
    const length = Number(/content-length:\s*(\d+)/i.exec(buffer.subarray(0, headerEnd).toString())?.[1])
    const bodyStart = headerEnd + 4
    if (buffer.length < bodyStart + length) return
    const { id, method, params } = JSON.parse(buffer.subarray(bodyStart, bodyStart + length).toString())
    buffer = buffer.subarray(bodyStart + length)
    if (method === "initialize") {
      const capabilities =
        mode === "pull" ? { diagnosticProvider: { interFileDependencies: false, workspaceDiagnostics: false } } : {}
      send({ jsonrpc: "2.0", id, result: { capabilities } })
    }
    if (method === "textDocument/didOpen" || method === "textDocument/didChange") {
      const uri = params.textDocument.uri
      texts.set(uri, params.textDocument.text ?? params.contentChanges[0].text)
      // Like rust-analyzer's cargo check, pushes from a pull server can describe older text.
      const diagnostics = mode === "pull" ? [diagnostic("stale")] : current(uri)
      send({ jsonrpc: "2.0", method: "textDocument/publishDiagnostics", params: { uri, diagnostics } })
    }
    if (method === "textDocument/diagnostic") {
      if (cancelled) send({ jsonrpc: "2.0", id, result: { kind: "full", items: current(params.textDocument.uri) } })
      else send({ jsonrpc: "2.0", id, error: { code: -32802, message: "server cancelled the request" } })
      cancelled = true
    }
    if (method === "shutdown") send({ jsonrpc: "2.0", id, result: null })
    if (method === "exit") process.exit(0)
  }
})
`,
    )
    process.env.PATH = `${directory}:${originalPath}`

    let lspTool: LspTool | undefined
    const ctx = {
      options: { servers: { fake: { command: [process.execPath, server, mode], extensions: [".fake"] } } },
      session: { get: async () => ({ location: { directory } }) },
      shell: { hook: async () => {} },
      tool: {
        hook: async () => {},
        transform: async (transform: (tools: { add(tool: LspTool): void }) => void) =>
          transform({
            add: (tool) => {
              lspTool = tool
            },
          }),
      },
    }
    cleanup = (await lspPlugin.setup(ctx as unknown as Plugin.Context)) ?? undefined
    const tool = lspTool
    assert.ok(tool)

    const diagnostics = async (text: string): Promise<unknown> => {
      await writeFile(source, text)
      return tool.execute({ operation: "diagnostics", file: source }, { sessionID: "test" })
    }
    assert.deepEqual(await diagnostics("broken\n"), { content: `${source}:1:1: error: broken` })
    assert.deepEqual(await diagnostics("fixed\n"), { content: "" })
  })
}

test("rust crates in one cargo workspace share a server", async (t) => {
  const { bin, directory } = await sandbox(t)
  const log = path.join(directory, "roots.log")
  const server = path.join(directory, "server.mjs")
  // Like `cargo locate-project --workspace`, which refuses a crate that isn't a member.
  await writeFile(
    path.join(bin, "cargo"),
    `#!/bin/sh
case "$PWD" in
  "${directory}"/crates/*) printf '%s\\n' '${directory}/Cargo.toml' ;;
  *) echo "error: current package believes it's in a workspace when it's not" >&2; exit 101 ;;
esac
`,
  )
  await chmod(path.join(bin, "cargo"), 0o755)
  await writeFile(
    server,
    `${serverPrelude}
import { appendFileSync } from "node:fs"
appendFileSync(process.argv[2], process.cwd() + "\\n")
listen(({ id, method, params }) => {
  if (method === "initialize") send({ jsonrpc: "2.0", id, result: { capabilities: {} } })
  if (method === "textDocument/didOpen") {
    send({ jsonrpc: "2.0", method: "textDocument/publishDiagnostics", params: { uri: params.textDocument.uri, diagnostics: [] } })
  }
})
`,
  )
  await writeFile(path.join(directory, "Cargo.toml"), "[workspace]\n")
  const files = ["crates/a", "crates/b", "other"].map((crate) => path.join(directory, crate, "src/lib.rs"))
  for (const file of files) {
    await mkdir(path.dirname(file), { recursive: true })
    await writeFile(path.join(path.dirname(file), "../Cargo.toml"), "[package]\n")
    await writeFile(file, "\n")
  }

  const tool = await setupTool(t, directory, {
    servers: { rust: { command: [process.execPath, server, log], extensions: [".rs"] } },
  })
  for (const file of files) await tool.execute({ operation: "diagnostics", file }, { sessionID: "test" })

  const roots = (await readFile(log, "utf8")).trim().split("\n")
  assert.deepEqual(roots.sort(), [directory, path.join(directory, "other")])
})

test("typescript files get a server per package", async (t) => {
  const { directory } = await sandbox(t)
  const log = path.join(directory, "roots.log")
  const server = path.join(directory, "server.mjs")
  await writeFile(
    server,
    `${serverPrelude}
import { appendFileSync } from "node:fs"
appendFileSync(process.argv[2], process.cwd() + "\\n")
listen(({ id, method, params }) => {
  if (method === "initialize") send({ jsonrpc: "2.0", id, result: { capabilities: {} } })
  if (method === "textDocument/didOpen") {
    send({ jsonrpc: "2.0", method: "textDocument/publishDiagnostics", params: { uri: params.textDocument.uri, diagnostics: [] } })
  }
})
`,
  )
  await mkdir(path.join(directory, ".git"))
  await writeFile(path.join(directory, "package.json"), "{}\n")
  for (const name of ["a", "b"]) {
    await mkdir(path.join(directory, "packages", name, "src"), { recursive: true })
    await writeFile(path.join(directory, "packages", name, "package.json"), "{}\n")
  }
  const files = ["packages/a/src/index.ts", "packages/a/src/view.tsx", "packages/b/src/index.ts", "scripts/x.ts"].map(
    (file) => path.join(directory, file),
  )
  for (const file of files) {
    await mkdir(path.dirname(file), { recursive: true })
    await writeFile(file, "\n")
  }

  const tool = await setupTool(t, directory, {
    servers: { typescript: { command: [process.execPath, server, log], extensions: [".ts", ".tsx"] } },
  })
  for (const file of files) await tool.execute({ operation: "diagnostics", file }, { sessionID: "test" })

  const roots = (await readFile(log, "utf8")).trim().split("\n")
  assert.deepEqual(roots.sort(), [directory, path.join(directory, "packages/a"), path.join(directory, "packages/b")])
})

for (const mode of ["loads", "stuck"]) {
  test(`rust-analyzer pulls wait for a workspace that ${mode === "loads" ? "loads" : "never loads"}`, async (t) => {
    const { directory } = await sandbox(t)
    const source = path.join(directory, "example.fake")
    const server = path.join(directory, "server.mjs")
    await writeFile(source, "broken\n")
    // Like rust-analyzer, it answers with nothing before its workspace loads, and says so only later.
    await writeFile(
      server,
      `${serverPrelude}
let loaded = false
listen(({ id, method }) => {
  if (method === "initialize") {
    const capabilities = { diagnosticProvider: { interFileDependencies: true, workspaceDiagnostics: false } }
    send({ jsonrpc: "2.0", id, result: { capabilities, serverInfo: { name: "rust-analyzer" } } })
  }
  if (method === "initialized" && process.argv[2] === "loads") {
    setTimeout(() => {
      loaded = true
      send({ jsonrpc: "2.0", method: "experimental/serverStatus", params: { health: "ok", quiescent: true } })
    }, 200)
  }
  if (method === "textDocument/diagnostic") {
    const items = loaded
      ? [{ message: "broken", severity: 1, range: { start: { line: 0, character: 0 }, end: { line: 0, character: 1 } } }]
      : []
    send({ jsonrpc: "2.0", id, result: { kind: "full", items } })
  }
})
`,
    )
    const tool = await setupTool(t, directory, {
      diagnosticTimeoutMs: 1_000,
      servers: { fake: { command: [process.execPath, server, mode], extensions: [".fake"] } },
    })
    const diagnostics = tool.execute({ operation: "diagnostics", file: source }, { sessionID: "test" })

    if (mode === "loads") assert.deepEqual(await diagnostics, { content: `${source}:1:1: error: broken` })
    else await assert.rejects(diagnostics, /rust-analyzer was still loading the workspace/)
  })
}
