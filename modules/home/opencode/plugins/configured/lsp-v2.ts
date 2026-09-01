import { spawn } from "node:child_process"
import type { ChildProcessWithoutNullStreams } from "node:child_process"
import { readFile, readdir } from "node:fs/promises"
import path from "node:path"
import { pathToFileURL } from "node:url"

import { Plugin } from "@opencode-ai/plugin"

interface ServerConfig {
  command: readonly [string, ...string[]]
  disabled?: boolean
  env?: NodeJS.ProcessEnv
  extensions: string[]
  initialization?: unknown
}

interface Server extends ServerConfig {
  id: string
  roots: string[]
}

interface Diagnostic {
  message?: unknown
  range?: { start?: { character?: number; line?: number } }
  severity?: number
}

interface RpcMessage {
  error?: { message?: string }
  id?: number
  jsonrpc?: "2.0"
  method?: string
  params?: unknown
  result?: unknown
}

type DiagnosticWaiter = (items: Diagnostic[]) => void

interface Client {
  diagnosticVersions: Map<string, number>
  diagnosticWaiters: Map<string, DiagnosticWaiter[]>
  diagnostics: Map<string, Diagnostic[]>
  documents?: Map<string, { text: string; version: number }>
  notify(method: string, params?: unknown): void
  process: ChildProcessWithoutNullStreams
  request<Result = unknown>(method: string, params?: unknown, timeout?: number): Promise<Result>
  server?: Server
}

interface ClientEntry {
  idleTimer?: NodeJS.Timeout
  promise: Promise<Client>
}

interface LspInput {
  character?: number
  file: string
  line?: number
  operation: "definition" | "diagnostics" | "document_symbols" | "hover" | "workspace_symbols"
  query?: string
}

const clients = new Map<string, ClientEntry>()
const defaultIdleTimeoutMs = 30 * 60 * 1000

const languageIDs: Record<string, string> = {
  ".bash": "shellscript",
  ".hs": "haskell",
  ".ksh": "shellscript",
  ".lhs": "haskell",
  ".lua": "lua",
  ".nix": "nix",
  ".rs": "rust",
  ".sh": "shellscript",
  ".ts": "typescript",
  ".tsx": "typescriptreact",
  ".yaml": "yaml",
  ".yml": "yaml",
  ".zsh": "shellscript",
}

function rootsFor(extensions: string[]): string[] {
  if (extensions.some((extension) => extension === ".hs" || extension === ".lhs")) {
    return ["hie.yaml", "cabal.project", "stack.yaml", "*.cabal"]
  }
  if (extensions.includes(".rs")) return ["Cargo.toml", ".git"]
  if (extensions.includes(".nix")) return ["flake.nix", "default.nix", ".git"]
  if (extensions.includes(".lua")) return [".luarc.json", ".luarc.jsonc", ".git"]
  return [".git"]
}

function direnvChanges(
  cwd: string,
  env: NodeJS.ProcessEnv,
): Promise<{ changes: Record<string, unknown>; error?: string }> {
  return new Promise((resolve) => {
    const child = spawn("direnv", ["export", "json"], {
      cwd,
      env: { ...env, DIRENV_NO_TMUX_RENAME: "1" },
      stdio: ["ignore", "pipe", "pipe"],
    })
    const chunks: Buffer[] = []
    const errors: Buffer[] = []
    child.stdout.on("data", (chunk) => chunks.push(chunk))
    child.stderr.on("data", (chunk) => errors.push(chunk))
    child.on("error", (error) => resolve({ changes: {}, error: error.message }))
    child.on("exit", (code) => {
      if (code !== 0) {
        return resolve({ changes: {}, error: Buffer.concat(errors).toString().trim() || `direnv exited with ${code}` })
      }
      try {
        const output = Buffer.concat(chunks).toString().trim()
        resolve({ changes: output ? (JSON.parse(output) as Record<string, unknown>) : {} })
      } catch {
        resolve({ changes: {}, error: "direnv returned invalid JSON" })
      }
    })
  })
}

function applyEnvironment(env: NodeJS.ProcessEnv, changes: Record<string, unknown>): NodeJS.ProcessEnv {
  const result = { ...env }
  for (const [key, value] of Object.entries(changes)) {
    if (value === null) delete result[key]
    else result[key] = String(value)
  }
  return result
}

function rpc(server: Server, root: string, env: NodeJS.ProcessEnv, onStop: () => void): Client {
  const process = spawn(server.command[0], server.command.slice(1), {
    cwd: root,
    env,
    stdio: ["pipe", "pipe", "pipe"],
  })
  let buffer = Buffer.alloc(0)
  let nextID = 1
  let stopped = false
  const pending = new Map<number, { reject: (error: Error) => void; resolve: (value: unknown) => void }>()
  const diagnostics = new Map<string, Diagnostic[]>()
  const diagnosticVersions = new Map<string, number>()
  const diagnosticWaiters = new Map<string, DiagnosticWaiter[]>()
  process.stderr.resume()

  const send = (message: RpcMessage): void => {
    const body = JSON.stringify(message)
    process.stdin.write(`Content-Length: ${Buffer.byteLength(body)}\r\n\r\n${body}`)
  }

  const notify = (method: string, params?: unknown): void =>
    send(params === undefined ? { jsonrpc: "2.0", method } : { jsonrpc: "2.0", method, params })

  const request = <Result = unknown>(method: string, params?: unknown, timeout = 30_000): Promise<Result> =>
    new Promise<Result>((resolve, reject) => {
      const id = nextID++
      const timer = setTimeout(() => {
        pending.delete(id)
        reject(new Error(`${method} timed out`))
      }, timeout)
      pending.set(id, {
        resolve: (value: unknown) => {
          clearTimeout(timer)
          resolve(value as Result)
        },
        reject: (error) => {
          clearTimeout(timer)
          reject(error)
        },
      })
      send(params === undefined ? { jsonrpc: "2.0", id, method } : { jsonrpc: "2.0", id, method, params })
    })

  const publishDiagnostics = (params: { diagnostics?: Diagnostic[]; uri?: string }): void => {
    if (!params.uri) return
    diagnostics.set(params.uri, params.diagnostics ?? [])
    diagnosticVersions.set(params.uri, (diagnosticVersions.get(params.uri) ?? 0) + 1)
    const waiters = diagnosticWaiters.get(params.uri)
    if (!waiters) return
    diagnosticWaiters.delete(params.uri)
    for (const resolve of waiters) resolve(params.diagnostics ?? [])
  }

  const handle = (message: RpcMessage): void => {
    if (message.id !== undefined && (message.result !== undefined || message.error !== undefined)) {
      const waiter = pending.get(message.id)
      if (!waiter) return
      pending.delete(message.id)
      if (message.error) waiter.reject(new Error(message.error.message ?? JSON.stringify(message.error)))
      else waiter.resolve(message.result)
      return
    }

    if (message.method === "textDocument/publishDiagnostics") {
      publishDiagnostics((message.params ?? {}) as { diagnostics?: Diagnostic[]; uri?: string })
      return
    }

    if (message.id === undefined) return
    let result = null
    if (message.method === "workspace/configuration") {
      const params = (message.params ?? {}) as { items?: unknown[] }
      result = (params.items ?? []).map(() => server.initialization ?? null)
    }
    if (message.method === "workspace/workspaceFolders") {
      result = [{ name: path.basename(root), uri: pathToFileURL(root).href }]
    }
    send({ jsonrpc: "2.0", id: message.id, result })
  }

  process.stdout.on("data", (chunk) => {
    buffer = Buffer.concat([buffer, chunk])
    while (true) {
      const headerEnd = buffer.indexOf("\r\n\r\n")
      if (headerEnd < 0) return
      const header = buffer.subarray(0, headerEnd).toString()
      const length = Number(/content-length:\s*(\d+)/i.exec(header)?.[1])
      if (!Number.isFinite(length)) {
        buffer = buffer.subarray(headerEnd + 4)
        continue
      }
      const bodyStart = headerEnd + 4
      if (buffer.length < bodyStart + length) return
      const body = buffer.subarray(bodyStart, bodyStart + length).toString()
      buffer = buffer.subarray(bodyStart + length)
      try {
        handle(JSON.parse(body) as RpcMessage)
      } catch {
        // Ignore malformed server output and continue processing later messages.
      }
    }
  })

  const fail = (error: Error): void => {
    if (stopped) return
    stopped = true
    for (const waiter of pending.values()) waiter.reject(error)
    pending.clear()
    onStop()
  }
  process.on("error", fail)
  process.on("exit", (code) => fail(new Error(`${server.command[0]} exited with status ${code}`)))

  return {
    request,
    notify,
    diagnostics,
    diagnosticVersions,
    diagnosticWaiters,
    process,
  }
}

async function start(server: Server, root: string, onStop: () => void): Promise<Client> {
  const loaded = await direnvChanges(root, globalThis.process.env)
  if (loaded.error) throw new Error(`Failed to load the project direnv environment: ${loaded.error}`)
  const changes = loaded.changes
  const env = { ...applyEnvironment(globalThis.process.env, changes), ...(server.env ?? {}) }
  const client = rpc(server, root, env, onStop)
  await client.request(
    "initialize",
    {
      processId: globalThis.process.pid,
      rootUri: pathToFileURL(root).href,
      workspaceFolders: [{ name: path.basename(root), uri: pathToFileURL(root).href }],
      capabilities: {
        window: { workDoneProgress: true },
        workspace: { configuration: true, workspaceFolders: true },
        textDocument: {
          synchronization: { didOpen: true, didChange: true },
          publishDiagnostics: { relatedInformation: true },
        },
      },
      initializationOptions: server.initialization ?? {},
    },
    120_000,
  )
  client.notify("initialized", {})
  return { ...client, server }
}

function waitForExit(process: ChildProcessWithoutNullStreams, timeout: number): Promise<boolean> {
  if (process.exitCode !== null) return Promise.resolve(true)
  return new Promise((resolve) => {
    const timer = setTimeout(() => {
      process.off("exit", exited)
      resolve(false)
    }, timeout)
    const exited = () => {
      clearTimeout(timer)
      resolve(true)
    }
    process.once("exit", exited)
  })
}

async function stop(client: Client): Promise<void> {
  if (client.process.exitCode !== null) return
  await client.request("shutdown", null, 5_000).catch(() => undefined)
  if (client.process.exitCode !== null) return
  try {
    client.notify("exit")
  } catch {
    // Continue to signals if the server closed its input without exiting.
  }
  if (await waitForExit(client.process, 2_000)) return
  client.process.kill("SIGTERM")
  if (await waitForExit(client.process, 2_000)) return
  client.process.kill("SIGKILL")
}

async function findRoot(server: Server, file: string, boundary: string): Promise<string> {
  let directory = path.dirname(file)
  while (true) {
    const entries: string[] = await readdir(directory).catch(() => [])
    if (
      server.roots.some((marker) =>
        marker.startsWith("*.") ? entries.some((entry) => entry.endsWith(marker.slice(1))) : entries.includes(marker),
      )
    ) {
      return directory
    }
    if (directory === boundary || directory === path.dirname(directory)) return boundary
    directory = path.dirname(directory)
  }
}

function waitForDiagnostics(client: Client, uri: string, since: number, timeout = 30_000): Promise<Diagnostic[]> {
  return new Promise<Diagnostic[]>((resolve) => {
    if ((client.diagnosticVersions.get(uri) ?? 0) > since) {
      return setTimeout(() => resolve(client.diagnostics.get(uri) ?? []), 300)
    }
    const timer = setTimeout(() => {
      const waiters = client.diagnosticWaiters.get(uri) ?? []
      client.diagnosticWaiters.set(
        uri,
        waiters.filter((waiter) => waiter !== done),
      )
      resolve(client.diagnostics.get(uri) ?? [])
    }, timeout)
    const done = (items: Diagnostic[]): void => {
      clearTimeout(timer)
      setTimeout(() => resolve(client.diagnostics.get(uri) ?? items), 300)
    }
    client.diagnosticWaiters.set(uri, [...(client.diagnosticWaiters.get(uri) ?? []), done])
  })
}

async function open(
  client: Client,
  file: string,
): Promise<{ changed: boolean; diagnosticVersion: number; uri: string }> {
  const text = await readFile(file, "utf8")
  const uri = pathToFileURL(file).href
  const diagnosticVersion = client.diagnosticVersions.get(uri) ?? 0
  const previous = client.documents?.get(uri)
  if (!client.documents) client.documents = new Map()
  if (previous === undefined) {
    client.documents.set(uri, { version: 0, text })
    client.notify("textDocument/didOpen", {
      textDocument: { uri, languageId: languageIDs[path.extname(file)] ?? "plaintext", version: 0, text },
    })
    return { uri, changed: true, diagnosticVersion }
  } else if (previous.text !== text) {
    const version = previous.version + 1
    client.documents.set(uri, { version, text })
    client.notify("textDocument/didChange", {
      textDocument: { uri, version },
      contentChanges: [{ text }],
    })
    return { uri, changed: true, diagnosticVersion }
  }
  return { uri, changed: false, diagnosticVersion }
}

function formatDiagnostics(file: string, diagnostics: Diagnostic[]): string {
  const labels = ["", "error", "warning", "information", "hint"]
  return diagnostics
    .map((diagnostic) => {
      const start = diagnostic.range?.start ?? {}
      const location = `${(start.line ?? 0) + 1}:${(start.character ?? 0) + 1}`
      const severity = labels[diagnostic.severity ?? 0] ?? "diagnostic"
      const message = String(diagnostic.message ?? "")
        .replace(/\s+/g, " ")
        .trim()
      return `${file}:${location}: ${severity}: ${message}`
    })
    .join("\n")
}

function position(input: Pick<LspInput, "character" | "line">): { character: number; line: number } {
  return {
    line: Math.max(0, (input.line ?? 1) - 1),
    character: Math.max(0, (input.character ?? 1) - 1),
  }
}

export default Plugin.define({
  id: "bbrian.lsp",
  setup: async (ctx) => {
    const options = ctx.options as { idleTimeoutMs?: unknown; servers?: Record<string, unknown> }
    const idleTimeoutMs =
      typeof options.idleTimeoutMs === "number" && Number.isFinite(options.idleTimeoutMs) && options.idleTimeoutMs > 0
        ? options.idleTimeoutMs
        : defaultIdleTimeoutMs
    const servers = Object.entries(options.servers ?? {}).flatMap(([id, value]): Server[] => {
      if (!value || typeof value !== "object") return []
      const configured = value as Partial<ServerConfig>
      const command = Array.isArray(configured.command)
        ? configured.command.filter((item): item is string => typeof item === "string")
        : []
      if (configured.disabled || command.length === 0) return []
      const extensions = Array.isArray(configured.extensions)
        ? configured.extensions.filter((item): item is string => typeof item === "string")
        : []
      return [{ ...configured, command: command as [string, ...string[]], id, extensions, roots: rootsFor(extensions) }]
    })

    const clientFor = async (server: Server, root: string): Promise<Client> => {
      const key = `${server.id}\0${root}`
      let entry = clients.get(key)
      if (!entry) {
        const created = {} as ClientEntry
        entry = created
        const remove = () => {
          if (clients.get(key) !== created) return
          clearTimeout(created.idleTimer)
          clients.delete(key)
        }
        created.promise = start(server, root, remove).catch((error: unknown) => {
          remove()
          throw error
        })
        clients.set(key, created)
      }
      clearTimeout(entry.idleTimer)
      entry.idleTimer = setTimeout(() => {
        if (clients.get(key) !== entry) return
        clients.delete(key)
        void entry.promise.then(stop).catch(() => undefined)
      }, idleTimeoutMs)
      entry.idleTimer.unref()
      return entry.promise
    }

    const diagnosticsFor = async (directory: string, value: string, timeout = 30_000): Promise<string> => {
      const file = path.resolve(directory, value)
      const server = servers.find((candidate) => candidate.extensions.includes(path.extname(file)))
      if (!server) return ""
      const root = await findRoot(server, file, directory)
      const client = await clientFor(server, root)
      const { uri, changed, diagnosticVersion } = await open(client, file)
      const diagnostics =
        changed || !client.diagnostics.has(uri)
          ? await waitForDiagnostics(client, uri, diagnosticVersion, timeout)
          : (client.diagnostics.get(uri) ?? [])
      return diagnostics.length > 0 ? formatDiagnostics(value, diagnostics) : ""
    }

    await ctx.tool.hook("execute.before", async (invocation) => {
      if (invocation.tool !== "shell" || !invocation.input || typeof invocation.input !== "object") return
      const input = invocation.input as { workdir?: unknown }
      const session = await ctx.session.get({ sessionID: invocation.sessionID })
      input.workdir = path.resolve(
        session.location.directory,
        typeof input.workdir === "string" ? input.workdir : session.location.directory,
      )
    })

    await ctx.shell.hook("create.before", async (invocation) => {
      const loaded = await direnvChanges(invocation.cwd, invocation.env)
      if (loaded.error) throw new Error(`Failed to load the shell direnv environment: ${loaded.error}`)
      for (const [key, value] of Object.entries(loaded.changes)) {
        if (value === null) delete invocation.env[key]
        else invocation.env[key] = String(value)
      }
    })

    await ctx.tool.transform((tools) => {
      tools.add({
        name: "lsp",
        description:
          "Query the configured Bash, Haskell, Lua, Nix, Rust, or YAML language server. Diagnostics are added automatically to supported file reads and changes; use diagnostics only for an explicit recheck.",
        input: {
          type: "object",
          properties: {
            operation: {
              type: "string",
              enum: ["diagnostics", "hover", "definition", "document_symbols", "workspace_symbols"],
            },
            file: {
              type: "string",
              description: "Supported source file, absolute or relative to the session directory",
            },
            line: { type: "integer", minimum: 1, description: "1-based line for hover or definition" },
            character: { type: "integer", minimum: 1, description: "1-based character for hover or definition" },
            query: { type: "string", description: "Query for workspace_symbols" },
          },
          required: ["operation", "file"],
          additionalProperties: false,
        },
        options: { codemode: false, permission: "lsp" },
        execute: async (rawInput, toolContext) => {
          const input = rawInput as LspInput
          const session = await ctx.session.get({ sessionID: toolContext.sessionID })
          const directory = session.location.directory
          if (input.operation === "diagnostics") {
            return { content: await diagnosticsFor(directory, input.file) }
          }
          const file = path.resolve(directory, input.file)
          const server = servers.find((candidate) => candidate.extensions.includes(path.extname(file)))
          if (!server) throw new Error(`No configured language server for: ${file}`)
          const root = await findRoot(server, file, directory)
          const client = await clientFor(server, root)
          const { uri, changed, diagnosticVersion } = await open(client, file)
          let result

          if (input.operation === "hover") {
            result = await client.request("textDocument/hover", {
              textDocument: { uri },
              position: position(input),
            })
          } else if (input.operation === "definition") {
            result = await client.request("textDocument/definition", {
              textDocument: { uri },
              position: position(input),
            })
          } else if (input.operation === "document_symbols") {
            result = await client.request("textDocument/documentSymbol", { textDocument: { uri } })
          } else {
            result = await client.request("workspace/symbol", { query: input.query ?? "" })
          }

          return { content: JSON.stringify(result ?? null, null, 2) }
        },
      })
    })

    await ctx.tool.hook("execute.after", async (event) => {
      if (event.status !== "completed" || !["edit", "patch", "read", "write"].includes(event.tool)) return

      const output = event.result.output as
        | { applied?: Array<{ target?: unknown; type?: unknown }>; target?: unknown }
        | undefined
      const input = event.input as { path?: unknown } | undefined
      const paths: unknown[] =
        event.tool === "patch"
          ? (output?.applied ?? []).filter((item) => item.type !== "delete").map((item) => item.target)
          : event.tool === "write"
            ? [output?.target]
            : [input?.path]
      const session = await ctx.session.get({ sessionID: event.sessionID })
      const messages: string[] = []

      for (const value of new Set(paths.filter((item): item is string => typeof item === "string"))) {
        try {
          const message = await diagnosticsFor(session.location.directory, value, 10_000)
          if (message) messages.push(message)
        } catch (error: unknown) {
          messages.push(
            `LSP diagnostics unavailable for ${value}: ${error instanceof Error ? error.message : String(error)}`,
          )
        }
      }

      if (messages.length > 0) {
        const text = messages.join("\n\n")
        const result = event.result as { content: unknown }
        result.content = Array.isArray(result.content)
          ? [...result.content, { type: "text", text }]
          : `${result.content ?? ""}${result.content ? "\n\n" : ""}${text}`
      }
    })

    return async () => {
      const running = [...clients.values()]
      clients.clear()
      await Promise.all(
        running.map(async (entry) => {
          clearTimeout(entry.idleTimer)
          const client = await entry.promise.catch(() => undefined)
          if (!client) return
          await stop(client)
        }),
      )
    }
  },
})
