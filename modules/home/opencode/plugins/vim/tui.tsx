import { Plugin } from "@opencode-ai/plugin/tui"
import type { EditBufferRenderable, EditorTraits } from "@opentui/core"
import { jsx } from "@opentui/solid/jsx-runtime"
import { onCleanup, onMount } from "solid-js"
import { VimEngine } from "./vim-engine.ts"

type HostEditorTraits = EditorTraits & { owner?: string; role?: string }

const normalKeys = [
  ..."abcdefghijklmnopqrstuvwxyz",
  ..."0123456789",
  "space",
  "-",
  "=",
  "[",
  "]",
  ";",
  "'",
  "\\",
  ",",
  "/",
  ".",
  "`",
  "!",
  "@",
  "#",
  "$",
  "%",
  "^",
  "&",
  "*",
  "(",
  ")",
  "_",
  "+",
  "{",
  "}",
  ":",
  '"',
  "?",
  "<",
  ">",
  "|",
  "~",
  "return",
  "escape",
  "backspace",
  "delete",
  "left",
  "right",
  "up",
  "down",
  "ctrl+a",
  "ctrl+b",
  "ctrl+d",
  "ctrl+e",
  "ctrl+f",
  "ctrl+k",
  "ctrl+r",
  "ctrl+u",
  "ctrl+v",
  "ctrl+w",
]

const vimKey = (key: string): { key: string; ctrl: boolean } => {
  if (key.startsWith("ctrl+")) return { key: key.slice(5), ctrl: true }
  const aliases: Record<string, string> = {
    backspace: "Backspace",
    delete: "Delete",
    down: "j",
    escape: "Escape",
    left: "h",
    return: "Enter",
    right: "l",
    space: " ",
    up: "k",
  }
  return { key: aliases[key] ?? key, ctrl: false }
}

export default Plugin.define({
  id: "local.opencode-vim-v2",
  setup(context) {
    let enabled = true
    let historyText: string | undefined
    let historyDraft: { cursor: number; text: string } | undefined
    const engine = new VimEngine()

    const editor = (): EditBufferRenderable | undefined => {
      const current = context.renderer.currentFocusedEditor
      const traits = current?.traits as HostEditorTraits | undefined
      if (!current || traits?.owner !== "opencode" || traits.role !== "prompt") return
      return current
    }

    const syncCursorStyle = (): void => {
      const input = editor()
      if (!input) return
      const normal = enabled && engine.mode !== "insert"
      const desired = normal
        ? ({ style: "block", blinking: false } as const)
        : ({ style: "line", blinking: true } as const)
      if (input.cursorStyle?.style === desired.style && input.cursorStyle?.blinking === desired.blinking) return
      input.cursorStyle = desired
      context.renderer.requestRender()
    }

    const setStatus = (input: EditBufferRenderable, status: string): void => {
      const traits = { ...input.traits }
      if (enabled && engine.mode !== "insert") traits.status = status || "NORMAL"
      else delete traits.status
      input.traits = traits
    }

    const browseHistory = (key: string, input: EditBufferRenderable): boolean => {
      if (!engine.idle || (key !== "j" && key !== "k")) return false
      const value = input.plainText
      const current = input.cursorOffset
      const start = value.lastIndexOf("\n", Math.max(0, current - 1)) + 1
      const end = value.indexOf("\n", current)
      if (key === "k" && start > 0) return false
      if (key === "j" && end >= 0) return false

      if (key === "k" && historyText === undefined) {
        historyDraft = { text: value, cursor: current }
        input.setText("")
        input.cursorOffset = 0
      } else if (key === "j" && historyText === undefined) return false

      input.cursorOffset = key === "k" ? 0 : input.plainText.length
      context.keymap.dispatch(key === "k" ? "prompt.history.previous" : "prompt.history.next")
      if (!input.plainText && historyDraft) {
        input.setText(historyDraft.text)
        input.cursorOffset = historyDraft.cursor
        historyDraft = undefined
        historyText = undefined
      } else historyText = input.plainText
      engine.sync(input.plainText, input.cursorOffset)
      return true
    }

    const apply = (key: string): void => {
      const input = editor()
      if (!input) return
      const parsed = vimKey(key)

      if (historyText !== undefined && input.plainText !== historyText) {
        historyText = undefined
        historyDraft = undefined
      }
      if (browseHistory(parsed.key, input)) return

      engine.sync(input.plainText, input.cursorOffset)
      if (parsed.key === "Escape" && engine.idle) {
        context.keymap.dispatch("session.interrupt")
        return
      }
      if (parsed.key === "Enter" && engine.idle) {
        context.keymap.dispatch("input.submit")
        return
      }

      const update = engine.handle(parsed.key, parsed.ctrl)
      if (update.text !== input.plainText) input.setText(update.text)
      input.cursorOffset = update.cursor
      if (update.selection) input.setSelection(update.selection.start, update.selection.end)
      else input.clearSelection()
      setStatus(input, update.status)
      syncCursorStyle()

      for (const action of update.actions) {
        if (action.type === "scroll") {
          const page = action.amount >= 1 ? "page" : "half.page"
          context.keymap.dispatch(`session.${page}.${action.direction}`)
        } else if (action.type === "command") context.keymap.dispatch(action.command)
        else if (action.type === "quit") input.blur()
      }
      context.renderer.requestRender()
    }

    const bind = (key: string, run: () => void, active: () => boolean) => ({
      bind: key,
      enabled: active,
      run,
    })

    const Controller = () => {
      onMount(() => {
        syncCursorStyle()
        const timer = setInterval(syncCursorStyle, 50)
        onCleanup(() => clearInterval(timer))
      })
      context.keymap.layer(() => ({
        mode: "global",
        priority: 1000,
        commands: [
          bind(
            "ctrl+o",
            () => context.keymap.dispatch("prompt.editor"),
            () => Boolean(editor()),
          ),
          {
            id: "opencode-vim.toggle",
            title: "Toggle Vim mode",
            group: "Vim",
            palette: true,
            slash: { name: "vim" },
            bind: false,
            run: () => {
              enabled = !enabled
              const input = editor()
              if (input) {
                engine.sync(input.plainText, input.cursorOffset)
                if (engine.mode !== "insert") engine.enterInsert()
                setStatus(input, "")
              }
              context.ui.toast.show({ message: `Vim mode ${enabled ? "enabled" : "disabled"}` })
            },
          },
          bind("escape", () => apply("escape"), () => Boolean(editor()) && enabled && engine.mode === "insert"),
          bind("ctrl+[", () => apply("escape"), () => Boolean(editor()) && enabled && engine.mode === "insert"),
          bind("ctrl+c", () => apply("escape"), () => Boolean(editor()) && enabled && engine.mode === "insert"),
          ...[..."ABCDEFGHIJKLMNOPQRSTUVWXYZ"].map((key) =>
            bind(`shift+${key.toLowerCase()}`, () => apply(key), () => Boolean(editor()) && enabled && engine.mode !== "insert"),
          ),
          ...normalKeys.map((key) =>
            bind(key, () => apply(key), () => Boolean(editor()) && enabled && engine.mode !== "insert"),
          ),
        ],
      }))
      return jsx("box", { height: 0 })
    }

    return context.ui.slot({
      append: "app",
      render: () => jsx(Controller),
    })
  },
})
