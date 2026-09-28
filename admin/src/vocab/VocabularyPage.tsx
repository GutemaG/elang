import { useCallback, useEffect, useState, type FormEvent, type KeyboardEvent, type ReactNode } from 'react'
import { Link, useParams } from 'react-router-dom'

import { ApiError } from '../api'
import { messageOf, useSession } from '../auth/SessionContext'
import { TYPE_INFO } from '../exercises/model'
import { plural } from '../format'
import { StatCard, StatRow } from '../shell/Page'
import { routes } from '../tree/levels'
import type { AdminVocabItem, AdminVocabList, ExerciseType } from '../types'
import { Button } from '../ui/Button'
import { Icon } from '../ui/Icon'
import { Input } from '../ui/Input'

type Field = 'word' | 'translation'
type FieldErrors = Partial<Record<Field, string>>

const asError = (e: unknown): Error => (e instanceof Error ? e : new Error(messageOf(e)))

/** For search: Latin ignores case; Ge'ez has none. */
const fold = (text: string) => text.trim().toLocaleLowerCase()

const typeName = (type: string) => TYPE_INFO[type as ExerciseType]?.name ?? type

/** One course's practice words (bolt 040): where each is used, how many
 * learners practise it, and an edit that keeps their progress. Like the
 * tree, nothing is kept locally -- every save is followed by a reload. */
export function VocabularyPage() {
  const { courseId = '' } = useParams()
  const { api } = useSession()
  const [list, setList] = useState<AdminVocabList | null>(null)
  const [loadError, setLoadError] = useState<Error | null>(null)
  const [writeError, setWriteError] = useState<string | null>(null)
  const [editing, setEditing] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)
  const [query, setQuery] = useState('')

  const fetchList = useCallback(() => api.get<AdminVocabList>(routes.vocab(courseId)), [api, courseId])

  const load = useCallback(async () => {
    try {
      setList(await fetchList())
      setLoadError(null)
    } catch (e) {
      setLoadError(asError(e))
    }
  }, [fetchList])

  useEffect(() => {
    let live = true
    fetchList().then(
      (l) => {
        if (!live) return
        setList(l)
        setLoadError(null)
      },
      (e: unknown) => {
        if (live) setLoadError(asError(e))
      },
    )
    return () => {
      live = false
    }
  }, [fetchList])

  /** Saves one word. Resolves to the field errors to show, or null when
   * saved (the form then closes). */
  const save = async (id: string, values: Record<Field, string>): Promise<FieldErrors | null> => {
    setBusy(true)
    setWriteError(null)
    try {
      await api.patch(routes.vocabItem(id), values)
      await load()
      return null
    } catch (e) {
      const field = e instanceof ApiError && e.status === 422 ? e.details.field : undefined
      if (field === 'word') return { word: messageOf(e) }
      if (field === 'translation') return { translation: messageOf(e) }
      setWriteError(messageOf(e))
      if (!(e instanceof ApiError && e.status === 401)) await load()
      return {}
    } finally {
      setBusy(false)
    }
  }

  if (!list) {
    if (loadError) {
      const notFound = loadError instanceof ApiError && loadError.status === 404
      return (
        <Page>
          <div className="rounded-lg border border-line bg-surface p-8 text-center shadow-e1">
            <span className="mx-auto grid size-12 place-items-center rounded-full bg-terracotta-tint text-terracotta">
              <Icon name={notFound ? 'search_off' : 'cloud_off'} className="text-2xl" />
            </span>
            <p role="alert" className="mt-4 text-base font-semibold text-coffee">
              {notFound ? 'This course does not exist.' : loadError.message}
            </p>
            <div className="mt-5 flex justify-center gap-2">
              {!notFound && (
                <Button variant="primary" onClick={() => void load()}>
                  Try again
                </Button>
              )}
              <Link
                to="/vocabulary"
                className="inline-flex h-11 items-center gap-2 rounded border border-line bg-surface px-4 text-sm font-semibold text-coffee hover:bg-inset sm:h-10"
              >
                All courses
              </Link>
            </div>
          </div>
        </Page>
      )
    }
    return (
      <Page>
        <div className="animate-pulse space-y-4" aria-busy="true">
          <p className="sr-only">Loading…</p>
          <div className="h-44 rounded-lg bg-inset" />
          <div className="h-16 rounded-lg bg-inset" />
          <div className="h-16 rounded-lg bg-inset" />
        </div>
      </Page>
    )
  }

  const { course, items } = list
  const used = items.filter((item) => item.used_by.length > 0).length
  const q = fold(query)
  const shown = q ? items.filter((item) => fold(item.word).includes(q) || fold(item.translation).includes(q)) : items

  return (
    <Page>
      <nav aria-label="Breadcrumb" className="flex min-w-0 items-center gap-1.5 text-sm text-stone">
        <Link to="/vocabulary" className="shrink-0 font-medium hover:text-forest">
          Vocabulary
        </Link>
        <Icon name="chevron_right" className="text-base" />
        <span className="min-w-0 truncate font-medium text-coffee">{course.title}</span>
      </nav>

      <section className="mt-4 rounded-lg border border-line bg-surface p-5 shadow-e1 sm:p-7">
        <div className="flex flex-wrap items-start justify-between gap-4">
          <div className="min-w-0 flex-[1_1_20rem]">
            <p className="text-xs font-bold tracking-[0.12em] text-forest uppercase">Vocabulary</p>
            <h1 className="mt-1 text-[1.75rem] leading-9 font-bold tracking-[-0.02em] break-words text-coffee lg:text-4xl lg:leading-11">
              {course.title}
            </h1>
            <p className="mt-2 max-w-2xl text-sm leading-6 text-stone">
              The words Practice brings back to each learner. Editing one keeps everyone's progress on it; the
              question learners see is edited in its exercise.
            </p>
          </div>
          <Link
            to={`/courses/${course.id}`}
            className="inline-flex h-11 items-center gap-2 rounded border border-line bg-surface px-4 text-sm font-semibold text-coffee hover:bg-inset sm:h-10"
          >
            <Icon name="menu_book" className="text-lg" />
            Curriculum
          </Link>
        </div>
        <StatRow className="border-t border-line pt-5">
          <StatCard icon="translate" label="Words" value={items.length} />
          <StatCard icon="quiz" label="In exercises" value={used} tone="forest" />
          <StatCard
            icon="link_off"
            label="Not used"
            value={items.length - used}
            tone={items.length - used > 0 ? 'terracotta' : 'coffee'}
          />
          <StatCard icon="group" label="Learners practising" value={list.learners} />
        </StatRow>
      </section>

      {writeError && (
        <div
          role="alert"
          className="mt-5 flex items-start gap-3 rounded-md border border-danger-line bg-danger-tint px-4 py-3 text-sm text-danger"
        >
          <Icon name="error" className="mt-px text-lg" />
          <span className="flex-1">{writeError}</span>
          <Button size="icon" variant="danger-ghost" aria-label="Dismiss" onClick={() => setWriteError(null)}>
            <Icon name="close" className="text-lg" />
          </Button>
        </div>
      )}
      {loadError && (
        <p className="mt-5 flex items-center gap-2 text-sm text-danger">
          <Icon name="sync_problem" className="text-lg" />
          Could not refresh: {loadError.message}
        </p>
      )}

      <section className="mt-8 rounded-lg border border-line bg-surface shadow-e1">
        <div className="flex flex-wrap items-center justify-between gap-3 border-b border-line px-4 py-4 sm:px-6">
          <div className="min-w-0">
            <h2 className="text-lg leading-6 font-semibold text-coffee">Words</h2>
            <p className="text-xs text-stone">
              {q ? `${shown.length} of ${plural(items.length, 'word')}` : plural(items.length, 'word')}, in the order
              learners meet them.
            </p>
          </div>
          {items.length > 0 && (
            <label className="relative w-full sm:w-72">
              <span className="sr-only">Search words</span>
              <Icon
                name="search"
                className="pointer-events-none absolute top-1/2 left-3 -translate-y-1/2 text-lg text-stone"
              />
              <Input
                type="search"
                placeholder="Search word or translation"
                value={query}
                className="pl-10"
                onChange={(e) => setQuery(e.target.value)}
              />
            </label>
          )}
        </div>

        {items.length === 0 && (
          <p className="px-6 py-12 text-center text-sm text-stone">This course has no practice words yet.</p>
        )}
        {items.length > 0 && shown.length === 0 && (
          <p className="px-6 py-12 text-center text-sm text-stone">No word matches “{query.trim()}”.</p>
        )}

        <ul className="divide-y divide-line">
          {shown.map((item) => (
            <li key={item.id} className="px-4 py-4 sm:px-6">
              {editing === item.id ? (
                <EditForm
                  item={item}
                  busy={busy}
                  onSave={(values) => save(item.id, values)}
                  onClose={() => setEditing(null)}
                />
              ) : (
                <WordRow
                  item={item}
                  courseId={course.id}
                  busy={busy}
                  onEdit={() => {
                    setWriteError(null)
                    setEditing(item.id)
                  }}
                />
              )}
            </li>
          ))}
        </ul>
      </section>
    </Page>
  )
}

function WordRow({
  item,
  courseId,
  busy,
  onEdit,
}: {
  item: AdminVocabItem
  courseId: string
  busy: boolean
  onEdit: () => void
}) {
  return (
    <div className="flex flex-wrap items-start gap-x-4 gap-y-3">
      {/* A 12rem basis keeps the word beside its uses on a laptop and puts
          the uses on their own line on a phone. */}
      <div className="min-w-0 flex-[1_1_12rem]">
        <p className="text-xl leading-7 font-semibold break-words text-coffee">
          {item.word}
        </p>
        <p className="text-sm break-words text-stone">{item.translation}</p>
      </div>

      <div className="min-w-0 flex-[2_1_16rem]">
        {item.used_by.length === 0 ? (
          <p className="flex items-center gap-1.5 text-sm text-terracotta">
            <Icon name="link_off" className="text-base" />
            Not in any exercise
          </p>
        ) : (
          <ul className="space-y-1" aria-label={`Exercises practising ${item.word}`}>
            {item.used_by.map((use) => (
              <li key={use.exercise_id} className="min-w-0">
                <Link
                  to={`/courses/${courseId}/lessons/${use.lesson_id}/exercises/${use.exercise_id}`}
                  title={`${use.section_title} › ${use.skill_title} › ${use.lesson_title}`}
                  className="inline-flex max-w-full items-baseline gap-2 rounded text-sm text-coffee hover:text-forest"
                >
                  <span className="tnum shrink-0 text-xs font-bold text-forest">{use.number}</span>
                  <span className="min-w-0 truncate">
                    {use.lesson_title}
                    <span className="text-stone"> · {typeName(use.type)}</span>
                  </span>
                </Link>
              </li>
            ))}
          </ul>
        )}
      </div>

      <div className="ml-auto flex items-center gap-2">
        <span
          className="tnum inline-flex items-center gap-1 rounded-full bg-inset px-2.5 py-0.5 text-xs font-semibold text-coffee-soft"
          title="Learners practising this word"
        >
          <Icon name="group" className="text-sm" />
          {item.learners}
          <span className="sr-only">{item.learners === 1 ? 'learner' : 'learners'}</span>
        </span>
        <Button size="sm" variant="outline" disabled={busy} aria-label={`Edit ${item.word}`} onClick={onEdit}>
          <Icon name="edit" className="text-lg sm:text-base" />
          <span className="hidden sm:inline">Edit</span>
        </Button>
      </div>
    </div>
  )
}

function EditForm({
  item,
  busy,
  onSave,
  onClose,
}: {
  item: AdminVocabItem
  busy: boolean
  onSave: (values: Record<Field, string>) => Promise<FieldErrors | null>
  onClose: () => void
}) {
  const [word, setWord] = useState(item.word)
  const [translation, setTranslation] = useState(item.translation)
  const [errors, setErrors] = useState<FieldErrors>({})
  const blank = word.trim() === '' || translation.trim() === ''

  async function submit(e: FormEvent) {
    e.preventDefault()
    if (blank) return
    const result = await onSave({ word: word.trim(), translation: translation.trim() })
    if (result === null) onClose()
    else setErrors(result)
  }

  const escape = (e: KeyboardEvent) => e.key === 'Escape' && onClose()

  return (
    <form aria-label={`Edit ${item.word}`} onSubmit={(e) => void submit(e)} className="space-y-3">
      <div className="grid gap-3 sm:grid-cols-2">
        <Labelled label="Word" error={errors.word}>
          <Input
            aria-invalid={errors.word ? true : undefined}
            value={word}
            autoFocus
            onChange={(e) => setWord(e.target.value)}
            onKeyDown={escape}
          />
        </Labelled>
        <Labelled label="Translation" error={errors.translation}>
          <Input
            aria-invalid={errors.translation ? true : undefined}
            value={translation}
            onChange={(e) => setTranslation(e.target.value)}
            onKeyDown={escape}
          />
        </Labelled>
      </div>
      <p className="flex items-start gap-1.5 text-xs text-stone">
        <Icon name="info" className="text-sm" />
        Learners keep their progress. The question itself is edited in its exercise.
      </p>
      <div className="flex gap-2">
        <Button type="submit" variant="primary" disabled={busy || blank}>
          <Icon name="check" className="text-lg" />
          Save
        </Button>
        <Button variant="ghost" onClick={onClose}>
          Cancel
        </Button>
      </div>
    </form>
  )
}

function Labelled({ label, error, children }: { label: string; error?: string; children: ReactNode }) {
  return (
    <div className="min-w-0">
      <label className="block">
        <span className="mb-1 block text-xs font-semibold text-coffee-soft">{label}</span>
        {children}
      </label>
      {error && (
        <p role="alert" className="mt-1 text-xs text-danger">
          {error}
        </p>
      )}
    </div>
  )
}

function Page({ children }: { children: ReactNode }) {
  return <main className="mx-auto max-w-6xl px-4 py-6 sm:px-6 lg:px-8 lg:py-8">{children}</main>
}
