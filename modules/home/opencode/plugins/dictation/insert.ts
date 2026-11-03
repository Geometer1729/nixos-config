import { join } from "node:path"

// The Hex dictate script computes the same path from the tmux pane it targets.
export function socketPath(runtimeDir: string, pane: string): string {
  return join(runtimeDir, `opencode-dictation-${pane.replace(/^%/, "")}.sock`)
}

// A Vim NORMAL-mode block cursor sits on a character; insert after it, as `a` would.
export function insertionPoint(text: string, cursor: number, normal: boolean): number {
  return normal && cursor < text.length && text[cursor] !== "\n" ? cursor + 1 : cursor
}

// Consecutive dictations would otherwise run together into one word.
export function insertion(before: string, text: string): string {
  return before !== "" && !/\s$/.test(before) && !/^\s/.test(text) ? ` ${text}` : text
}
