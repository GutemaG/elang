import { useCallback, useEffect, useId, useState, type FormEvent, type ReactNode } from 'react'
import { Link, useNavigate, useParams, useSearchParams } from 'react-router-dom'

import { ApiError } from '../api'
import { AudioField } from '../audio/AudioField'
import { messageOf, useSession } from '../auth/SessionContext'
import { Section } from '../exercises/fields'
import { routes } from '../tree/levels'
import { uploadThroughLink } from '../upload/link'
import type { Curriculum, CurriculumRow, CurriculumStatus } from '../types'
import { Button } from '../ui/Button'
import { cx } from '../ui/cx'
import { Icon } from '../ui/Icon'
import { FIELD_CLASS, Input } from '../ui/Input'
import { ExercisesPanel } from './ExercisesPanel'
import { CONFIDENCE_LABELS, LANGUAGE_COLUMNS, NO_COUNTS, orderedLessons, STATUS_LABELS } from './model'
import { blankProblem, changesOf, draftOf, nextUnrecorded, ordered, retexts, type Draft, type Order } from './rows'
import { lessonPath } from './WorkbookPage'

const STATUS_TONES: Record<CurriculumStatus, string> = {
  to_do: 'bg-inset text-stone',
  draft: 'bg-inset text-coffee-soft',
  needs_change: 'bg-terracotta-tint text-terracotta',
  reviewed: 'bg-forest-tint text-forest',
}

const ORDERS: { key: Order; label: string }[] = [
  { key: 'check_first', label: 'Check first' },
  { key: 'in_order', label: 'In order' },
]

const when = (iso: string) =>
  new Date(iso).toLocaleString('en-GB', { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' })

/** One lesson's words and sentence (intent 025, bolt 084): corrected,
 * reviewed and recorded one row at a time, with a native speaker. */
export function LessonPage() {
  const { courseId = '', lessonRef = '' } = useParams()
  const [search, setSearch] = useSearchParams()
  const navigate = useNavigate()
  const { api } = useSession()
  const [curriculum, setCurriculum] = useState<Curriculum | null>(null)
  const [loadError, setLoadError] = useState<string | null>(null)
  const [order, setOrder] = useState<Order>('check_first')
  // Kept here: the editor starts afresh after every save.
  const [notice, setNotice] = useState<string | null>(null)

  const fetchCurriculum = useCallback(() => api.get<Curriculum>(routes.curriculum(courseId)), [api, courseId])

  const reload = useCallback(async () => {
    const fresh = await fetchCurriculum()
    setCurriculum(fresh)
    return fresh
  }, [fetchCurriculum])

  useEffect(() => {
    let live = true
    fetchCurriculum().then(
      (c) => live && setCurriculum(c),
      (e: unknown) => live && setLoadError(messageOf(e)),
    )
    return () => {
      live = false
    }
  }, [fetchCurriculum])

  if (!curriculum) {
    return (
      <Page>
        {loadError ? (
          <p role="alert" className="text-sm text-danger">
            {loadError}
          </p>
        ) : (
          <p className="text-sm text-stone">Loading…</p>
        )}
      </Page>
    )
  }

  const lessons = orderedLessons(curriculum.entries)
  const index = lessons.findIndex((l) => l.lesson.ref === lessonRef)
  const line = lessons[index]
  if (!line) {
    return (
      <Page>
        <Crumbs courseId={courseId} title={curriculum.course_title} />
        <p role="alert" className="text-sm text-danger">
          This lesson is not in the workbook.
        </p>
      </Page>
    )
  }
  const { lesson, skill, section } = line
  const rows = ordered(
    curriculum.rows.filter((r) => r.lesson_ref === lesson.ref),
    order,
  )
  const current = rows.find((r) => r.ref === search.get('row')) ?? rows[0]
  const counts = lesson.counts ?? NO_COUNTS
  const pick = (ref: string) => {
    setNotice(null)
    setSearch({ row: ref }, { replace: true })
  }
  const previousLesson = lessons[index - 1]?.lesson
  const nextLesson = lessons[index + 1]?.lesson

  return (
    <Page>
      <Crumbs courseId={courseId} title={curriculum.course_title} />
      <header className="flex flex-wrap items-start justify-between gap-4">
        <div className="min-w-0">
          <p className="text-xs font-bold tracking-[0.12em] text-forest uppercase">
            {section?.title} · {skill?.title}
          </p>
          <h1 className="mt-1 text-[1.75rem] leading-9 font-bold tracking-[-0.02em] text-coffee">{lesson.title}</h1>
          <p className="tnum mt-1 text-sm text-stone">
            {lesson.ref} · {counts.reviewed}/{counts.rows} reviewed · {counts.recorded}/{counts.rows} recorded
          </p>
        </div>
        <div className="flex gap-1">
          <Button
            size="icon"
            variant="ghost"
            aria-label="Previous lesson"
            disabled={!previousLesson}
            onClick={() => previousLesson && navigate(lessonPath(courseId, previousLesson.ref))}
          >
            <Icon name="chevron_left" className="text-xl" />
          </Button>
          <Button
            size="icon"
            variant="ghost"
            aria-label="Next lesson"
            disabled={!nextLesson}
            onClick={() => nextLesson && navigate(lessonPath(courseId, nextLesson.ref))}
          >
            <Icon name="chevron_right" className="text-xl" />
          </Button>
        </div>
      </header>

      {(lesson.goal || lesson.grammar) && (
        <dl className="mt-4 grid gap-3 rounded-lg bg-inset p-4 text-sm sm:grid-cols-2">
          {lesson.goal && (
            <div>
              <dt className="text-xs font-semibold text-stone">Can-do goal</dt>
              <dd className="mt-0.5 text-coffee">{lesson.goal}</dd>
            </div>
          )}
          {lesson.grammar && (
            <div>
              <dt className="text-xs font-semibold text-stone">Grammar</dt>
              <dd className="mt-0.5 leading-6 text-coffee">{lesson.grammar}</dd>
            </div>
          )}
        </dl>
      )}

      <section aria-label="Words and sentence" className="mt-6 overflow-hidden rounded-lg border border-line bg-surface shadow-e1">
        <div className="flex flex-wrap items-center justify-between gap-3 border-b border-line px-4 py-3">
          <h2 className="text-base font-semibold text-coffee">Words and sentence</h2>
          <div role="group" aria-label="Order" className="flex rounded bg-inset p-1">
            {ORDERS.map((o) => (
              <button
                key={o.key}
                type="button"
                aria-pressed={order === o.key}
                onClick={() => setOrder(o.key)}
                className={cx(
                  'rounded-sm px-3 py-1.5 text-xs font-semibold',
                  order === o.key ? 'bg-surface text-forest shadow-e1' : 'text-stone hover:text-coffee',
                )}
              >
                {o.label}
              </button>
            ))}
          </div>
        </div>
        {rows.length === 0 ? (
          <p className="px-4 py-8 text-center text-sm text-stone">This lesson has no words or sentence yet.</p>
        ) : (
          <ul>
            {rows.map((r) => (
              <li key={r.ref} className="border-t border-line first:border-t-0">
                <button
                  type="button"
                  aria-current={r.ref === current?.ref ? 'true' : undefined}
                  onClick={() => pick(r.ref)}
                  className={cx(
                    'flex w-full flex-wrap items-center gap-x-3 gap-y-1 px-4 py-2.5 text-left hover:bg-inset',
                    r.ref === current?.ref && 'bg-forest-tint/60',
                  )}
                >
                  <span className="tnum w-12 shrink-0 text-xs font-semibold text-stone">{r.ref}</span>
                  <span className="min-w-0 flex-1">
                    <span className="block truncate text-sm text-coffee">{r.english}</span>
                    <span className="block truncate text-sm font-semibold text-coffee">{r.text ?? '—'}</span>
                  </span>
                  {r.confidence && r.confidence !== 'high' && (
                    <span className="rounded-full bg-sky-50 px-2 py-0.5 text-[0.6875rem] font-bold text-sky-700">
                      {CONFIDENCE_LABELS[r.confidence]}
                    </span>
                  )}
                  <span className={cx('rounded-full px-2.5 py-0.5 text-xs font-bold', STATUS_TONES[r.status])}>
                    {STATUS_LABELS[r.status]}
                  </span>
                  <Icon name={r.audio_url ? 'mic' : 'mic_off'} className={cx('text-lg', r.audio_url ? 'text-forest' : 'text-stone')} />
                  <span className="sr-only">{r.audio_url ? 'Recorded' : 'Not recorded'}</span>
                </button>
              </li>
            ))}
          </ul>
        )}
      </section>

      {current && (
        <RowEditor
          key={`${current.ref}-${current.version}`}
          courseId={courseId}
          language={curriculum.language}
          row={current}
          position={rows.indexOf(current)}
          count={rows.length}
          onPick={(i) => rows[i] && pick(rows[i].ref)}
          reload={reload}
          notice={notice}
          setNotice={setNotice}
          onNext={(fresh) => {
            const next = nextUnrecorded(fresh.entries, fresh.rows, lesson.ref, current.ref, order)
            if (!next) return false
            if (next.lesson === lesson.ref) setSearch({ row: next.row }, { replace: true })
            else navigate(`${lessonPath(courseId, next.lesson)}?row=${encodeURIComponent(next.row)}`)
            return true
          }}
        />
      )}

      <ExercisesPanel key={lesson.ref} courseId={courseId} curriculum={curriculum} lesson={lesson} reload={reload} />
    </Page>
  )
}

function RowEditor({
  courseId,
  language,
  row,
  position,
  count,
  onPick,
  reload,
  notice,
  setNotice,
  onNext,
}: {
  courseId: string
  language: string
  row: CurriculumRow
  position: number
  count: number
  onPick: (index: number) => void
  reload: () => Promise<Curriculum>
  notice: string | null
  setNotice: (notice: string | null) => void
  /** Goes to the next unrecorded row; false when none is left. */
  onNext: (fresh: Curriculum) => boolean
}) {
  const { api } = useSession()
  const ids = useId()
  const [draft, setDraft] = useState<Draft>(() => draftOf(row))
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<{ message: string; stale?: boolean } | null>(null)
  const change = changesOf(draft, row)
  const dirty = Object.keys(change).length > 0
  const blank = blankProblem(draft, row.kind)
  const warnRetext = retexts(change, row)
  const hasRomanization = LANGUAGE_COLUMNS[language]?.romanization !== null
  const upload = (clip: Blob, type: string) =>
    uploadThroughLink(api, routes.curriculumUploads(courseId), { row_ref: row.ref }, clip, type, {
      notConfigured: 'This server has nowhere to store audio yet, so recordings can’t be uploaded. Paste a link instead.',
      store: 'audio store',
    })

  const edit = <K extends keyof Draft>(key: K, value: Draft[K]) => {
    setDraft((d) => ({ ...d, [key]: value }))
    setNotice(null)
  }

  async function save(then?: 'next') {
    if (busy || blank) return
    setBusy(true)
    setError(null)
    try {
      let message = 'Saved.'
      if (dirty) {
        const answer = await api.patch<{ row: CurriculumRow; reset_to_draft: boolean }>(
          routes.curriculumRow(courseId, row.ref),
          { version: row.version, ...change },
        )
        if (answer.reset_to_draft) message = 'Saved. The words changed, so it is back to Draft: check its recording.'
      }
      setNotice(null)
      const fresh = await reload()
      if (then === 'next' && !onNext(fresh)) message = dirty ? `${message} Every row is recorded.` : 'Every row is recorded.'
      setNotice(then === 'next' && message === 'Saved.' ? null : message)
    } catch (e) {
      if (e instanceof ApiError && e.errorCode === 'content_changed') {
        setError({ message: 'Someone saved this row after you opened it. Reload to see their change; yours is not saved.', stale: true })
      } else {
        const field = e instanceof ApiError && typeof e.details.field === 'string' ? `${e.details.field}: ` : ''
        setError({ message: `${field}${messageOf(e)}` })
      }
    } finally {
      setBusy(false)
    }
  }

  function submit(e: FormEvent) {
    e.preventDefault()
    void save()
  }

  return (
    <form onSubmit={submit} className="mt-6 space-y-5" aria-label={`Row ${row.ref}`}>
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h2 className="text-lg font-semibold text-coffee">
            {row.kind === 'sentence' ? 'Sentence' : 'Word'} {row.ref}
          </h2>
          <p className="text-xs text-stone">
            {row.updated_by ? `Last changed by ${row.updated_by}, ${when(row.updated_at)}` : `Last changed ${when(row.updated_at)}`}
            {row.confidence && ` · First draft: ${CONFIDENCE_LABELS[row.confidence].toLowerCase()} confidence`}
          </p>
        </div>
        <div className="flex gap-1">
          <Button size="icon" variant="ghost" aria-label="Previous row" disabled={position === 0} onClick={() => onPick(position - 1)}>
            <Icon name="chevron_left" className="text-xl" />
          </Button>
          <Button size="icon" variant="ghost" aria-label="Next row" disabled={position >= count - 1} onClick={() => onPick(position + 1)}>
            <Icon name="chevron_right" className="text-xl" />
          </Button>
        </div>
      </div>

      <Section title="Words">
        <div className="grid gap-4 sm:grid-cols-2">
          <Field id={`${ids}-english`} label="English">
            <Input id={`${ids}-english`} value={draft.english} onChange={(e) => edit('english', e.target.value)} />
          </Field>
          <Field id={`${ids}-text`} label={LANGUAGE_COLUMNS[language]?.name ?? 'Translation'}>
            <Input id={`${ids}-text`} lang={language} value={draft.text} onChange={(e) => edit('text', e.target.value)} className="text-base" />
          </Field>
          {hasRomanization && (
            <Field id={`${ids}-romanization`} label="Romanization" hint="In Latin letters, as the lessons write it.">
              <Input id={`${ids}-romanization`} value={draft.romanization} className="font-mono" onChange={(e) => edit('romanization', e.target.value)} />
            </Field>
          )}
          {row.kind === 'sentence' && (
            <>
              <Field
                id={`${ids}-blank`}
                label="Word to blank"
                hint="The gap-fill exercise hides this word; it must be in the sentence exactly."
                error={blank}
              >
                <Input id={`${ids}-blank`} lang={language} value={draft.blank} onChange={(e) => edit('blank', e.target.value)} />
              </Field>
              <Field id={`${ids}-accepted`} label="Other accepted answers" hint="One per line.">
                <textarea
                  id={`${ids}-accepted`}
                  lang={language}
                  rows={2}
                  className={cx(FIELD_CLASS, 'h-auto py-2')}
                  value={draft.accepted}
                  onChange={(e) => edit('accepted', e.target.value)}
                />
              </Field>
            </>
          )}
          <Field id={`${ids}-notes`} label="Notes">
            <textarea
              id={`${ids}-notes`}
              rows={2}
              className={cx(FIELD_CLASS, 'h-auto py-2')}
              value={draft.notes}
              onChange={(e) => edit('notes', e.target.value)}
            />
          </Field>
        </div>
        {warnRetext && (
          <p role="note" className="mt-3 flex items-start gap-2 rounded bg-terracotta-tint p-3 text-sm text-terracotta">
            <Icon name="warning" className="text-lg" />
            This row is recorded. Saving new words sends it back to Draft, as the recording may no longer match.
          </p>
        )}
      </Section>

      <AudioField
        title="Recording"
        hint="Said once, clearly, by a native speaker. Record it here, upload a file, or paste a link."
        upload={upload}
        url={draft.audio_url}
        savedUrl={row.audio_url}
        onChange={(url) => edit('audio_url', url)}
      />

      <Section title="Review">
        <div className="grid gap-4 sm:grid-cols-2">
          <Field id={`${ids}-status`} label="Status">
            <select
              id={`${ids}-status`}
              className={FIELD_CLASS}
              value={draft.status}
              onChange={(e) => edit('status', e.target.value as CurriculumStatus)}
            >
              {(Object.keys(STATUS_LABELS) as CurriculumStatus[]).map((s) => (
                <option key={s} value={s}>
                  {STATUS_LABELS[s]}
                </option>
              ))}
            </select>
          </Field>
          <Field id={`${ids}-comment`} label="Reviewer comment">
            <textarea
              id={`${ids}-comment`}
              rows={2}
              className={cx(FIELD_CLASS, 'h-auto py-2')}
              value={draft.comment}
              onChange={(e) => edit('comment', e.target.value)}
            />
          </Field>
        </div>
      </Section>

      {error && (
        <div role="alert" className="flex flex-wrap items-center gap-3 rounded-md border border-danger-line bg-danger-tint px-4 py-3 text-sm text-danger">
          <span className="flex-1">{error.message}</span>
          {error.stale && (
            <Button size="sm" onClick={() => void reload()}>
              Reload
            </Button>
          )}
        </div>
      )}
      {notice && (
        <p role="status" className="rounded-md bg-forest-tint px-4 py-3 text-sm text-forest">
          {notice}
        </p>
      )}

      <div className="flex flex-col-reverse gap-2 sm:flex-row sm:justify-end">
        <Button type="submit" disabled={busy || !dirty || !!blank} className="justify-center">
          Save
        </Button>
        <Button variant="primary" disabled={busy || !!blank} className="justify-center" onClick={() => void save('next')}>
          <Icon name="mic" className="text-lg" />
          {dirty ? 'Save and next unrecorded' : 'Next unrecorded'}
        </Button>
      </div>
    </form>
  )
}

function Field({
  id,
  label,
  hint,
  error,
  children,
}: {
  id: string
  label: string
  hint?: string
  error?: string | null
  children: ReactNode
}) {
  return (
    <div className="min-w-0">
      <label htmlFor={id} className="mb-1.5 block text-sm font-semibold text-coffee">
        {label}
      </label>
      {children}
      {error ? (
        <p role="alert" className="mt-1 text-xs text-danger">
          {error}
        </p>
      ) : (
        hint && <p className="mt-1 text-xs text-stone">{hint}</p>
      )}
    </div>
  )
}

function Crumbs({ courseId, title }: { courseId: string; title: string }) {
  return (
    <nav aria-label="Breadcrumb" className="mb-3 flex flex-wrap items-center gap-1 text-sm">
      <Link to="/workbook" className="text-forest hover:underline">
        Workbook
      </Link>
      <Icon name="chevron_right" className="text-base text-stone" />
      <Link to={`/courses/${courseId}/workbook`} className="text-forest hover:underline">
        {title}
      </Link>
    </nav>
  )
}

function Page({ children }: { children: ReactNode }) {
  return <main className="mx-auto max-w-4xl px-4 py-6 sm:px-6 lg:px-8 lg:py-8">{children}</main>
}
