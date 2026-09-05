import { Plugin } from "@opencode-ai/plugin/tui"
import type { EditBufferRenderable, EditorTraits } from "@opentui/core"
import { jsx } from "@opentui/solid/jsx-runtime"
import { onCleanup, onMount } from "solid-js"

type Mode = "insert" | "normal"
type Operator = "c" | "d" | "y"
type Pending = "" | "f" | "g" | "r" | "t" | Operator
type Snapshot = { cursor: number; text: string }
type HostEditorTraits = EditorTraits & { owner?: string; role?: string }
type Word = { index: number; text: string }

const printable = [
  ..."abcdefghijklmnopqrstuvwxyz0123456789",
  "space",
  "-",
  "=",
  "[",
  "]",
  ";",
  "'",
  "\\",
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
  "~",
]

export default Plugin.define({
  id: "local.opencode-vim-v2",
  setup(context) {
    let enabled = true
    let mode: Mode = "insert"
    let pending: Pending = ""
    let pendingCount = 1
    let count = ""
    let desiredColumn: number | undefined
    let yank = ""
    let yankLinewise = false
    let insertSnapshot: Snapshot | undefined
    const undo: Snapshot[] = []
    const redo: Snapshot[] = []

    const editor = (): EditBufferRenderable | undefined => {
      const current = context.renderer.currentFocusedEditor
      const traits = current?.traits as HostEditorTraits | undefined
      if (!current || traits?.owner !== "opencode" || traits.role !== "prompt") return
      return current
    }

    const text = () => editor()?.plainText ?? ""
    const cursor = () => editor()?.cursorOffset ?? 0
    const clamp = (value: number, min: number, max: number): number => Math.max(min, Math.min(value, max))
    const lineStart = (value: string, offset: number): number => value.lastIndexOf("\n", Math.max(0, offset - 1)) + 1
    const lineEnd = (value: string, offset: number): number => {
      const end = value.indexOf("\n", offset)
      return end < 0 ? value.length : end
    }

    const setCursor = (offset: number, allowEnd = false): void => {
      const input = editor()
      if (!input) return
      const value = input.plainText
      let max = value.length
      if (!allowEnd && value.length > 0) {
        const end = lineEnd(value, clamp(offset, 0, value.length))
        max = Math.max(lineStart(value, end), end - 1)
      }
      input.cursorOffset = clamp(offset, 0, max)
    }

    const setMode = (next: Mode): void => {
      const input = editor()
      mode = next
      pending = ""
      pendingCount = 1
      count = ""
      desiredColumn = undefined
      if (!input) return
      const traits = { ...input.traits }
      if (enabled && next === "normal") traits.status = "NORMAL"
      else delete traits.status
      input.traits = traits
      syncCursorStyle()
    }

    const syncCursorStyle = () => {
      const input = editor()
      if (!input) return
      const desired =
        enabled && mode === "normal"
          ? ({ style: "block", blinking: false } as const)
          : ({ style: "line", blinking: true } as const)
      if (input.cursorStyle?.style === desired.style && input.cursorStyle?.blinking === desired.blinking) return
      input.cursorStyle = desired
      context.renderer.requestRender()
    }

    const snapshot = (): Snapshot => ({ text: text(), cursor: cursor() })
    const restore = (state: Snapshot): void => {
      const input = editor()
      if (!input) return
      input.setText(state.text)
      setCursor(state.cursor, mode === "insert")
    }
    const change = (fn: () => void): void => {
      const before = snapshot()
      fn()
      if (before.text === text()) return
      undo.push(before)
      redo.length = 0
    }
    const replace = (start: number, end: number, replacement = ""): void => {
      const input = editor()
      if (!input) return
      const value = input.plainText
      input.setText(value.slice(0, start) + replacement + value.slice(end))
      setCursor(start, mode === "insert")
    }

    const words = (value: string): Word[] =>
      Array.from(value.matchAll(/[A-Za-z0-9_]+|[^\sA-Za-z0-9_]+/g), (match) => ({
        index: match.index ?? 0,
        text: match[0],
      }))
    const wordForward = (value: string, offset: number): number =>
      words(value).find((match) => match.index > offset)?.index ?? value.length
    const wordBackward = (value: string, offset: number): number => {
      const previous = words(value).filter((match) => match.index < offset)
      return previous.at(-1)?.index ?? 0
    }
    const WORDBackward = (value: string, offset: number): number => {
      let target = Math.max(0, offset - 1)
      while (target > 0 && /\s/.test(value[target] ?? "")) target--
      while (target > 0 && !/\s/.test(value[target - 1] ?? "")) target--
      return target
    }
    const WORDForward = (value: string, offset: number): number => {
      let target = offset
      while (target < value.length && !/\s/.test(value[target] ?? "")) target++
      while (target < value.length && /\s/.test(value[target] ?? "")) target++
      return target
    }
    const wordEnd = (value: string, offset: number): number => {
      const match = words(value).find((item) => item.index + item.text.length - 1 > offset)
      return match ? match.index + match.text.length - 1 : Math.max(0, value.length - 1)
    }
    const WORDEnd = (value: string, offset: number): number => {
      const match = Array.from(value.matchAll(/\S+/g)).find(
        (item) => (item.index ?? 0) + item[0].length - 1 > offset,
      )
      return match ? (match.index ?? 0) + match[0].length - 1 : Math.max(0, value.length - 1)
    }
    const findForward = (value: string, offset: number, character: string, repeat: number): number | undefined => {
      const end = lineEnd(value, offset)
      let target = offset
      for (let index = 0; index < repeat; index++) {
        target = value.indexOf(character, target + 1)
        if (target < 0 || target >= end) return
      }
      return target
    }

    const vertical = (delta: number): void => {
      const value = text()
      const current = cursor()
      const start = lineStart(value, current)
      const column = desiredColumn ?? current - start
      let targetStart
      if (delta < 0) {
        if (start === 0) return
        targetStart = lineStart(value, start - 1)
      } else {
        const end = lineEnd(value, current)
        if (end === value.length) return
        targetStart = end + 1
      }
      const targetEnd = lineEnd(value, targetStart)
      desiredColumn = column
      setCursor(Math.min(targetStart + column, Math.max(targetStart, targetEnd - 1)))
    }

    const enterInsert = (offset: number): void => {
      insertSnapshot = snapshot()
      setCursor(offset, true)
      setMode("insert")
    }
    const enterNormal = (): void => {
      if (insertSnapshot && insertSnapshot.text !== text()) {
        undo.push(insertSnapshot)
        redo.length = 0
      }
      insertSnapshot = undefined
      setMode("normal")
      const value = text()
      const current = cursor()
      if (current > lineStart(value, current)) setCursor(current - 1)
      else setCursor(current)
    }

    const deleteLine = (enterInsertAfter = false): void => {
      const value = text()
      const start = lineStart(value, cursor())
      let end = lineEnd(value, cursor())
      if (end < value.length) end += 1
      else if (start > 0) return replace(start - 1, end)
      replace(start, end)
      if (enterInsertAfter) enterInsert(start)
    }

    const applyOperator = (operator: Operator, motion: string): void => {
      const value = text()
      const current = cursor()
      if (motion === operator) {
        if (operator === "y") {
          const start = lineStart(value, current)
          const end = Math.min(value.length, lineEnd(value, current) + 1)
          yank = value.slice(start, end)
          yankLinewise = true
        } else {
          change(() => deleteLine(operator === "c"))
        }
        return
      }

      let target
      if (motion === "w") target = wordForward(value, current)
      if (motion === "W") target = WORDForward(value, current)
      if (motion === "B") target = WORDBackward(value, current)
      if (motion === "e") target = wordEnd(value, current) + 1
      if (motion === "E") target = WORDEnd(value, current) + 1
      if (motion === "$" || motion === "D" || motion === "C") target = lineEnd(value, current)
      if (motion === "0") target = lineStart(value, current)
      if (target === undefined) return
      const start = Math.min(current, target)
      const end = Math.max(current, target)
      if (operator === "y") {
        yank = value.slice(start, end)
        yankLinewise = false
        return
      }
      change(() => replace(start, end))
      if (operator === "c") enterInsert(start)
    }

    const handleNormal = (key: string): void => {
      const input = editor()
      if (!input) return
      const value = input.plainText
      const current = cursor()

      // Escape cancels a pending operator or count. Otherwise this layer would
      // swallow the key, so hand it to opencode's own escape binding.
      if (key === "escape") {
        const cancelled = Boolean(pending || count)
        pending = ""
        pendingCount = 1
        count = ""
        desiredColumn = undefined
        if (!cancelled) context.keymap.dispatch("session.interrupt")
        return
      }

      if (pending === "f" || pending === "t") {
        const motion = pending
        pending = ""
        const target = findForward(value, current, key === "space" ? " " : key, pendingCount)
        pendingCount = 1
        if (target !== undefined) setCursor(motion === "t" ? Math.max(current, target - 1) : target)
        return
      }
      if (pending === "r") {
        pending = ""
        const repeat = pendingCount
        pendingCount = 1
        if (current + repeat > lineEnd(value, current)) return
        const replacement = key === "space" ? " " : key
        change(() => {
          replace(current, current + repeat, replacement.repeat(repeat))
          setCursor(current + repeat - 1)
        })
        return
      }

      if (/^[1-9]$/.test(key) || (count && key === "0")) {
        count += key
        return
      }
      const repeat = Number(count || 1)
      count = ""

      if (pending) {
        const operator = pending
        pending = ""
        if (operator === "g") {
          if (key === "g") setCursor(0)
          else if (key === "t") context.keymap.dispatch("session.tab.next")
          else if (key === "T") context.keymap.dispatch("session.tab.previous")
        } else applyOperator(operator, key)
        return
      }

      if (key === "d" || key === "c" || key === "y" || key === "g") {
        pending = key
        return
      }
      if (key === "f" || key === "t") {
        pending = key
        pendingCount = repeat
        return
      }
      if (key === "r") {
        pending = "r"
        pendingCount = repeat
        return
      }
      if (key === "h" || key === "left") setCursor(current - repeat)
      else if (key === "l" || key === "right") setCursor(current + repeat)
      else if (key === "j" || key === "down") {
        if (!value) context.keymap.dispatch("prompt.history.next")
        else for (let i = 0; i < repeat; i++) vertical(1)
      } else if (key === "k" || key === "up") {
        if (!value) context.keymap.dispatch("prompt.history.previous")
        else for (let i = 0; i < repeat; i++) vertical(-1)
      } else if (key === "w")
        setCursor(Array.from({ length: repeat }).reduce<number>((offset) => wordForward(value, offset), current))
      else if (key === "W")
        setCursor(Array.from({ length: repeat }).reduce<number>((offset) => WORDForward(value, offset), current))
      else if (key === "b")
        setCursor(Array.from({ length: repeat }).reduce<number>((offset) => wordBackward(value, offset), current))
      else if (key === "B")
        setCursor(Array.from({ length: repeat }).reduce<number>((offset) => WORDBackward(value, offset), current))
      else if (key === "e")
        setCursor(Array.from({ length: repeat }).reduce<number>((offset) => wordEnd(value, offset), current))
      else if (key === "E")
        setCursor(Array.from({ length: repeat }).reduce<number>((offset) => WORDEnd(value, offset), current))
      else if (key === "0") setCursor(lineStart(value, current))
      else if (key === "^") {
        const start = lineStart(value, current)
        setCursor(start + (value.slice(start, lineEnd(value, current)).match(/^\s*/)?.[0].length ?? 0))
      } else if (key === "$") setCursor(Math.max(lineStart(value, current), lineEnd(value, current) - 1))
      else if (key === "G") setCursor(Math.max(0, value.length - 1))
      else if (key === "i") enterInsert(current)
      else if (key === "a") enterInsert(Math.min(value.length, current + 1))
      else if (key === "I") enterInsert(lineStart(value, current))
      else if (key === "A") enterInsert(lineEnd(value, current))
      else if (key === "o")
        change(() => {
          const end = lineEnd(value, current)
          replace(end, end, "\n")
          enterInsert(end + 1)
        })
      else if (key === "O")
        change(() => {
          const start = lineStart(value, current)
          replace(start, start, "\n")
          enterInsert(start)
        })
      else if (key === "x") change(() => replace(current, Math.min(value.length, current + repeat)))
      else if (key === "D") applyOperator("d", "$")
      else if (key === "C") applyOperator("c", "$")
      else if (key === "p" || key === "P")
        change(() => {
          if (!yank) return
          if (yankLinewise) {
            const offset = key === "p" ? Math.min(value.length, lineEnd(value, current) + 1) : lineStart(value, current)
            replace(offset, offset, yank)
          } else {
            const offset = key === "p" ? Math.min(value.length, current + 1) : current
            replace(offset, offset, yank)
          }
        })
      else if (key === "u") {
        const previous = undo.pop()
        if (previous) {
          redo.push(snapshot())
          restore(previous)
        } else context.keymap.dispatch("input.undo")
      } else if (key === "ctrl+r") {
        const next = redo.pop()
        if (next) {
          undo.push(snapshot())
          restore(next)
        } else context.keymap.dispatch("input.redo")
      } else if (key === "ctrl+u") context.keymap.dispatch("session.half.page.up")
      else if (key === "ctrl+d") context.keymap.dispatch("session.half.page.down")
      else if (key === "ctrl+b") context.keymap.dispatch("session.page.up")
      else if (key === "ctrl+f") context.keymap.dispatch("session.page.down")
      else if (key === "return") context.keymap.dispatch("input.submit")
      desiredColumn = key === "j" || key === "k" || key === "up" || key === "down" ? desiredColumn : undefined
    }

    const bind = (key: string, run: () => void, active: () => boolean) => ({
      bind: key,
      enabled: active,
      run: () => {
        run()
      },
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
              setMode("insert")
              context.ui.toast.show({ message: `Vim mode ${enabled ? "enabled" : "disabled"}` })
            },
          },
          bind("escape", enterNormal, () => Boolean(editor()) && enabled && mode === "insert"),
          bind("ctrl+[", enterNormal, () => Boolean(editor()) && enabled && mode === "insert"),
          bind("ctrl+c", enterNormal, () => Boolean(editor()) && enabled && mode === "insert"),
          ...[..."ABCDEFGHIJKLMNOPQRSTUVWXYZ"].map((key) =>
            bind(
              `shift+${key.toLowerCase()}`,
              () => handleNormal(key),
              () => Boolean(editor()) && enabled && mode === "normal",
            ),
          ),
          ...[
            ...printable,
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
            "ctrl+w",
          ].map((key) =>
            bind(
              key,
              () => handleNormal(key),
              () => Boolean(editor()) && enabled && mode === "normal",
            ),
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
