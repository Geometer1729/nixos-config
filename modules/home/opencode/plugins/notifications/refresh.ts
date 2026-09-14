import { setTimeout as sleep } from "node:timers/promises"

// Events are invalidations only. Serialize full refreshes and remember an event
// arriving during a read so its newer state cannot be lost behind that read.
export function refreshQueue(
  refresh: () => Promise<void>,
  signal: AbortSignal,
  onError: (error: unknown) => void,
  debounceMs = 150,
) {
  let dirty = false
  let running = false
  let task = Promise.resolve()

  const request = () => {
    if (signal.aborted) return
    dirty = true
    if (running) return
    running = true
    task = (async () => {
      try {
        while (dirty && !signal.aborted) {
          await sleep(debounceMs, undefined, { signal })
          dirty = false
          try {
            await refresh()
          } catch (error) {
            if (signal.aborted) return
            onError(error)
            dirty = true
            await sleep(1000, undefined, { signal })
          }
        }
      } catch (error) {
        if (!signal.aborted) onError(error)
      } finally {
        running = false
      }
    })()
  }

  return { request, settled: () => task }
}
