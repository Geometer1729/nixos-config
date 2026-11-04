import { spawn } from "node:child_process"
import { randomUUID } from "node:crypto"
import { rm } from "node:fs/promises"
import { join } from "node:path"

import type { Clip } from "./speaker.ts"

export interface Commands {
  // Synthesizes stdin into the WAV file given as its argument.
  synthesize: string
  // Plays the WAV file given as its argument.
  play: string
}

interface Process {
  // Whether it exited successfully.
  readonly done: Promise<boolean>
  stop(): void
}

// Each runs in its own process group, which is stopped as a whole.
function run(command: string, args: string[], input?: string): Process {
  const child = spawn(command, args, {
    detached: true,
    stdio: [input === undefined ? "ignore" : "pipe", "ignore", "ignore"],
  })
  const done = new Promise<boolean>((resolve) => {
    child.once("exit", (code) => resolve(code === 0))
    child.once("error", (error) => {
      console.error("OpenCode speech:", error)
      resolve(false)
    })
  })
  if (child.stdin) {
    child.stdin.once("error", () => {})
    child.stdin.end(input)
  }
  return {
    done,
    stop: () => {
      if (child.pid === undefined || child.exitCode !== null || child.signalCode !== null) return
      try {
        process.kill(-child.pid, "SIGTERM")
      } catch {}
    },
  }
}

// Synthesis starts when the message arrives, so it can play the moment it is viewed.
export function prepare(commands: Commands, directory: string, text: string): Clip {
  const wav = join(directory, `${randomUUID()}.wav`)
  const synthesis = run(commands.synthesize, [wav], text)
  return {
    play: () => {
      let player: Process | undefined
      let stopped = false
      const done = synthesis.done.then(async (synthesized) => {
        if (!synthesized || stopped) return
        player = run(commands.play, [wav])
        await player.done
      })
      return {
        done,
        stop: () => {
          stopped = true
          player?.stop()
        },
      }
    },
    discard: () => {
      synthesis.stop()
      void synthesis.done.then(() => rm(wav, { force: true })).catch(() => {})
    },
  }
}
