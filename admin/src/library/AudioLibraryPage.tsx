import { useCallback, useEffect, useMemo, useState, type ReactNode } from 'react'
import { Link } from 'react-router-dom'

import { messageOf, useSession } from '../auth/SessionContext'
import { PageHeader, StatCard, StatRow } from '../shell/Page'
import { Badge } from '../ui/Badge'
import { Button } from '../ui/Button'
import { cx } from '../ui/cx'
import { Icon } from '../ui/Icon'
import { FIELD_CLASS, Input } from '../ui/Input'
import { Modal } from '../ui/Modal'
import { usePlayer } from '../voices/usePlayer'
import {
  describeUse,
  fileNameOf,
  folderOf,
  formatBytes,
  formatOf,
  LIBRARY,
  LIBRARY_DELETE,
  LIBRARY_RESTORE,
  LIBRARY_TRASH,
  partsOfUse,
  type AudioFile,
  type AudioLibrary,
  type AudioUse,
} from './api'
import { ExportDialog } from './ExportDialog'

type Tab = 'files' | 'missing' | 'trash'
type Status = '' | 'in_use' | 'unused'
type Source = '' | 'recorded' | 'generated'
type SortKey = 'name' | 'size' | 'uploaded'
type Sort = { key: SortKey; dir: 'asc' | 'desc' }
type Confirm = { kind: 'trash' | 'delete'; keys: string[]; bytes: number }

const PAGE = 100
const DEFAULT_SORT: Sort = { key: 'uploaded', dir: 'desc' }

const when = (iso: string) =>
  new Date(iso).toLocaleString('en-GB', { day: 'numeric', month: 'short', year: 'numeric' })

const TH = 'px-3 py-2.5 text-left text-xs font-semibold whitespace-nowrap text-stone'
const TD = 'px-3 py-3 align-top'

/** Every stored audio file and what uses it (intent 029). Super admins
 * hear a file, open where it is used to replace it, move unused files to
 * the trash, and export a backup. */
export function AudioLibraryPage() {
  const { api } = useSession()
  const player = usePlayer()
  const [library, setLibrary] = useState<AudioLibrary | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [tab, setTab] = useState<Tab>('files')
  const [search, setSearch] = useState('')
  const [courseId, setCourseId] = useState('')
  const [status, setStatus] = useState<Status>('')
  const [source, setSource] = useState<Source>('')
  const [format, setFormat] = useState('')
  const [sort, setSort] = useState<Sort>(DEFAULT_SORT)
  const [shown, setShown] = useState(PAGE)
  const [selected, setSelected] = useState<Set<string>>(new Set())
  const [confirm, setConfirm] = useState<Confirm | null>(null)
  const [busy, setBusy] = useState(false)
  const [confirmError, setConfirmError] = useState<string | null>(null)
  const [exporting, setExporting] = useState(false)
  const [playProblem, setPlayProblem] = useState<string | null>(null)

  const load = useCallback(async () => {
    try {
      setLibrary(await api.get<AudioLibrary>(LIBRARY))
      setError(null)
    } catch (e) {
      setError(messageOf(e))
    }
  }, [api])

  useEffect(() => {
    let live = true
    api.get<AudioLibrary>(LIBRARY).then(
      (lib) => live && setLibrary(lib),
      (e: unknown) => live && setError(messageOf(e)),
    )
    return () => {
      live = false
    }
  }, [api])

  const formats = useMemo(() => {
    const counts = new Map<string, number>()
    for (const f of library?.files ?? []) counts.set(formatOf(f.key), (counts.get(formatOf(f.key)) ?? 0) + 1)
    return [...counts].sort((a, b) => b[1] - a[1])
  }, [library])

  const course = library?.courses.find((c) => c.id === courseId) ?? null
  const files = useMemo(() => {
    if (!library) return []
    const needle = search.trim().toLowerCase()
    const matching = library.files.filter((f) => {
      if (status && f.status !== status) return false
      if (source && f.source !== source) return false
      if (format && formatOf(f.key) !== format) return false
      if (course) {
        const inCourse = f.uses.some((u) =>
          u.place.startsWith('sound') ? u.language === course.learning_language : u.course_id === course.id,
        )
        if (!inCourse && !(f.uses.length === 0 && f.language === course.learning_language)) return false
      }
      if (needle) {
        const haystack = [f.key, ...f.uses.map((u) => `${describeUse(u)} ${u.prompt ?? ''} ${u.text ?? ''}`)]
        if (!haystack.join(' ').toLowerCase().includes(needle)) return false
      }
      return true
    })
    const sign = sort.dir === 'asc' ? 1 : -1
    return matching.sort((a, b) => {
      const by =
        sort.key === 'size'
          ? a.size - b.size
          : sort.key === 'name'
            ? fileNameOf(a.key).localeCompare(fileNameOf(b.key))
            : a.uploaded_at.localeCompare(b.uploaded_at)
      return sign * (by || a.key.localeCompare(b.key))
    })
  }, [library, search, status, source, format, course, sort])

  const filtered = Boolean(search.trim() || courseId || status || source || format)
  const trashable = files.filter((f) => f.can_trash)
  const tabKeys = tab === 'trash' ? new Set(library?.trash.map((t) => t.key)) : new Set(files.map((f) => f.key))
  const picked = [...selected].filter((k) => tabKeys.has(k))
  const sizeOf = (keys: string[]) => {
    const all = [...(library?.files ?? []), ...(library?.trash ?? [])]
    return all.filter((f) => keys.includes(f.key)).reduce((sum, f) => sum + f.size, 0)
  }

  function toggle(key: string) {
    setSelected((s) => {
      const next = new Set(s)
      if (next.has(key)) next.delete(key)
      else next.add(key)
      return next
    })
  }

  function toggleAll(keys: string[]) {
    const all = keys.length > 0 && keys.every((k) => selected.has(k))
    setSelected(all ? new Set() : new Set(keys))
  }

  function switchTab(next: Tab) {
    setTab(next)
    setSelected(new Set())
    setShown(PAGE)
  }

  function sortBy(key: SortKey) {
    setSort((s) => (s.key === key ? { key, dir: s.dir === 'asc' ? 'desc' : 'asc' } : { key, dir: key === 'name' ? 'asc' : 'desc' }))
  }

  function clearFilters() {
    setSearch('')
    setCourseId('')
    setStatus('')
    setSource('')
    setFormat('')
    setShown(PAGE)
  }

  async function play(file: { key: string; url: string }) {
    setPlayProblem(null)
    if (player.playing === file.key) return player.stop()
    if (!(await player.play(file.key, file.url))) setPlayProblem(`${file.key} could not be played in this browser.`)
  }

  async function act(path: string, keys: string[]) {
    setBusy(true)
    setConfirmError(null)
    try {
      await api.post(path, { keys })
      setConfirm(null)
      setSelected(new Set())
      await load()
    } catch (e) {
      setConfirmError(messageOf(e))
    } finally {
      setBusy(false)
    }
  }

  const t = library?.totals
  const shownBytes = files.reduce((sum, f) => sum + f.size, 0)

  return (
    <main className="mx-auto max-w-7xl px-4 py-6 sm:px-6 lg:px-8 lg:py-8">
      <PageHeader
        eyebrow="Configuration"
        title="Audio library"
        description="Every audio file in storage and where it is used. Open a use to record or replace its audio, clear out files nothing uses, and export a backup."
        actions={
          <Button variant="primary" disabled={!library} onClick={() => setExporting(true)}>
            <Icon name="download" className="text-lg" />
            Export backup
          </Button>
        }
      />

      {error && (
        <div
          role="alert"
          className="mt-6 flex flex-wrap items-center gap-3 rounded-md border border-danger-line bg-danger-tint px-4 py-3 text-sm text-danger"
        >
          <Icon name="error" className="text-lg" />
          <span className="flex-1">{error}</span>
          <Button size="sm" onClick={() => void load()}>
            Try again
          </Button>
        </div>
      )}

      {t && (
        <StatRow>
          <StatCard icon="library_music" label="Files" value={t.files} />
          <StatCard icon="cloud" label="Storage used" value={formatBytes(t.bytes)} />
          <StatCard icon="link_off" label="Not used" value={t.unused} tone={t.unused ? 'terracotta' : 'forest'} />
          <StatCard icon="report" label="Missing files" value={t.missing} tone={t.missing ? 'terracotta' : 'forest'} />
        </StatRow>
      )}

      {library && (
        <>
          <div className="mt-6 flex flex-wrap items-center gap-3">
            <div className="flex rounded bg-inset p-1" role="group" aria-label="Show">
              {(
                [
                  ['files', `Files (${library.totals.files})`],
                  ['missing', `Missing (${library.totals.missing})`],
                  ['trash', `Trash (${library.totals.trash})`],
                ] as const
              ).map(([key, label]) => (
                <button
                  key={key}
                  type="button"
                  aria-pressed={tab === key}
                  onClick={() => switchTab(key)}
                  className={cx(
                    'rounded-sm px-3 py-1.5 text-sm font-semibold transition-colors',
                    tab === key ? 'bg-surface text-forest shadow-e1' : 'text-stone hover:text-coffee',
                  )}
                >
                  {label}
                </button>
              ))}
            </div>
            <span className="text-xs text-stone">
              {library.storage === 'local' ? 'Stored on this computer (local development).' : 'Stored on Cloudflare R2.'}
              {library.external_links > 0 &&
                ` ${library.external_links} ${library.external_links === 1 ? 'link points' : 'links point'} to audio elsewhere.`}
            </span>
          </div>

          {playProblem && (
            <p role="alert" className="mt-3 text-sm text-danger">
              {playProblem}
            </p>
          )}

          {tab === 'files' && (
            <section className="mt-4 overflow-hidden rounded-lg border border-line bg-surface shadow-e1">
              <div className="flex flex-col gap-3 border-b border-line px-4 py-4 sm:px-5">
                <div className="grid grid-cols-1 gap-2 sm:grid-cols-2 lg:grid-cols-[minmax(14rem,2fr)_repeat(4,minmax(0,1fr))]">
                  <label className="relative min-w-0 sm:col-span-2 lg:col-span-1">
                    <span className="sr-only">Search</span>
                    <Icon
                      name="search"
                      className="pointer-events-none absolute top-1/2 left-3 -translate-y-1/2 text-lg text-stone"
                    />
                    <Input
                      type="search"
                      value={search}
                      onChange={(e) => setSearch(e.target.value)}
                      placeholder="File, lesson or text"
                      className="pl-9"
                    />
                  </label>
                  <Filter label="Course" value={courseId} onChange={setCourseId}>
                    <option value="">All courses</option>
                    {library.courses.map((c) => (
                      <option key={c.id} value={c.id}>
                        {c.title}
                      </option>
                    ))}
                  </Filter>
                  <Filter label="Status" value={status} onChange={(v) => setStatus(v as Status)}>
                    <option value="">Any status</option>
                    <option value="in_use">In use</option>
                    <option value="unused">Not used</option>
                  </Filter>
                  <Filter label="Source" value={source} onChange={(v) => setSource(v as Source)}>
                    <option value="">Any source</option>
                    <option value="recorded">Recorded or uploaded</option>
                    <option value="generated">Generated by Addis AI</option>
                  </Filter>
                  <Filter label="Format" value={format} onChange={setFormat}>
                    <option value="">Any format</option>
                    {formats.map(([f, n]) => (
                      <option key={f} value={f}>
                        {f} ({n})
                      </option>
                    ))}
                  </Filter>
                </div>
                <div className="flex flex-wrap items-center gap-x-3 gap-y-2">
                  <span className="text-sm text-coffee-soft">
                    {filtered
                      ? `${files.length} of ${library.files.length} files · ${formatBytes(shownBytes)}`
                      : `${files.length} files · ${formatBytes(shownBytes)}`}
                  </span>
                  {filtered && (
                    <Button size="sm" variant="ghost" onClick={clearFilters}>
                      <Icon name="filter_alt_off" className="text-lg" />
                      Clear filters
                    </Button>
                  )}
                  <span className="flex-1" />
                  {trashable.length > 0 && (
                    <Button size="sm" variant="ghost" onClick={() => setSelected(new Set(trashable.map((f) => f.key)))}>
                      Select all not used ({trashable.length})
                    </Button>
                  )}
                  <Button
                    variant="danger"
                    size="sm"
                    disabled={picked.length === 0}
                    onClick={() => {
                      setConfirmError(null)
                      setConfirm({ kind: 'trash', keys: picked, bytes: sizeOf(picked) })
                    }}
                  >
                    <Icon name="delete" className="text-lg" />
                    {picked.length ? `Move ${picked.length} to trash` : 'Move to trash'}
                  </Button>
                </div>
              </div>

              {files.length === 0 ? (
                <p className="px-4 py-12 text-center text-sm text-stone">No audio files match these filters.</p>
              ) : (
                <div className="overflow-x-auto">
                  <table className="w-full min-w-[64rem] text-sm">
                    <thead className="bg-canvas">
                      <tr>
                        <th scope="col" className={cx(TH, 'w-10 pl-4 sm:pl-5')}>
                          <input
                            type="checkbox"
                            aria-label="Select every file shown that nothing uses"
                            disabled={trashable.length === 0}
                            checked={trashable.length > 0 && trashable.every((f) => selected.has(f.key))}
                            onChange={() => toggleAll(trashable.map((f) => f.key))}
                            className="size-4 accent-forest"
                          />
                        </th>
                        <SortHeader label="File" sortKey="name" sort={sort} onSort={sortBy} />
                        <th scope="col" className={TH}>
                          Format
                        </th>
                        <SortHeader label="Size" sortKey="size" sort={sort} onSort={sortBy} align="right" />
                        <SortHeader label="Uploaded" sortKey="uploaded" sort={sort} onSort={sortBy} />
                        <th scope="col" className={TH}>
                          Source
                        </th>
                        <th scope="col" className={TH}>
                          Status
                        </th>
                        <th scope="col" className={cx(TH, 'pr-4 sm:pr-5')}>
                          Used in
                        </th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-line">
                      {files.slice(0, shown).map((f) => (
                        <FileRow
                          key={f.key}
                          file={f}
                          selected={selected.has(f.key)}
                          onToggle={() => toggle(f.key)}
                          playing={player.playing === f.key}
                          onPlay={() => void play(f)}
                        />
                      ))}
                    </tbody>
                  </table>
                </div>
              )}
              {files.length > shown && (
                <div className="flex justify-center border-t border-line px-4 py-3">
                  <Button onClick={() => setShown((n) => n + PAGE)}>Show more ({files.length - shown} left)</Button>
                </div>
              )}
            </section>
          )}

          {tab === 'missing' && (
            <section className="mt-4 overflow-hidden rounded-lg border border-line bg-surface shadow-e1">
              <div className="border-b border-line px-4 py-3 sm:px-5">
                <p className="text-sm text-coffee-soft">
                  These places link to audio that is no longer in storage, so learners hear nothing. Open each one and
                  record or upload the audio again.
                </p>
              </div>
              {library.missing.length === 0 ? (
                <p className="px-4 py-12 text-center text-sm text-stone">Every link has its file.</p>
              ) : (
                <div className="overflow-x-auto">
                  <table className="w-full min-w-[44rem] text-sm">
                    <thead className="bg-canvas">
                      <tr>
                        <th scope="col" className={cx(TH, 'pl-4 sm:pl-5')}>
                          Missing file
                        </th>
                        <th scope="col" className={cx(TH, 'pr-4 sm:pr-5')}>
                          Linked from
                        </th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-line">
                      {library.missing.map((m) => (
                        <tr key={m.key} className="hover:bg-canvas">
                          <td className={cx(TD, 'pl-4 sm:pl-5')}>
                            <FileName fileKey={m.key} />
                          </td>
                          <td className={cx(TD, 'pr-4 sm:pr-5')}>
                            <Uses uses={m.uses} />
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )}
            </section>
          )}

          {tab === 'trash' && (
            <section className="mt-4 overflow-hidden rounded-lg border border-line bg-surface shadow-e1">
              <div className="flex flex-wrap items-center gap-2 border-b border-line px-4 py-3 sm:px-5">
                <span className="text-sm text-coffee-soft">
                  {picked.length === 0
                    ? `${library.trash.length} in the trash · ${formatBytes(library.totals.trash_bytes)}`
                    : `${picked.length} selected · ${formatBytes(sizeOf(picked))}`}
                </span>
                <span className="flex-1" />
                <Button size="sm" disabled={picked.length === 0 || busy} onClick={() => void act(LIBRARY_RESTORE, picked)}>
                  <Icon name="restore_from_trash" className="text-lg" />
                  Restore
                </Button>
                <Button
                  variant="danger"
                  size="sm"
                  disabled={picked.length === 0}
                  onClick={() => {
                    setConfirmError(null)
                    setConfirm({ kind: 'delete', keys: picked, bytes: sizeOf(picked) })
                  }}
                >
                  <Icon name="delete_forever" className="text-lg" />
                  Delete for good
                </Button>
              </div>
              {!confirm && confirmError && (
                <p role="alert" className="px-4 pt-3 text-sm text-danger sm:px-5">
                  {confirmError}
                </p>
              )}
              {library.trash.length === 0 ? (
                <p className="px-4 py-12 text-center text-sm text-stone">The trash is empty.</p>
              ) : (
                <div className="overflow-x-auto">
                  <table className="w-full min-w-[40rem] text-sm">
                    <thead className="bg-canvas">
                      <tr>
                        <th scope="col" className={cx(TH, 'w-10 pl-4 sm:pl-5')}>
                          <input
                            type="checkbox"
                            aria-label="Select everything in the trash"
                            checked={library.trash.every((f) => selected.has(f.key))}
                            onChange={() => toggleAll(library.trash.map((f) => f.key))}
                            className="size-4 accent-forest"
                          />
                        </th>
                        <th scope="col" className={TH}>
                          File
                        </th>
                        <th scope="col" className={cx(TH, 'text-right')}>
                          Size
                        </th>
                        <th scope="col" className={cx(TH, 'pr-4 sm:pr-5')}>
                          Moved to trash
                        </th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-line">
                      {library.trash.map((f) => (
                        <tr key={f.key} className={cx('hover:bg-canvas', selected.has(f.key) && 'bg-forest-tint/40')}>
                          <td className={cx(TD, 'pl-4 sm:pl-5')}>
                            <input
                              type="checkbox"
                              aria-label={`Select ${f.original_key}`}
                              checked={selected.has(f.key)}
                              onChange={() => toggle(f.key)}
                              className="size-4 accent-forest"
                            />
                          </td>
                          <td className={TD}>
                            <FileName fileKey={f.original_key} />
                          </td>
                          <td className={cx(TD, 'tnum text-right whitespace-nowrap text-coffee-soft')}>
                            {formatBytes(f.size)}
                          </td>
                          <td className={cx(TD, 'pr-4 whitespace-nowrap text-coffee-soft sm:pr-5')}>{when(f.moved_at)}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )}
            </section>
          )}
        </>
      )}

      {confirm && (
        <Modal
          title={
            confirm.kind === 'trash'
              ? `Move ${confirm.keys.length} ${confirm.keys.length === 1 ? 'file' : 'files'} to the trash?`
              : `Delete ${confirm.keys.length} ${confirm.keys.length === 1 ? 'file' : 'files'} for good?`
          }
          onClose={() => !busy && setConfirm(null)}
        >
          <p className="mt-2 text-sm leading-6 text-coffee-soft">
            {confirm.kind === 'trash'
              ? `${formatBytes(confirm.bytes)}. Nothing uses them. You can restore them from the trash.`
              : `${formatBytes(confirm.bytes)}. This can’t be undone.`}
          </p>
          {confirmError && (
            <p role="alert" className="mt-3 text-sm text-danger">
              {confirmError}
            </p>
          )}
          <div className="mt-6 flex flex-col-reverse gap-2 sm:flex-row sm:justify-end">
            <Button className="justify-center" disabled={busy} onClick={() => setConfirm(null)}>
              Cancel
            </Button>
            <Button
              variant="danger"
              className="justify-center"
              disabled={busy}
              onClick={() => void act(confirm.kind === 'trash' ? LIBRARY_TRASH : LIBRARY_DELETE, confirm.keys)}
            >
              {confirm.kind === 'trash' ? 'Move to trash' : 'Delete for good'}
            </Button>
          </div>
        </Modal>
      )}

      {exporting && library && <ExportDialog courses={library.courses} onClose={() => setExporting(false)} />}
    </main>
  )
}

function Filter({
  label,
  value,
  onChange,
  children,
}: {
  label: string
  value: string
  onChange: (value: string) => void
  children: ReactNode
}) {
  return (
    <label className="min-w-0">
      <span className="sr-only">{label}</span>
      <select
        className={cx(FIELD_CLASS, value && 'border-forest text-forest')}
        value={value}
        onChange={(e) => onChange(e.target.value)}
      >
        {children}
      </select>
    </label>
  )
}

function SortHeader({
  label,
  sortKey,
  sort,
  onSort,
  align = 'left',
}: {
  label: string
  sortKey: SortKey
  sort: Sort
  onSort: (key: SortKey) => void
  align?: 'left' | 'right'
}) {
  const active = sort.key === sortKey
  return (
    <th
      scope="col"
      aria-sort={active ? (sort.dir === 'asc' ? 'ascending' : 'descending') : 'none'}
      className={cx(TH, align === 'right' && 'text-right')}
    >
      <button
        type="button"
        onClick={() => onSort(sortKey)}
        className={cx(
          'inline-flex items-center gap-0.5 font-semibold hover:text-coffee',
          active ? 'text-coffee' : 'text-stone',
        )}
      >
        {label}
        <Icon
          name={active ? (sort.dir === 'asc' ? 'arrow_upward' : 'arrow_downward') : 'unfold_more'}
          className="text-sm"
        />
      </button>
    </th>
  )
}

function FileName({ fileKey }: { fileKey: string }) {
  return (
    <span className="block min-w-0">
      <span className="block font-mono text-[0.8125rem] font-semibold break-all text-coffee">
        {fileNameOf(fileKey)}
      </span>
      <span className="block font-mono text-xs break-all text-stone">{folderOf(fileKey)}</span>
    </span>
  )
}

function FileRow({
  file,
  selected,
  onToggle,
  playing,
  onPlay,
}: {
  file: AudioFile
  selected: boolean
  onToggle: () => void
  playing: boolean
  onPlay: () => void
}) {
  const tooNew = file.status === 'unused' && !file.can_trash
  return (
    <tr className={cx('hover:bg-canvas', selected && 'bg-forest-tint/40')}>
      <td className={cx(TD, 'pl-4 sm:pl-5')}>
        {file.can_trash && (
          <input
            type="checkbox"
            aria-label={`Select ${file.key}`}
            checked={selected}
            onChange={onToggle}
            className="mt-1.5 size-4 accent-forest"
          />
        )}
      </td>
      <td className={cx(TD, 'max-w-[20rem]')}>
        <span className="flex items-start gap-2.5">
          <Button
            size="icon"
            variant={playing ? 'coffee' : 'outline'}
            aria-label={`${playing ? 'Stop' : 'Play'} ${file.key}`}
            onClick={onPlay}
            className="shrink-0 rounded-full"
          >
            <Icon name={playing ? 'stop' : 'play_arrow'} filled className="text-lg" />
          </Button>
          <FileName fileKey={file.key} />
        </span>
      </td>
      <td className={TD}>
        <span className="rounded bg-inset px-1.5 py-0.5 font-mono text-xs font-semibold text-coffee-soft">
          {formatOf(file.key)}
        </span>
      </td>
      <td className={cx(TD, 'tnum text-right whitespace-nowrap text-coffee-soft')}>{formatBytes(file.size)}</td>
      <td className={cx(TD, 'whitespace-nowrap text-coffee-soft')}>{when(file.uploaded_at)}</td>
      <td className={cx(TD, 'whitespace-nowrap')}>
        <span className="inline-flex items-center gap-1 text-coffee-soft">
          <Icon name={file.source === 'generated' ? 'auto_awesome' : 'mic'} className="text-base text-stone" />
          {file.source === 'generated' ? 'Addis AI' : 'Recorded'}
        </span>
      </td>
      <td className={cx(TD, 'whitespace-nowrap')}>
        <Badge tone={file.status === 'in_use' ? 'published' : 'draft'} dot>
          {file.status === 'in_use' ? 'In use' : 'Not used'}
        </Badge>
        {tooNew && (
          <span className="mt-1 block text-xs text-stone" title="Uploaded less than a day ago, so it can’t go to the trash yet">
            Under a day old
          </span>
        )}
      </td>
      <td className={cx(TD, 'min-w-[16rem] pr-4 sm:pr-5')}>
        {file.uses.length === 0 ? <span className="text-stone">—</span> : <Uses uses={file.uses} />}
      </td>
    </tr>
  )
}

function Uses({ uses }: { uses: AudioUse[] }) {
  return (
    <ul className="flex flex-col gap-2">
      {uses.map((u) => {
        const { title, where } = partsOfUse(u)
        return (
          <li key={`${u.place}-${u.admin_path}`} className="flex items-start justify-between gap-3">
            <span className="min-w-0">
              <span className="block font-medium text-coffee">{title}</span>
              <span className="block text-xs text-stone">{where}</span>
            </span>
            <Link
              to={u.admin_path}
              aria-label={`Open ${describeUse(u)}`}
              className="inline-flex shrink-0 items-center gap-0.5 rounded px-1.5 py-0.5 text-sm font-semibold text-forest hover:bg-forest-tint"
            >
              Open
              <Icon name="arrow_forward" className="text-base" />
            </Link>
          </li>
        )
      })}
    </ul>
  )
}
