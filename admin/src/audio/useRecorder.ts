import { useCallback, useEffect, useRef, useState } from 'react'

import { MAX_RECORDING_SECONDS, recordingType } from './formats'

export type MicProblem = 'denied' | 'no-mic' | 'failed'

export type RecorderState =
  | { kind: 'idle' }
  | { kind: 'asking' }
  | { kind: 'recording'; startedAt: number }
  | { kind: 'recorded'; clip: Blob; url: string; seconds: number }
  | { kind: 'blocked'; problem: MicProblem }

function problemOf(e: unknown): MicProblem {
  const name = e instanceof DOMException || e instanceof Error ? e.name : ''
  if (name === 'NotAllowedError' || name === 'SecurityError') return 'denied'
  if (name === 'NotFoundError' || name === 'OverconstrainedError') return 'no-mic'
  return 'failed'
}

/** One take at a time from the microphone, kept in the browser until the
 * admin uses it: start, stop, then play back, discard or record again.
 * The microphone is released as soon as a take stops, and everything is
 * released when the component using this goes away. */
export function useRecorder() {
  const [state, setState] = useState<RecorderState>({ kind: 'idle' })
  const [seconds, setSeconds] = useState(0)
  const recorder = useRef<MediaRecorder | null>(null)
  const stream = useRef<MediaStream | null>(null)
  const takeUrl = useRef<string | null>(null)

  const releaseTake = () => {
    if (takeUrl.current) URL.revokeObjectURL(takeUrl.current)
    takeUrl.current = null
  }

  const stop = useCallback(() => {
    if (recorder.current?.state === 'recording') recorder.current.stop()
  }, [])

  async function start() {
    releaseTake()
    setSeconds(0)
    setState({ kind: 'asking' })
    let media: MediaStream
    try {
      media = await navigator.mediaDevices.getUserMedia({ audio: true })
    } catch (e) {
      setState({ kind: 'blocked', problem: problemOf(e) })
      return
    }

    let rec: MediaRecorder
    try {
      const type = recordingType()
      rec = new MediaRecorder(media, type ? { mimeType: type } : undefined)
    } catch {
      media.getTracks().forEach((t) => t.stop())
      setState({ kind: 'blocked', problem: 'failed' })
      return
    }
    const chunks: Blob[] = []
    const startedAt = Date.now()
    rec.ondataavailable = (e: BlobEvent) => {
      if (e.data.size > 0) chunks.push(e.data)
    }
    rec.onstop = () => {
      media.getTracks().forEach((t) => t.stop())
      stream.current = null
      recorder.current = null
      const clip = new Blob(chunks, { type: rec.mimeType || chunks[0]?.type || '' })
      const url = URL.createObjectURL(clip)
      takeUrl.current = url
      setState({ kind: 'recorded', clip, url, seconds: (Date.now() - startedAt) / 1000 })
    }
    stream.current = media
    recorder.current = rec
    rec.start()
    setState({ kind: 'recording', startedAt })
  }

  function discard() {
    releaseTake()
    setSeconds(0)
    setState({ kind: 'idle' })
  }

  // The running clock, and the automatic stop at the limit.
  const startedAt = state.kind === 'recording' ? state.startedAt : null
  useEffect(() => {
    if (startedAt === null) return
    const tick = window.setInterval(() => {
      const elapsed = (Date.now() - startedAt) / 1000
      setSeconds(Math.min(elapsed, MAX_RECORDING_SECONDS))
      if (elapsed >= MAX_RECORDING_SECONDS) stop()
    }, 250)
    return () => window.clearInterval(tick)
  }, [startedAt, stop])

  // Leaving the page mid-take must not leave the microphone on.
  useEffect(
    () => () => {
      const rec = recorder.current
      if (rec) {
        rec.onstop = null
        if (rec.state === 'recording') rec.stop()
      }
      stream.current?.getTracks().forEach((t) => t.stop())
      releaseTake()
    },
    [],
  )

  return { state, seconds, start, stop, discard }
}
