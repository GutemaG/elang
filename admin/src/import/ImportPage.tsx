import { useEffect, useRef, useState, type ChangeEvent, type ReactNode } from 'react'
import { Link, useNavigate, useParams } from 'react-router-dom'

import { ApiError } from '../api'
import { messageOf, useSession } from '../auth/SessionContext'
import { ExercisePreview } from '../exercises/ExercisePreview'
import { TYPE_INFO, plainMessage } from '../exercises/model'
import { routes } from '../tree/levels'
import type { AdminCourseTree, ExerciseBody, ExerciseType } from '../types'
import { Button } from '../ui/Button'
import { cx } from '../ui/cx'
import { Icon } from '../ui/Icon'
import { Modal } from '../ui/Modal'
import { COLUMNS } from './csvFormat'
import { CSV_TYPE, JSON_TYPE, readText, saveFile } from './download'
import { readCsv, type ImportRow, type ReadResult } from './fromCsv'
import { readJson } from './json'
import { EXAMPLES, csvTemplate, jsonExample } from './templates'
import { bodyToRow } from './toCsv'

/** The most one import holds, as the server allows (bolt 056). */
const IMPORT_MAX = 200
/** 1 MB: far more than 200 exercises need. */
const MAX_BYTES = 1024 * 1024

type Format = 'csv' | 'json'
type Mode = 'append' | 'replace'

interface Lesson {
  courseTitle: string
  title: string
  exerciseCount: number
}

interface ImportProblem {
  index: number
  field: string
  message: string
}

function lessonIn(tree: AdminCourseTree, lessonId: string): Lesson | null {
  for (const section of tree.sections)
    for (const skill of section.skills)
      for (const lesson of skill.lessons)
        if (lesson.id === lessonId)
          return {
            courseTitle: tree.course.title,
            title: lesson.title,
            exerciseCount: lesson.exercise_count,
          }
  return null
}

/** Its type's name, or the unknown type as written (JSON can hold one). */
const typeName = (type: string): string => TYPE_INFO[type as ExerciseType]?.name ?? type

/** The answer as the CSV would write it, for the table; empty when the
 * exercise is too malformed to say. */
function answerOf(body: ExerciseBody): string {
  try {
    return bodyToRow(body).answer ?? ''
  } catch {
    return ''
  }
}

/** Importing a lesson's exercises from a CSV or JSON file (bolt 056):
 * choose or paste it, check every row (here, then on the server without
 * saving), then add them all, or replace the lesson's, in one step. */
export function ImportPage() {
  const { courseId = '', lessonId = '' } = useParams()
  const { api } = useSession()
  const navigate = useNavigate()

  const [lesson, setLesson] = useState<Lesson | null>(null)
  const [loadError, setLoadError] = useState<string | null>(null)
  const [source, setSource] = useState<string | null>(null)
  const [read, setRead] = useState<ReadResult | null>(null)
  // Server problems, by the row's place in `read.rows`.
  const [serverProblems, setServerProblems] = useState<Record<number, string>>({})
  const [checking, setChecking] = useState(false)
  const [checked, setChecked] = useState(false)
  const [topError, setTopError] = useState<string | null>(null)
  const [pasted, setPasted] = useState('')
  const [mode, setMode] = useState<Mode>('append')
  const [confirming, setConfirming] = useState(false)
  const [saving, setSaving] = useState(false)
  const [previewing, setPreviewing] = useState<number | null>(null)
  // Each read's number; a check that returns after a newer read is ignored.
  const attempt = useRef(0)

  useEffect(() => {
    let live = true
    api.get<AdminCourseTree>(routes.tree(courseId)).then(
      (tree) => {
        if (!live) return
        const found = lessonIn(tree, lessonId)
        if (found) setLesson(found)
        else setLoadError('This lesson does not exist, or belongs to another course.')
      },
      (e: unknown) => {
        if (live) setLoadError(messageOf(e))
      },
    )
    return () => {
      live = false
    }
  }, [api, courseId, lessonId])

  const rows = read?.rows ?? []
  const pending = rows.length > 0 && !saving

  // Leaving with a file read but not added asks first, as the editor does.
  useEffect(() => {
    if (!pending) return
    const warn = (e: BeforeUnloadEvent) => e.preventDefault()
    window.addEventListener('beforeunload', warn)
    return () => window.removeEventListener('beforeunload', warn)
  }, [pending])

  const backTo = `/courses/${courseId}?open=${encodeURIComponent(lessonId)}`

  /** Where each server problem belongs: `bodies[i]` came from `rows[at[i]]`. */
  const placeProblems = (problems: ImportProblem[], at: number[], format: Format) =>
    Object.fromEntries(
      problems.map((p) => [
        at[p.index],
        // A CSV's writer never saw the stored field names; a JSON's did.
        format === 'csv' ? plainMessage(p.message) : p.message,
      ]),
    )

  async function take(text: string, format: Format, name: string) {
    const current = ++attempt.current
    const result = format === 'json' ? readJson(text) : readCsv(text)
    setSource(name)
    setRead(result)
    setServerProblems({})
    setChecked(false)
    setTopError(null)
    setMode('append')
    if (result.error) return
    if (result.rows.length > IMPORT_MAX) {
      setTopError(
        `One import holds at most ${IMPORT_MAX} exercises, and this file has ${result.rows.length}. Split it into smaller files.`,
      )
      return
    }
    const at = result.rows.flatMap((row, i) => (row.body ? [i] : []))
    if (at.length === 0) return
    setChecking(true)
    try {
      await api.post(routes.importExercises(lessonId), {
        exercises: at.map((i) => result.rows[i]!.body),
        dry_run: true,
      })
      if (current === attempt.current) setChecked(true)
    } catch (e) {
      if (current !== attempt.current) return
      if (e instanceof ApiError && e.errorCode === 'invalid_import') {
        setServerProblems(placeProblems(e.details.rows as ImportProblem[], at, format))
        setChecked(true)
      } else setTopError(messageOf(e))
    } finally {
      if (current === attempt.current) setChecking(false)
    }
  }

  async function onFile(e: ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0]
    e.target.value = ''
    if (!file) return
    if (file.size > MAX_BYTES) {
      attempt.current++
      setSource(file.name)
      setRead(null)
      setTopError('This file is over 1 MB. Split it into smaller files.')
      return
    }
    await take(await readText(file), /\.json$/i.test(file.name) ? 'json' : 'csv', file.name)
  }

  const onPaste = () => {
    const text = pasted.trim()
    if (!text) return
    if (new Blob([text]).size > MAX_BYTES) {
      setTopError('This text is over 1 MB. Split it into smaller parts.')
      return
    }
    void take(text, text.startsWith('[') || text.startsWith('{') ? 'json' : 'csv', 'Pasted text')
  }

  const problemOf = (row: ImportRow, i: number): string | null => row.problem ?? serverProblems[i] ?? null
  const failing = rows.filter((row, i) => problemOf(row, i) !== null).length
  const ready = rows.length > 0 && failing === 0 && checked && !checking && !topError && !read?.error

  async function add() {
    setConfirming(false)
    setSaving(true)
    setTopError(null)
    try {
      await api.post(routes.importExercises(lessonId), {
        exercises: rows.map((r) => r.body),
        mode,
      })
      navigate(backTo, { state: { imported: rows.length } })
    } catch (e) {
      if (e instanceof ApiError && e.errorCode === 'invalid_import') {
        const format: Format = rows[0]?.label.startsWith('Row') ? 'csv' : 'json'
        setServerProblems(
          placeProblems(
            e.details.rows as ImportProblem[],
            rows.map((_, i) => i),
            format,
          ),
        )
      } else setTopError(messageOf(e))
      setSaving(false)
    }
  }

  if (loadError) {
    return (
      <Page>
        <div className="rounded-lg border border-line bg-surface p-8 text-center shadow-e1">
          <p role="alert" className="text-base font-semibold text-coffee">
            {loadError}
          </p>
          <Link to={backTo} className="mt-4 inline-flex items-center gap-1 text-sm font-semibold text-forest">
            <Icon name="arrow_back" className="text-base" />
            Back to the lesson
          </Link>
        </div>
      </Page>
    )
  }

  const count = rows.length
  const existing = lesson?.exerciseCount ?? 0

  return (
    <Page>
      <nav aria-label="Breadcrumb" className="flex flex-wrap items-center gap-1.5 text-sm text-stone">
        <Link to="/" className="font-medium hover:text-forest">
          Courses
        </Link>
        <Icon name="chevron_right" className="text-base" />
        <Link to={`/courses/${courseId}`} className="font-medium hover:text-forest">
          {lesson?.courseTitle ?? 'Course'}
        </Link>
        <Icon name="chevron_right" className="text-base" />
        <Link to={backTo} className="font-medium text-coffee hover:text-forest">
          {lesson?.title ?? 'Lesson'}
        </Link>
      </nav>

      <header className="mt-4 flex flex-wrap items-end justify-between gap-4">
        <div>
          <h1 className="text-[1.75rem] leading-9 font-bold tracking-[-0.02em] text-coffee">Import exercises</h1>
          <p className="mt-1 text-sm text-stone">
            From a CSV or JSON file, into{' '}
            {lesson ? <strong className="text-coffee">{lesson.title}</strong> : 'this lesson'}. Nothing is saved until
            you add them.
          </p>
        </div>
        <Link
          to={backTo}
          className="inline-flex h-11 items-center gap-2 rounded border border-line bg-surface px-4 text-sm font-semibold text-coffee hover:bg-inset sm:h-10"
        >
          <Icon name="arrow_back" className="text-lg" />
          Back to lesson
        </Link>
      </header>

      <section className="mt-6 rounded-lg border border-line bg-surface p-4 shadow-e1 sm:p-5">
        <div className="flex flex-wrap items-center gap-3">
          <label className="inline-flex h-11 cursor-pointer items-center gap-2 rounded border border-transparent bg-forest px-4 text-sm font-semibold text-white shadow-e1 hover:bg-forest-hover focus-within:outline-2 focus-within:outline-offset-2 focus-within:outline-forest sm:h-10">
            <Icon name="upload_file" className="text-lg" />
            Choose a file
            <input
              type="file"
              accept=".csv,.json,text/csv,application/json"
              className="sr-only"
              onChange={(e) => void onFile(e)}
            />
          </label>
          <span className="text-sm text-stone">CSV or JSON, up to 1 MB and {IMPORT_MAX} exercises.</span>
        </div>
        <div className="mt-4 flex flex-wrap items-center gap-2 border-t border-line pt-4">
          <span className="text-sm text-coffee-soft">Start from a sample, one exercise of each type:</span>
          <Button size="sm" onClick={() => saveFile('exercises-sample.csv', csvTemplate(), CSV_TYPE)}>
            <Icon name="download" className="text-base" />
            Sample CSV
          </Button>
          <Button size="sm" onClick={() => saveFile('exercises-sample.json', jsonExample(), JSON_TYPE)}>
            <Icon name="download" className="text-base" />
            Sample JSON
          </Button>
        </div>
        <details className="mt-4">
          <summary className="cursor-pointer text-sm font-semibold text-coffee-soft">Or paste the text</summary>
          <label htmlFor="import-paste" className="sr-only">
            CSV or JSON to import
          </label>
          <textarea
            id="import-paste"
            value={pasted}
            onChange={(e) => setPasted(e.target.value)}
            rows={6}
            spellCheck={false}
            className="mt-2 block w-full rounded border border-line bg-surface p-3 font-mono text-sm text-coffee"
            placeholder={'type,prompt,answer,wrong\nmultiple_choice,How do you say "hello"?,ሰላም,ቻው | እሺ'}
          />
          <Button className="mt-2" size="sm" disabled={!pasted.trim()} onClick={onPaste}>
            <Icon name="fact_check" className="text-base" />
            Check pasted text
          </Button>
        </details>
      </section>

      {(topError || read?.error) && (
        <p
          role="alert"
          className="mt-5 flex items-start gap-2 rounded-md border border-danger-line bg-danger-tint px-4 py-3 text-sm text-danger"
        >
          <Icon name="error" className="mt-px text-lg" />
          <span>
            {source && <strong className="font-semibold">{source}: </strong>}
            {topError ?? read?.error}
          </span>
        </p>
      )}

      {count > 0 && !read?.error && (
        <section aria-label="Preview" className="mt-6">
          <div className="flex flex-wrap items-center justify-between gap-3">
            <h2 className="text-lg font-semibold text-coffee">
              {source}: {count === 1 ? '1 exercise' : `${count} exercises`}
            </h2>
            <p role="status" className="text-sm font-semibold">
              {checking ? (
                <span className="inline-flex items-center gap-1.5 text-stone">
                  <Icon name="progress_activity" className="animate-spin text-base" />
                  Checking…
                </span>
              ) : failing > 0 ? (
                <span className="text-danger">
                  {failing === 1 ? '1 row needs fixing' : `${failing} rows need fixing`}. Fix the file and choose it
                  again.
                </span>
              ) : ready ? (
                <span className="inline-flex items-center gap-1.5 text-forest">
                  <Icon name="check_circle" className="text-base" />
                  Every row can be added
                </span>
              ) : null}
            </p>
          </div>

          <div className="mt-3 overflow-x-auto rounded-lg border border-line bg-surface">
            <table className="w-full min-w-[40rem] text-left text-sm">
              <thead className="border-b border-line bg-inset text-xs font-bold tracking-[0.04em] text-stone uppercase">
                <tr>
                  <th scope="col" className="px-3 py-2">
                    Where
                  </th>
                  <th scope="col" className="px-3 py-2">
                    Type
                  </th>
                  <th scope="col" className="px-3 py-2">
                    Prompt
                  </th>
                  <th scope="col" className="px-3 py-2">
                    Answer
                  </th>
                  <th scope="col" className="px-3 py-2">
                    Check
                  </th>
                  <th scope="col" className="px-3 py-2">
                    <span className="sr-only">Preview</span>
                  </th>
                </tr>
              </thead>
              <tbody className="divide-y divide-line">
                {rows.map((row, i) => {
                  const problem = problemOf(row, i)
                  return (
                    <tr key={i} className={cx(problem && 'bg-danger-tint/40')}>
                      <td className="px-3 py-2 whitespace-nowrap text-stone">{row.label}</td>
                      <td className="px-3 py-2 whitespace-nowrap">{row.body ? typeName(row.body.type) : '—'}</td>
                      <td className="max-w-[16rem] px-3 py-2 break-words text-coffee">{row.body?.prompt ?? '—'}</td>
                      <td className="max-w-[14rem] px-3 py-2 break-words">{row.body ? answerOf(row.body) : '—'}</td>
                      <td className="px-3 py-2">
                        {problem ? (
                          <span className="flex items-start gap-1.5 text-danger">
                            <Icon name="error" className="mt-px text-base" />
                            {problem}
                          </span>
                        ) : checked ? (
                          <span className="inline-flex items-center gap-1.5 text-forest">
                            <Icon name="check" className="text-base" />
                            OK
                          </span>
                        ) : (
                          <span className="text-stone">…</span>
                        )}
                      </td>
                      <td className="px-1 py-1 text-right">
                        {row.body && !problem && checked && (
                          <Button
                            size="sm"
                            variant="ghost"
                            aria-label={`Preview ${row.label}`}
                            title="See it as a learner will"
                            onClick={() => setPreviewing(i)}
                          >
                            <Icon name="visibility" className="text-base" />
                            Preview
                          </Button>
                        )}
                      </td>
                    </tr>
                  )
                })}
              </tbody>
            </table>
          </div>

          <div className="mt-5 flex flex-col gap-4 rounded-lg border border-line bg-surface p-4 shadow-e1 sm:flex-row sm:items-end sm:justify-between">
            {existing > 0 ? (
              <fieldset>
                <legend className="text-sm font-semibold text-coffee">
                  This lesson has {existing === 1 ? '1 exercise' : `${existing} exercises`}
                </legend>
                <label className="mt-2 flex items-center gap-2 text-sm text-coffee">
                  <input
                    type="radio"
                    name="mode"
                    checked={mode === 'append'}
                    onChange={() => setMode('append')}
                    className="size-4 accent-forest"
                  />
                  Add these after them
                </label>
                <label className="mt-1 flex items-center gap-2 text-sm text-coffee">
                  <input
                    type="radio"
                    name="mode"
                    checked={mode === 'replace'}
                    onChange={() => setMode('replace')}
                    className="size-4 accent-forest"
                  />
                  Replace them with these
                </label>
              </fieldset>
            ) : (
              <p className="text-sm text-stone">This lesson has no exercises yet.</p>
            )}
            <Button
              variant="primary"
              className="justify-center"
              disabled={!ready || saving}
              onClick={() => (mode === 'replace' ? setConfirming(true) : void add())}
            >
              <Icon
                name={saving ? 'progress_activity' : 'playlist_add'}
                className={saving ? 'animate-spin text-lg' : 'text-lg'}
              />
              {mode === 'replace'
                ? `Replace with ${count}`
                : `Add ${count === 1 ? '1 exercise' : `${count} exercises`}`}
            </Button>
          </div>
        </section>
      )}

      <Help />

      {confirming && (
        <Modal
          title={`Replace the ${existing === 1 ? 'exercise' : `${existing} exercises`}?`}
          onClose={() => setConfirming(false)}
        >
          <p className="mt-2 text-sm leading-6 text-coffee-soft">
            {existing === 1 ? 'The exercise' : `All ${existing} exercises`} in <strong>{lesson?.title}</strong> will be
            deleted, and the {count === 1 ? 'one' : count} in this file added in their place.
          </p>
          <p className="mt-1 text-sm leading-6 text-stone">
            Learners see the change straight away. This cannot be undone; export the lesson first to keep a copy.
          </p>
          <div className="mt-6 flex flex-col-reverse gap-2 sm:flex-row sm:justify-end">
            <Button className="justify-center" onClick={() => setConfirming(false)}>
              Cancel
            </Button>
            <Button variant="danger" className="justify-center" onClick={() => void add()}>
              Replace
            </Button>
          </div>
        </Modal>
      )}

      {previewing !== null && rows[previewing]?.body && (
        <Modal title={`Preview: ${rows[previewing].label}`} onClose={() => setPreviewing(null)} className="sm:max-w-lg">
          <div className="mt-4">
            <ExercisePreview body={rows[previewing].body!} />
          </div>
          <div className="mt-4 flex justify-end">
            <Button onClick={() => setPreviewing(null)}>Close</Button>
          </div>
        </Modal>
      )}
    </Page>
  )
}

/** What each column holds, with one example per type (the samples above). */
function Help() {
  return (
    <details className="mt-8 rounded-lg border border-line bg-surface p-4 shadow-e1 sm:p-5">
      <summary className="cursor-pointer text-base font-semibold text-coffee">How to write the file</summary>
      <div className="mt-4 space-y-4 text-sm leading-6 text-coffee-soft">
        <p>
          <strong className="text-coffee">CSV:</strong> one row per exercise, with a header row. The columns are{' '}
          {COLUMNS.map((c, i) => (
            <span key={c}>
              <code className="rounded-sm bg-inset px-1">{c}</code>
              {i < COLUMNS.length - 1 ? ', ' : ''}
            </span>
          ))}
          ; leave out any you don't need. Separate several items in a cell with{' '}
          <code className="rounded-sm bg-inset px-1">|</code>. In Excel, save as <strong>CSV UTF-8</strong> so Amharic
          is kept.
        </p>
        <ul className="list-disc space-y-1 pl-5">
          <li>
            <strong>answer</strong>: the correct choice; for a sentence, its words in order; for spell tiles, the word
            (one tile per letter); for match pairs, <code>left=right</code> pairs; for pictures, the correct picture's
            address.
          </li>
          <li>
            <strong>wrong</strong>: the wrong choices or pictures, or extra words and tiles.
          </li>
          <li>
            <strong>sentence</strong> (gap fill): the sentence, with <code>___</code> where the gap is.
          </li>
          <li>
            <strong>audio_url</strong> (listening, audio image choice) and pictures: addresses of files already
            uploaded, starting <code>https://</code>.
          </li>
          <li>
            <strong>descriptions</strong> (pictures, optional): for the answer's picture, then each wrong one.
          </li>
          <li>
            <strong>pronunciation</strong> (optional): the prompt's word or sentence in Latin letters, e.g.{' '}
            <code>bunna</code>; for gap fill, the sentence with <code>___</code>. Not for questions that are only heard.
          </li>
          <li>
            <strong>answer_pronunciation</strong>, <strong>wrong_pronunciation</strong> (optional): each item of{' '}
            <strong>answer</strong> and <strong>wrong</strong> in Latin letters, in the same order, separated with{' '}
            <code>|</code>. Leave a place empty for an item without one (<code>selam | | wuha</code>). For match pairs,
            write <code>left=right</code> (<code>selam=</code> when only the left word needs one).
          </li>
        </ul>
        <p>Choices are mixed up, so the answer isn't always first. The same file always gives the same order.</p>
        <div className="overflow-x-auto rounded border border-line">
          <table className="w-full min-w-[40rem] text-left text-xs">
            <thead className="bg-inset font-bold text-stone">
              <tr>
                {COLUMNS.map((c) => (
                  <th key={c} scope="col" className="px-2 py-1.5">
                    {c}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody className="divide-y divide-line">
              {EXAMPLES.map((row) => (
                <tr key={row.type}>
                  {COLUMNS.map((c) => (
                    <td key={c} className="px-2 py-1.5 break-words">
                      {row[c]}
                    </td>
                  ))}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        <p>
          <strong className="text-coffee">JSON:</strong> a list of exercises as the site stores them (<code>type</code>,{' '}
          <code>prompt</code>, <code>content</code>, <code>answer_key</code>), or a file from Export JSON. It is added
          exactly as written.
        </p>
      </div>
    </details>
  )
}

function Page({ children }: { children: ReactNode }) {
  return <main className="mx-auto max-w-6xl px-4 py-6 sm:px-6 lg:px-8 lg:py-8">{children}</main>
}
