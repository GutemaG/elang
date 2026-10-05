// The browser's side of cleaning a clip: reading any recording or file into
// samples, playing samples, and writing the cleaned clip as an mp3. Kept
// apart from clean.ts so tests can swap it out (jsdom has no audio engine).

import { cleanUp, findSpeech, toInt16, type Pcm, type Span } from './clean'
import { applyEffects, type Effect } from './effects'

/** Cleaned clips are stored at this rate: plenty for a voice, and half the
 * size of 48 kHz. */
export const CLEAN_RATE = 24000
/** Mono at 64 kbps: about 8 KB for a one-second letter. */
const MP3_KBPS = 64
/** A fixed bitrate, so a cleaned clip's size is known from its length
 * alone: the effects never change it, only the cut does. */
export const MP3_BYTES_PER_SECOND = (MP3_KBPS * 1000) / 8

/** About how big the cleaned mp3 of `seconds` will be: the frames, plus
 * one the encoder adds at the end. */
export const mp3SizeOf = (seconds: number): number => Math.round(seconds * MP3_BYTES_PER_SECOND) + 192

/** lame takes samples in blocks of this many. */
const MP3_BLOCK = 1152

/** A clip read into samples, and where its speech was found. */
export interface Prepared {
  pcm: Pcm
  auto: Span
}

/** Reads a recording or file, mixed to mono at CLEAN_RATE, and finds its
 * speech; null when this browser cannot read it (or has no audio engine). */
export async function prepareClip(clip: Blob): Promise<Prepared | null> {
  if (typeof OfflineAudioContext === 'undefined') return null
  try {
    // decodeAudioData resamples to the context's rate.
    const context = new OfflineAudioContext(1, 1, CLEAN_RATE)
    const buffer = await context.decodeAudioData(await clip.arrayBuffer())
    const samples = new Float32Array(buffer.length)
    for (let c = 0; c < buffer.numberOfChannels; c++) {
      const channel = buffer.getChannelData(c)
      for (let i = 0; i < samples.length; i++) samples[i]! += channel[i]! / buffer.numberOfChannels
    }
    const pcm = { samples, rate: buffer.sampleRate }
    return { pcm, auto: findSpeech(pcm) }
  } catch {
    return null
  }
}

/** The cleaned span as an mp3. The encoder loads the first time it is
 * needed, so it is not part of every page. */
export async function encodeMp3(pcm: Pcm): Promise<Blob> {
  const { Mp3Encoder } = await import('@breezystack/lamejs')
  const encoder = new Mp3Encoder(1, pcm.rate, MP3_KBPS)
  const samples = toInt16(pcm.samples)
  const parts: Uint8Array[] = []
  for (let at = 0; at < samples.length; at += MP3_BLOCK) {
    const part = encoder.encodeBuffer(samples.subarray(at, at + MP3_BLOCK))
    if (part.length) parts.push(part)
  }
  const last = encoder.flush()
  if (last.length) parts.push(last)
  return new Blob(parts as BlobPart[], { type: 'audio/mpeg' })
}

let playing: { context: AudioContext; done: () => void } | null = null

/** Plays samples, stopping whatever this played before. `onEnd` runs when
 * it finishes or is stopped; the returned function stops it. */
export function playPcm(pcm: Pcm, onEnd: () => void): () => void {
  stopPcm()
  const context = new AudioContext()
  const buffer = context.createBuffer(1, Math.max(1, pcm.samples.length), pcm.rate)
  buffer.copyToChannel(pcm.samples as Float32Array<ArrayBuffer>, 0)
  const source = context.createBufferSource()
  source.buffer = buffer
  source.connect(context.destination)
  const mine = {
    context,
    done: () => {
      if (playing !== mine) return
      playing = null
      void context.close()
      onEnd()
    },
  }
  source.onended = mine.done
  playing = mine
  source.start()
  return () => {
    if (playing === mine) {
      source.onended = null
      source.stop()
      mine.done()
    }
  }
}

export function stopPcm() {
  playing?.done()
}

/** How a clip is to be stored: cleaned (with its cut and effects), or as it
 * came. */
export interface CleanChoice {
  use: 'cleaned' | 'original'
  /** Where the admin moved the cut to, or null for where it was found. */
  span: Span | null
  effects: readonly Effect[]
}

/** The cleaned version: the effects over the whole clip (so noise is learnt
 * from all its quiet), then the cut, the level and the fades. */
export function cleanedPcm(prepared: Prepared, choice: Pick<CleanChoice, 'span' | 'effects'>): Pcm {
  return cleanUp(applyEffects(prepared.pcm, choice.effects), choice.span ?? prepared.auto)
}

/** What to store for a clip: the cleaned version as an mp3, or the clip as
 * it came when the admin chose that or it could not be read. */
export async function finalClip(
  original: { clip: Blob; type: string },
  prepared: Prepared | null,
  choice: CleanChoice,
): Promise<{ clip: Blob; type: string }> {
  if (choice.use === 'original' || !prepared) return original
  return { clip: await encodeMp3(cleanedPcm(prepared, choice)), type: 'audio/mpeg' }
}
