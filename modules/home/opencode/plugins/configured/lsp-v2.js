import { spawn } from "node:child_process"
import { readFile, readdir } from "node:fs/promises"
import path from "node:path"
import { pathToFileURL } from "node:url"

const clients = new Map()

const languageIDs = {
  ".bash": "shellscript",
  ".hs": "haskell",
  ".ksh": "shellscript",
  ".lhs": "haskell",
  ".lua": "lua",
  ".nix": "nix",
  ".rs": "rust",
  ".sh": "shellscript",
  ".yaml": "yaml",
  ".yml": "yaml",
  ".zsh": "shellscript",
}

function rootsFor(extensions) {
  if (extensions.some((extension) => extension === ".hs" || extension === ".lhs")) {
    return ["hie.yaml", "cabal.project", "stack.yaml", "*.cabal"]
  }
  if (extensions.includes(".rs")) return ["Cargo.toml", ".git"]
  if (extensions.includes(".nix")) return ["flake.nix", "default.nix", ".git"]
  if (extensions.includes(".lua")) return [".luarc.json", ".luarc.jsonc", ".git"]
  return [".git"]
}

function direnvChanges(cwd, env) {
  return new Promise((resolve) => {
    const child = spawn("direnv", ["export", "json"], {
      cwd,
      env: { ...env, DIRENV_NO_TMUX_RENAME: "1" },
      stdio: ["ignore", "pipe", "pipe"],
    })
    const chunks = []
    const errors = []
    child.stdout.on("data", (chunk) => chunks.push(chunk))
    child.stderr.on("data", (chunk) => errors.push(chunk))
    child.on("error", (error) => resolve({ changes: {}, error: error.message }))
    child.on("exit", (code) => {
      if (code !== 0) {
        return resolve({ changes: {}, error: Buffer.concat(errors).toString().trim() || `direnv exited with ${code}` })
      }
      try {
        const output = Buffer.concat(chunks).toString().trim()
        resolve({ changes: output ? JSON.parse(output) : {} })
      } catch {
        resolve({ changes: {}, error: "direnv returned invalid JSON" })
      }
    })
  })
}

function applyEnvironment(env, changes) {
  const result = { ...env }
  for (const [key, value] of Object.entries(changes)) {
    if (value === null) delete result[key]
    else result[key] = String(value)
  }
  return result
}

function rpc(server, root, env) {
  const process = spawn(server.command[0], server.command.slice(1), {
    cwd: root,
    env,
    stdio: ["pipe", "pipe", "pipe"],
  })
  let buffer = Buffer.alloc(0)
  let nextID = 1
  let stopped = false
  const pending = new Map()
  const diagnostics = new Map()
  const diagnosticVersions = new Map()
  const diagnosticWaiters = new Map()
  process.stderr.resume()

  const send = (message) => {
    const body = JSON.stringify(message)
    process.stdin.write(`Content-Length: ${Buffer.byteLength(body)}\r\n\r\n${body}`)
  }

  const notify = (method, params) => send({ jsonrpc: "2.0", method, params })

  const request = (method, params, timeout = 30_000) =>
    new Promise((resolve, reject) => {
      const id = nextID++
      const timer = setTimeout(() => {
        pending.delete(id)
        reject(new Error(`${method} timed out`))
      }, timeout)
      pending.set(id, {
        resolve: (value) => {
          clearTimeout(timer)
          resolve(value)
        },
        reject: (error) => {
          clearTimeout(timer)
          reject(error)
        },
      })
      send({ jsonrpc: "2.0", id, method, params })
    })

  const publishDiagnostics = (params) => {
    diagnostics.set(params.uri, params.diagnostics ?? [])
    diagnosticVersions.set(params.uri, (diagnosticVersions.get(params.uri) ?? 0) + 1)
    const waiters = diagnosticWaiters.get(params.uri)
    if (!waiters) return
    diagnosticWaiters.delete(params.uri)
    for (const resolve of waiters) resolve(params.diagnostics ?? [])
  }

  const handle = (message) => {
    if (message.id !== undefined && (message.result !== undefined || message.error !== undefined)) {
      const waiter = pending.get(message.id)
      if (!waiter) return
      pending.delete(message.id)
      if (message.error) waiter.reject(new Error(message.error.message ?? JSON.stringify(message.error)))
      else waiter.resolve(message.result)
      return
    }

    if (message.method === "textDocument/publishDiagnostics") {
      publishDiagnostics(message.params)
      return
    }

    if (message.id === undefined) return
    let result = null
    if (message.method === "workspace/configuration") {
      result = (message.params?.items ?? []).map(() => server.initialization ?? null)
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
        handle(JSON.parse(body))
      } catch {
        // Ignore malformed server output and continue processing later messages.
      }
    }
  })

  const fail = (error) => {
    if (stopped) return
    stopped = true
    for (const waiter of pending.values()) waiter.reject(error)
    pending.clear()
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

async function start(server, root) {
  const loaded = await direnvChanges(root, globalThis.process.env)
  if (loaded.error) throw new Error(`Failed to load the project direnv environment: ${loaded.error}`)
  const changes = loaded.changes
  const env = { ...applyEnvironment(globalThis.process.env, changes), ...(server.env ?? {}) }
  const client = rpc(server, root, env)
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

async function findRoot(server, file, boundary) {
  let directory = path.dirname(file)
  while (true) {
    const entries = await readdir(directory).catch(() => [])
    if (server.roots.some((marker) => (marker.startsWith("*.") ? entries.some((entry) => entry.endsWith(marker.slice(1))) : entries.includes(marker)))) {
      return directory
    }
    if (directory === boundary || directory === path.dirname(directory)) return boundary
    directory = path.dirname(directory)
  }
}

function waitForDiagnostics(client, uri, since, timeout = 30_000) {
  return new Promise((resolve) => {
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
    const done = (items) => {
      clearTimeout(timer)
      setTimeout(() => resolve(client.diagnostics.get(uri) ?? items), 300)
    }
    client.diagnosticWaiters.set(uri, [...(client.diagnosticWaiters.get(uri) ?? []), done])
  })
}

async function open(client, file) {
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

function formatDiagnostics(file, diagnostics) {
  const labels = ["", "error", "warning", "information", "hint"]
  return diagnostics.map((diagnostic) => {
    const start = diagnostic.range?.start ?? {}
    const location = `${(start.line ?? 0) + 1}:${(start.character ?? 0) + 1}`
    const severity = labels[diagnostic.severity] ?? "diagnostic"
    const message = String(diagnostic.message ?? "").replace(/\s+/g, " ").trim()
    return `${file}:${location}: ${severity}: ${message}`
  }).join("\n")
}

function position(input) {
  return {
    line: Math.max(0, (input.line ?? 1) - 1),
    character: Math.max(0, (input.character ?? 1) - 1),
  }
}

export default {
  id: "bbrian.lsp",
  setup: async (ctx) => {
    const servers = Object.entries(ctx.options.servers ?? {}).flatMap(([id, server]) => {
      if (!server || server.disabled || !Array.isArray(server.command)) return []
      const extensions = Array.isArray(server.extensions) ? server.extensions : []
      return [{ ...server, id, extensions, roots: rootsFor(extensions) }]
    })

    const diagnosticsFor = async (directory, value, timeout = 30_000) => {
      const file = path.resolve(directory, value)
      const server = servers.find((candidate) => candidate.extensions.includes(path.extname(file)))
      if (!server) return ""
      const root = await findRoot(server, file, directory)
      const key = `${server.id}\0${root}`
      if (!clients.has(key)) {
        const starting = start(server, root).catch((error) => {
          clients.delete(key)
          throw error
        })
        clients.set(key, starting)
      }
      const client = await clients.get(key)
      const { uri, changed, diagnosticVersion } = await open(client, file)
      const diagnostics =
        changed || !client.diagnostics.has(uri)
          ? await waitForDiagnostics(client, uri, diagnosticVersion, timeout)
          : (client.diagnostics.get(uri) ?? [])
      return diagnostics.length > 0 ? formatDiagnostics(value, diagnostics) : ""
    }

    await ctx.shell.hook("create.before", async (invocation) => {
      const loaded = await direnvChanges(invocation.cwd, invocation.env)
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
            file: { type: "string", description: "Supported source file, absolute or relative to the session directory" },
            line: { type: "integer", minimum: 1, description: "1-based line for hover or definition" },
            character: { type: "integer", minimum: 1, description: "1-based character for hover or definition" },
            query: { type: "string", description: "Query for workspace_symbols" },
          },
          required: ["operation", "file"],
          additionalProperties: false,
        },
        options: { codemode: false, permission: "lsp" },
        execute: async (input, toolContext) => {
          const session = await ctx.session.get({ sessionID: toolContext.sessionID })
          const directory = session.location.directory
          if (input.operation === "diagnostics") {
            return { content: await diagnosticsFor(directory, input.file) }
          }
          const file = path.resolve(directory, input.file)
          const server = servers.find((candidate) => candidate.extensions.includes(path.extname(file)))
          if (!server) throw new Error(`No configured language server for: ${file}`)
          const root = await findRoot(server, file, directory)
          const key = `${server.id}\0${root}`
          if (!clients.has(key)) {
            const starting = start(server, root).catch((error) => {
              clients.delete(key)
              throw error
            })
            clients.set(key, starting)
          }
          const client = await clients.get(key)
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

      const output = event.result.output
      const paths =
        event.tool === "patch"
          ? (output?.applied ?? []).filter((item) => item.type !== "delete").map((item) => item.target)
          : event.tool === "write"
            ? [output?.target]
            : [event.input?.path]
      const session = await ctx.session.get({ sessionID: event.sessionID })
      const messages = []

      for (const value of new Set(paths.filter((item) => typeof item === "string"))) {
        try {
          const message = await diagnosticsFor(session.location.directory, value, 10_000)
          if (message) messages.push(message)
        } catch (error) {
          messages.push(`LSP diagnostics unavailable for ${value}: ${error.message ?? String(error)}`)
        }
      }

      if (messages.length > 0) {
        const text = messages.join("\n\n")
        event.result.content = Array.isArray(event.result.content)
          ? [...event.result.content, { type: "text", text }]
          : `${event.result.content ?? ""}${event.result.content ? "\n\n" : ""}${text}`
      }
    })

    return async () => {
      const running = [...clients.values()]
      clients.clear()
      await Promise.all(
        running.map(async (value) => {
          const client = await value.catch(() => undefined)
          if (!client) return
          client.notify("exit")
          client.process.kill("SIGTERM")
        }),
      )
    }
  },
}
