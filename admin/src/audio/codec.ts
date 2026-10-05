// The browser's side of cleaning a clip: reading any recording or file into
// samples, playing samples, and writing the cleaned clip as an mp3. Kept
// apart from clean.ts so tests can swap it out (jsdom has no audio engine).

import { cleanUp, findSpeech, toInt16, type Pcm, type Span } from './clean'

/** Cleaned clips are stored at this rate: plenty for a voice, and half the
 * size of 48 kHz. */
export const CLEAN_RATE = 24000
/** Mono at 64 kbps: about 8 KB for a one-second letter. */
const MP3_KBPS = 64
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

/** What to store for a clip: the cleaned span as an mp3, or the clip as it
 * came when the admin chose that or it could not be read. */
export async function finalClip(
  original: { clip: Blob; type: string },
  prepared: Prepared | null,
  choice: { use: 'cleaned' | 'original'; span: Span | null },
): Promise<{ clip: Blob; type: string }> {
  if (choice.use === 'original' || !prepared) return original
  return { clip: await encodeMp3(cleanUp(prepared.pcm, choice.span ?? prepared.auto)), type: 'audio/mpeg' }
}
