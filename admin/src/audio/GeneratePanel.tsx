import { useEffect, useId, useState, type ReactNode } from 'react'

import { messageOf, useSession } from '../auth/SessionContext'
import { Button } from '../ui/Button'
import { cx } from '../ui/cx'
import { Icon } from '../ui/Icon'
import { FIELD_CLASS } from '../ui/Input'
import { DEFAULT_SPEED, MAX_TEXT, generateClip, type GeneratedClip, type VoiceGender } from '../voices/api'
import { SpeedField } from '../voices/SpeedField'
import { useVoiceSetup } from '../voices/useVoiceSetup'
import { useCleaning, useClipUpload, type ClipUploader } from './clipHooks'

/** Which clip a field is for, so the Generate tab knows the language and
 * what to say. Exercises know only their lesson; the server finds its
 * language. */
export interface VoiceSource {
  language?: string
  lessonId?: string
  /** The words the item already has, filled in for the admin. */
  text?: string
}

const VOICE_LANGUAGES = ['am', 'om']
const GENDER_KEY = 'buna.admin.voiceGender'

function storedGender(): VoiceGender {
  try {
    return localStorage.getItem(GENDER_KEY) === 'male' ? 'male' : 'female'
  } catch {
    return 'female'
  }
}

function storeGender(gender: VoiceGender): void {
  try {
    localStorage.setItem(GENDER_KEY, gender)
  } catch {
    // Not remembered this time; the choice still applies.
  }
}

/** A take: the clip, and a URL to play it, freed when it is replaced. */
interface Take {
  clip: GeneratedClip
  url: string
}

// A take is an mp3 (`output_format: mp3_44100` on the server).
const TAKE_TYPE = 'audio/mpeg'

/** The stored name's tag for a take, so the clip later says who spoke it
 * (FR-21); none for a voice id the server wouldn't accept. */
const sourceOf = (voiceId: string) => (/^(am|om)-[a-z0-9-]{1,40}$/.test(voiceId) ? `gen-${voiceId}` : undefined)

/** The fourth way to get a clip (FR-16 to FR-19): typed words said by the
 * language's Addis AI voice, trimmed in the clip editor like a recording,
 * then stored like an uploaded file when the admin keeps it. */
export function GeneratePanel({
  voice,
  send,
  onUploaded,
}: {
  voice: VoiceSource
  /** The field's store, the same one Upload uses. */
  send: ClipUploader
  onUploaded: (url: string) => void
}) {
  const { api } = useSession()
  const ids = useId()
  const setup = useVoiceSetup(api, voice.language)
  // An untouched box follows the item's words; an edited one keeps the admin's.
  const [edited, setEdited] = useState<string | null>(null)
  const text = edited ?? voice.text ?? ''
  const [gender, setGender] = useState<VoiceGender>(storedGender)
  const [speed, setSpeed] = useState<number | null>(null)
  const [busy, setBusy] = useState(false)
  const [problem, setProblem] = useState<string | null>(null)
  const [take, setTake] = useState<Take | null>(null)
  const clean = useCleaning(take?.clip.blob ?? null, 'As generated')
  const upload = useClipUpload(send, onUploaded)

  const takeUrl = take?.url
  useEffect(() => {
    if (!takeUrl) return
    return () => URL.revokeObjectURL(takeUrl)
  }, [takeUrl])

  if (setup.kind === 'loading') return <p className="text-sm text-stone">Loading voices…</p>
  if (setup.kind === 'failed') return <Note icon="error">{setup.message}</Note>
  if (!setup.configured) {
    return <Note icon="voice_over_off">Generated voices aren’t set up on this server. Record or upload instead.</Note>
  }
  if (voice.language && !VOICE_LANGUAGES.includes(voice.language)) {
    return <Note icon="voice_over_off">Generated voices are not available for {voice.language}.</Note>
  }

  const settings = setup.language
  const savedSpeed = settings?.speed ?? DEFAULT_SPEED
  const currentSpeed = speed ?? savedSpeed
  const nameOf = (g: VoiceGender) => {
    if (!settings) return ''
    const id = g === 'male' ? settings.male_voice_id : settings.female_voice_id
    return setup.names[id] ?? id
  }
  const length = text.trim().length
  const ready = length > 0 && length <= MAX_TEXT && !busy

  /** Stores the take, cleaned or as generated, as Upload stores a file. */
  async function keep(t: Take) {
    if (await upload.send(t.clip.blob, TAKE_TYPE, clean.cleaning, sourceOf(t.clip.voiceId))) {
      clean.reset()
      setTake(null)
    }
  }

  async function generate() {
    setBusy(true)
    setProblem(null)
    try {
      const clip = await generateClip(api, {
        ...(voice.language ? { language: voice.language } : { lesson_id: voice.lessonId }),
        text,
        gender,
        speed: currentSpeed,
      })
      // A new take gets its own cut; cleaned or not, and the effects, stay.
      clean.reset()
      upload.setProblem(null)
      setTake({ clip, url: URL.createObjectURL(clip.blob) })
    } catch (e) {
      setProblem(messageOf(e))
    } finally {
      setBusy(false)
    }
  }

  return (
    <div className="space-y-4">
      <div className="min-w-0">
        <label htmlFor={`${ids}-text`} className="mb-1.5 block text-sm font-semibold text-coffee">
          Words to say
        </label>
        <textarea
          id={`${ids}-text`}
          lang={voice.language}
          rows={2}
          value={text}
          placeholder="Type the words the learner should hear"
          onChange={(e) => setEdited(e.target.value)}
          className={cx(FIELD_CLASS, 'h-auto py-2 leading-6')}
        />
        <p className={cx('tnum mt-1 text-right text-xs', length > MAX_TEXT ? 'font-semibold text-danger' : 'text-stone')}>
          {length} / {MAX_TEXT}
        </p>
      </div>

      <div role="radiogroup" aria-label="Voice" className="flex flex-wrap gap-2">
        {(['male', 'female'] as const).map((g) => {
          const name = nameOf(g)
          const label = `${g === 'male' ? 'Male' : 'Female'}${name ? ` · ${name}` : ''}`
          return (
            <button
              key={g}
              type="button"
              role="radio"
              aria-checked={gender === g}
              onClick={() => {
                setGender(g)
                storeGender(g)
              }}
              className={cx(
                'inline-flex h-11 items-center gap-1.5 rounded border px-3 text-sm font-semibold transition-colors sm:h-10',
                gender === g
                  ? 'border-forest bg-forest-tint text-forest'
                  : 'border-line bg-surface text-coffee-soft hover:bg-inset',
              )}
            >
              <Icon name={gender === g ? 'radio_button_checked' : 'radio_button_unchecked'} className="text-base" />
              {label}
            </button>
          )
        })}
      </div>

      <SpeedField
        id={`${ids}-speed`}
        value={currentSpeed}
        defaultValue={savedSpeed}
        hint="This clip only. The language’s usual speed is set on the Voices page."
        onChange={setSpeed}
      />

      <Button variant="primary" disabled={!ready} onClick={() => void generate()}>
        <Icon name="record_voice_over" className="text-lg" />
        {busy ? 'Generating…' : take ? 'Generate again' : 'Generate'}
      </Button>

      {problem && (
        <p role="alert" className="flex items-start gap-1.5 text-sm text-danger">
          <Icon name="error" className="mt-px text-base" />
          <span>{problem}</span>
        </p>
      )}

      {take && (
        <div className="space-y-3">
          {clean.editor(<audio controls src={take.url} aria-label="Play the generated clip" className="w-full" />)}
          <p className="text-xs text-stone">
            {take.clip.voiceName} · {take.clip.seconds.toFixed(1)} s · not stored yet
          </p>
          <div className="flex flex-wrap gap-2">
            <Button
              variant="primary"
              disabled={upload.busy || clean.working}
              onClick={() => void keep(take)}
            >
              <Icon name="cloud_upload" className="text-lg" />
              {upload.busy ? 'Uploading…' : 'Use this clip'}
            </Button>
            <Button
              variant="danger-ghost"
              disabled={upload.busy}
              onClick={() => {
                clean.reset()
                upload.setProblem(null)
                setTake(null)
              }}
            >
              <Icon name="delete" className="text-lg" />
              Discard
            </Button>
          </div>
          {upload.problem && (
            <p role="alert" className="flex items-start gap-1.5 text-sm text-danger">
              <Icon name="error" className="mt-px text-base" />
              <span>{upload.problem}</span>
            </p>
          )}
        </div>
      )}
    </div>
  )
}

function Note({ icon, children }: { icon: string; children: ReactNode }) {
  return (
    <p className="flex items-start gap-1.5 rounded bg-terracotta-tint px-3 py-2 text-sm leading-6 text-terracotta">
      <Icon name={icon} className="mt-1 text-base" />
      <span>{children}</span>
    </p>
  )
}
