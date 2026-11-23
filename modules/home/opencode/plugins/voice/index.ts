import { Plugin } from "@opencode/plugin"

import { automaticTitle, isDelegation, parseModel, VoiceSessions } from "./delegation.ts"
import { excerpts, type MessageLike, minutesAgo, overview, type Row, search } from "./overview.ts"
import { client, readState, rowFor } from "./state.ts"
import { monitor } from "./monitor.ts"
import { settles, waitUntil } from "./wait.ts"

// Gives the phone apps' OpenCode Session Delegator what their built-in delegator
// has (session list, read, send, wait) plus a live overview of every session, and
// the phone-side ios_voice_* tools the apps act on when a delegator session calls
// them. The apps read those calls' inputs from the session's event stream, so the
// tools themselves only acknowledge. ios_voice_open_session is not here: the
// phone hosts it over client MCP during a call.

const guidance = `You are running the user's live phone voice call. Their speech arrives as [Voice delta] lines, transcribed and possibly misheard; your final reply is read aloud. Answer in one to three short spoken sentences unless they ask for detail, with no Markdown, IDs, paths or code.
You manage the user's other OpenCode sessions on this computer. Coding work happens by messaging the session that owns it with voice_send_message; do it yourself only when the user asks you to.
- The "voice-sessions" context lists every session that is working, waiting on the user, or finished, as of the user's latest words. Answer status questions from it, call voice_sessions to search or list more, and voice_read_session for what a session actually said.
- After sending work, or when the user wants to hear when a session finishes, call ios_voice_watch_session for it and end your turn: the phone announces its reply when it lands.
- Call voice_wait only when you must act on a result in this turn ("when it's done, tell the other one to…"), or the user wants to know when a session needs them (an approval or question, which the phone doesn't announce). Say what you're waiting for with ios_voice_say first. If voice_wait returns because the user spoke, answer them first; wait again only if they still want it.
- Always end your turn with a short spoken reply, even after ios_voice_say, except after a [Session update].
- A [Session update] message is not from the user: it says another session finished or needs the user. Tell them right away with ios_voice_say in one or two short sentences, then end your turn without another reply. If it interrupted a voice_wait the user still wants, call voice_wait again after speaking.
- Send with delivery "queue" when the work should start after the session's current work ("when it's done, also…"); otherwise steer.
- A session that needs approval or asked a question is blocked until the user answers it on a screen; tell them which one.
- To put a session on the phone's screen, use the phone's open-session tool when it is available.
- Never say something happened unless a tool confirmed it.`

const phoneTools = ["ios_voice_say", "ios_voice_watch_session", "ios_voice_pin_session", "ios_voice_end_call"]
const voiceTools = [
  "voice_sessions", "voice_read_session", "voice_send_message", "voice_create_session", "voice_interrupt_session", "voice_wait",
]

const sessionID = { type: "string", description: "A session ID from the voice-sessions context or voice_sessions" }

type Input = Record<string, unknown>
const text = (input: Input, key: string) => typeof input[key] === "string" ? (input[key] as string).trim() : ""
const integer = (input: Input, key: string, fallback: number, max: number) => {
  const value = input[key]
  return typeof value === "number" && Number.isFinite(value) ? Math.min(Math.max(1, Math.round(value)), max) : fallback
}
const json = (value: unknown) => ({ content: JSON.stringify(value) })

const report = (error: unknown) => console.error("OpenCode voice:", error)

function bounded<T>(promise: Promise<T>, ms: number): Promise<T | undefined> {
  return Promise.race([promise, new Promise<undefined>((resolve) => setTimeout(resolve, ms))])
}

/** When voice_send_message last sent each session work, so a wait right after can tell its result apart. */
const sent = new Map<string, number>()

const describe = (row: Row, now: number) => ({
  id: row.id,
  title: row.title,
  project: row.project,
  directory: row.directory,
  status: row.status,
  ...(row.detail ? { detail: row.detail } : {}),
  updated_minutes_ago: minutesAgo(row.updated, now),
})

export default Plugin.define({
  id: "local.voice",
  async setup(ctx) {
    const agent = typeof ctx.options.agent === "string" ? ctx.options.agent : undefined
    const model = parseModel(ctx.options.model)
    const voiceSessions = new VoiceSessions()
    const announced = new Map<string, string>()
    const isVoice = (id: string, current: string) => current === agent || voiceSessions.has(id)

    const latestReply = async (id: string, signal: AbortSignal) => {
      const api = await client()
      const page = await api.message.list({ sessionID: id, limit: 5, order: "desc", type: "assistant" }, { signal })
      return excerpts(page.data as unknown as MessageLike[], 800).find((line) => !line.startsWith("Agent: (no text)"))
    }

    // Automatic mode creates a plain "Voice" session with the server's default
    // agent and model; move it to the voice agent once. A picked or viewed
    // session keeps its own agent and model.
    const adopt = async (id: string) => {
      if (!agent) return
      const session = await ctx.session.get({ sessionID: id })
      if (session.parentID || session.title?.trim() !== automaticTitle || session.agent === agent) return
      await ctx.session.switchAgent({ sessionID: id, agent })
      if (model) await ctx.session.switchModel({ sessionID: id, model })
    }

    // The overview rides on a session instruction entry, so a change is announced
    // at the turn's first step instead of rewriting the cached prompt every call.
    const announce = async (id: string) => {
      const api = await client()
      const state = await readState(api, AbortSignal.timeout(4000), { limit: 25 })
      const value = overview(state.rows.filter((row) => row.id !== id))
      if (announced.get(id) === value) return
      await ctx.session.instructions.entry.put({ sessionID: id, key: "voice-sessions", value })
      announced.set(id, value)
    }

    await ctx.session.hook("prompt", async (event) => {
      if (!isDelegation(event.prompt.text)) return
      voiceSessions.mark(event.sessionID)
      monitor().heard(event.sessionID)
      // Admission waits for these; a slow server must not hold the user's words.
      await bounded(Promise.all([adopt(event.sessionID).catch(report), announce(event.sessionID).catch(report)]), 3000)
    })

    await ctx.session.hook("context", (event) => {
      if (isVoice(event.sessionID, event.agent)) {
        event.system.push({ type: "text", text: guidance })
        return
      }
      for (const name of [...phoneTools, ...voiceTools]) delete event.tools[name]
    })

    await ctx.tool.transform((tools) => {
      // Direct tools: the phone only sees top-level calls, and Code Mode adds a round trip.
      const add = (tool: Parameters<typeof tools.add>[0]) => tools.add({ ...tool, options: { codemode: false } })

      // The phone apps match these names and input fields exactly.
      add({
        name: "ios_voice_say",
        description: "Say a short status line aloud on the user's voice call right away, while you keep working, such as before a long wait. Your final reply is spoken anyway; don't repeat it here.",
        input: {
          type: "object",
          properties: { text: { type: "string", minLength: 1, description: "One short spoken sentence" } },
          required: ["text"],
          additionalProperties: false,
        },
        execute: async () => ({ content: "Spoken on the call, if one is active." }),
      })
      add({
        name: "ios_voice_watch_session",
        description: "Have the phone announce a session's reply aloud when its current work finishes, so you can end your turn instead of waiting. Use after sending work to another session, or when the user wants to hear when one finishes. Works only during this call.",
        input: {
          type: "object",
          properties: {
            session_id: sessionID,
            note: { type: "string", description: "What the user is waiting to hear, in a few words" },
          },
          required: ["session_id"],
          additionalProperties: false,
        },
        execute: async (raw) => {
          // The phone announces it, so the session-update monitor stays quiet about its next result.
          const id = text(raw as Input, "session_id")
          if (id) monitor().watch(id)
          return { content: "The phone will announce that session's reply when it finishes." }
        },
      })
      add({
        name: "ios_voice_pin_session",
        description: "Pin or unpin a session on the phone's home screen.",
        input: {
          type: "object",
          properties: { session_id: sessionID, pinned: { type: "boolean" } },
          required: ["session_id", "pinned"],
          additionalProperties: false,
        },
        execute: async () => ({ content: "Done on the phone." }),
      })
      add({
        name: "ios_voice_end_call",
        description: "Hang up the voice call after your current reply, when the user says goodbye or asks to end the call.",
        input: { type: "object", properties: {}, additionalProperties: false },
        execute: async () => {
          monitor().hungUp()
          return { content: "The call ends after your reply." }
        },
      })

      add({
        name: "voice_sessions",
        description: "List the user's OpenCode sessions, most urgent first (needs approval, question, working, failed, finished), or search them by words from the title or project, forgiving word order and mishearings.",
        input: {
          type: "object",
          properties: {
            query: { type: "string", description: "Words from the session title or project" },
            limit: { type: "integer", minimum: 1, maximum: 50 },
          },
          additionalProperties: false,
        },
        execute: async (raw, context) => {
          const input = raw as Input
          const query = text(input, "query")
          const limit = integer(input, "limit", 15, 50)
          const state = await readState(await client(), context.signal, { limit: query ? 100 : limit + 1 })
          const others = state.rows.filter((row) => row.id !== context.sessionID)
          const found = query ? search(others, query) : others
          const now = Date.now()
          return json({ sessions: found.slice(0, limit).map((row) => describe(row, now)), more: Math.max(0, found.length - limit) })
        },
      })

      add({
        name: "voice_read_session",
        description: "Read what a session said recently and whether it is working or waiting on the user. Messages are text excerpts, oldest first.",
        input: {
          type: "object",
          properties: { session_id: sessionID, limit: { type: "integer", minimum: 1, maximum: 30 } },
          required: ["session_id"],
          additionalProperties: false,
        },
        execute: async (raw, context) => {
          const input = raw as Input
          const id = text(input, "session_id")
          const api = await client()
          const [state, page] = await Promise.all([
            readState(api, context.signal, { limit: 0, include: [id] }),
            api.message.list({ sessionID: id, limit: integer(input, "limit", 8, 30), order: "desc" }, { signal: context.signal }),
          ])
          const row = rowFor(state, id)
          return json({
            session: row ? describe(row, Date.now()) : { id },
            messages: excerpts([...(page.data as unknown as MessageLike[])].reverse()),
          })
        },
      })

      add({
        name: "voice_send_message",
        description: "Send the user's request to another session, whose agent does the work. Steer (default) reaches it at its next step; queue runs after its current work. Then call ios_voice_watch_session for it.",
        input: {
          type: "object",
          properties: {
            session_id: sessionID,
            text: { type: "string", minLength: 1, description: "A clear instruction keeping the user's exact intent, not a transcript" },
            delivery: { type: "string", enum: ["steer", "queue"] },
          },
          required: ["session_id", "text"],
          additionalProperties: false,
        },
        execute: async (raw, context) => {
          const input = raw as Input
          const id = text(input, "session_id")
          const delivery = input.delivery === "queue" ? "queue" : "steer"
          const api = await client()
          // Like a typed steer, move a blocking shell to the background so the agent reads it next.
          if (delivery === "steer") {
            await api.session.background({ sessionID: id }, { signal: AbortSignal.any([context.signal, AbortSignal.timeout(1500)]) })
              .catch(() => undefined)
          }
          await api.session.prompt({
            sessionID: id,
            delivery,
            text: `${text(input, "text")}\n\n(Relayed from the user's voice call: lead your reply with one or two plain sentences that can be read aloud.)`,
          }, { signal: context.signal })
          sent.set(id, Date.now())
          return { content: `Sent (${delivery}). Call ios_voice_watch_session for ${id} so the phone announces the reply.` }
        },
      })

      add({
        name: "voice_create_session",
        description: "Start a new session in a project directory on this computer, optionally with its first request. Use voice_sessions to find a project's directory.",
        input: {
          type: "object",
          properties: {
            directory: { type: "string", description: "A project or worktree directory" },
            title: { type: "string" },
            text: { type: "string", description: "The first request, as a clear instruction" },
          },
          required: ["directory"],
          additionalProperties: false,
        },
        execute: async (raw, context) => {
          const input = raw as Input
          const directory = text(input, "directory").replace(/\/+$/, "")
          const api = await client()
          const projects = await api.project.list({ archived: false }, { signal: context.signal })
          if (!projects.some((project) => project.canonical === directory || project.sandboxes.includes(directory))) {
            return json({
              error: "Not a known project directory; no session was created.",
              known: projects.map((project) => project.canonical),
            })
          }
          const title = text(input, "title")
          const created = await api.session.create({ location: { directory }, ...(title ? { title } : {}) }, { signal: context.signal })
          const first = text(input, "text")
          if (first) {
            await api.session.prompt({ sessionID: created.id, text: first }, { signal: context.signal })
            sent.set(created.id, Date.now())
          }
          return json({ session_id: created.id, started: !!first })
        },
      })

      add({
        name: "voice_interrupt_session",
        description: "Stop a session's current work.",
        input: {
          type: "object",
          properties: { session_id: sessionID },
          required: ["session_id"],
          additionalProperties: false,
        },
        execute: async (raw, context) => {
          const id = text(raw as Input, "session_id")
          const result = await (await client()).session.interrupt({ sessionID: id }, { signal: context.signal })
          return json(result)
        },
      })

      add({
        name: "voice_wait",
        description: "Wait until one of the given sessions finishes, fails, or needs the user (approval or a question), then return their status and latest reply. Returns early when the user speaks again. Only when the user asked to wait or to chain work; otherwise use ios_voice_watch_session.",
        input: {
          type: "object",
          properties: {
            session_ids: { type: "array", items: sessionID, minItems: 1, maxItems: 10 },
            timeout_seconds: { type: "integer", minimum: 10, maximum: 900, description: "Default 300" },
          },
          required: ["session_ids"],
          additionalProperties: false,
        },
        execute: async (raw, context) => {
          const input = raw as Input
          const ids = [...new Set((Array.isArray(input.session_ids) ? input.session_ids : [])
            .filter((id): id is string => typeof id === "string" && id.trim() !== "").map((id) => id.trim()))]
          if (!ids.length) return json({ error: "session_ids required" })
          const api = await client()
          const started = Date.now()
          const ran = new Set<string>()
          let last: Row[] = []
          await context.progress({ status: `Waiting for ${ids.length === 1 ? "a session" : `${ids.length} sessions`}` })
          // This wait reports these sessions itself; the monitor's updates would repeat it.
          const release = monitor().wait(ids)

          const outcome = await waitUntil<string[]>({
            signal: context.signal,
            timeoutMs: integer(input, "timeout_seconds", 300, 900) * 1000,
            pollMs: 20_000,
            wakes: async (signal, wake) => {
              const types = [
                "session.idle", "session.execution.started", "session.execution.succeeded", "session.execution.failed",
                "session.execution.interrupted", "permission.asked", "form.created", "session.inbox.enqueued",
              ] as const
              for await (const event of api.event.subscribe({ types, signal })) {
                if (event.type === "server.connected") continue
                if (event.type !== "session.inbox.enqueued" || event.data.sessionID !== context.sessionID) wake()
                else wake(event.data.item.type === "user" ? "user_spoke" : "update")
              }
            },
            check: async () => {
              const state = await readState(api, context.signal, { limit: 0, include: ids })
              last = ids.flatMap((id) => rowFor(state, id) ?? [])
              const settled = ids.filter((id) => {
                const row = rowFor(state, id)
                if (row?.status === "running") ran.add(id)
                return settles(row?.status, {
                  idle: state.sessions.get(id)?.time.idle,
                  ran: ran.has(id),
                  started,
                  sent: sent.get(id),
                  now: Date.now(),
                })
              })
              return settled.length ? settled : undefined
            },
          }).finally(release)

          const now = Date.now()
          const sessions = await Promise.all(last.map(async (row) => ({
            ...describe(row, now),
            ...(outcome.type === "result" && outcome.result.includes(row.id) && row.status !== "running"
              ? { latest_reply: await latestReply(row.id, context.signal).catch(() => undefined) }
              : {}),
          })))
          const missing = ids.filter((id) => !last.some((row) => row.id === id))
          const reasons = {
            result: "a session changed",
            user_spoke: "the user spoke; answer them, and wait again only if they still want it",
            update: "a [Session update] about another session arrived; speak it, then call voice_wait again",
            timeout: "timed out; the sessions are still working",
          }
          return json({
            stopped_because: reasons[outcome.type],
            waited_seconds: Math.round((now - started) / 1000),
            sessions,
            ...(missing.length ? { unknown_session_ids: missing } : {}),
          })
        },
      })
    })
  },
})
