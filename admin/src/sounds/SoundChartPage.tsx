import { useId, useRef, useState, type FormEvent, type ReactNode } from 'react'
import { Link, useNavigate, useParams } from 'react-router-dom'

import { messageOf, useSession } from '../auth/SessionContext'
import { saveFile, readText, CSV_TYPE } from '../import/download'
import { plural } from '../format'
import { PageHeader } from '../shell/Page'
import { routes } from '../tree/levels'
import type { AdminSoundChart, AdminSoundGroup, AdminSoundLetter, SoundLetterStatus } from '../types'
import { Badge } from '../ui/Badge'
import { Button } from '../ui/Button'
import { cx } from '../ui/cx'
import { Icon } from '../ui/Icon'
import { Input } from '../ui/Input'
import { Modal } from '../ui/Modal'
import {
  STATE_LABELS,
  STATUS_LABELS,
  chartToCsv,
  csvName,
  csvToChanges,
  englishOf,
  lettersOf,
  needingRecording,
  rowsOf,
  stateOf,
  type CsvResult,
  type LetterState,
} from './model'
import { useSoundChart } from './useSoundChart'

type Filter = 'all' | 'no_audio' | 'needs_review' | 'draft' | 'ready'

const FILTERS: { id: Filter; label: string }[] = [
  { id: 'all', label: 'All' },
  { id: 'no_audio', label: 'No audio' },
  { id: 'needs_review', label: 'Needs review' },
  { id: 'draft', label: 'Draft' },
  { id: 'ready', label: 'Ready' },
]

export const STATE_TONES: Record<LetterState, { dot: string; tile: string }> = {
  ready: { dot: 'bg-forest', tile: 'border-line bg-surface' },
  needs_review: { dot: 'bg-sky-600', tile: 'border-line bg-surface' },
  draft: { dot: 'bg-stone-soft', tile: 'border-line bg-surface' },
  no_audio: { dot: 'bg-terracotta', tile: 'border-dashed border-terracotta-line bg-terracotta-tint/40' },
  same_sound: { dot: 'bg-line-strong', tile: 'border-line bg-inset' },
}

/** A letter can be marked ready or for review only once it has a recording
 * of its own. */
const reviewable = (letter: AdminSoundLetter) => !letter.same_as_id && !!letter.audio_url

/** The letters picked to mark in one go, and how to change the pick. */
interface Selection {
  ids: Set<string>
  toggle: (id: string) => void
}

function shows(filter: Filter, letter: AdminSoundLetter): boolean {
  const state = stateOf(letter)
  if (filter === 'all') return true
  if (filter === 'no_audio') return state === 'no_audio'
  return state === filter
}

/** One language's chart: every letter as a tile showing where it stands,
 * the ways to fill it, and the switch that shows it in the app. */
export function SoundChartPage() {
  const { language = '' } = useParams()
  const { chart, error, setError, saveLetters, setEnabled, reload } = useSoundChart(language)
  const [filter, setFilter] = useState<Filter>('all')
  const [groupKey, setGroupKey] = useState<string | null>(null)
  const [turning, setTurning] = useState<'on' | 'off' | null>(null)
  const [csv, setCsv] = useState<CsvResult | null>(null)
  const [adding, setAdding] = useState(false)
  const [deleting, setDeleting] = useState(false)
  const [notice, setNotice] = useState<string | null>(null)
  const [selected, setSelected] = useState<Set<string> | null>(null)
  const [marking, setMarking] = useState<SoundLetterStatus | null>(null)
  const fileInput = useRef<HTMLInputElement>(null)

  if (!chart) {
    return (
      <main className="mx-auto max-w-6xl px-4 py-6 sm:px-6 lg:px-8 lg:py-8">
        {error ? <ErrorBar message={error} /> : <p className="text-sm text-stone">Loading…</p>}
      </main>
    )
  }

  const group = chart.groups.find((g) => g.key === groupKey) ?? chart.groups[0]
  const missing = needingRecording(chart).length
  const shown = group ? lettersOf(chart, group.key).filter((x) => reviewable(x) && shows(filter, x)) : []
  const picked = chart.letters.filter((x) => selected?.has(x.id))
  const changing = (status: SoundLetterStatus) => picked.filter((x) => x.status !== status)
  const selection: Selection | null = selected && {
    ids: selected,
    toggle: (id) =>
      setSelected((old) => {
        const next = new Set(old)
        if (!next.delete(id)) next.add(id)
        return next
      }),
  }

  async function importCsv(file: File | undefined) {
    if (!file || !chart) return
    setError(null)
    setCsv(csvToChanges(await readText(file), chart))
    if (fileInput.current) fileInput.current.value = ''
  }

  return (
    <main className="mx-auto max-w-6xl px-4 py-6 sm:px-6 lg:px-8 lg:py-8">
      <nav aria-label="Breadcrumb" className="mb-3 text-sm">
        <Link to="/sounds" className="text-forest hover:underline">
          Sounds
        </Link>
      </nav>
      <PageHeader
        eyebrow="Sounds"
        title={`${chart.language_name} · ${englishOf(chart.title)}`}
        description="Tap a letter to edit it and add its sound. Letters that sound the same as another play that one’s recording."
        actions={
          <>
            <input
              ref={fileInput}
              type="file"
              accept=".csv,text/csv"
              aria-label="CSV file to import"
              className="hidden"
              onChange={(e) => void importCsv(e.target.files?.[0])}
            />
            <Button onClick={() => fileInput.current?.click()}>
              <Icon name="upload_file" className="text-lg" />
              Import CSV
            </Button>
            <Button onClick={() => saveFile(csvName(chart), chartToCsv(chart), CSV_TYPE)}>
              <Icon name="download" className="text-lg" />
              Export CSV
            </Button>
            <Link
              to={`/sounds/${chart.language}/upload`}
              className="inline-flex h-11 items-center gap-2 rounded border border-line bg-surface px-4 text-sm font-semibold text-coffee hover:bg-inset sm:h-10"
            >
              <Icon name="library_music" className="text-lg" />
              Upload files
            </Link>
            <Link
              to={`/sounds/${chart.language}/record`}
              aria-disabled={missing === 0}
              className={cx(
                'inline-flex h-11 items-center gap-2 rounded border border-transparent bg-forest px-4 text-sm font-semibold text-white shadow-e1 hover:bg-forest-hover sm:h-10',
                missing === 0 && 'pointer-events-none opacity-45',
              )}
            >
              <Icon name="mic" className="text-lg" />
              Record missing ({missing})
            </Link>
          </>
        }
      />

      {error && <ErrorBar message={error} onRetry={() => void reload()} />}
      {notice && (
        <p role="status" className="mt-4 rounded-md bg-forest-tint px-4 py-3 text-sm text-forest">
          {notice}
        </p>
      )}

      <section className="mt-6 flex flex-wrap items-center gap-2" aria-label="Where the chart stands">
        <Count>{plural(chart.counts.letters, 'letter')}</Count>
        <Count tone="ready">{chart.counts.ready} ready</Count>
        <Count tone="needs_review">{chart.counts.needs_review} need review</Count>
        <Count tone="no_audio">{chart.counts.needs_recording} no audio</Count>
        {chart.counts.same_sound > 0 && <Count tone="same_sound">{chart.counts.same_sound} share a sound</Count>}
        <span className="ml-auto flex items-center gap-3">
          {chart.enabled ? (
            <Badge tone="published" dot>
              In the app
            </Badge>
          ) : (
            <Badge tone="neutral">Not in the app</Badge>
          )}
          <Button
            variant={chart.enabled ? 'outline' : 'primary'}
            size="sm"
            onClick={() => setTurning(chart.enabled ? 'off' : 'on')}
          >
            {chart.enabled ? 'Hide from the app' : 'Show in the app…'}
          </Button>
        </span>
      </section>

      <div className="mt-5 flex flex-wrap items-center gap-2">
        <div role="group" aria-label="Show letters" className="flex flex-wrap gap-1 rounded border border-line bg-inset p-1">
          {FILTERS.map((f) => (
            <button
              key={f.id}
              type="button"
              aria-pressed={filter === f.id}
              onClick={() => setFilter(f.id)}
              className={cx(
                'rounded px-3 py-1 text-[0.8125rem] font-semibold',
                filter === f.id ? 'bg-surface text-coffee shadow-e1' : 'text-stone hover:text-coffee',
              )}
            >
              {f.label}
            </button>
          ))}
        </div>
        {chart.groups.length > 1 && (
          <div role="tablist" aria-label="Group" className="flex flex-wrap gap-1">
            {chart.groups.map((g) => (
              <button
                key={g.key}
                type="button"
                role="tab"
                aria-selected={g.key === group?.key}
                onClick={() => setGroupKey(g.key)}
                className={cx(
                  'rounded-full border px-3 py-1 text-[0.8125rem] font-semibold',
                  g.key === group?.key
                    ? 'border-coffee bg-coffee text-white'
                    : 'border-line bg-surface text-coffee-soft hover:bg-inset',
                )}
              >
                {englishOf(g.names)} · {lettersOf(chart, g.key).length}
              </button>
            ))}
          </div>
        )}
        <span className="ml-auto flex gap-1">
          {!selected && (
            <Button
              size="sm"
              variant="ghost"
              onClick={() => {
                setNotice(null)
                setSelected(new Set())
              }}
            >
              <Icon name="checklist" className="text-lg" />
              Select letters
            </Button>
          )}
          <Button size="sm" variant="ghost" onClick={() => setAdding(true)}>
            <Icon name="add" className="text-lg" />
            Add letter
          </Button>
        </span>
      </div>

      {selected && (
        <div
          role="toolbar"
          aria-label="Selected letters"
          className="sticky top-0 z-10 mt-3 flex flex-wrap items-center gap-2 rounded-md border border-forest/30 bg-forest-tint px-3 py-2"
        >
          <span className="tnum text-sm font-semibold text-forest" aria-live="polite">
            {picked.length === 0 ? 'Tap letters to select them' : `${plural(picked.length, 'letter')} selected`}
          </span>
          <Button
            size="sm"
            variant="ghost"
            disabled={shown.length === 0 || shown.every((x) => selected.has(x.id))}
            onClick={() => setSelected(new Set([...selected, ...shown.map((x) => x.id)]))}
          >
            Select all shown ({shown.length})
          </Button>
          {picked.length > 0 && (
            <Button size="sm" variant="ghost" onClick={() => setSelected(new Set())}>
              Clear
            </Button>
          )}
          <span className="ml-auto flex flex-wrap gap-2">
            <Button size="sm" disabled={changing('needs_review').length === 0} onClick={() => setMarking('needs_review')}>
              Mark needs review
            </Button>
            <Button size="sm" variant="primary" disabled={changing('ready').length === 0} onClick={() => setMarking('ready')}>
              <Icon name="done_all" className="text-lg" />
              Mark ready
            </Button>
            <Button size="sm" variant="ghost" onClick={() => setSelected(null)}>
              Done
            </Button>
          </span>
        </div>
      )}

      {group && <GroupGrid chart={chart} group={group} filter={filter} selection={selection} />}

      <Legend />

      {!chart.enabled && (
        <div className="mt-10 border-t border-line pt-4">
          <Button variant="danger-ghost" size="sm" onClick={() => setDeleting(true)}>
            <Icon name="delete" className="text-lg" />
            Delete this chart
          </Button>
        </div>
      )}

      {turning === 'on' && (
        <TurnOnDialog
          chart={chart}
          onClose={() => setTurning(null)}
          onConfirm={async () => {
            await setEnabled(true)
            setTurning(null)
            setNotice('The chart is on. Learners see the Sounds tab the next time the app opens.')
          }}
        />
      )}
      {turning === 'off' && (
        <ConfirmDialog
          title="Hide the chart from the app?"
          body="Learners of this language lose the Sounds tab the next time the app opens. Nothing is deleted."
          confirm="Hide it"
          onClose={() => setTurning(null)}
          onConfirm={async () => {
            await setEnabled(false)
            setTurning(null)
            setNotice(null)
          }}
        />
      )}
      {csv && (
        <CsvDialog
          result={csv}
          onClose={() => setCsv(null)}
          onApply={async () => {
            await saveLetters(csv.changes)
            setNotice(`Imported changes to ${plural(csv.changes.length, 'letter')}.`)
            setCsv(null)
          }}
        />
      )}
      {adding && group && (
        <AddLetterDialog
          language={chart.language}
          group={group}
          onClose={() => setAdding(false)}
          onAdded={async () => {
            setAdding(false)
            await reload()
          }}
        />
      )}
      {marking && (
        <ConfirmDialog
          title={`Mark ${plural(changing(marking).length, 'letter')} ${STATUS_LABELS[marking].toLowerCase()}?`}
          body={
            marking === 'ready'
              ? 'Ready means a native speaker has listened to each recording and it sounds right. Recordings stay as they are.'
              : 'They go back on the list for a native speaker to check. Recordings stay as they are.'
          }
          confirm={`Mark ${STATUS_LABELS[marking].toLowerCase()}`}
          onClose={() => setMarking(null)}
          onConfirm={async () => {
            const changes = changing(marking).map((x) => ({ id: x.id, status: marking }))
            await saveLetters(changes)
            setNotice(`${plural(changes.length, 'letter')} marked ${STATUS_LABELS[marking]}.`)
            setMarking(null)
            setSelected(null)
          }}
        />
      )}
      {deleting && <DeleteChartDialog chart={chart} onClose={() => setDeleting(false)} />}
    </main>
  )
}

function ErrorBar({ message, onRetry }: { message: string; onRetry?: () => void }) {
  return (
    <div
      role="alert"
      className="mt-6 flex flex-wrap items-center gap-3 rounded-md border border-danger-line bg-danger-tint px-4 py-3 text-sm text-danger"
    >
      <Icon name="error" className="text-lg" />
      <span className="flex-1">{message}</span>
      {onRetry && (
        <Button size="sm" onClick={onRetry}>
          Try again
        </Button>
      )}
    </div>
  )
}

const COUNT_TONES: Record<LetterState | 'plain', string> = {
  plain: 'bg-inset text-coffee-soft',
  ready: 'bg-forest-tint text-forest',
  needs_review: 'bg-sky-50 text-sky-700',
  draft: 'bg-inset text-stone',
  no_audio: 'bg-terracotta-tint text-terracotta',
  same_sound: 'bg-inset text-stone',
}

function Count({ tone = 'plain', children }: { tone?: LetterState | 'plain'; children: ReactNode }) {
  return (
    <span className={cx('tnum rounded-full px-3 py-1 text-xs font-bold', COUNT_TONES[tone])}>{children}</span>
  )
}

function Legend() {
  const states: LetterState[] = ['ready', 'needs_review', 'draft', 'no_audio', 'same_sound']
  return (
    <ul className="mt-4 flex flex-wrap gap-4 text-xs text-stone" aria-label="Key">
      {states.map((s) => (
        <li key={s} className="flex items-center gap-1.5">
          <span aria-hidden="true" className={cx('size-2 rounded-full', STATE_TONES[s].dot)} />
          {STATE_LABELS[s]}
        </li>
      ))}
    </ul>
  )
}

function GroupGrid({
  chart,
  group,
  filter,
  selection,
}: {
  chart: AdminSoundChart
  group: AdminSoundGroup
  filter: Filter
  selection: Selection | null
}) {
  const letters = lettersOf(chart, group.key)
  if (letters.length === 0) {
    return <p className="mt-6 text-sm text-stone">This group has no letters yet. Use “Add letter”.</p>
  }
  const byId = new Map(chart.letters.map((x) => [x.id, x]))
  const tile = (letter: AdminSoundLetter) => (
    <Tile
      key={letter.id}
      chart={chart}
      letter={letter}
      dim={!shows(filter, letter) || (!!selection && !reviewable(letter))}
      sameAs={byId.get(letter.same_as_id ?? '')}
      selection={selection}
    />
  )

  if (group.columns) {
    return (
      <div className="mt-4 overflow-x-auto">
        <table className="border-separate border-spacing-1" aria-label={englishOf(group.names)}>
          <thead>
            <tr>
              <th scope="col" className="w-8" />
              {group.column_labels.map((label, i) => (
                <th key={i} scope="col" className="text-xs font-bold text-stone">
                  {label}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {rowsOf(group, letters).map((row, r) => (
              <tr key={row[0]!.id}>
                <th scope="row" className="tnum pr-1 text-right text-xs font-medium text-stone-soft">
                  {r + 1}
                </th>
                {row.map((letter) => (
                  <td key={letter.id}>{tile(letter)}</td>
                ))}
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    )
  }
  return <ul className="mt-4 grid grid-cols-[repeat(auto-fill,minmax(4.5rem,1fr))] gap-1.5">{letters.map((x) => <li key={x.id}>{tile(x)}</li>)}</ul>
}

function Tile({
  chart,
  letter,
  dim,
  sameAs,
  selection,
}: {
  chart: AdminSoundChart
  letter: AdminSoundLetter
  dim: boolean
  sameAs?: AdminSoundLetter
  selection: Selection | null
}) {
  const state = stateOf(letter)
  const label = `${letter.glyph}, ${letter.romanization || 'no romanization'}: ${STATE_LABELS[state]}${sameAs ? ` as ${sameAs.glyph}` : ''}`
  const picked = !!selection?.ids.has(letter.id)
  const className = cx(
    'relative flex min-w-[3.25rem] flex-col items-center rounded border px-1.5 pt-1.5 pb-1 transition-[opacity,box-shadow] hover:shadow-e1',
    'focus-visible:outline-2 focus-visible:outline-forest',
    STATE_TONES[state].tile,
    picked && 'border-forest bg-forest-tint ring-2 ring-forest',
    dim && 'opacity-30',
  )
  const face = (
    <>
      {picked ? (
        <Icon name="check_circle" filled className="absolute -top-1.5 -right-1.5 rounded-full bg-surface text-base text-forest" />
      ) : (
        <span aria-hidden="true" className={cx('absolute top-1 right-1 size-1.5 rounded-full', STATE_TONES[state].dot)} />
      )}
      <span className={cx('text-lg leading-6 font-semibold', state === 'same_sound' ? 'text-stone' : 'text-coffee')}>
        {letter.glyph}
      </span>
      <span className="font-mono text-[0.625rem] text-stone">{letter.romanization || '—'}</span>
    </>
  )
  if (selection) {
    const can = reviewable(letter)
    return (
      <button
        type="button"
        aria-label={label}
        aria-pressed={picked}
        title={can ? label : `${label}. Needs a recording of its own to be marked.`}
        disabled={!can}
        onClick={() => selection.toggle(letter.id)}
        className={cx(className, 'w-full', can ? 'cursor-pointer' : 'cursor-not-allowed hover:shadow-none')}
      >
        {face}
      </button>
    )
  }
  return (
    <Link to={`/sounds/${chart.language}/letters/${letter.id}`} aria-label={label} title={label} className={className}>
      {face}
    </Link>
  )
}

function ConfirmDialog({
  title,
  body,
  confirm,
  onClose,
  onConfirm,
}: {
  title: string
  body: string
  confirm: string
  onClose: () => void
  onConfirm: () => Promise<void>
}) {
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)
  return (
    <Modal title={title} onClose={() => !busy && onClose()}>
      <p className="mt-2 text-sm leading-6 text-coffee-soft">{body}</p>
      {error && (
        <p role="alert" className="mt-3 text-sm text-danger">
          {error}
        </p>
      )}
      <div className="mt-6 flex flex-col-reverse gap-2 sm:flex-row sm:justify-end">
        <Button className="justify-center" disabled={busy} onClick={onClose}>
          Cancel
        </Button>
        <Button
          variant="primary"
          className="justify-center"
          disabled={busy}
          onClick={() => {
            setBusy(true)
            onConfirm().catch((e: unknown) => {
              setError(messageOf(e))
              setBusy(false)
            })
          }}
        >
          {confirm}
        </Button>
      </div>
    </Modal>
  )
}

function TurnOnDialog({
  chart,
  onClose,
  onConfirm,
}: {
  chart: AdminSoundChart
  onClose: () => void
  onConfirm: () => Promise<void>
}) {
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const { gaps, counts } = chart
  const sounds = counts.letters - counts.same_sound
  const checks = [
    {
      ok: !gaps.no_letters,
      title: 'The chart has letters',
      detail: gaps.no_letters ? 'Add at least one letter.' : plural(counts.letters, 'letter'),
    },
    {
      ok: gaps.no_romanization === 0,
      title: 'Every letter has a romanization',
      detail:
        gaps.no_romanization === 0
          ? `${counts.letters} of ${counts.letters}`
          : `${plural(gaps.no_romanization, 'letter')} still need one.`,
    },
    {
      ok: gaps.no_audio === 0,
      title: 'Every sound has audio',
      detail:
        gaps.no_audio === 0
          ? `${sounds} recordings${counts.same_sound ? `, shared by ${counts.same_sound} letters that sound the same` : ''}`
          : `${counts.needs_recording} of ${sounds} still need a recording.`,
    },
  ]
  const ready = checks.every((c) => c.ok)
  return (
    <Modal title="Show this chart in the app?" onClose={() => !busy && onClose()} className="sm:max-w-lg">
      <ul className="mt-4 space-y-3">
        {checks.map((c) => (
          <li key={c.title} className="flex items-start gap-3">
            <span
              aria-hidden="true"
              className={cx(
                'grid size-6 shrink-0 place-items-center rounded-full',
                c.ok ? 'bg-forest-tint text-forest' : 'bg-danger-tint text-danger',
              )}
            >
              <Icon name={c.ok ? 'check' : 'close'} className="text-base" />
            </span>
            <span>
              <span className="block text-sm font-semibold text-coffee">
                <span className="sr-only">{c.ok ? 'Done: ' : 'Not yet: '}</span>
                {c.title}
              </span>
              <span className="block text-xs text-stone">{c.detail}</span>
            </span>
          </li>
        ))}
        {counts.needs_review > 0 && (
          <li className="flex items-start gap-3">
            <span aria-hidden="true" className="grid size-6 shrink-0 place-items-center rounded-full bg-terracotta-tint text-terracotta">
              !
            </span>
            <span>
              <span className="block text-sm font-semibold text-coffee">
                {plural(counts.needs_review, 'letter')} still need review
              </span>
              <span className="block text-xs text-stone">Allowed, but a native speaker should check them soon.</span>
            </span>
          </li>
        )}
      </ul>
      <p className="mt-4 text-sm leading-6 text-coffee-soft">
        Learners of {chart.language_name} see the Sounds tab the next time the app opens, and the chart downloads for
        use offline. Later changes reach phones on their next launch.
      </p>
      {error && (
        <p role="alert" className="mt-3 text-sm text-danger">
          {error}
        </p>
      )}
      <div className="mt-6 flex flex-col-reverse gap-2 sm:flex-row sm:justify-end">
        <Button className="justify-center" disabled={busy} onClick={onClose}>
          Cancel
        </Button>
        <Button
          variant="primary"
          className="justify-center"
          disabled={busy || !ready}
          onClick={() => {
            setBusy(true)
            onConfirm().catch((e: unknown) => {
              setError(messageOf(e))
              setBusy(false)
            })
          }}
        >
          Show in the app
        </Button>
      </div>
    </Modal>
  )
}

function CsvDialog({ result, onClose, onApply }: { result: CsvResult; onClose: () => void; onApply: () => Promise<void> }) {
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)
  return (
    <Modal title="Import from CSV" onClose={() => !busy && onClose()} className="sm:max-w-lg">
      <p className="mt-2 text-sm leading-6 text-coffee-soft">
        {result.changes.length === 0
          ? 'Nothing in the file differs from the chart.'
          : `${plural(result.changes.length, 'letter')} will change. Recordings are not in the file and stay as they are.`}
      </p>
      {result.problems.length > 0 && (
        <div className="mt-3 rounded bg-danger-tint p-3">
          <p className="text-sm font-semibold text-danger">
            {plural(result.problems.length, 'row')} can’t be used and will be skipped:
          </p>
          <ul className="mt-1 max-h-40 list-disc overflow-y-auto pl-5 text-xs text-danger">
            {result.problems.map((p) => (
              <li key={p.line}>
                Line {p.line}: {p.message}
              </li>
            ))}
          </ul>
        </div>
      )}
      {error && (
        <p role="alert" className="mt-3 text-sm text-danger">
          {error}
        </p>
      )}
      <div className="mt-6 flex flex-col-reverse gap-2 sm:flex-row sm:justify-end">
        <Button className="justify-center" disabled={busy} onClick={onClose}>
          Cancel
        </Button>
        <Button
          variant="primary"
          className="justify-center"
          disabled={busy || result.changes.length === 0}
          onClick={() => {
            setBusy(true)
            onApply().catch((e: unknown) => {
              setError(messageOf(e))
              setBusy(false)
            })
          }}
        >
          Import {result.changes.length > 0 ? plural(result.changes.length, 'change') : ''}
        </Button>
      </div>
    </Modal>
  )
}

function AddLetterDialog({
  language,
  group,
  onClose,
  onAdded,
}: {
  language: string
  group: AdminSoundGroup
  onClose: () => void
  onAdded: () => Promise<void>
}) {
  const { api } = useSession()
  const ids = { glyph: useId(), romanization: useId() }
  const [glyph, setGlyph] = useState('')
  const [romanization, setRomanization] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  async function submit(e: FormEvent) {
    e.preventDefault()
    if (!glyph.trim() || busy) return
    setBusy(true)
    setError(null)
    try {
      await api.post(routes.soundLetters(language), {
        group: group.key,
        glyph: glyph.trim(),
        romanization: romanization.trim(),
      })
      await onAdded()
    } catch (err) {
      setError(messageOf(err))
      setBusy(false)
    }
  }

  return (
    <Modal title={`Add a letter to ${englishOf(group.names)}`} onClose={() => !busy && onClose()}>
      <form className="mt-5 space-y-4" onSubmit={(e) => void submit(e)}>
        <div className="grid gap-4 sm:grid-cols-2">
          <div>
            <label htmlFor={ids.glyph} className="mb-1.5 block text-sm font-semibold text-coffee">
              Letter
            </label>
            <Input id={ids.glyph} value={glyph} maxLength={16} onChange={(e) => setGlyph(e.target.value)} />
          </div>
          <div>
            <label htmlFor={ids.romanization} className="mb-1.5 block text-sm font-semibold text-coffee">
              Romanization
            </label>
            <Input
              id={ids.romanization}
              value={romanization}
              maxLength={32}
              onChange={(e) => setRomanization(e.target.value)}
            />
          </div>
        </div>
        <p className="text-xs text-stone">It goes at the end of the group. Add its sound from the letter’s page.</p>
        {error && (
          <p role="alert" className="text-sm text-danger">
            {error}
          </p>
        )}
        <div className="flex flex-col-reverse gap-2 sm:flex-row sm:justify-end">
          <Button className="justify-center" disabled={busy} onClick={onClose}>
            Cancel
          </Button>
          <Button type="submit" variant="primary" className="justify-center" disabled={busy || !glyph.trim()}>
            Add letter
          </Button>
        </div>
      </form>
    </Modal>
  )
}

function DeleteChartDialog({ chart, onClose }: { chart: AdminSoundChart; onClose: () => void }) {
  const { api } = useSession()
  const navigate = useNavigate()
  return (
    <ConfirmDialog
      title={`Delete the ${chart.language_name} chart?`}
      body={`All ${plural(chart.counts.letters, 'letter')} and their details go. Uploaded recordings stay in storage but are no longer used.`}
      confirm="Delete chart"
      onClose={onClose}
      onConfirm={async () => {
        await api.delete(routes.soundChart(chart.language))
        navigate('/sounds')
      }}
    />
  )
}
