// Generated voices (intent 027): the backend's voice settings, the voices
// Addis AI offers, and the credit left. Shared by the Voices page and the
// clip fields' Generate tab.

import type { ApiClient } from '../api'

const VOICE = '/api/v1/admin/voice'

export const voiceRoutes = {
  settings: `${VOICE}/settings`,
  language: (code: string) => `${VOICE}/settings/${code}`,
  voices: (code: string) => `${VOICE}/voices?language=${encodeURIComponent(code)}`,
  usage: `${VOICE}/usage`,
  generate: `${VOICE}/generate`,
}

export type VoiceGender = 'male' | 'female'

/** One language's voices and speed. `updated_by`/`updated_at` are null
 * while it still uses the default voices. */
export interface VoiceLanguage {
  language: string
  language_name: string
  male_voice_id: string
  female_voice_id: string
  speed: number
  updated_by: string | null
  updated_at: string | null
}

export interface VoiceSettingsList {
  /** Whether this server can generate audio (an Addis AI key is set). */
  configured: boolean
  languages: VoiceLanguage[]
}

export interface VoiceOption {
  id: string
  name: string
  descriptor: string
  gender: string
  style: string
  preview_audio_url: string | null
}

export interface VoiceCatalog {
  language: string
  /** Available voices only, in Addis's order. */
  voices: VoiceOption[]
}

export interface VoiceUsage {
  balance: number
  currency: string
  formatted_balance: string
  price_per_minute: number | null
  max_characters: number | null
}

export const SPEED_MIN = 0
export const SPEED_MAX = 100
export const DEFAULT_SPEED = 50

/** Lesson audio is a word, a phrase or a sentence (FR-9). */
export const MAX_TEXT = 500

/** What each language's Try it says until the admin types something else. */
export const SAMPLE_TEXT: Record<string, string> = {
  am: 'ሰላም! ስሜ ሳራ ነው። እንኳን ደህና መጣህ።',
  om: 'Akkam! Maqaan koo Saaraa dha. Baga nagaan dhufte.',
}

export interface GenerateBody {
  text: string
  gender: VoiceGender
  /** One of these two: the clip's language, or the lesson it is for. */
  language?: string
  lesson_id?: string
  /** This take only; the language's saved settings otherwise. */
  speed?: number
  voice_id?: string
}

export interface GeneratedClip {
  blob: Blob
  voiceId: string
  voiceName: string
  seconds: number
  creditsRemaining: number | null
}

/** A take of `body.text`, not stored anywhere yet (FR-8). */
export async function generateClip(api: ApiClient, body: GenerateBody): Promise<GeneratedClip> {
  const { blob, headers } = await api.postForBlob(voiceRoutes.generate, body)
  const credits = headers.get('X-Credits-Remaining')
  const voiceId = headers.get('X-Voice-Id') ?? body.voice_id ?? ''
  let voiceName = voiceId
  try {
    voiceName = decodeURIComponent(headers.get('X-Voice-Name') ?? '') || voiceId
  } catch {
    // A malformed name: the id still says who spoke.
  }
  return {
    blob,
    voiceId,
    voiceName,
    seconds: Number(headers.get('X-Duration-Seconds') ?? 0) || 0,
    creditsRemaining: credits ? Number(credits) : null,
  }
}
