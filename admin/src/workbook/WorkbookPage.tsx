import { useCallback, useEffect, useRef, useState, type ReactNode } from 'react'
import { Link, useParams } from 'react-router-dom'

import { ApiError } from '../api'
import { messageOf, useSession } from '../auth/SessionContext'
import { PageHeader, StatCard, StatRow } from '../shell/Page'
import { routes } from '../tree/levels'
import type { Curriculum, CurriculumCounts, CurriculumEntry, CurriculumImportResult } from '../types'
import { Button } from '../ui/Button'
import { cx } from '../ui/cx'
import { Icon } from '../ui/Icon'
import { ImportDialog } from './ImportDialog'
import { curriculumToSheets, isReady, NO_COUNTS, outline, parseWorkbook, sumCounts, workbookName, type ParsedWorkbook } from './model'

type Filter = 'all' | 'ready' | 'needs_change'

const FILTERS: { key: Filter; label: string }[] = [
  { key: 'all', label: 'All lessons' },
  { key: 'ready', label: 'Ready to publish' },
  { key: 'needs_change', label: 'Needs change' },
]

const shows = (filter: Filter, lesson: CurriculumEntry) =>
  filter === 'all' ||
  (filter === 'ready' && isReady(lesson.counts)) ||
  (filter === 'needs_change' && (lesson.counts?.needs_change ?? 0) > 0)

/** Where a lesson's rows are reviewed and recorded (bolt 084). */
export const lessonPath = (courseId: string, ref: string) => `/courses/${courseId}/workbook/lessons/${encodeURIComponent(ref)}`

/** A course's curriculum workbook (intent 025): loaded once from the Excel
 * file, then reviewed, recorded and published from here. */
export function WorkbookPage() {
  const { courseId = '' } = useParams()
  const { api } = useSession()
  const [curriculum, setCurriculum] = useState<Curriculum | null>(null)
  const [loadError, setLoadError] = useState<ApiError | Error | null>(null)
  const [filter, setFilter] = useState<Filter>('all')
  const [importing, setImporting] = useState<{ name: string; parsed: ParsedWorkbook } | null>(null)
  const [notice, setNotice] = useState<string | null>(null)
  const [error, setError] = useState<string | null>(null)
  const fileInput = useRef<HTMLInputElement>(null)

  const fetchCurriculum = useCallback(() => api.get<Curriculum>(routes.curriculum(courseId)), [api, courseId])

  const load = useCallback(async () => {
    try {
      setCurriculum(await fetchCurriculum())
      setLoadError(null)
    } catch (e) {
      setLoadError(e instanceof Error ? e : new Error(messageOf(e)))
    }
  }, [fetchCurriculum])

  useEffect(() => {
    let live = true
    fetchCurriculum().then(
      (c) => {
        if (!live) return
        setCurriculum(c)
        setLoadError(null)
      },
      (e: unknown) => {
        if (live) setLoadError(e instanceof Error ? e : new Error(messageOf(e)))
      },
    )
    return () => {
      live = false
    }
  }, [fetchCurriculum])

  async function choose(file: File | undefined) {
    if (fileInput.current) fileInput.current.value = ''
    if (!file || !curriculum) return
    setError(null)
    setNotice(null)
    try {
      // The Excel libraries load only when a file is chosen or saved.
      const { readWorkbook } = await import('./files')
      setImporting({ name: file.name, parsed: parseWorkbook(await readWorkbook(file), curriculum.language) })
    } catch {
      setError('That file could not be read as an Excel workbook (.xlsx).')
    }
  }

  function imported(result: CurriculumImportResult) {
    setImporting(null)
    const rows = result.rows.added + result.rows.changed
    const plan = result.entries.added + result.entries.changed
    setNotice(`Imported: ${rows} words and sentences, ${plan} sections, skills and lessons.`)
    void load()
  }

  async function exportFile() {
    if (!curriculum) return
    try {
      const { saveWorkbook } = await import('./files')
      await saveWorkbook(workbookName(curriculum.course_title), curriculumToSheets(curriculum))
    } catch (e) {
      setError(messageOf(e))
    }
  }

  if (!curriculum) {
    return (
      <Page>
        {loadError ? (
          <div className="rounded-lg border border-line bg-surface p-8 text-center shadow-e1">
            <p role="alert" className="text-base font-semibold text-coffee">
              {loadError instanceof ApiError && loadError.status === 404 ? 'This course does not exist.' : loadError.message}
            </p>
            <div className="mt-5 flex justify-center gap-2">
              <Button variant="primary" onClick={() => void load()}>
                Try again
              </Button>
              <Link
                to="/workbook"
                className="inline-flex h-11 items-center gap-2 rounded border border-line bg-surface px-4 text-sm font-semibold text-coffee hover:bg-inset sm:h-10"
              >
                All courses
              </Link>
            </div>
          </div>
        ) : (
          <p className="text-sm text-stone" aria-busy="true">
            Loading…
          </p>
        )}
      </Page>
    )
  }

  const empty = curriculum.entries.length === 0
  const total = curriculum.counts
  const sections = outline(curriculum.entries)
  const lessons = curriculum.entries.filter((e) => e.kind === 'lesson')
  const count = (f: Filter) => lessons.filter((l) => shows(f, l)).length

  return (
    <Page>
      <nav aria-label="Breadcrumb" className="mb-3 text-sm">
        <Link to="/workbook" className="text-forest hover:underline">
          Workbook
        </Link>
      </nav>
      <PageHeader
        eyebrow="Workbook"
        title={curriculum.course_title}
        description="The words and sentences each lesson teaches. Correct and review them with a native speaker, record each one, then publish the lesson."
        actions={
          <>
            <input
              ref={fileInput}
              type="file"
              accept=".xlsx,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
              aria-label="Workbook file to import"
              className="hidden"
              onChange={(e) => void choose(e.target.files?.[0])}
            />
            <Button variant={empty ? 'primary' : 'outline'} onClick={() => fileInput.current?.click()}>
              <Icon name="upload_file" className="text-lg" />
              Import workbook
            </Button>
            <Button disabled={empty} onClick={() => void exportFile()}>
              <Icon name="download" className="text-lg" />
              Export to Excel
            </Button>
          </>
        }
      />

      {error && (
        <p role="alert" className="mt-4 rounded-md border border-danger-line bg-danger-tint px-4 py-3 text-sm text-danger">
          {error}
        </p>
      )}
      {notice && (
        <p role="status" className="mt-4 rounded-md bg-forest-tint px-4 py-3 text-sm text-forest">
          {notice}
        </p>
      )}

      {empty ? (
        <section className="mt-6 rounded-lg border border-line bg-surface p-8 text-center shadow-e1">
          <span className="mx-auto grid size-12 place-items-center rounded-full bg-inset text-coffee-soft">
            <Icon name="table_view" className="text-2xl" />
          </span>
          <h2 className="mt-4 text-base font-semibold text-coffee">Nothing imported yet</h2>
          <p className="mx-auto mt-1 max-w-md text-sm leading-6 text-stone">
            Import the curriculum workbook (.xlsx) to start. Its Plan, Words and Sentences tabs are read, in this
            course’s language; you will see what changes before anything is saved.
          </p>
        </section>
      ) : (
        <>
          <StatRow>
            <StatCard icon="format_list_bulleted" label="Words and sentences" value={total.rows} />
            <StatCard icon="edit_note" label="Filled in" value={`${total.filled}/${total.rows}`} />
            <StatCard icon="task_alt" label="Reviewed" value={`${total.reviewed}/${total.rows}`} tone="forest" />
            <StatCard icon="mic" label="Recorded" value={`${total.recorded}/${total.rows}`} tone="terracotta" />
          </StatRow>

          <div role="group" aria-label="Show lessons" className="mt-6 flex w-fit flex-wrap gap-1 rounded border border-line bg-inset p-1">
            {FILTERS.map((f) => (
              <button
                key={f.key}
                type="button"
                aria-pressed={filter === f.key}
                onClick={() => setFilter(f.key)}
                className={cx(
                  'rounded-sm px-3 py-1.5 text-xs font-semibold transition-colors',
                  filter === f.key ? 'bg-surface text-forest shadow-e1' : 'text-stone hover:text-coffee',
                )}
              >
                {f.label} <span className="tnum opacity-70">({count(f.key)})</span>
              </button>
            ))}
          </div>

          <div className="mt-4 space-y-6">
            {sections.map(({ section, skills }) => {
              const shown = skills
                .map((s) => ({ ...s, lessons: s.lessons.filter((l) => shows(filter, l)) }))
                .filter((s) => s.lessons.length > 0)
              if (shown.length === 0) return null
              return (
                <section
                  key={section.ref}
                  aria-labelledby={`section-${section.ref}`}
                  className="overflow-hidden rounded-lg border border-line bg-surface shadow-e1"
                >
                  <header className="flex flex-wrap items-center justify-between gap-3 border-b border-line px-4 py-3 sm:px-6">
                    <h2 id={`section-${section.ref}`} className="text-base font-semibold text-coffee">
                      <span className="text-stone">{section.ref} · </span>
                      {section.title}
                    </h2>
                    <Progress counts={sumCounts(skills.flatMap((s) => s.lessons))} />
                  </header>
                  {shown.map(({ skill, lessons: list }) => (
                    <div key={skill.ref} className="border-b border-line last:border-b-0">
                      <h3 className="flex flex-wrap items-center justify-between gap-2 bg-inset/60 px-4 py-2 text-sm font-semibold text-coffee sm:px-6">
                        <span>{skill.title}</span>
                        <Progress counts={sumCounts(skills.find((s) => s.skill.ref === skill.ref)!.lessons)} compact />
                      </h3>
                      <ul>
                        {list.map((lesson) => (
                          <LessonLine key={lesson.ref} courseId={courseId} lesson={lesson} />
                        ))}
                      </ul>
                    </div>
                  ))}
                </section>
              )
            })}
            {count(filter) === 0 && (
              <p className="rounded-lg border border-line bg-surface px-6 py-10 text-center text-sm text-stone">
                No lessons {filter === 'ready' ? 'are ready to publish yet' : 'need changes'}.
              </p>
            )}
          </div>
        </>
      )}

      {importing && (
        <ImportDialog
          courseId={courseId}
          fileName={importing.name}
          parsed={importing.parsed}
          onClose={() => setImporting(null)}
          onImported={imported}
        />
      )}
    </Page>
  )
}

function LessonLine({ courseId, lesson }: { courseId: string; lesson: CurriculumEntry }) {
  const counts = lesson.counts ?? NO_COUNTS
  return (
    <li className="border-t border-line first:border-t-0">
      <Link
        to={lessonPath(courseId, lesson.ref)}
        className="flex flex-wrap items-center gap-x-4 gap-y-1 px-4 py-3 hover:bg-inset sm:px-6"
      >
        <span className="min-w-0 flex-1">
          <span className="block text-sm font-semibold text-coffee">{lesson.title}</span>
          <span className="block text-xs text-stone">{lesson.ref}</span>
        </span>
        {counts.needs_change > 0 && (
          <span className="rounded-full bg-terracotta-tint px-2.5 py-0.5 text-xs font-bold text-terracotta">
            {counts.needs_change} need{counts.needs_change === 1 ? 's' : ''} change
          </span>
        )}
        {lesson.publish_state === 'published' && (
          <span className="rounded-full bg-forest-tint px-2.5 py-0.5 text-xs font-bold text-forest">Published</span>
        )}
        {lesson.publish_state === 'changed' && (
          <span className="rounded-full bg-terracotta-tint px-2.5 py-0.5 text-xs font-bold text-terracotta">
            Changed since publish
          </span>
        )}
        {isReady(lesson.counts) && lesson.publish_state !== 'published' && lesson.publish_state !== 'changed' && (
          <span className="rounded-full bg-forest-tint px-2.5 py-0.5 text-xs font-bold text-forest">Ready</span>
        )}
        <Progress counts={counts} />
      </Link>
    </li>
  )
}

/** Reviewed and recorded out of the rows, as two short bars. */
function Progress({ counts, compact = false }: { counts: CurriculumCounts; compact?: boolean }) {
  const bar = (done: number, tone: string, label: string) => (
    <span className="flex items-center gap-2" title={`${done} of ${counts.rows} ${label}`}>
      {!compact && (
        <span className="h-1.5 w-16 overflow-hidden rounded-full bg-inset" aria-hidden="true">
          <span className={cx('block h-full rounded-full', tone)} style={{ width: `${counts.rows ? (100 * done) / counts.rows : 0}%` }} />
        </span>
      )}
      <span className="tnum text-xs text-stone">
        {done}/{counts.rows} {label}
      </span>
    </span>
  )
  return (
    <span className="flex flex-wrap items-center gap-3">
      {bar(counts.reviewed, 'bg-forest', 'reviewed')}
      {bar(counts.recorded, 'bg-terracotta', 'recorded')}
    </span>
  )
}

function Page({ children }: { children: ReactNode }) {
  return <main className="mx-auto max-w-6xl px-4 py-6 sm:px-6 lg:px-8 lg:py-8">{children}</main>
}
