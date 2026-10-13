import { useEffect, useId, useState, type FormEvent } from 'react'

import { ApiError } from '../api'
import { messageOf, useSession } from '../auth/SessionContext'
import { routes } from '../tree/levels'
import type { AdminCourse, AdminCourseList, AdminRole } from '../types'
import { Button } from '../ui/Button'
import { cx } from '../ui/cx'
import { Input } from '../ui/Input'
import { Modal } from '../ui/Modal'
import { ROLE_LABEL, TEAM, teamMember, type TeamMember } from './api'

const ROLE_HINT: Record<AdminRole, string> = {
  course_admin: 'Works on the courses you choose',
  super_admin: 'Everything, including the team and configuration',
}

type Field = 'email' | 'role' | 'course_ids'

/** Adds an admin, or changes one's role and courses (intent 028). The
 * email of an existing admin can't change: remove them and add the new
 * address instead. */
export function MemberDialog({
  member,
  onClose,
  onSaved,
}: {
  member: TeamMember | null
  onClose: () => void
  onSaved: () => void
}) {
  const { api } = useSession()
  const ids = { email: useId(), courses: useId() }
  const [email, setEmail] = useState(member?.email ?? '')
  const [role, setRole] = useState<AdminRole>(member?.role ?? 'course_admin')
  const [chosen, setChosen] = useState<Set<string>>(() => new Set(member?.courses.map((c) => c.id)))
  const [courses, setCourses] = useState<AdminCourse[] | null>(null)
  const [busy, setBusy] = useState(false)
  const [errors, setErrors] = useState<Partial<Record<Field, string>>>({})
  const [problem, setProblem] = useState<string | null>(null)

  useEffect(() => {
    let live = true
    api.get<AdminCourseList>(routes.courses).then(
      (list) => live && setCourses(list.courses),
      (e: unknown) => live && setProblem(messageOf(e)),
    )
    return () => {
      live = false
    }
  }, [api])

  function toggle(id: string) {
    setChosen((now) => {
      const next = new Set(now)
      if (next.has(id)) next.delete(id)
      else next.add(id)
      return next
    })
    setErrors((e) => ({ ...e, course_ids: undefined }))
  }

  const allChosen = !!courses?.length && courses.every((c) => chosen.has(c.id))
  const ready = member !== null || email.trim() !== ''

  async function submit(e: FormEvent) {
    e.preventDefault()
    if (!ready) return
    setBusy(true)
    setErrors({})
    setProblem(null)
    const course_ids = role === 'course_admin' ? [...chosen] : []
    try {
      if (member?.id) await api.put(teamMember(member.id), { role, course_ids })
      else await api.post(TEAM, { email: email.trim(), role, course_ids })
      onSaved()
    } catch (err) {
      const field = err instanceof ApiError ? err.details.field : undefined
      if (field === 'email' || field === 'role' || field === 'course_ids') {
        setErrors({ [field]: messageOf(err) })
      } else {
        setProblem(messageOf(err))
      }
      setBusy(false)
    }
  }

  return (
    <Modal
      title={member ? `Edit ${member.email}` : 'Add admin'}
      onClose={() => !busy && onClose()}
      className="sm:max-w-lg"
    >
      <form className="mt-5 space-y-5" onSubmit={(e) => void submit(e)}>
        <div>
          <label htmlFor={ids.email} className="mb-1.5 block text-sm font-semibold text-coffee">
            Email
          </label>
          <Input
            id={ids.email}
            type="email"
            value={email}
            disabled={!!member}
            autoFocus={!member}
            autoComplete="off"
            placeholder="name@example.com"
            onChange={(e) => {
              setEmail(e.target.value)
              setErrors((x) => ({ ...x, email: undefined }))
            }}
          />
          {errors.email ? (
            <p role="alert" className="mt-1 text-xs text-danger">
              {errors.email}
            </p>
          ) : (
            <p className="mt-1 text-xs text-stone">
              {member
                ? 'An address can’t change: remove this admin and add the new one.'
                : 'They sign in with Google using this address. No email is sent.'}
            </p>
          )}
        </div>

        <fieldset>
          <legend className="mb-1.5 block text-sm font-semibold text-coffee">Role</legend>
          <div className="grid gap-2 sm:grid-cols-2">
            {(['course_admin', 'super_admin'] as const).map((r) => (
              <label
                key={r}
                className={cx(
                  'flex cursor-pointer items-start gap-2.5 rounded-md border px-3 py-2.5',
                  role === r ? 'border-forest bg-inset' : 'border-line hover:bg-inset',
                )}
              >
                <input
                  type="radio"
                  name="role"
                  value={r}
                  checked={role === r}
                  onChange={() => {
                    setRole(r)
                    setErrors({})
                  }}
                  className="mt-1 accent-forest"
                />
                <span className="min-w-0">
                  <span className="block text-sm font-semibold text-coffee">{ROLE_LABEL[r]}</span>
                  <span className="block text-xs text-stone">{ROLE_HINT[r]}</span>
                </span>
              </label>
            ))}
          </div>
          {errors.role && (
            <p role="alert" className="mt-1 text-xs text-danger">
              {errors.role}
            </p>
          )}
        </fieldset>

        {role === 'course_admin' && (
          <fieldset aria-describedby={ids.courses}>
            <div className="mb-1.5 flex items-center justify-between gap-2">
              <legend className="text-sm font-semibold text-coffee">Courses</legend>
              {!!courses?.length && (
                <Button
                  size="sm"
                  variant="ghost"
                  onClick={() => setChosen(allChosen ? new Set() : new Set(courses.map((c) => c.id)))}
                >
                  {allChosen ? 'Clear all' : 'Select all'}
                </Button>
              )}
            </div>
            {!courses && <p className="text-sm text-stone">Loading courses…</p>}
            {courses?.length === 0 && <p className="text-sm text-stone">There are no courses yet.</p>}
            <div className="grid gap-1.5">
              {courses?.map((course) => (
                <label key={course.id} className="flex cursor-pointer items-center gap-2.5 text-sm text-coffee">
                  <input
                    type="checkbox"
                    checked={chosen.has(course.id)}
                    onChange={() => toggle(course.id)}
                    className="size-4 accent-forest"
                  />
                  {course.title}
                </label>
              ))}
            </div>
            {errors.course_ids ? (
              <p role="alert" className="mt-1 text-xs text-danger">
                {errors.course_ids}
              </p>
            ) : (
              <p id={ids.courses} className="mt-1 text-xs text-stone">
                They see and change only these. None is fine for now.
              </p>
            )}
          </fieldset>
        )}

        {problem && (
          <p role="alert" className="text-sm text-danger">
            {problem}
          </p>
        )}
        <div className="flex flex-col-reverse gap-2 pt-1 sm:flex-row sm:justify-end">
          <Button className="justify-center" disabled={busy} onClick={onClose}>
            Cancel
          </Button>
          <Button type="submit" variant="primary" className="justify-center" disabled={busy || !ready}>
            {busy ? 'Saving…' : member ? 'Save' : 'Add admin'}
          </Button>
        </div>
      </form>
    </Modal>
  )
}
