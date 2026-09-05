import {
  TextBuffer,
  createInitialContext,
  executeOperatorOnRange,
  processKeystroke,
  resetContext,
} from "@vimee/core"
import type { CursorPosition, VimAction, VimContext, VimMode } from "@vimee/core"

export type VimHostAction =
  | Extract<VimAction, { type: "scroll" | "quit" | "save" }>
  | { type: "command"; command: string }

type EngineAction = VimAction | Extract<VimHostAction, { type: "command" }>

export type VimUpdate = {
  actions: VimHostAction[]
  cursor: number
  mode: VimMode | "replace"
  selection?: { start: number; end: number }
  status: string
  text: string
}

const positionAt = (text: string, offset: number): CursorPosition => {
  const before = text.slice(0, Math.max(0, Math.min(offset, text.length)))
  const lines = before.split("\n")
  return { line: lines.length - 1, col: lines.at(-1)?.length ?? 0 }
}

const offsetAt = (text: string, position: CursorPosition): number => {
  const lines = text.split("\n")
  const line = Math.max(0, Math.min(position.line, lines.length - 1))
  const prefix = lines.slice(0, line).reduce((length, value) => length + value.length + 1, 0)
  return prefix + Math.max(0, Math.min(position.col, lines[line]?.length ?? 0))
}

const previousWordEnd = (text: string, offset: number, WORD: boolean): number => {
  const pattern = WORD ? /\S+/g : /[A-Za-z0-9_]+|[^\sA-Za-z0-9_]+/g
  const matches = Array.from(text.matchAll(pattern))
  return matches
    .map((match) => (match.index ?? 0) + match[0].length - 1)
    .filter((end) => end < offset)
    .at(-1) ?? 0
}

const nextWordEnd = (text: string, offset: number, WORD: boolean): number => {
  const pattern = WORD ? /\S+/g : /[A-Za-z0-9_]+|[^\sA-Za-z0-9_]+/g
  const match = Array.from(text.matchAll(pattern)).find(
    (item) => (item.index ?? 0) + item[0].length - 1 > offset,
  )
  return match ? (match.index ?? 0) + match[0].length - 1 : Math.max(0, text.length - 1)
}

const insertedKeys = (before: string, after: string, cursor: number): string[] => {
  let start = 0
  while (start < before.length && start < after.length && before[start] === after[start]) start++
  let beforeEnd = before.length
  let afterEnd = after.length
  while (beforeEnd > start && afterEnd > start && before[beforeEnd - 1] === after[afterEnd - 1]) {
    beforeEnd--
    afterEnd--
  }

  const keys: string[] = []
  if (beforeEnd === cursor) keys.push(...Array.from({ length: beforeEnd - start }, () => "Backspace"))
  for (const character of after.slice(start, afterEnd)) keys.push(character === "\n" ? "Enter" : character)
  return keys
}

export class VimEngine {
  private buffer = new TextBuffer("")
  private context: VimContext = {
    ...createInitialContext({ line: 0, col: 0 }),
    mode: "insert",
    statusMessage: "-- INSERT --",
  }
  private insertBase: { cursor: number; text: string } | undefined
  private insertNeedsUndo = false
  private operatorCount = 1
  private operatorMotionCount = ""
  private replaceKeys: string[] | undefined
  private lastReplace: string[] | undefined
  private adapterLastChange: string[] | undefined
  private adapterPendingChange: string[] | undefined
  private replaying = false

  get idle(): boolean {
    return !this.replaceKeys && this.context.mode === "normal" && this.context.phase === "idle" && this.context.count === 0
  }

  get mode(): VimMode | "replace" {
    return this.replaceKeys ? "replace" : this.context.mode
  }

  sync(text: string, cursor: number): void {
    if (this.buffer.getContent() !== text) {
      if (this.context.mode === "insert" && this.insertNeedsUndo) {
        this.buffer.saveUndoPoint(this.context.cursor)
        this.insertNeedsUndo = false
      }
      if (this.context.mode === "insert") this.buffer.replaceContent(text)
      else {
        this.buffer.saveUndoPoint(this.context.cursor)
        this.buffer.replaceContent(text)
      }
    }
    this.context = { ...this.context, cursor: positionAt(text, cursor) }
  }

  handle(key: string, ctrl = false): VimUpdate {
    if (this.replaceKeys) return this.handleReplace(key, ctrl)

    const beforeMode = this.context.mode
    const beforeText = this.buffer.getContent()
    const pendingChange = this.context.pendingChange

    if (
      this.context.phase === "operator-pending"
      && (/^[1-9]$/.test(key) || Boolean(this.operatorMotionCount) && key === "0")
    ) {
      this.operatorMotionCount += key
      return this.update([])
    }
    if (this.operatorMotionCount) {
      this.context = {
        ...this.context,
        count: this.operatorCount * Number(this.operatorMotionCount),
      }
      this.operatorMotionCount = ""
    }

    if (this.context.phase === "g-pending" && (key === "e" || key === "E")) {
      return this.backwardEnd(key === "E")
    }
    if (this.context.phase === "g-pending" && !this.context.operator && (key === "t" || key === "T")) {
      this.context = resetContext(this.context)
      return this.update([{ type: "command", command: key === "t" ? "session.tab.next" : "session.tab.previous" }])
    }
    if (key === "E" && (this.context.phase === "idle" || this.context.phase === "operator-pending")) {
      const text = this.buffer.getContent()
      let target = offsetAt(text, this.context.cursor)
      for (let index = 0; index < (this.context.count || 1); index++) target = nextWordEnd(text, target, true)
      return this.motion(positionAt(text, target), true, key)
    }
    if (key === "|" && (this.context.phase === "idle" || this.context.phase === "operator-pending")) {
      const line = this.buffer.getLine(this.context.cursor.line)
      const target = {
        ...this.context.cursor,
        col: Math.min(Math.max(0, line.length - 1), Math.max(0, (this.context.count || 1) - 1)),
      }
      return this.motion(target, false, key)
    }
    if (key === "s" && this.context.mode === "normal" && this.context.phase === "idle") {
      const text = this.buffer.getContent()
      const current = offsetAt(text, this.context.cursor)
      const end = text.indexOf("\n", current)
      const lineEnd = end < 0 ? text.length : end
      if (current === lineEnd) {
        this.context = {
          ...this.context,
          mode: "insert",
          pendingChange: ["s"],
          statusMessage: "-- INSERT --",
        }
        this.insertBase = { text, cursor: current }
        this.insertNeedsUndo = true
        this.adapterPendingChange = ["s"]
        return this.update([])
      }
      const target = positionAt(text, Math.min(lineEnd - 1, current + (this.context.count || 1) - 1))
      return this.operate("c", target, true, key)
    }
    if (key === "R" && this.context.mode === "normal" && this.context.phase === "idle") {
      this.buffer.saveUndoPoint(this.context.cursor)
      this.replaceKeys = []
      return this.update([])
    }
    if (key === "." && this.context.mode === "normal" && this.context.phase === "idle" && this.adapterLastChange) {
      const change = [...this.adapterLastChange]
      let update = this.update([])
      this.replaying = true
      try {
        for (const replayKey of change) update = this.handle(replayKey)
      } finally {
        this.replaying = false
        this.adapterLastChange = change
      }
      return update
    }
    if (key === "." && this.context.mode === "normal" && this.context.phase === "idle" && this.lastReplace) {
      this.buffer.saveUndoPoint(this.context.cursor)
      for (const replacement of this.lastReplace) this.replaceCharacter(replacement)
      this.context = {
        ...resetContext(this.context),
        cursor: positionAt(this.buffer.getContent(), Math.max(0, offsetAt(this.buffer.getContent(), this.context.cursor) - 1)),
      }
      return this.update([])
    }

    const remap = this.context.mode === "normal" && this.context.phase === "idle"
      ? ({ X: ["d", "h"], S: ["c", "c"], Y: ["y", "y"] } as const)[
          key as "X" | "S" | "Y"
        ]
      : undefined
    const keys = remap ?? [key]
    let actions: VimAction[] = []
    for (const mapped of keys) {
      const previous = this.context
      const result = processKeystroke(mapped, this.context, this.buffer, ctrl && mapped === key, false)
      this.context = result.newCtx
      actions.push(...result.actions)
      if (previous.phase === "idle" && result.newCtx.phase === "operator-pending") {
        this.operatorCount = previous.count || 1
      }
    }
    if (actions.some((action) => action.type === "content-change") && key !== "." && !this.replaying) {
      this.lastReplace = undefined
      this.adapterLastChange = undefined
    }

    const enteredInsert = beforeMode !== "insert" && this.context.mode === "insert"
    if (enteredInsert) {
      const changedOnEntry = actions.some((action) => action.type === "content-change")
      this.insertBase = { text: this.buffer.getContent(), cursor: offsetAt(this.buffer.getContent(), this.context.cursor) }
      this.insertNeedsUndo = !changedOnEntry
      if (!this.adapterPendingChange) this.adapterLastChange = undefined
    }

    if (beforeMode === "insert" && key === "Escape" && this.insertBase) {
      const typed = insertedKeys(this.insertBase.text, beforeText, this.insertBase.cursor)
      if (typed.length) {
        this.context = {
          ...this.context,
          lastChange: [...pendingChange, ...typed, "Escape"],
        }
      }
      if (this.adapterPendingChange && !this.replaying) {
        this.adapterLastChange = [...this.adapterPendingChange, ...typed, "Escape"]
      }
      this.adapterPendingChange = undefined
      this.insertBase = undefined
      this.insertNeedsUndo = false
    }

    if (this.context.phase === "idle") {
      this.operatorCount = 1
      this.operatorMotionCount = ""
    }
    return this.update(actions)
  }

  private backwardEnd(WORD: boolean): VimUpdate {
    const text = this.buffer.getContent()
    let targetOffset = offsetAt(text, this.context.cursor)
    for (let index = 0; index < (this.context.count || 1); index++) {
      targetOffset = previousWordEnd(text, targetOffset, WORD)
    }
    return this.motion(positionAt(text, targetOffset), true, WORD ? "E" : "e")
  }

  private handleReplace(key: string, ctrl: boolean): VimUpdate {
    const replaceKeys = this.replaceKeys
    if (!replaceKeys) return this.update([])
    if (key === "Escape") {
      if (replaceKeys.length) {
        this.lastReplace = [...replaceKeys]
        this.adapterLastChange = undefined
      }
      this.replaceKeys = undefined
      const text = this.buffer.getContent()
      const current = offsetAt(text, this.context.cursor)
      const start = text.lastIndexOf("\n", Math.max(0, current - 1)) + 1
      this.context = {
        ...resetContext(this.context),
        cursor: positionAt(text, Math.max(start, current - 1)),
        mode: "normal",
      }
      return this.update([])
    }
    if (key === "Backspace") {
      const text = this.buffer.getContent()
      const current = offsetAt(text, this.context.cursor)
      const start = text.lastIndexOf("\n", Math.max(0, current - 1)) + 1
      this.context = { ...this.context, cursor: positionAt(text, Math.max(start, current - 1)) }
      replaceKeys.pop()
      return this.update([])
    }
    if (ctrl || key.length !== 1 && key !== "Enter") return this.update([])
    const replacement = key === "Enter" ? "\n" : key
    replaceKeys.push(replacement)
    this.replaceCharacter(replacement)
    return this.update([])
  }

  private replaceCharacter(replacement: string): void {
    const text = this.buffer.getContent()
    const current = offsetAt(text, this.context.cursor)
    const atLineEnd = current >= text.length || text[current] === "\n"
    const next = text.slice(0, current) + replacement + text.slice(current + (atLineEnd ? 0 : 1))
    this.buffer.replaceContent(next)
    this.context = { ...this.context, cursor: positionAt(next, current + replacement.length) }
  }

  private motion(target: CursorPosition, inclusive: boolean, key: string): VimUpdate {
    const operator = this.context.operator
    if (!operator) {
      this.context = { ...resetContext(this.context), cursor: target }
      return this.update([])
    }

    return this.operate(operator, target, inclusive, key)
  }

  private operate(operator: "c" | "d" | "y" | ">" | "<", target: CursorPosition, inclusive: boolean, key: string): VimUpdate {
    const count = this.context.count || 1
    const sequence = [
      ...(count > 1 ? [...String(count)] : []),
      ...this.context.pendingChange.filter((item) => !/^[0-9]$/.test(item)),
      key,
    ]
    this.buffer.saveUndoPoint(this.context.cursor)
    const result = executeOperatorOnRange(
      operator,
      { start: this.context.cursor, end: target, linewise: false, inclusive },
      this.buffer,
      this.context.cursor,
    )
    const enteredInsert = result.newMode === "insert"
    this.context = {
      ...resetContext(this.context),
      cursor: result.newCursor,
      lastChange: [...this.context.pendingChange, key],
      mode: result.newMode,
      pendingChange: [],
      register: result.yankedText,
      statusMessage: enteredInsert ? "-- INSERT --" : result.statusMessage,
    }
    if (enteredInsert) {
      this.insertBase = {
        text: this.buffer.getContent(),
        cursor: offsetAt(this.buffer.getContent(), result.newCursor),
      }
      this.insertNeedsUndo = false
    }
    if (!this.replaying) {
      if (operator === "c") this.adapterPendingChange = sequence
      else if (operator === "d") this.adapterLastChange = sequence
    }
    return this.update(result.actions)
  }

  enterInsert(): VimUpdate {
    this.replaceKeys = undefined
    this.adapterPendingChange = undefined
    this.context = {
      ...resetContext(this.context),
      mode: "insert",
      statusMessage: "-- INSERT --",
      visualAnchor: null,
    }
    return this.update([])
  }

  private update(actions: EngineAction[]): VimUpdate {
    const text = this.buffer.getContent()
    const selection = this.selection(text)
    return {
      actions: actions.filter(
        (action): action is VimHostAction =>
          action.type === "scroll" || action.type === "quit" || action.type === "save" || action.type === "command",
      ),
      cursor: offsetAt(text, this.context.cursor),
      mode: this.replaceKeys ? "replace" : this.context.mode,
      ...(selection ? { selection } : {}),
      status: this.replaceKeys ? "REPLACE" : this.context.statusMessage,
      text,
    }
  }

  private selection(text: string): { start: number; end: number } | undefined {
    const anchor = this.context.visualAnchor
    if (!anchor || !this.context.mode.startsWith("visual")) return
    let start = Math.min(offsetAt(text, anchor), offsetAt(text, this.context.cursor))
    let end = Math.max(offsetAt(text, anchor), offsetAt(text, this.context.cursor)) + 1
    if (this.context.mode === "visual-line") {
      start = text.lastIndexOf("\n", Math.max(0, start - 1)) + 1
      const newline = text.indexOf("\n", end)
      end = newline < 0 ? text.length : newline + 1
    }
    return { start, end: Math.min(text.length, end) }
  }
}
