import { useEffect, useId, useMemo, useState, type FormEvent } from 'react'
import { Link, useNavigate } from 'react-router-dom'

import { messageOf, useSession } from '../auth/SessionContext'
import { plural } from '../format'
import { PageHeader } from '../shell/Page'
import { routes } from '../tree/levels'
import type { AdminLanguageList, AdminSoundChart, AdminSoundChartList, AdminSoundChartSummary } from '../types'
import { Badge } from '../ui/Badge'
import { Button } from '../ui/Button'
import { cx } from '../ui/cx'
import { Icon } from '../ui/Icon'
import { FIELD_CLASS } from '../ui/Input'
import { Modal } from '../ui/Modal'
import { TEMPLATES, englishOf } from './model'

/** Every language's Sounds chart: how far each has got, and a new one.
 * The app's Sounds tab shows a chart only once it is turned on. */
export function SoundsPage() {
  const { api } = useSession()
  const [charts, setCharts] = useState<AdminSoundChartSummary[] | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [creating, setCreating] = useState(false)
  const taken = useMemo(() => new Set(charts?.map((c) => c.language) ?? []), [charts])

  useEffect(() => {
    let live = true
    api.get<AdminSoundChartList>(routes.soundCharts).then(
      (list) => live && setCharts(list.charts),
      (e: unknown) => live && setError(messageOf(e)),
    )
    return () => {
      live = false
    }
  }, [api])

  return (
    <main className="mx-auto max-w-6xl px-4 py-6 sm:px-6 lg:px-8 lg:py-8">
      <PageHeader
        eyebrow="Workspace"
        title="Sounds"
        description="The letters of each language and how they sound, for the app’s Sounds tab. Start a chart from a template, record or upload each sound, then turn it on."
        actions={
          <Button variant="primary" onClick={() => setCreating(true)}>
            <Icon name="add" className="text-lg" />
            New chart
          </Button>
        }
      />

      {error && (
        <p
          role="alert"
          className="mt-6 flex items-center gap-3 rounded-md border border-danger-line bg-danger-tint px-4 py-3 text-sm text-danger"
        >
          <Icon name="error" className="text-lg" />
          {error}
        </p>
      )}

      {!charts && !error && <p className="mt-6 text-sm text-stone">Loading…</p>}

      {charts?.length === 0 && (
        <section className="mt-6 rounded-lg border border-dashed border-line-strong bg-surface px-6 py-12 text-center">
          <Icon name="graphic_eq" className="text-4xl text-stone" />
          <h2 className="mt-2 text-lg font-semibold text-coffee">No charts yet</h2>
          <p className="mx-auto mt-1 max-w-md text-sm text-stone">
            Start with Amharic from the Fidel template or Afaan Oromo from Qubee: every letter is filled in, so only the
            recordings are left.
          </p>
          <Button variant="primary" className="mt-4" onClick={() => setCreating(true)}>
            New chart
          </Button>
        </section>
      )}

      {charts && charts.length > 0 && (
        <ul className="mt-6 grid gap-4 md:grid-cols-2">
          {charts.map((chart) => (
            <li key={chart.language}>
              <ChartCard chart={chart} />
            </li>
          ))}
        </ul>
      )}

      {creating && (
        <NewChartDialog taken={taken} onClose={() => setCreating(false)} />
      )}
    </main>
  )
}

function ChartCard({ chart }: { chart: AdminSoundChartSummary }) {
  const { counts } = chart
  const recorded = counts.letters - counts.same_sound - counts.needs_recording
  const toRecord = counts.letters - counts.same_sound
  return (
    <Link
      to={`/sounds/${chart.language}`}
      className="block rounded-lg border border-line bg-surface p-5 shadow-e1 transition-colors hover:border-forest-line focus-visible:outline-2 focus-visible:outline-forest"
    >
      <div className="flex flex-wrap items-center gap-2">
        <h2 className="text-lg font-semibold text-coffee">
          {chart.language_name} · {englishOf(chart.title)}
        </h2>
        {chart.enabled ? (
          <Badge tone="published" dot>
            In the app
          </Badge>
        ) : (
          <Badge tone="neutral">Not in the app</Badge>
        )}
      </div>
      <p className="mt-1 text-sm text-stone">
        {plural(counts.letters, 'letter')} · {recorded} of {toRecord} sounds recorded · {counts.ready} ready
      </p>
      <div className="mt-3 h-2 overflow-hidden rounded-full bg-inset" aria-hidden="true">
        <div className="h-full rounded-full bg-forest" style={{ width: `${toRecord ? (recorded / toRecord) * 100 : 0}%` }} />
      </div>
    </Link>
  )
}

function NewChartDialog({ taken, onClose }: { taken: Set<string>; onClose: () => void }) {
  const { api } = useSession()
  const navigate = useNavigate()
  const ids = { language: useId(), template: useId() }
  const [languages, setLanguages] = useState<AdminLanguageList['languages'] | null>(null)
  const [language, setLanguage] = useState('')
  const [template, setTemplate] = useState<string>('fidel')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    let live = true
    api.get<AdminLanguageList>(routes.languages).then(
      (list) => {
        if (!live) return
        const open = list.languages.filter((l) => !taken.has(l.code) && l.code !== 'en')
        setLanguages(open)
        const first = open[0]
        if (first) {
          setLanguage(first.code)
          setTemplate(first.code === 'om' ? 'qubee' : first.code === 'am' ? 'fidel' : 'empty')
        }
      },
      (e: unknown) => live && setError(messageOf(e)),
    )
    return () => {
      live = false
    }
  }, [api, taken])

  async function submit(e: FormEvent) {
    e.preventDefault()
    if (!language || busy) return
    setBusy(true)
    setError(null)
    try {
      const chart = await api.post<AdminSoundChart>(routes.soundCharts, { language, template })
      navigate(`/sounds/${chart.language}`)
    } catch (err) {
      setError(messageOf(err))
      setBusy(false)
    }
  }

  return (
    <Modal title="New sounds chart" onClose={() => !busy && onClose()}>
      <form className="mt-5 space-y-4" onSubmit={(e) => void submit(e)}>
        <div>
          <label htmlFor={ids.language} className="mb-1.5 block text-sm font-semibold text-coffee">
            Language
          </label>
          <select
            id={ids.language}
            className={FIELD_CLASS}
            value={language}
            disabled={!languages?.length}
            onChange={(e) => setLanguage(e.target.value)}
          >
            {languages?.map((l) => (
              <option key={l.code} value={l.code}>
                {l.name} · {l.native_name}
              </option>
            ))}
          </select>
          {languages?.length === 0 && (
            <p className="mt-1 text-xs text-stone">Every language already has a chart.</p>
          )}
        </div>
        <fieldset>
          <legend id={ids.template} className="mb-1.5 text-sm font-semibold text-coffee">
            Start from
          </legend>
          <div className="space-y-2">
            {TEMPLATES.map((t) => (
              <label
                key={t.id}
                className={cx(
                  'flex cursor-pointer items-start gap-3 rounded border p-3',
                  template === t.id ? 'border-forest bg-forest-tint' : 'border-line bg-surface',
                )}
              >
                <input
                  type="radio"
                  name="template"
                  value={t.id}
                  checked={template === t.id}
                  onChange={() => setTemplate(t.id)}
                  className="mt-1 accent-forest"
                />
                <span>
                  <span className="block text-sm font-semibold text-coffee">{t.name}</span>
                  <span className="block text-xs text-stone">{t.description}</span>
                </span>
              </label>
            ))}
          </div>
        </fieldset>
        {error && (
          <p role="alert" className="text-sm text-danger">
            {error}
          </p>
        )}
        <div className="flex flex-col-reverse gap-2 sm:flex-row sm:justify-end">
          <Button className="justify-center" disabled={busy} onClick={onClose}>
            Cancel
          </Button>
          <Button type="submit" variant="primary" className="justify-center" disabled={busy || !language}>
            {busy ? 'Creating…' : 'Create chart'}
          </Button>
        </div>
      </form>
    </Modal>
  )
}
