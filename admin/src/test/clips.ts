// Made-up recordings for the clip-cleaning tests: a quiet room, with a
// tone where the speech would be.

import { findSpeech, type Pcm } from '../audio/clean'
import type { Prepared } from '../audio/codec'

export const RATE = 24000

/** `seconds` of faint room noise, with tones at `parts` ([from, to, level]
 * in seconds and 0..1). */
export function room(seconds: number, ...parts: [number, number, number][]): Pcm {
  const samples = new Float32Array(Math.round(seconds * RATE))
  let seed = 7
  for (let i = 0; i < samples.length; i++) {
    seed = (seed * 16807) % 2147483647
    samples[i] = ((seed / 2147483647) * 2 - 1) * 0.002
  }
  for (const [from, to, level] of parts) {
    for (let i = Math.round(from * RATE); i < Math.round(to * RATE); i++) {
      samples[i] = level * Math.sin((2 * Math.PI * 220 * i) / RATE)
    }
  }
  return { samples, rate: RATE }
}

/** Two seconds with speech from 0.5 s to 1.0 s, as prepareClip reads it. */
export function prepared(): Prepared {
  const pcm = room(2, [0.5, 1, 0.3])
  return { pcm, auto: findSpeech(pcm) }
}
