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
  formatBytes,
  LIBRARY,
  LIBRARY_DELETE,
  LIBRARY_RESTORE,
  LIBRARY_TRASH,
  describeUse,
  type AudioFile,
  type AudioLibrary,
  type AudioUse,
} from './api'
import { ExportDialog } from './ExportDialog'

type Tab = 'files' | 'missing' | 'trash'
type Status = '' | 'in_use' | 'unused'
type Source = '' | 'recorded' | 'generated'
type Confirm = { kind: 'trash' | 'delete'; keys: string[]; bytes: number }

const PAGE = 100

const when = (iso: string) =>
  new Date(iso).toLocaleString('en-GB', { day: 'numeric', month: 'short', year: 'numeric' })

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

  const course = library?.courses.find((c) => c.id === courseId) ?? null
  const files = useMemo(() => {
    if (!library) return []
    const needle = search.trim().toLowerCase()
    return library.files.filter((f) => {
      if (status && f.status !== status) return false
      if (source && f.source !== source) return false
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
  }, [library, search, status, source, course])

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

  function switchTab(next: Tab) {
    setTab(next)
    setSelected(new Set())
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

  return (
    <main className="mx-auto max-w-6xl px-4 py-6 sm:px-6 lg:px-8 lg:py-8">
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
            <>
              <div className="mt-4 flex flex-wrap items-center gap-2">
                <label className="relative min-w-0 flex-1 basis-56">
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
                <label className="min-w-0">
                  <span className="sr-only">Course</span>
                  <select
                    className={cx(FIELD_CLASS, 'w-auto max-w-[14rem]')}
                    value={courseId}
                    onChange={(e) => setCourseId(e.target.value)}
                  >
                    <option value="">All courses</option>
                    {library.courses.map((c) => (
                      <option key={c.id} value={c.id}>
                        {c.title}
                      </option>
                    ))}
                  </select>
                </label>
                <label className="min-w-0">
                  <span className="sr-only">Status</span>
                  <select
                    className={cx(FIELD_CLASS, 'w-auto')}
                    value={status}
                    onChange={(e) => setStatus(e.target.value as Status)}
                  >
                    <option value="">In use or not</option>
                    <option value="in_use">In use</option>
                    <option value="unused">Not used</option>
                  </select>
                </label>
                <label className="min-w-0">
                  <span className="sr-only">Source</span>
                  <select
                    className={cx(FIELD_CLASS, 'w-auto')}
                    value={source}
                    onChange={(e) => setSource(e.target.value as Source)}
                  >
                    <option value="">Recorded or generated</option>
                    <option value="recorded">Recorded or uploaded</option>
                    <option value="generated">Generated by Addis AI</option>
                  </select>
                </label>
              </div>

              <SelectionBar
                count={picked.length}
                bytes={sizeOf(picked)}
                onSelectAll={
                  trashable.length > 0 ? () => setSelected(new Set(trashable.map((f) => f.key))) : undefined
                }
                selectAllLabel={`Select all not used (${trashable.length})`}
                onClear={() => setSelected(new Set())}
              >
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
                  Move to trash
                </Button>
              </SelectionBar>

              <section className="mt-3 overflow-hidden rounded-lg border border-line bg-surface shadow-e1">
                {files.length === 0 ? (
                  <p className="px-4 py-8 text-center text-sm text-stone">No audio files match.</p>
                ) : (
                  <ul className="divide-y divide-line">
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
                  </ul>
                )}
              </section>
              {files.length > shown && (
                <div className="mt-3 flex justify-center">
                  <Button onClick={() => setShown((n) => n + PAGE)}>
                    Show more ({files.length - shown} left)
                  </Button>
                </div>
              )}
            </>
          )}

          {tab === 'missing' && (
            <section className="mt-4 overflow-hidden rounded-lg border border-line bg-surface shadow-e1">
              <div className="border-b border-line px-4 py-3 sm:px-6">
                <p className="text-sm text-coffee-soft">
                  These places link to audio that is no longer in storage, so learners hear nothing. Open each one and
                  record or upload the audio again.
                </p>
              </div>
              {library.missing.length === 0 ? (
                <p className="px-4 py-8 text-center text-sm text-stone">Every link has its file.</p>
              ) : (
                <ul className="divide-y divide-line">
                  {library.missing.map((m) => (
                    <li key={m.key} className="px-4 py-3 sm:px-6">
                      <span className="font-mono text-xs break-all text-stone">{m.key}</span>
                      <Uses uses={m.uses} />
                    </li>
                  ))}
                </ul>
              )}
            </section>
          )}

          {tab === 'trash' && (
            <>
              <SelectionBar
                count={picked.length}
                bytes={sizeOf(picked)}
                onSelectAll={
                  library.trash.length > 0 ? () => setSelected(new Set(library.trash.map((f) => f.key))) : undefined
                }
                selectAllLabel={`Select all (${library.trash.length})`}
                onClear={() => setSelected(new Set())}
              >
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
              </SelectionBar>
              {!confirm && confirmError && (
                <p role="alert" className="mt-2 text-sm text-danger">
                  {confirmError}
                </p>
              )}
              <section className="mt-3 overflow-hidden rounded-lg border border-line bg-surface shadow-e1">
                {library.trash.length === 0 ? (
                  <p className="px-4 py-8 text-center text-sm text-stone">The trash is empty.</p>
                ) : (
                  <ul className="divide-y divide-line">
                    {library.trash.map((f) => (
                      <li key={f.key} className="flex flex-wrap items-center gap-x-3 gap-y-1 px-4 py-3 sm:px-6">
                        <input
                          type="checkbox"
                          aria-label={`Select ${f.original_key}`}
                          checked={selected.has(f.key)}
                          onChange={() => toggle(f.key)}
                          className="size-4 accent-forest"
                        />
                        <span className="min-w-0 flex-1 basis-64">
                          <span className="block font-mono text-sm break-all text-coffee">{f.original_key}</span>
                          <span className="block text-xs text-stone">
                            {formatBytes(f.size)} · moved to trash {when(f.moved_at)}
                          </span>
                        </span>
                      </li>
                    ))}
                  </ul>
                )}
              </section>
            </>
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

function SelectionBar({
  count,
  bytes,
  onSelectAll,
  selectAllLabel,
  onClear,
  children,
}: {
  count: number
  bytes: number
  onSelectAll?: () => void
  selectAllLabel: string
  onClear: () => void
  children: ReactNode
}) {
  return (
    <div className="mt-3 flex flex-wrap items-center gap-2">
      <span className="text-sm text-coffee-soft">
        {count === 0 ? 'Nothing selected' : `${count} selected · ${formatBytes(bytes)}`}
      </span>
      {onSelectAll && (
        <Button size="sm" variant="ghost" onClick={onSelectAll}>
          {selectAllLabel}
        </Button>
      )}
      {count > 0 && (
        <Button size="sm" variant="ghost" onClick={onClear}>
          Clear
        </Button>
      )}
      <span className="flex-1" />
      {children}
    </div>
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
  return (
    <li className="flex items-start gap-3 px-4 py-3 sm:px-6">
      <span className="flex h-8 w-4 shrink-0 items-center">
        {file.can_trash && (
          <input
            type="checkbox"
            aria-label={`Select ${file.key}`}
            checked={selected}
            onChange={onToggle}
            className="size-4 accent-forest"
          />
        )}
      </span>
      <Button
        size="icon"
        variant={playing ? 'coffee' : 'outline'}
        aria-label={`${playing ? 'Stop' : 'Play'} ${file.key}`}
        onClick={onPlay}
      >
        <Icon name={playing ? 'stop' : 'play_arrow'} filled className="text-lg" />
      </Button>
      <span className="min-w-0 flex-1">
        <span className="flex flex-wrap items-center gap-2">
          <span className="font-mono text-sm break-all text-coffee">{file.key}</span>
          <Badge tone={file.status === 'in_use' ? 'published' : 'draft'} dot>
            {file.status === 'in_use' ? 'In use' : 'Not used'}
          </Badge>
        </span>
        <span className="mt-0.5 block text-xs text-stone">
          {formatBytes(file.size)} · {when(file.uploaded_at)} ·{' '}
          {file.source === 'generated' ? 'Generated by Addis AI' : 'Recorded or uploaded'}
          {file.status === 'unused' && !file.can_trash && ' · Less than a day old, so it can’t go to the trash yet'}
        </span>
        <Uses uses={file.uses} />
      </span>
    </li>
  )
}

function Uses({ uses }: { uses: AudioUse[] }) {
  if (uses.length === 0) return null
  return (
    <ul className="mt-1.5 flex flex-col gap-1">
      {uses.map((u) => (
        <li key={`${u.place}-${u.admin_path}`} className="flex flex-wrap items-center gap-x-2 text-sm text-coffee-soft">
          <span className="min-w-0">{describeUse(u)}</span>
          <Link
            to={u.admin_path}
            className="inline-flex items-center gap-0.5 text-sm font-semibold text-forest hover:underline"
          >
            Open
            <Icon name="arrow_forward" className="text-base" />
          </Link>
        </li>
      ))}
    </ul>
  )
}
