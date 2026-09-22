import assert from "node:assert/strict"
import { execFileSync } from "node:child_process"
import { mkdtemp, mkdir, writeFile, readFile, symlink, rename, rm } from "node:fs/promises"
import { createServer } from "node:net"
import { tmpdir } from "node:os"
import { join } from "node:path"
import { pathToFileURL } from "node:url"
import { setTimeout as sleep } from "node:timers/promises"

const [serverConfig, cliConfig, packagePath] = process.argv.slice(2)
// Tie this regression to the deployed configuration, rather than testing a
// workaround the configuration could accidentally stop using.
for (const file of [serverConfig, cliConfig]) {
  const config = JSON.parse(await readFile(file, "utf8"))
  const local = config.plugins.map((entry) => typeof entry === "string" ? entry : entry.package)
    .filter((target) => target.startsWith("file:"))
  assert.ok(local.length > 0)
  assert.ok(local.every((target) => target.startsWith("file:///nix/store/")), `${file}: local plugin registrations must use immutable paths`)
}
const { OpenCode } = await import(pathToFileURL(join(packagePath, "node_modules/@opencode/client/dist/promise/index.js")))
const { Service } = await import(pathToFileURL(join(packagePath, "node_modules/@opencode/client/dist/promise/service.js")))
const root = await mkdtemp(join(tmpdir(), "opencode-reload-"))
const config = join(root, "config/opencode")
const env = {
  ...process.env, HOME: join(root, "home"), XDG_CONFIG_HOME: join(root, "config"),
  XDG_DATA_HOME: join(root, "data"), XDG_STATE_HOME: join(root, "state"),
  XDG_CACHE_HOME: join(root, "cache"), XDG_RUNTIME_DIR: join(root, "run"),
  OPENCODE_DISABLE_MODELS_FETCH: "true",
}
delete env.DBUS_SESSION_BUS_ADDRESS
delete env.OPENCODE_DISABLE_FILEWATCHER
const cli = (...args) => execFileSync("opencode2", args, { env, cwd: root, encoding: "utf8", timeout: 20000 })
try {
  await Promise.all([mkdir(config, { recursive: true }), mkdir(env.HOME), mkdir(env.XDG_RUNTIME_DIR)])
  const generation = async (version) => {
    const target = join(root, `package-${version}`)
    await mkdir(target)
    await writeFile(join(target, "index.js"), `export default { id: "test.reload", setup() { return () => {} } } // ${version}\n`)
    // Home Manager replaces the configuration symlink on each generation.
    // Plugin registrations point directly to the immutable package, with no
    // auto-discovery aliases that could load duplicate plugin IDs.
    const configuration = join(root, `config-${version}.json`)
    await writeFile(configuration, JSON.stringify({ update: "disable", plugins: [`file://${target}`] }))
    await symlink(configuration, join(config, "opencode.json.next"))
    await rename(join(config, "opencode.json.next"), join(config, "opencode.json"))
    return target
  }
  const first = await generation(1)
  const reservation = createServer()
  await new Promise((resolve) => reservation.listen(0, "127.0.0.1", resolve))
  const port = reservation.address().port
  await new Promise((resolve) => reservation.close(resolve))
  cli("service", "set", "port", String(port))
  cli("api", "get", "/api/info")
  const endpoint = await Service.discover({ file: join(env.XDG_STATE_HOME, "opencode/service.json") })
  assert.ok(endpoint)
  const client = OpenCode.make({ baseUrl: endpoint.url, headers: Service.headers(endpoint) })
  const check = async (directory, target) => {
    let plugins = []
    const deadline = Date.now() + 15000
    do {
      plugins = (await client.plugin.list({ location: { directory } })).data
      const probe = plugins.find((plugin) => plugin.id === "test.reload")
      if (probe?.state.status === "active" && probe.source.path === join(target, "index.js")) break
      await sleep(100)
    } while (Date.now() < deadline)
    const local = plugins.filter((plugin) => plugin.source.type !== "builtin")
    assert.equal(local.length, 1, JSON.stringify(local))
    const probe = plugins.find((plugin) => plugin.id === "test.reload")
    assert.equal(probe?.state.status, "active", JSON.stringify(plugins.filter((plugin) => plugin.source.type !== "builtin")))
    assert.equal(probe.source.path, join(target, "index.js"))
  }
  await check(env.HOME, first)
  const second = await generation(2)
  for (const location of await client.debug.location.list()) await client.debug.location.evict({ location })
  // Use explicit locations and the client: bare CLI API requests target the
  // service's home directory, regardless of the CLI's working directory.
  await check(env.HOME, second)
  await check(root, second)
  console.log("Plugin reload passed: new generation remains active after symlink replacement and location eviction.")
} finally {
  try { cli("service", "stop") } finally { await rm(root, { recursive: true }) }
}
