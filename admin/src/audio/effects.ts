// Ways to improve how a recording sounds, chosen by the admin before it is
// stored: background noise taken out, low rumble cut, and the voice made
// warmer or clearer. Pure, on plain samples (see clean.ts), so each is
// tested on made-up tones. None changes the voice's pitch or its vowels.

import type { Pcm } from './clean'

export type Effect = 'denoise' | 'rumble' | 'warmer' | 'clearer'

/** In the order they are shown and applied. */
export const EFFECTS: { id: Effect; label: string; hint: string }[] = [
  {
    id: 'denoise',
    label: 'Reduce noise',
    hint: 'Takes out steady background noise (a fan, hiss, a hum), learnt from the quiet around the sound.',
  },
  { id: 'rumble', label: 'Remove rumble', hint: 'Cuts the low thud of traffic, a desk or the microphone being handled.' },
  { id: 'warmer', label: 'Warmer', hint: 'A fuller, deeper tone: more body in the low voice and softer highs.' },
  { id: 'clearer', label: 'Clearer', hint: 'Lifts the range consonants are heard in, so ch, x and dh stand out.' },
]

/** The effects picked, in their own order, so the result never depends on
 * the order they were clicked in. */
export const ordered = (effects: readonly Effect[]): Effect[] => EFFECTS.map((e) => e.id).filter((id) => effects.includes(id))

export function applyEffects(pcm: Pcm, effects: readonly Effect[]): Pcm {
  let out = pcm
  for (const effect of ordered(effects)) out = APPLY[effect](out)
  return out
}

const APPLY: Record<Effect, (pcm: Pcm) => Pcm> = {
  denoise: reduceNoise,
  // Two passes: a steep cut below 80 Hz, where no voice is.
  rumble: (pcm) => filter(filter(pcm, highPass(80, pcm.rate)), highPass(80, pcm.rate)),
  warmer: (pcm) => filter(filter(pcm, lowShelf(250, 4, pcm.rate)), highShelf(6000, -3, pcm.rate)),
  clearer: (pcm) => filter(filter(pcm, peaking(3000, 4, 1, pcm.rate)), lowShelf(200, -2, pcm.rate)),
}

// --- filters (the Audio EQ Cookbook's biquads) -------------------------------------

interface Biquad {
  b0: number
  b1: number
  b2: number
  a1: number
  a2: number
}

function normalised(b0: number, b1: number, b2: number, a0: number, a1: number, a2: number): Biquad {
  return { b0: b0 / a0, b1: b1 / a0, b2: b2 / a0, a1: a1 / a0, a2: a2 / a0 }
}

export function highPass(hz: number, rate: number, q = Math.SQRT1_2): Biquad {
  const w = (2 * Math.PI * hz) / rate
  const cos = Math.cos(w)
  const alpha = Math.sin(w) / (2 * q)
  return normalised((1 + cos) / 2, -(1 + cos), (1 + cos) / 2, 1 + alpha, -2 * cos, 1 - alpha)
}

export function peaking(hz: number, gainDb: number, q: number, rate: number): Biquad {
  const a = 10 ** (gainDb / 40)
  const w = (2 * Math.PI * hz) / rate
  const cos = Math.cos(w)
  const alpha = Math.sin(w) / (2 * q)
  return normalised(1 + alpha * a, -2 * cos, 1 - alpha * a, 1 + alpha / a, -2 * cos, 1 - alpha / a)
}

export function lowShelf(hz: number, gainDb: number, rate: number): Biquad {
  const a = 10 ** (gainDb / 40)
  const w = (2 * Math.PI * hz) / rate
  const cos = Math.cos(w)
  const s = 2 * Math.sqrt(a) * (Math.sin(w) / 2) * Math.SQRT2
  return normalised(
    a * (a + 1 - (a - 1) * cos + s),
    2 * a * (a - 1 - (a + 1) * cos),
    a * (a + 1 - (a - 1) * cos - s),
    a + 1 + (a - 1) * cos + s,
    -2 * (a - 1 + (a + 1) * cos),
    a + 1 + (a - 1) * cos - s,
  )
}

export function highShelf(hz: number, gainDb: number, rate: number): Biquad {
  const a = 10 ** (gainDb / 40)
  const w = (2 * Math.PI * hz) / rate
  const cos = Math.cos(w)
  const s = 2 * Math.sqrt(a) * (Math.sin(w) / 2) * Math.SQRT2
  return normalised(
    a * (a + 1 + (a - 1) * cos + s),
    -2 * a * (a - 1 + (a + 1) * cos),
    a * (a + 1 + (a - 1) * cos - s),
    a + 1 - (a - 1) * cos + s,
    2 * (a - 1 - (a + 1) * cos),
    a + 1 - (a - 1) * cos - s,
  )
}

export function filter(pcm: Pcm, f: Biquad): Pcm {
  const x = pcm.samples
  const y = new Float32Array(x.length)
  let x1 = 0
  let x2 = 0
  let y1 = 0
  let y2 = 0
  for (let i = 0; i < x.length; i++) {
    const out = f.b0 * x[i]! + f.b1 * x1 + f.b2 * x2 - f.a1 * y1 - f.a2 * y2
    x2 = x1
    x1 = x[i]!
    y2 = y1
    y1 = out
    y[i] = out
  }
  return { samples: y, rate: pcm.rate }
}

// --- noise reduction (spectral gating) ------------------------------------------

const FFT_SIZE = 512
const HOP = FFT_SIZE / 4
/** How much of the noise's level is taken from each sound, and the least
 * that is left of anything (−20 dB), so speech never turns watery. */
const OVER_SUBTRACT = 2
const FLOOR = 0.1
/** The noise is learnt from the quietest fifth of the clip, but only when
 * that is clearly quieter than the rest: a clip that is all speech is left
 * alone. */
const QUIET_SHARE = 0.2
const MIN_QUIET_DB = 12

/** In-place radix-2 FFT of `re` + i·`im` (length a power of two). */
export function fft(re: Float64Array, im: Float64Array, inverse = false) {
  const n = re.length
  for (let i = 1, j = 0; i < n; i++) {
    let bit = n >> 1
    for (; j & bit; bit >>= 1) j ^= bit
    j ^= bit
    if (i < j) {
      ;[re[i], re[j]] = [re[j]!, re[i]!]
      ;[im[i], im[j]] = [im[j]!, im[i]!]
    }
  }
  for (let size = 2; size <= n; size <<= 1) {
    const angle = ((inverse ? 2 : -2) * Math.PI) / size
    const wr = Math.cos(angle)
    const wi = Math.sin(angle)
    for (let start = 0; start < n; start += size) {
      let cr = 1
      let ci = 0
      for (let k = 0; k < size / 2; k++) {
        const a = start + k
        const b = a + size / 2
        const tr = re[b]! * cr - im[b]! * ci
        const ti = re[b]! * ci + im[b]! * cr
        re[b] = re[a]! - tr
        im[b] = im[a]! - ti
        re[a] = re[a]! + tr
        im[a] = im[a]! + ti
        const next = cr * wr - ci * wi
        ci = cr * wi + ci * wr
        cr = next
      }
    }
  }
  if (inverse) {
    for (let i = 0; i < n; i++) {
      re[i] = re[i]! / n
      im[i] = im[i]! / n
    }
  }
}

/** Learns the noise's spectrum from the quietest moments, then turns each
 * frequency down by how much of it is noise. */
export function reduceNoise(pcm: Pcm): Pcm {
  const n = FFT_SIZE
  const half = n / 2 + 1
  const window = Float64Array.from({ length: n }, (_, i) => 0.5 - 0.5 * Math.cos((2 * Math.PI * i) / n))
  // Padded so the first and last samples get whole frames.
  const padded = new Float64Array(pcm.samples.length + 2 * n)
  padded.set(pcm.samples, n)
  const frames = Math.floor((padded.length - n) / HOP) + 1
  if (pcm.samples.length < n) return pcm

  const spectra: { re: Float64Array; im: Float64Array; mag: Float64Array; energy: number }[] = []
  for (let f = 0; f < frames; f++) {
    const re = new Float64Array(n)
    const im = new Float64Array(n)
    for (let i = 0; i < n; i++) re[i] = padded[f * HOP + i]! * window[i]!
    fft(re, im)
    const mag = new Float64Array(half)
    let energy = 0
    for (let k = 0; k < half; k++) {
      mag[k] = Math.hypot(re[k]!, im[k]!)
      energy += mag[k]! * mag[k]!
    }
    spectra.push({ re, im, mag, energy })
  }

  // Frames wholly inside the padding are silent by construction: skip them.
  const real = spectra.slice(Math.ceil(n / HOP), Math.max(Math.ceil(n / HOP) + 1, frames - Math.ceil(n / HOP)))
  const byEnergy = [...real].sort((a, b) => a.energy - b.energy)
  const quiet = byEnergy.slice(0, Math.max(1, Math.floor(byEnergy.length * QUIET_SHARE)))
  const loud = byEnergy.slice(Math.floor(byEnergy.length / 2))
  const mean = (xs: typeof byEnergy) => xs.reduce((s, x) => s + x.energy, 0) / Math.max(1, xs.length)
  if (10 * Math.log10(mean(loud) / Math.max(mean(quiet), 1e-20)) < MIN_QUIET_DB) return pcm

  const noise = new Float64Array(half)
  for (const frame of quiet) for (let k = 0; k < half; k++) noise[k]! += frame.mag[k]! / quiet.length

  const out = new Float64Array(padded.length)
  const weight = new Float64Array(padded.length)
  let previous = new Float64Array(half).fill(1)
  for (let f = 0; f < frames; f++) {
    const { re, im, mag } = spectra[f]!
    const raw = new Float64Array(half)
    for (let k = 0; k < half; k++) raw[k] = Math.max(FLOOR, 1 - (OVER_SUBTRACT * noise[k]!) / Math.max(mag[k]!, 1e-12))
    // Smoothed across neighbouring frequencies and the frame before, so the
    // leftover noise does not twinkle.
    const gain = new Float64Array(half)
    for (let k = 0; k < half; k++) {
      const across = (raw[Math.max(0, k - 1)]! + raw[k]! * 2 + raw[Math.min(half - 1, k + 1)]!) / 4
      gain[k] = Math.max(across, previous[k]! * 0.5)
    }
    previous = gain
    for (let k = 0; k < half; k++) {
      re[k] = re[k]! * gain[k]!
      im[k] = im[k]! * gain[k]!
      // The mirrored half keeps the signal real.
      if (k > 0 && k < n / 2) {
        re[n - k] = re[k]!
        im[n - k] = -im[k]!
      }
    }
    fft(re, im, true)
    for (let i = 0; i < n; i++) {
      out[f * HOP + i]! += re[i]! * window[i]!
      weight[f * HOP + i]! += window[i]! * window[i]!
    }
  }
  const samples = new Float32Array(pcm.samples.length)
  for (let i = 0; i < samples.length; i++) {
    const w = weight[i + n]!
    samples[i] = w > 1e-6 ? out[i + n]! / w : 0
  }
  return { samples, rate: pcm.rate }
}
