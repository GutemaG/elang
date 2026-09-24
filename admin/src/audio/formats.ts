// What the audio store accepts, and the checks made in the browser before
// anything is sent. Mirrors `AUDIO_TYPES` and `MAX_UPLOAD_BYTES` in
// backend/app/application/admin_audio_use_cases.py (bolt 036).

export const MAX_AUDIO_BYTES = 5 * 1024 * 1024

/** Recordings stop by themselves after this long: two minutes of speech is
 * far below the 5 MB limit in any format a browser records. */
export const MAX_RECORDING_SECONDS = 120

export const AUDIO_TYPES: readonly string[] = ['audio/mp4', 'audio/x-m4a', 'audio/mpeg', 'audio/webm', 'audio/ogg']

// Names some browsers use for an allowed type.
const ALIASES: Record<string, string> = { 'audio/mp3': 'audio/mpeg', 'audio/m4a': 'audio/mp4' }

// For files the browser gives no type at all (it happens with .m4a on some
// systems).
const BY_EXTENSION: Record<string, string> = {
  m4a: 'audio/mp4',
  mp3: 'audio/mpeg',
  webm: 'audio/webm',
  ogg: 'audio/ogg',
}

/** `audio/webm;codecs=opus` -> `audio/webm`. The upload link is signed for
 * the base type, and the store refuses any other Content-Type. */
export function baseType(type: string): string {
  return (type.split(';')[0] ?? '').trim().toLowerCase()
}

/** The allowed type a file or recording is sent as, or null. */
export function audioTypeOf({ name, type }: { name?: string; type: string }): string | null {
  const base = baseType(type)
  if (base) {
    const known = ALIASES[base] ?? base
    return AUDIO_TYPES.includes(known) ? known : null
  }
  const extension = name?.split('.').pop()?.toLowerCase() ?? ''
  return name?.includes('.') ? (BY_EXTENSION[extension] ?? null) : null
}

export type ClipCheck = { ok: true; type: string } | { ok: false; problem: string }

/** Refuses what the server would refuse, before any request. */
export function checkClip(clip: { name?: string; type: string; size: number }): ClipCheck {
  const type = audioTypeOf(clip)
  if (!type) {
    return {
      ok: false,
      problem: clip.type.startsWith('audio/')
        ? 'That audio format can’t be stored. Use an m4a, mp3, webm or ogg file.'
        : 'That isn’t an audio file. Use an m4a, mp3, webm or ogg file.',
    }
  }
  if (clip.size === 0) return { ok: false, problem: 'That file is empty.' }
  if (clip.size > MAX_AUDIO_BYTES) {
    return { ok: false, problem: `That file is ${formatSize(clip.size)}. Clips can be 5 MB at most.` }
  }
  return { ok: true, type }
}

/** AAC in mp4: the one recording format every phone plays. */
export const IPHONE_SAFE_RECORDING = 'audio/mp4;codecs=mp4a.40.2'

/** The best format this browser can record in, or '' to let it choose.
 * AAC in mp4 first. Plain `audio/mp4` can mean Opus in mp4 (Chrome and
 * Edge pick it), which iPhones may not play, so it comes second; WebM
 * last. */
export function recordingType(): string {
  if (typeof MediaRecorder === 'undefined') return ''
  return [IPHONE_SAFE_RECORDING, 'audio/mp4', 'audio/webm'].find((t) => MediaRecorder.isTypeSupported(t)) ?? ''
}

export function canRecord(): boolean {
  return typeof MediaRecorder !== 'undefined' && typeof navigator.mediaDevices?.getUserMedia === 'function'
}

export function formatSize(bytes: number): string {
  if (bytes < 1024) return `${bytes} B`
  if (bytes < 1024 * 1024) return `${Math.round(bytes / 1024)} KB`
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`
}

/** 75 -> "1:15". */
export function formatDuration(seconds: number): string {
  const whole = Math.max(0, Math.floor(seconds))
  return `${Math.floor(whole / 60)}:${String(whole % 60).padStart(2, '0')}`
}
