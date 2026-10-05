// Cleaning a recorded clip before it is stored: the silence around the
// speech cut away, the volume brought to one level and short fades so it
// never clicks. Pure, on plain samples, so the rules are tested without a
// browser's audio engine (jsdom has none). Decoding, playing and encoding
// are in codec.ts.

/** Mono samples in -1..1, and how many there are a second. */
export interface Pcm {
  samples: Float32Array
  rate: number
}

/** A stretch of a clip, in seconds from its start. */
export interface Span {
  start: number
  end: number
}

/** Loudness is measured in slices this long. */
const FRAME_SECONDS = 0.01
/** Kept before the speech, so a soft start (h, a breath of air) stays. */
export const LEAD_SECONDS = 0.08
/** Kept after it, so a vowel can fade out on its own. */
export const TAIL_SECONDS = 0.15
/** A loud stretch shorter than this is a click unless it sits near speech:
 * the burst of an ejective (ቀ, ጠ, q) is that short, but never alone. */
const BLIP_SECONDS = 0.04
const NEAR_SECONDS = 0.25
/** Every cleaned clip is brought to this loudness (−18 dBFS RMS over the
 * speech), with its peaks kept under −1 dBFS. */
const TARGET_RMS = 0.126
const PEAK_LIMIT = 0.89
const FADE_IN_SECONDS = 0.01
const FADE_OUT_SECONDS = 0.02
/** Never cut to less than this: a clip has to be long enough to tap. */
export const MIN_SECONDS = 0.15

export const durationOf = (pcm: Pcm): number => pcm.samples.length / pcm.rate

const db = (x: number) => 20 * Math.log10(Math.max(x, 1e-9))

function frameLevels(pcm: Pcm): number[] {
  const size = Math.max(1, Math.round(pcm.rate * FRAME_SECONDS))
  const levels: number[] = []
  for (let at = 0; at < pcm.samples.length; at += size) {
    let sum = 0
    const end = Math.min(at + size, pcm.samples.length)
    for (let i = at; i < end; i++) sum += pcm.samples[i]! * pcm.samples[i]!
    levels.push(Math.sqrt(sum / (end - at)))
  }
  return levels
}

/** Where the speech is: from the first loud stretch to the last, with a
 * little kept either side. The quiet level is the room's own (the 10th
 * percentile of the clip), and speech is 10 dB over it and within 35 dB of
 * the loudest moment. A clip with nothing over that is kept whole. */
export function findSpeech(pcm: Pcm): Span {
  const whole = { start: 0, end: durationOf(pcm) }
  const levels = frameLevels(pcm)
  if (levels.length === 0) return whole
  const sorted = [...levels].sort((a, b) => a - b)
  const floor = db(sorted[Math.floor(sorted.length * 0.1)]!)
  const peak = db(sorted[sorted.length - 1]!)
  const threshold = Math.max(floor + 10, peak - 35)

  // Runs of loud frames, as [first, last] frame indexes.
  const runs: [number, number][] = []
  levels.forEach((level, i) => {
    if (db(level) < threshold) return
    const last = runs[runs.length - 1]
    if (last && last[1] === i - 1) last[1] = i
    else runs.push([i, i])
  })
  const frames = (seconds: number) => Math.round(seconds / FRAME_SECONDS)
  const long = runs.filter(([a, b]) => b - a + 1 >= frames(BLIP_SECONDS))
  if (long.length === 0) return whole
  const kept = runs.filter(
    ([a, b]) => b - a + 1 >= frames(BLIP_SECONDS) || long.some(([c, d]) => a - d <= frames(NEAR_SECONDS) && c - b <= frames(NEAR_SECONDS)),
  )

  const start = Math.max(0, kept[0]![0] * FRAME_SECONDS - LEAD_SECONDS)
  const end = Math.min(whole.end, (kept[kept.length - 1]![1] + 1) * FRAME_SECONDS + TAIL_SECONDS)
  return widen({ start, end }, whole.end)
}

/** Keeps a span inside the clip and at least MIN_SECONDS long. */
export function widen(span: Span, length: number): Span {
  let start = Math.min(Math.max(0, span.start), length)
  let end = Math.min(Math.max(start, span.end), length)
  if (end - start < MIN_SECONDS) {
    const middle = (start + end) / 2
    start = Math.max(0, middle - MIN_SECONDS / 2)
    end = Math.min(length, start + MIN_SECONDS)
    start = Math.max(0, end - MIN_SECONDS)
  }
  return { start, end }
}

/** The span cut out, brought to the common loudness and faded at both ends. */
export function cleanUp(pcm: Pcm, span: Span): Pcm {
  const from = Math.round(Math.max(0, span.start) * pcm.rate)
  const to = Math.min(pcm.samples.length, Math.round(span.end * pcm.rate))
  const out = pcm.samples.slice(from, Math.max(from, to))

  // Loudness over the speech only: frames within 30 dB of the loudest.
  const levels = frameLevels({ samples: out, rate: pcm.rate })
  const loudest = Math.max(0, ...levels)
  const speech = levels.filter((l) => db(l) > db(loudest) - 30)
  const rms = speech.length ? Math.sqrt(speech.reduce((s, l) => s + l * l, 0) / speech.length) : 0
  let peak = 0
  for (const x of out) peak = Math.max(peak, Math.abs(x))
  const gain = rms > 0 && peak > 0 ? Math.min(TARGET_RMS / rms, PEAK_LIMIT / peak) : 1

  const fadeIn = Math.min(out.length, Math.round(FADE_IN_SECONDS * pcm.rate))
  const fadeOut = Math.min(out.length, Math.round(FADE_OUT_SECONDS * pcm.rate))
  for (let i = 0; i < out.length; i++) {
    let g = gain
    if (i < fadeIn) g *= i / fadeIn
    const left = out.length - 1 - i
    if (left < fadeOut) g *= left / fadeOut
    out[i] = Math.max(-1, Math.min(1, out[i]! * g))
  }
  return { samples: out, rate: pcm.rate }
}

/** 16-bit samples, as both encoders take them. */
export function toInt16(samples: Float32Array): Int16Array {
  const out = new Int16Array(samples.length)
  for (let i = 0; i < samples.length; i++) {
    const x = Math.max(-1, Math.min(1, samples[i]!))
    out[i] = x < 0 ? x * 0x8000 : x * 0x7fff
  }
  return out
}

/** The loudest point in each of `count` equal slices, 0..1: what the
 * waveform draws. */
export function peaksOf(pcm: Pcm, count: number): number[] {
  const n = pcm.samples.length
  if (n === 0 || count <= 0) return []
  const out: number[] = []
  for (let b = 0; b < count; b++) {
    const from = Math.floor((b * n) / count)
    const to = Math.max(from + 1, Math.floor(((b + 1) * n) / count))
    let peak = 0
    for (let i = from; i < Math.min(to, n); i++) peak = Math.max(peak, Math.abs(pcm.samples[i]!))
    out.push(peak)
  }
  return out
}

/** 1.234 -> "1.23 s". */
export const formatSeconds = (s: number): string => `${s.toFixed(2)} s`
