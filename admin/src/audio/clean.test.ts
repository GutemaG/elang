import { describe, expect, it } from 'vitest'

import { RATE, prepared, room } from '../test/clips'
import { LEAD_SECONDS, MIN_SECONDS, TAIL_SECONDS, cleanUp, durationOf, findSpeech, peaksOf, toInt16, widen } from './clean'
import { encodeMp3, finalClip, mp3SizeOf, prepareClip } from './codec'

const close = (seconds: number) => expect.closeTo(seconds, 2)

describe('finding the speech', () => {
  it('keeps the speech with a little either side', () => {
    expect(findSpeech(room(2, [0.5, 1, 0.3]))).toEqual({ start: close(0.5 - LEAD_SECONDS), end: close(1 + TAIL_SECONDS) })
  })

  it('finds quiet speech too, judged against the room', () => {
    expect(findSpeech(room(2, [0.6, 1.2, 0.02]))).toEqual({ start: close(0.6 - LEAD_SECONDS), end: close(1.2 + TAIL_SECONDS) })
  })

  it('ignores a click far from the speech, such as the key that stopped it', () => {
    expect(findSpeech(room(2, [0.5, 1, 0.3], [1.8, 1.81, 0.9]))).toEqual({ start: close(0.42), end: close(1.15) })
  })

  it('keeps the short burst of an ejective just before its vowel', () => {
    // ቀ: a 20 ms burst, a short closure, then the vowel.
    expect(findSpeech(room(2, [0.4, 0.42, 0.5], [0.52, 1, 0.3])).start).toBeCloseTo(0.4 - LEAD_SECONDS, 2)
  })

  it('keeps a clip with nothing to find whole', () => {
    expect(findSpeech(room(1.5))).toEqual({ start: 0, end: 1.5 })
    expect(findSpeech({ samples: new Float32Array(0), rate: RATE })).toEqual({ start: 0, end: 0 })
  })

  it('stays inside the clip at its edges', () => {
    expect(findSpeech(room(1, [0, 1, 0.3]))).toEqual({ start: 0, end: 1 })
  })

  it('never cuts to less than a tap', () => {
    expect(widen({ start: 0.5, end: 0.5 }, 2)).toEqual({ start: close(0.5 - MIN_SECONDS / 2), end: close(0.5 + MIN_SECONDS / 2) })
    expect(widen({ start: 0.95, end: 3 }, 1)).toEqual({ start: close(1 - MIN_SECONDS), end: 1 })
    expect(widen({ start: -1, end: 0.05 }, 1)).toEqual({ start: 0, end: close(MIN_SECONDS) })
  })
})

describe('cleaning a clip', () => {
  const rms = (xs: Float32Array) => Math.sqrt(xs.reduce((s, x) => s + x * x, 0) / xs.length)
  const peak = (xs: Float32Array) => xs.reduce((m, x) => Math.max(m, Math.abs(x)), 0)

  it('cuts the span, and fades in and out so it never clicks', () => {
    const out = cleanUp(room(2, [0, 2, 0.3]), { start: 0.5, end: 1.25 })
    expect(durationOf(out)).toBeCloseTo(0.75, 3)
    expect(Math.abs(out.samples[0]!)).toBe(0)
    expect(Math.abs(out.samples[out.samples.length - 1]!)).toBe(0)
  })

  it('brings loud and quiet takes to the same level', () => {
    const loud = cleanUp(room(1, [0, 1, 0.6]), { start: 0, end: 1 })
    const quiet = cleanUp(room(1, [0, 1, 0.03]), { start: 0, end: 1 })
    expect(rms(loud.samples)).toBeCloseTo(rms(quiet.samples), 2)
    expect(rms(loud.samples)).toBeCloseTo(0.126, 1)
  })

  it('keeps the peaks under −1 dBFS', () => {
    // Speech with one very loud moment: the peak, not the level, sets the gain.
    const out = cleanUp(room(1, [0, 1, 0.01], [0.5, 0.51, 1]), { start: 0, end: 1 })
    expect(peak(out.samples)).toBeLessThanOrEqual(0.89 + 1e-6)
  })

  it('leaves the samples it was given alone', () => {
    const pcm = room(1, [0, 1, 0.3])
    const before = pcm.samples.slice()
    cleanUp(pcm, { start: 0.2, end: 0.8 })
    expect(pcm.samples).toEqual(before)
  })

  it('draws the loudest point of each slice', () => {
    const peaks = peaksOf(room(1, [0.5, 1, 0.5]), 4)
    expect(peaks).toHaveLength(4)
    expect(peaks[0]).toBeLessThan(0.01)
    expect(peaks[3]).toBeCloseTo(0.5, 2)
    expect(peaksOf({ samples: new Float32Array(0), rate: RATE }, 4)).toEqual([])
  })

  it('turns samples into 16-bit, clipping what is over', () => {
    expect([...toInt16(new Float32Array([0, 1, -1, 2, -0.5]))]).toEqual([0, 32767, -32768, 32767, -16384])
  })
})

describe('storing a clip', () => {
  it('writes a small mp3', async () => {
    const mp3 = await encodeMp3(cleanUp(room(1, [0, 1, 0.3]), { start: 0, end: 1 }))
    expect(mp3.type).toBe('audio/mpeg')
    // 64 kbps for a second: about 8 KB.
    expect(mp3.size).toBeGreaterThan(6000)
    expect(mp3.size).toBeLessThan(10000)
    // The size shown before it is made is close to what it comes to.
    expect(Math.abs(mp3.size - mp3SizeOf(1))).toBeLessThan(600)
    // jsdom's Blob has no arrayBuffer(); a FileReader reads it.
    const bytes = await new Promise<Uint8Array>((resolve) => {
      const reader = new FileReader()
      reader.onload = () => resolve(new Uint8Array(reader.result as ArrayBuffer))
      reader.readAsArrayBuffer(mp3)
    })
    // An MPEG audio frame starts with eleven set bits.
    expect(bytes[0]).toBe(0xff)
    expect(bytes[1]! & 0xe0).toBe(0xe0)
  })

  it('sends the cleaned mp3, or the clip as it came when asked or when it could not be read', async () => {
    const original = { clip: new Blob(['take'], { type: 'audio/mp4' }), type: 'audio/mp4' }
    const prep = prepared()

    const cleaned = await finalClip(original, prep, { use: 'cleaned', span: null, effects: [] })
    expect(cleaned.type).toBe('audio/mpeg')
    expect(cleaned.clip.size).toBeLessThan(8000)

    expect(await finalClip(original, prep, { use: 'original', span: null, effects: [] })).toBe(original)
    expect(await finalClip(original, null, { use: 'cleaned', span: null, effects: [] })).toBe(original)
  })

  it('reads nothing in a browser without an audio engine', async () => {
    expect(await prepareClip(new Blob(['x']))).toBeNull()
  })
})
