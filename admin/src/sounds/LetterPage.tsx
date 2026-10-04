import { useId, useState, type FormEvent, type ReactNode } from 'react'
import { Link, useNavigate, useParams } from 'react-router-dom'

import { AudioField } from '../audio/AudioField'
import { messageOf, useSession } from '../auth/SessionContext'
import { Section } from '../exercises/fields'
import { routes } from '../tree/levels'
import type { AdminSoundChart, AdminSoundLetter, Localized, SoundLetterChange, SoundLetterStatus } from '../types'
import { Button } from '../ui/Button'
import { cx } from '../ui/cx'
import { Icon } from '../ui/Icon'
import { FIELD_CLASS, Input } from '../ui/Input'
import { Modal } from '../ui/Modal'
import { APP_LANGUAGES, STATE_LABELS, STATUS_LABELS, englishOf, stateOf, uploadSound } from './model'
import { useSoundChart } from './useSoundChart'

interface Draft {
  glyph: string
  romanization: string
  same_as_id: string
  hint: Localized
  audio_url: string
  example_word: string
  example_romanization: string
  example_meaning: Localized
  example_audio_url: string
  status: SoundLetterStatus
  recorded_by: string
}

function draftOf(x: AdminSoundLetter): Draft {
  return {
    glyph: x.glyph,
    romanization: x.romanization,
    same_as_id: x.same_as_id ?? '',
    hint: { ...x.hint },
    audio_url: x.audio_url ?? '',
    example_word: x.example_word ?? '',
    example_romanization: x.example_romanization ?? '',
    example_meaning: { ...x.example_meaning },
    example_audio_url: x.example_audio_url ?? '',
    status: x.status,
    recorded_by: x.recorded_by ?? '',
  }
}

const cleanLocalized = (o: Localized): Localized =>
  Object.fromEntries(Object.entries(o).filter(([, v]) => (v ?? '').trim() !== '').map(([k, v]) => [k, v!.trim()]))
const same = (a: Localized, b: Localized) => JSON.stringify(cleanLocalized(a)) === JSON.stringify(cleanLocalized(b))
const orNull = (text: string) => text.trim() || null

/** Only what differs from the saved letter. */
function changesOf(saved: AdminSoundLetter, d: Draft): SoundLetterChange {
  const c: SoundLetterChange = { id: saved.id }
  if (d.glyph.trim() !== saved.glyph) c.glyph = d.glyph.trim()
  if (d.romanization.trim() !== saved.romanization) c.romanization = d.romanization.trim()
  if (orNull(d.same_as_id) !== saved.same_as_id) c.same_as_id = orNull(d.same_as_id)
  if (!same(d.hint, saved.hint)) c.hint = cleanLocalized(d.hint)
  if (orNull(d.audio_url) !== saved.audio_url) c.audio_url = orNull(d.audio_url)
  if (orNull(d.example_word) !== saved.example_word) c.example_word = orNull(d.example_word)
  if (orNull(d.example_romanization) !== saved.example_romanization) {
    c.example_romanization = orNull(d.example_romanization)
  }
  if (!same(d.example_meaning, saved.example_meaning)) c.example_meaning = cleanLocalized(d.example_meaning)
  if (orNull(d.example_audio_url) !== saved.example_audio_url) c.example_audio_url = orNull(d.example_audio_url)
  if (d.status !== saved.status) c.status = d.status
  if (orNull(d.recorded_by) !== saved.recorded_by) c.recorded_by = orNull(d.recorded_by)
  return c
}

/** One letter: what it is, its sound, an example word, and whether a
 * native speaker has checked it. "Save and next" walks the chart. */
export function LetterPage() {
  const { language = '', letterId = '' } = useParams()
  const { chart, error, saveLetters } = useSoundChart(language)
  if (!chart) {
    return (
      <main className="mx-auto max-w-4xl px-4 py-6 sm:px-6 lg:px-8 lg:py-8">
        {error ? (
          <p role="alert" className="text-sm text-danger">
            {error}
          </p>
        ) : (
          <p className="text-sm text-stone">Loading…</p>
        )}
      </main>
    )
  }
  const letter = chart.letters.find((x) => x.id === letterId)
  if (!letter) {
    return (
      <main className="mx-auto max-w-4xl px-4 py-6 sm:px-6 lg:px-8 lg:py-8">
        <p className="text-sm text-stone">
          No such letter. <Link to={`/sounds/${language}`} className="text-forest underline">Back to the chart</Link>
        </p>
      </main>
    )
  }
  // Keyed by the letter, so moving to the next starts a fresh form.
  return <LetterForm key={letter.id} chart={chart} letter={letter} saveLetters={saveLetters} />
}

function LetterForm({
  chart,
  letter,
  saveLetters,
}: {
  chart: AdminSoundChart
  letter: AdminSoundLetter
  saveLetters: (changes: SoundLetterChange[]) => Promise<AdminSoundChart>
}) {
  const { api } = useSession()
  const navigate = useNavigate()
  const [saved, setSaved] = useState(letter)
  const [draft, setDraft] = useState(() => draftOf(letter))
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [notice, setNotice] = useState<string | null>(null)
  const [deleting, setDeleting] = useState(false)
  const ids = { glyph: useId(), romanization: useId(), same: useId(), word: useId(), wordRom: useId(), by: useId() }

  const index = chart.letters.findIndex((x) => x.id === letter.id)
  const next = chart.letters[index + 1]
  const previous = chart.letters[index - 1]
  const group = chart.groups.find((g) => g.key === letter.group)
  const sharedBy = chart.letters.filter((x) => x.same_as_id === letter.id)
  // A letter may share the sound of one with its own recording, and not
  // while others share its own.
  const sources = chart.letters.filter((x) => x.id !== letter.id && !x.same_as_id)
  const sameAs = chart.letters.find((x) => x.id === draft.same_as_id)
  const change = changesOf(saved, draft)
  const dirty = Object.keys(change).length > 1
  const upload = (clip: Blob, type: string) => uploadSound(api, chart.language, clip, type)
  const position = group?.columns
    ? `${englishOf(group.names)} · row ${Math.floor(letter.position / group.columns) + 1}, ${group.column_labels[letter.position % group.columns] ?? ''}`
    : `${englishOf(group?.names ?? {})} · ${letter.position + 1}`

  const edit = <K extends keyof Draft>(key: K, value: Draft[K]) => {
    setDraft((d) => ({ ...d, [key]: value }))
    setNotice(null)
  }

  async function save(then?: 'next') {
    if (busy) return
    setBusy(true)
    setError(null)
    try {
      if (dirty) {
        const updated = await saveLetters([change])
        const fresh = updated.letters.find((x) => x.id === letter.id)
        if (fresh) {
          setSaved(fresh)
          setDraft(draftOf(fresh))
        }
      }
      if (then === 'next' && next) {
        navigate(`/sounds/${chart.language}/letters/${next.id}`)
        return
      }
      setNotice('Saved.')
    } catch (e) {
      setError(messageOf(e))
    } finally {
      setBusy(false)
    }
  }

  function submit(e: FormEvent) {
    e.preventDefault()
    void save()
  }

  return (
    <main className="mx-auto max-w-4xl px-4 py-6 sm:px-6 lg:px-8 lg:py-8">
      <nav aria-label="Breadcrumb" className="mb-3 flex flex-wrap items-center gap-1 text-sm">
        <Link to="/sounds" className="text-forest hover:underline">
          Sounds
        </Link>
        <Icon name="chevron_right" className="text-base text-stone" />
        <Link to={`/sounds/${chart.language}`} className="text-forest hover:underline">
          {chart.language_name} · {englishOf(chart.title)}
        </Link>
      </nav>

      <form onSubmit={submit} className="space-y-5">
        <header className="flex flex-wrap items-center gap-5">
          <span
            aria-hidden="true"
            className="grid size-28 shrink-0 place-items-center rounded-lg bg-forest-tint text-6xl font-bold text-forest"
          >
            {draft.glyph || '?'}
          </span>
          <div className="min-w-0 flex-1">
            <p className="text-xs font-bold tracking-[0.12em] text-forest uppercase">{position}</p>
            <h1 className="mt-1 text-[1.75rem] leading-9 font-bold text-coffee">
              Letter {saved.glyph} <span className="font-mono text-xl text-stone">{saved.romanization}</span>
            </h1>
            <p className="mt-1 text-sm text-stone">
              {STATE_LABELS[stateOf(saved)]} · {index + 1} of {chart.letters.length}
            </p>
          </div>
          <div className="flex gap-1">
            <Button
              size="icon"
              variant="ghost"
              aria-label="Previous letter"
              disabled={!previous}
              onClick={() => previous && navigate(`/sounds/${chart.language}/letters/${previous.id}`)}
            >
              <Icon name="chevron_left" className="text-xl" />
            </Button>
            <Button
              size="icon"
              variant="ghost"
              aria-label="Next letter"
              disabled={!next}
              onClick={() => next && navigate(`/sounds/${chart.language}/letters/${next.id}`)}
            >
              <Icon name="chevron_right" className="text-xl" />
            </Button>
          </div>
        </header>

        <Section title="The letter">
          <div className="grid gap-4 sm:grid-cols-2">
            <Field id={ids.glyph} label="Letter">
              <Input id={ids.glyph} value={draft.glyph} maxLength={16} onChange={(e) => edit('glyph', e.target.value)} />
            </Field>
            <Field id={ids.romanization} label="Romanization" hint="In Latin letters, as the lessons write it.">
              <Input
                id={ids.romanization}
                value={draft.romanization}
                maxLength={32}
                className="font-mono"
                onChange={(e) => edit('romanization', e.target.value)}
              />
            </Field>
            <Field
              id={ids.same}
              label="Same sound as"
              hint={
                sharedBy.length > 0
                  ? `${sharedBy.map((x) => x.glyph).join(' ')} share this letter’s sound, so it keeps its own.`
                  : 'For a letter written differently but said the same, like ሐ and ሀ. It then plays that one’s recording.'
              }
            >
              <select
                id={ids.same}
                className={FIELD_CLASS}
                value={draft.same_as_id}
                disabled={sharedBy.length > 0}
                onChange={(e) => edit('same_as_id', e.target.value)}
              >
                <option value="">No, it has its own sound</option>
                {sources.map((x) => (
                  <option key={x.id} value={x.id}>
                    {x.glyph} · {x.romanization}
                  </option>
                ))}
              </select>
            </Field>
          </div>
          <LocalizedFields
            label="Hint for learners"
            hint="Optional. For a sound English has not got, e.g. “Pushed out from the throat”."
            value={draft.hint}
            max={200}
            onChange={(v) => edit('hint', v)}
          />
        </Section>

        {sameAs ? (
          <Section title="Sound">
            <p className="flex items-center gap-2 rounded-lg bg-inset p-3 text-sm text-coffee-soft">
              <Icon name="link" className="text-lg" />
              Plays the recording of {sameAs.glyph} ({sameAs.romanization}). Nothing to record.
            </p>
          </Section>
        ) : (
          <AudioField
            title="Sound"
            hint="About a second, said once and clearly. Record it here, upload a file, or paste a link."
            upload={upload}
            url={draft.audio_url}
            savedUrl={saved.audio_url}
            onChange={(url) => {
              edit('audio_url', url)
              // A new recording goes back to review.
              if (url !== saved.audio_url && draft.status === 'ready') edit('status', 'needs_review')
            }}
          />
        )}

        <Section title="Example word" hint="Optional. Shown under the letter in the app, with its own recording.">
          <div className="grid gap-4 sm:grid-cols-2">
            <Field id={ids.word} label="Word">
              <Input id={ids.word} value={draft.example_word} maxLength={64} onChange={(e) => edit('example_word', e.target.value)} />
            </Field>
            <Field id={ids.wordRom} label="The word’s romanization">
              <Input
                id={ids.wordRom}
                value={draft.example_romanization}
                maxLength={64}
                className="font-mono"
                onChange={(e) => edit('example_romanization', e.target.value)}
              />
            </Field>
          </div>
          <LocalizedFields label="Meaning" value={draft.example_meaning} max={120} onChange={(v) => edit('example_meaning', v)} />
        </Section>

        {draft.example_word.trim() && (
          <AudioField
            title="Example word’s sound"
            hint="The whole word, said once."
            upload={upload}
            url={draft.example_audio_url}
            savedUrl={saved.example_audio_url}
            onChange={(url) => edit('example_audio_url', url)}
          />
        )}

        <Section title="Review">
          <div className="flex flex-wrap items-end gap-4">
            <div role="radiogroup" aria-label="Status" className="inline-flex rounded border border-line bg-inset p-1">
              {(Object.keys(STATUS_LABELS) as SoundLetterStatus[]).map((s) => (
                <button
                  key={s}
                  type="button"
                  role="radio"
                  aria-checked={draft.status === s}
                  onClick={() => edit('status', s)}
                  className={cx(
                    'rounded px-3 py-1.5 text-sm font-semibold',
                    draft.status === s ? 'bg-surface text-coffee shadow-e1' : 'text-stone hover:text-coffee',
                  )}
                >
                  {STATUS_LABELS[s]}
                </button>
              ))}
            </div>
            <Field id={ids.by} label="Recorded by" hint="Credited in the app.">
              <Input
                id={ids.by}
                value={draft.recorded_by}
                maxLength={120}
                className="sm:w-64"
                onChange={(e) => edit('recorded_by', e.target.value)}
              />
            </Field>
          </div>
        </Section>

        <div className="sticky bottom-0 -mx-4 flex flex-wrap items-center gap-3 border-t border-line bg-canvas/95 px-4 py-3 backdrop-blur sm:mx-0 sm:rounded-lg sm:border">
          <Button variant="danger-ghost" size="sm" disabled={busy || sharedBy.length > 0} onClick={() => setDeleting(true)}>
            <Icon name="delete" className="text-lg" />
            Delete
          </Button>
          <span className="flex-1 text-sm" aria-live="polite">
            {error && (
              <span role="alert" className="text-danger">
                {error}
              </span>
            )}
            {!error && notice && <span className="text-forest">{notice}</span>}
            {!error && !notice && dirty && <span className="text-stone">Unsaved changes</span>}
          </span>
          <Button type="submit" disabled={busy || !dirty}>
            Save
          </Button>
          <Button variant="primary" disabled={busy || (!dirty && !next)} onClick={() => void save('next')}>
            {next ? 'Save and next' : 'Save'}
            {next && <Icon name="arrow_forward" className="text-lg" />}
          </Button>
        </div>
      </form>

      {deleting && (
        <Modal title={`Delete ${saved.glyph}?`} onClose={() => !busy && setDeleting(false)}>
          <p className="mt-2 text-sm leading-6 text-coffee-soft">The letter and its details leave the chart.</p>
          <div className="mt-6 flex flex-col-reverse gap-2 sm:flex-row sm:justify-end">
            <Button className="justify-center" disabled={busy} onClick={() => setDeleting(false)}>
              Cancel
            </Button>
            <Button
              variant="danger"
              className="justify-center"
              disabled={busy}
              onClick={() => {
                setBusy(true)
                api.delete(routes.soundLetter(chart.language, saved.id)).then(
                  () => navigate(`/sounds/${chart.language}`),
                  (e: unknown) => {
                    setDeleting(false)
                    setBusy(false)
                    setError(messageOf(e))
                  },
                )
              }}
            >
              Delete letter
            </Button>
          </div>
        </Modal>
      )}
    </main>
  )
}

function Field({ id, label, hint, children }: { id: string; label: string; hint?: string; children: ReactNode }) {
  return (
    <div className="min-w-0">
      <label htmlFor={id} className="mb-1.5 block text-sm font-semibold text-coffee">
        {label}
      </label>
      {children}
      {hint && <p className="mt-1 text-xs text-stone">{hint}</p>}
    </div>
  )
}

/** The same text in each app language. English is the fallback. */
function LocalizedFields({
  label,
  hint,
  value,
  max,
  onChange,
}: {
  label: string
  hint?: string
  value: Localized
  max: number
  onChange: (value: Localized) => void
}) {
  const base = useId()
  return (
    <fieldset className="mt-4">
      <legend className="text-sm font-semibold text-coffee">{label}</legend>
      {hint && <p className="mt-0.5 text-xs text-stone">{hint}</p>}
      <div className="mt-2 grid gap-3 sm:grid-cols-3">
        {APP_LANGUAGES.map(({ code, name }) => (
          <div key={code} className="min-w-0">
            <label htmlFor={`${base}-${code}`} className="mb-1 block text-xs font-semibold text-coffee-soft">
              {name}
            </label>
            <Input
              id={`${base}-${code}`}
              value={value[code] ?? ''}
              maxLength={max}
              onChange={(e) => onChange({ ...value, [code]: e.target.value })}
            />
          </div>
        ))}
      </div>
    </fieldset>
  )
}
