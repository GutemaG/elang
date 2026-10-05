import { describe, expect, it } from 'vitest'

import { RATE, room } from '../test/clips'
import type { Pcm } from './clean'
import { applyEffects, fft, ordered, reduceNoise } from './effects'

/** One second of a sine at `hz`. */
const tone = (hz: number, level = 0.3): Pcm => ({
  samples: Float32Array.from({ length: RATE }, (_, i) => level * Math.sin((2 * Math.PI * hz * i) / RATE)),
  rate: RATE,
})

/** The level of the middle of a clip (past any filter's start-up), in dB. */
function levelDb(pcm: Pcm, from = 0.25, to = 0.75): number {
  const xs = pcm.samples.subarray(Math.round(from * pcm.rate), Math.round(to * pcm.rate))
  const rms = Math.sqrt(xs.reduce((s, x) => s + x * x, 0) / xs.length)
  return 20 * Math.log10(rms)
}

const change = (hz: number, ...effects: Parameters<typeof applyEffects>[1]) =>
  levelDb(applyEffects(tone(hz), effects)) - levelDb(tone(hz))

describe('the effects', () => {
  it('remove rumble cuts the lows and leaves the voice', () => {
    expect(change(30, 'rumble')).toBeLessThan(-15)
    expect(Math.abs(change(300, 'rumble'))).toBeLessThan(0.5)
    expect(Math.abs(change(2000, 'rumble'))).toBeLessThan(0.1)
  })

  it('warmer adds body to the low voice and softens the highs', () => {
    expect(change(100, 'warmer')).toBeGreaterThan(3)
    expect(change(10000, 'warmer')).toBeLessThan(-2)
    expect(Math.abs(change(1500, 'warmer'))).toBeLessThan(1.5)
  })

  it('clearer lifts where consonants are heard', () => {
    expect(change(3000, 'clearer')).toBeGreaterThan(3)
    expect(change(100, 'clearer')).toBeLessThan(-1)
    expect(Math.abs(change(700, 'clearer'))).toBeLessThan(1.5)
  })

  it('apply in one order however they were picked', () => {
    expect(ordered(['clearer', 'denoise', 'warmer'])).toEqual(['denoise', 'warmer', 'clearer'])
    const a = applyEffects(tone(500), ['clearer', 'warmer'])
    const b = applyEffects(tone(500), ['warmer', 'clearer'])
    expect(a.samples).toEqual(b.samples)
  })

  it('change nothing when none are picked', () => {
    const pcm = tone(440)
    expect(applyEffects(pcm, [])).toBe(pcm)
  })
})

describe('reducing noise', () => {
  /** Hiss all through, and a vowel-like tone in the middle. */
  function noisy(): Pcm {
    const pcm = room(2, [0.7, 1.3, 0.3])
    let seed = 3
    for (let i = 0; i < pcm.samples.length; i++) {
      seed = (seed * 16807) % 2147483647
      pcm.samples[i]! += ((seed / 2147483647) * 2 - 1) * 0.03
    }
    return pcm
  }

  it('takes the hiss out of the quiet and keeps the sound', () => {
    const before = noisy()
    const after = reduceNoise(before)
    expect(after.samples.length).toBe(before.samples.length)
    // The quiet before the sound: much less hiss.
    expect(levelDb(after, 0.1, 0.6) - levelDb(before, 0.1, 0.6)).toBeLessThan(-12)
    // The sound itself: about as loud as it was.
    expect(Math.abs(levelDb(after, 0.8, 1.2) - levelDb(before, 0.8, 1.2))).toBeLessThan(1.5)
  })

  it('leaves a clip with no quiet moment alone, rather than eat the speech', () => {
    const pcm = tone(300)
    expect(reduceNoise(pcm)).toBe(pcm)
  })

  it('leaves a clip too short to measure alone', () => {
    const pcm = { samples: new Float32Array(100), rate: RATE }
    expect(reduceNoise(pcm)).toBe(pcm)
  })

  it('rests on an FFT that goes there and back', () => {
    const re = Float64Array.from({ length: 8 }, (_, i) => Math.sin(i))
    const im = new Float64Array(8)
    const copy = re.slice()
    fft(re, im)
    // A sine's energy is in its own frequencies, not the constant term.
    expect(Math.abs(re[0]!)).toBeLessThan(Math.abs(copy.reduce((s, x) => s + x, 0)) + 1e-9)
    fft(re, im, true)
    re.forEach((x, i) => expect(x).toBeCloseTo(copy[i]!, 9))
    im.forEach((x) => expect(x).toBeCloseTo(0, 9))
  })
})
