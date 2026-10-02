import { useCallback, useEffect, useId, useState, type FormEvent } from 'react'

import { messageOf, useSession } from '../auth/SessionContext'
import { languageGlyph, plural } from '../format'
import { PageHeader } from '../shell/Page'
import { routes } from '../tree/levels'
import type { AdminLanguage, AdminLanguageList } from '../types'
import { Badge } from '../ui/Badge'
import { Button } from '../ui/Button'
import { Icon } from '../ui/Icon'
import { Input } from '../ui/Input'
import { Modal } from '../ui/Modal'

type Editing = { kind: 'new' } | { kind: 'edit'; language: AdminLanguage }

/** The languages courses are made from. Adding one here is all it takes to
 * create courses for it: the app reads each language's names from the
 * server, so it needs no update. */
export function LanguagesPage() {
  const { api } = useSession()
  const [languages, setLanguages] = useState<AdminLanguage[] | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [editing, setEditing] = useState<Editing | null>(null)
  const [deleting, setDeleting] = useState<AdminLanguage | null>(null)
  const [busy, setBusy] = useState(false)

  const load = useCallback(async () => {
    try {
      setLanguages((await api.get<AdminLanguageList>(routes.languages)).languages)
      setError(null)
    } catch (e) {
      setError(messageOf(e))
    }
  }, [api])

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

  async function remove(language: AdminLanguage) {
    setBusy(true)
    try {
      await api.delete(routes.language(language.code))
      setDeleting(null)
      await load()
    } catch (e) {
      setDeleting(null)
      setError(messageOf(e))
    } finally {
      setBusy(false)
    }
  }

  return (
    <main className="mx-auto max-w-6xl px-4 py-6 sm:px-6 lg:px-8 lg:py-8">
      <PageHeader
        eyebrow="Curriculum"
        title="Languages"
        description="The languages a course can teach or teach from. Add one here, then create its courses under Curriculum — the app shows its name without an update."
        actions={
          <Button variant="primary" onClick={() => setEditing({ kind: 'new' })}>
            <Icon name="add" className="text-lg" />
            Add language
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

      <section className="mt-6 overflow-hidden rounded-lg border border-line bg-surface shadow-e1">
        <div className="border-b border-line px-4 py-4 sm:px-6">
          <h2 className="text-lg leading-6 font-semibold text-coffee">All languages</h2>
          <p className="text-xs text-stone">
            {languages ? plural(languages.length, 'language') : 'Loading…'}, by name. One a course uses can’t be
            deleted.
          </p>
        </div>
        {languages?.length === 0 && (
          <p className="px-6 py-12 text-center text-sm text-stone">There are no languages yet.</p>
        )}
        <ul className="divide-y divide-line">
          {languages?.map((language) => (
            <li key={language.code} className="flex items-center gap-4 px-4 py-3 sm:px-6">
              <span
                aria-hidden="true"
                className="grid size-11 shrink-0 place-items-center rounded-md border border-line bg-inset text-lg font-bold text-coffee"
              >
                {languageGlyph(language.native_name)}
              </span>
              <span className="min-w-0 flex-1">
                <span className="flex flex-wrap items-center gap-2">
                  <span className="text-base font-semibold text-coffee">{language.name}</span>
                  <span className="text-sm text-stone">{language.native_name}</span>
                  <Badge tone="forest">{language.code}</Badge>
                </span>
                <span className="mt-0.5 block text-sm text-stone">
                  {language.course_count === 0 ? 'No courses yet' : `Used by ${plural(language.course_count, 'course')}`}
                </span>
              </span>
              <Button
                size="icon"
                variant="ghost"
                aria-label={`Edit ${language.name}`}
                onClick={() => setEditing({ kind: 'edit', language })}
              >
                <Icon name="edit" className="text-lg" />
              </Button>
              <Button
                size="icon"
                variant="danger-ghost"
                aria-label={`Delete ${language.name}`}
                disabled={language.course_count > 0}
                title={language.course_count > 0 ? 'Courses use this language' : undefined}
                onClick={() => setDeleting(language)}
              >
                <Icon name="delete" className="text-lg" />
              </Button>
            </li>
          ))}
        </ul>
      </section>

      {editing && (
        <LanguageDialog
          editing={editing}
          onClose={() => setEditing(null)}
          onSaved={() => {
            setEditing(null)
            void load()
          }}
        />
      )}

      {deleting && (
        <Modal title={`Delete ${deleting.name}?`} onClose={() => !busy && setDeleting(null)}>
          <p className="mt-2 text-sm leading-6 text-coffee-soft">
            No course uses it. It stops being offered for new courses.
          </p>
          <div className="mt-6 flex flex-col-reverse gap-2 sm:flex-row sm:justify-end">
            <Button className="justify-center" disabled={busy} onClick={() => setDeleting(null)}>
              Cancel
            </Button>
            <Button variant="danger" className="justify-center" disabled={busy} onClick={() => void remove(deleting)}>
              Delete
            </Button>
          </div>
        </Modal>
      )}
    </main>
  )
}

function LanguageDialog({
  editing,
  onClose,
  onSaved,
}: {
  editing: Editing
  onClose: () => void
  onSaved: () => void
}) {
  const { api } = useSession()
  const existing = editing.kind === 'edit' ? editing.language : null
  const ids = { code: useId(), name: useId(), native: useId() }
  const [code, setCode] = useState(existing?.code ?? '')
  const [name, setName] = useState(existing?.name ?? '')
  const [nativeName, setNativeName] = useState(existing?.native_name ?? '')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const ready = /^[a-z]{2,3}$/.test(code.trim().toLowerCase()) && name.trim() !== '' && nativeName.trim() !== ''

  async function submit(e: FormEvent) {
    e.preventDefault()
    if (!ready) return
    setBusy(true)
    setError(null)
    try {
      if (existing) {
        await api.patch(routes.language(existing.code), { name: name.trim(), native_name: nativeName.trim() })
      } else {
        await api.post(routes.languages, {
          code: code.trim().toLowerCase(),
          name: name.trim(),
          native_name: nativeName.trim(),
        })
      }
      onSaved()
    } catch (err) {
      setError(messageOf(err))
      setBusy(false)
    }
  }

  return (
    <Modal title={existing ? `Edit ${existing.name}` : 'Add language'} onClose={() => !busy && onClose()}>
      <form className="mt-5 space-y-4" onSubmit={(e) => void submit(e)}>
        <div>
          <label htmlFor={ids.code} className="mb-1.5 block text-sm font-semibold text-coffee">
            Code
          </label>
          <Input
            id={ids.code}
            value={code}
            disabled={!!existing}
            maxLength={3}
            placeholder="e.g. ti or sid"
            autoComplete="off"
            onChange={(e) => setCode(e.target.value)}
          />
          <p className="mt-1 text-xs text-stone">
            {existing
              ? 'A code never changes: courses and learners refer to it.'
              : 'Its ISO 639 code: two letters (ti, so) or, if it has none, three (sid, wal).'}
          </p>
        </div>
        <div className="grid gap-4 sm:grid-cols-2">
          <div>
            <label htmlFor={ids.name} className="mb-1.5 block text-sm font-semibold text-coffee">
              Name in English
            </label>
            <Input id={ids.name} value={name} maxLength={64} placeholder="Tigrinya" onChange={(e) => setName(e.target.value)} />
          </div>
          <div>
            <label htmlFor={ids.native} className="mb-1.5 block text-sm font-semibold text-coffee">
              Its own name
            </label>
            <Input
              id={ids.native}
              value={nativeName}
              maxLength={64}
              placeholder="ትግርኛ"
              onChange={(e) => setNativeName(e.target.value)}
            />
          </div>
        </div>
        {error && (
          <p role="alert" className="text-sm text-danger">
            {error}
          </p>
        )}
        <div className="flex flex-col-reverse gap-2 pt-2 sm:flex-row sm:justify-end">
          <Button className="justify-center" disabled={busy} onClick={onClose}>
            Cancel
          </Button>
          <Button type="submit" variant="primary" className="justify-center" disabled={busy || !ready}>
            {existing ? 'Save' : 'Add language'}
          </Button>
        </div>
      </form>
    </Modal>
  )
}
