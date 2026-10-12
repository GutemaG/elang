import { useEffect, useId, useState, type ReactNode } from 'react'

import { ApiError } from '../api'
import { messageOf, useSession } from '../auth/SessionContext'
import { Button } from '../ui/Button'
import { Icon } from '../ui/Icon'
import { FIELD_CLASS } from '../ui/Input'
import {
  MAX_TEXT,
  SAMPLE_TEXT,
  generateClip,
  voiceRoutes,
  type VoiceGender,
  type VoiceLanguage,
  type VoiceOption,
} from './api'
import { Field, SpeedField } from './SpeedField'
import type { Player } from './usePlayer'
import { forgetVoiceSetup } from './useVoiceSetup'

const when = (iso: string) =>
  new Date(iso).toLocaleString('en-GB', { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' })

interface Draft {
  male_voice_id: string
  female_voice_id: string
  speed: number
}

type Field = keyof Draft

const draftOf = (s: VoiceLanguage): Draft => ({
  male_voice_id: s.male_voice_id,
  female_voice_id: s.female_voice_id,
  speed: s.speed,
})

/** The catalog for a card: still loading, loaded, or failed to load. */
export type CatalogState = { kind: 'loading' } | { kind: 'ready'; voices: VoiceOption[] } | { kind: 'failed'; message: string }

interface Props {
  settings: VoiceLanguage
  /** Null when this server can't generate: the card is read-only. */
  catalog: CatalogState | null
  onRetryCatalog: () => void
  onSaved: (saved: VoiceLanguage) => void
  /** The page's one player: previews and tries never overlap. */
  player: Player
  /** A try spent credit, so the page reloads the credit line. */
  onTried: () => void
}

/** One language's voices and speed (FR-13): chosen, then saved on their
 * own, so editing one language never disturbs another. */
export function VoiceCard({ settings, catalog, onRetryCatalog, onSaved, player, onTried }: Props) {
  const { api } = useSession()
  const ids = useId()
  const [draft, setDraft] = useState<Draft>(() => draftOf(settings))
  const [busy, setBusy] = useState(false)
  const [saved, setSaved] = useState(false)
  const [errors, setErrors] = useState<Partial<Record<Field, string>>>({})
  const [problem, setProblem] = useState<string | null>(null)
  const [sample, setSample] = useState(SAMPLE_TEXT[settings.language] ?? '')
  const [trying, setTrying] = useState<VoiceGender | null>(null)
  const [tryProblem, setTryProblem] = useState<string | null>(null)

  const original = draftOf(settings)
  const changed =
    draft.male_voice_id !== original.male_voice_id ||
    draft.female_voice_id !== original.female_voice_id ||
    draft.speed !== original.speed

  useEffect(() => {
    if (!saved) return
    const timer = setTimeout(() => setSaved(false), 3000)
    return () => clearTimeout(timer)
  }, [saved])

  function edit<K extends Field>(field: K, value: Draft[K]) {
    setDraft((d) => ({ ...d, [field]: value }))
    setErrors((e) => ({ ...e, [field]: undefined }))
    setProblem(null)
    setSaved(false)
  }

  async function save() {
    setBusy(true)
    setErrors({})
    setProblem(null)
    try {
      const result = await api.put<VoiceLanguage>(voiceRoutes.language(settings.language), draft)
      setDraft(draftOf(result))
      setSaved(true)
      forgetVoiceSetup()
      onSaved(result)
    } catch (e) {
      const field = e instanceof ApiError ? e.details.field : undefined
      if (typeof field === 'string' && field in draft) setErrors({ [field]: e instanceof Error ? e.message : '' })
      else setProblem(messageOf(e))
    } finally {
      setBusy(false)
    }
  }

  async function listen(key: string, src: string, onFail: (message: string) => void) {
    if (player.playing === key) return player.stop()
    if (!(await player.play(key, src))) onFail('This browser couldn’t play the clip.')
  }

  /** Says the sample with the card's unsaved choices; saves nothing (FR-14). */
  async function tryVoice(gender: VoiceGender) {
    setTrying(gender)
    setTryProblem(null)
    try {
      const take = await generateClip(api, {
        language: settings.language,
        text: sample,
        gender,
        voice_id: draft[`${gender}_voice_id`],
        speed: draft.speed,
      })
      onTried()
      await listen(`try-${settings.language}-${gender}`, URL.createObjectURL(take.blob), setTryProblem)
    } catch (e) {
      setTryProblem(messageOf(e))
    } finally {
      setTrying(null)
    }
  }

  const sampleLength = sample.trim().length
  const canTry = trying === null && sampleLength > 0 && sampleLength <= MAX_TEXT
  const title = `${settings.language_name} · ${settings.language}`
  const lastChanged =
    settings.updated_by && settings.updated_at
      ? `Last changed by ${settings.updated_by}, ${when(settings.updated_at)}`
      : 'Default voices'

  return (
    <section
      aria-labelledby={`${ids}-title`}
      className="overflow-hidden rounded-lg border border-line bg-surface shadow-e1"
    >
      <div className="flex flex-wrap items-baseline justify-between gap-2 border-b border-line px-4 py-4 sm:px-6">
        <h2 id={`${ids}-title`} className="text-lg leading-6 font-semibold text-coffee">
          {title}
        </h2>
        <p className="text-xs text-stone">{lastChanged}</p>
      </div>

      {catalog === null ? (
        <ReadOnly settings={settings} />
      ) : (
        <div className="space-y-5 px-4 py-5 sm:px-6">
          {catalog.kind === 'failed' && (
            <p role="alert" className="flex flex-wrap items-center gap-2 rounded bg-terracotta-tint px-3 py-2 text-sm text-terracotta">
              <Icon name="cloud_off" className="text-base" />
              <span className="flex-1">The voice list couldn’t be loaded. {catalog.message}</span>
              <Button size="sm" onClick={onRetryCatalog}>
                Retry
              </Button>
            </p>
          )}

          <div className="grid gap-4 sm:grid-cols-2">
            {(['male', 'female'] as const).map((gender) => (
              <VoiceSelect
                key={gender}
                id={`${ids}-${gender}`}
                gender={gender}
                value={draft[`${gender}_voice_id`]}
                catalog={catalog}
                error={errors[`${gender}_voice_id`]}
                onChange={(v) => edit(`${gender}_voice_id`, v)}
                player={player}
                onPreview={(key, src) => void listen(key, src, setProblem)}
              />
            ))}
          </div>

          <SpeedField
            id={`${ids}-speed`}
            value={draft.speed}
            error={errors.speed}
            onChange={(v) => edit('speed', v)}
          />

          <div className="min-w-0">
            <label htmlFor={`${ids}-sample`} className="mb-1.5 block text-sm font-semibold text-coffee">
              Sample
            </label>
            <textarea
              id={`${ids}-sample`}
              lang={settings.language}
              rows={2}
              value={sample}
              onChange={(e) => setSample(e.target.value)}
              className={`${FIELD_CLASS} h-auto py-2 leading-6`}
            />
            <div className="mt-2 flex flex-wrap items-center gap-2">
              {(['male', 'female'] as const).map((gender) => (
                <Button key={gender} disabled={!canTry} onClick={() => void tryVoice(gender)}>
                  <Icon name="record_voice_over" className="text-lg" />
                  {trying === gender ? 'Generating…' : `Try ${gender}`}
                </Button>
              ))}
              <span
                className={`tnum ml-auto text-xs ${sampleLength > MAX_TEXT ? 'font-semibold text-danger' : 'text-stone'}`}
              >
                {sampleLength} / {MAX_TEXT}
              </span>
            </div>
            <p className="mt-1 text-xs text-stone">
              Uses the voices and speed above, saved or not. Nothing is stored.
            </p>
            {tryProblem && (
              <p role="alert" className="mt-2 flex items-start gap-1.5 text-sm text-danger">
                <Icon name="error" className="mt-px text-base" />
                <span>{tryProblem}</span>
              </p>
            )}
          </div>

          {problem && (
            <p role="alert" className="flex items-start gap-1.5 text-sm text-danger">
              <Icon name="error" className="mt-px text-base" />
              <span>{problem}</span>
            </p>
          )}

          <div className="flex flex-wrap items-center justify-end gap-2">
            {saved && (
              <span aria-live="polite" className="mr-auto flex items-center gap-1.5 text-sm text-forest">
                <Icon name="check_circle" className="text-base" filled />
                Saved
              </span>
            )}
            <Button
              variant="ghost"
              disabled={!changed || busy}
              onClick={() => {
                setDraft(original)
                setErrors({})
                setProblem(null)
              }}
            >
              Discard
            </Button>
            <Button variant="primary" disabled={!changed || busy} onClick={() => void save()}>
              {busy ? 'Saving…' : `Save ${settings.language_name}`}
            </Button>
          </div>
        </div>
      )}
    </section>
  )
}

const GENDER_LABEL: Record<VoiceGender, string> = { male: 'Male voice', female: 'Female voice' }

function VoiceSelect({
  id,
  gender,
  value,
  catalog,
  error,
  onChange,
  player,
  onPreview,
}: {
  id: string
  gender: VoiceGender
  value: string
  catalog: CatalogState
  error?: string
  onChange: (id: string) => void
  player: Player
  onPreview: (key: string, src: string) => void
}) {
  const voices = catalog.kind === 'ready' ? catalog.voices.filter((v) => v.gender === gender) : []
  const chosen = voices.find((v) => v.id === value)
  // FR-15: Addis may stop offering a voice that was saved.
  const gone = catalog.kind === 'ready' && !chosen
  const hint =
    catalog.kind === 'loading' ? 'Loading voices…' : chosen ? chosen.descriptor || chosen.style : undefined
  const previewKey = `preview-${value}`
  const previewing = player.playing === previewKey

  return (
    <Field
      id={id}
      label={GENDER_LABEL[gender]}
      hint={hint}
      error={error ?? (gone ? 'Addis AI no longer offers this voice. Choose another and save.' : undefined)}
    >
      <div className="flex gap-2">
        <select id={id} className={FIELD_CLASS} value={value} onChange={(e) => onChange(e.target.value)}>
          {/* A saved voice the list doesn't have is kept, never silently changed. */}
          {!chosen && <option value={value}>{gone ? `${value} (no longer offered)` : value}</option>}
          {voices.map((v) => (
            <option key={v.id} value={v.id}>
              {v.style ? `${v.name} · ${v.style}` : v.name}
            </option>
          ))}
        </select>
        <Button
          size="icon"
          variant="outline"
          className="shrink-0"
          aria-label={previewing ? 'Stop' : `Play ${chosen?.name ?? value} preview`}
          title={chosen?.preview_audio_url ? undefined : 'No preview for this voice'}
          disabled={!chosen?.preview_audio_url}
          onClick={() => chosen?.preview_audio_url && onPreview(previewKey, chosen.preview_audio_url)}
        >
          <Icon name={previewing ? 'stop' : 'play_arrow'} className="text-lg" filled />
        </Button>
      </div>
    </Field>
  )
}

function ReadOnly({ settings }: { settings: VoiceLanguage }) {
  return (
    <dl className="grid gap-4 px-4 py-5 text-sm sm:grid-cols-3 sm:px-6">
      <Fact label="Male voice">{settings.male_voice_id}</Fact>
      <Fact label="Female voice">{settings.female_voice_id}</Fact>
      <Fact label="Speed">{settings.speed}</Fact>
    </dl>
  )
}

function Fact({ label, children }: { label: string; children: ReactNode }) {
  return (
    <div className="min-w-0">
      <dt className="text-xs font-semibold text-stone">{label}</dt>
      <dd className="mt-0.5 break-all text-coffee">{children}</dd>
    </div>
  )
}
