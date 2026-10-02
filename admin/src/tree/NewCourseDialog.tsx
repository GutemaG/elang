import { useEffect, useId, useState, type FormEvent } from 'react'
import { Link, useNavigate } from 'react-router-dom'

import { messageOf, useSession } from '../auth/SessionContext'
import type { AdminCourse, AdminLanguage, AdminLanguageList } from '../types'
import { Button } from '../ui/Button'
import { FIELD_CLASS, Input } from '../ui/Input'
import { Modal } from '../ui/Modal'
import { routes } from './levels'

/** A new course for a language pair. The pairs come from the languages
 * table, so a language added there can be picked here straight away. The
 * course starts as coming soon; it opens on its (empty) curriculum. */
export function NewCourseDialog({ taken, onClose }: { taken: AdminCourse[]; onClose: () => void }) {
  const { api } = useSession()
  const navigate = useNavigate()
  const ids = { learning: useId(), from: useId(), title: useId() }
  const [languages, setLanguages] = useState<AdminLanguage[] | null>(null)
  const [learning, setLearning] = useState('')
  const [from, setFrom] = useState('')
  const [title, setTitle] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    let live = true
    api.get<AdminLanguageList>(routes.languages).then(
      (list) => live && setLanguages(list.languages),
      (e: unknown) => live && setError(messageOf(e)),
    )
    return () => {
      live = false
    }
  }, [api])

  const nameOf = (code: string) => languages?.find((l) => l.code === code)?.name ?? code
  const existing = taken.find((c) => c.learning_language === learning && c.from_language === from)
  const problem =
    learning && from && learning === from
      ? 'Pick two different languages.'
      : existing
        ? `“${existing.title}” already teaches ${nameOf(learning)} to ${nameOf(from)} speakers.`
        : null
  const suggested = learning && from ? `${nameOf(from)} to ${nameOf(learning)}` : 'e.g. English to Tigrinya'

  async function submit(e: FormEvent) {
    e.preventDefault()
    if (!learning || !from || problem) return
    setBusy(true)
    setError(null)
    try {
      const course = await api.post<AdminCourse>(routes.courses, {
        learning_language: learning,
        from_language: from,
        title: title.trim(),
      })
      navigate(`/courses/${course.id}`)
    } catch (err) {
      setError(messageOf(err))
      setBusy(false)
    }
  }

  return (
    <Modal title="New course" onClose={() => !busy && onClose()}>
      <p className="mt-2 text-sm leading-6 text-stone">
        A course teaches one language to speakers of another. It starts as <strong>coming soon</strong>: learners
        see it but can’t pick it until you make it available.
      </p>
      <form className="mt-5 space-y-4" onSubmit={(e) => void submit(e)}>
        <div className="grid gap-4 sm:grid-cols-2">
          <LanguageSelect id={ids.learning} label="Language to learn" value={learning} languages={languages} onChange={setLearning} />
          <LanguageSelect id={ids.from} label="Learners speak" value={from} languages={languages} onChange={setFrom} />
        </div>
        <div>
          <label htmlFor={ids.title} className="mb-1.5 block text-sm font-semibold text-coffee">
            Title <span className="font-normal text-stone">(optional)</span>
          </label>
          <Input id={ids.title} value={title} placeholder={suggested} maxLength={255} onChange={(e) => setTitle(e.target.value)} />
        </div>
        <p className="text-xs text-stone">
          Missing a language?{' '}
          <Link to="/languages" className="font-semibold text-forest hover:underline">
            Add it in Languages
          </Link>
          .
        </p>
        {(problem || error) && (
          <p role="alert" className="text-sm text-danger">
            {problem ?? error}
          </p>
        )}
        <div className="flex flex-col-reverse gap-2 pt-2 sm:flex-row sm:justify-end">
          <Button className="justify-center" disabled={busy} onClick={onClose}>
            Cancel
          </Button>
          <Button type="submit" variant="primary" className="justify-center" disabled={busy || !learning || !from || !!problem}>
            Create course
          </Button>
        </div>
      </form>
    </Modal>
  )
}

function LanguageSelect({
  id,
  label,
  value,
  languages,
  onChange,
}: {
  id: string
  label: string
  value: string
  languages: AdminLanguage[] | null
  onChange: (code: string) => void
}) {
  return (
    <div>
      <label htmlFor={id} className="mb-1.5 block text-sm font-semibold text-coffee">
        {label}
      </label>
      <select id={id} className={FIELD_CLASS} value={value} disabled={!languages} onChange={(e) => onChange(e.target.value)}>
        <option value="">{languages ? 'Choose a language' : 'Loading…'}</option>
        {languages?.map((l) => (
          <option key={l.code} value={l.code}>
            {l.name} · {l.native_name}
          </option>
        ))}
      </select>
    </div>
  )
}
