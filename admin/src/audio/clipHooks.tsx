import { useState, type ReactNode } from 'react'

import { messageOf } from '../auth/SessionContext'
import { plainMessage } from '../exercises/model'
import type { Span } from './clean'
import { ClipEditor, usePrepared, type ClipUse } from './ClipEditor'
import { finalClip, type Prepared } from './codec'
import type { Effect } from './effects'
import { MAX_AUDIO_BYTES, formatSize } from './formats'

/** Stores one clip and returns the address to keep. `source` tags a
 * generated take (`gen-om-obse`) so its stored name says who spoke it. */
export type ClipUploader = (clip: Blob, type: string, source?: string) => Promise<string>

// Shared by every way of getting a clip: Record, Upload and Generate
// (intent 027) clean and store a clip the same way.

/** What the clip editor chose: cleaned (with its cut) or as recorded. */
export interface Cleaning {
  prepared: Prepared | null
  use: ClipUse
  span: Span | null
  effects: readonly Effect[]
}

/** The clip editor's choices for one clip. The cut is cleared for the next
 * clip; cleaned or not, and the effects, carry over to it. */
export function useCleaning(clip: Blob | null, originalLabel?: string) {
  const state = usePrepared(clip)
  const [use, setUse] = useState<ClipUse>('cleaned')
  const [span, setSpan] = useState<Span | null>(null)
  const [effects, setEffects] = useState<Effect[]>([])
  const cleaning: Cleaning = { prepared: state.kind === 'ready' ? state.prepared : null, use, span, effects }
  return {
    cleaning,
    /** Still reading the clip, so the cleaned version is not ready to send. */
    working: state.kind === 'working' && use === 'cleaned',
    reset: () => setSpan(null),
    editor: (original: ReactNode) => (
      <ClipEditor
        state={state}
        use={use}
        onUse={setUse}
        span={span}
        onSpan={setSpan}
        effects={effects}
        onEffects={setEffects}
        original={original}
        originalLabel={originalLabel}
        originalSize={clip?.size ?? 0}
      />
    ),
  }
}

/** Sends one clip to the store. `send` answers false when it failed, and
 * `problem` then says why. */
export function useClipUpload(store: ClipUploader, onUploaded: (url: string) => void) {
  const [busy, setBusy] = useState(false)
  const [problem, setProblem] = useState<string | null>(null)

  async function send(clip: Blob, type: string, cleaning?: Cleaning, source?: string): Promise<boolean> {
    setBusy(true)
    setProblem(null)
    try {
      const final = cleaning ? await finalClip({ clip, type }, cleaning.prepared, cleaning) : { clip, type }
      if (final.clip.size > MAX_AUDIO_BYTES) {
        setProblem(`The clip is ${formatSize(final.clip.size)}; clips can be 5 MB at most. Use the cleaned version, or a shorter one.`)
        return false
      }
      onUploaded(await store(final.clip, final.type, source))
      return true
    } catch (e) {
      setProblem(plainMessage(messageOf(e)))
      return false
    } finally {
      setBusy(false)
    }
  }

  return { busy, problem, setProblem, send }
}
