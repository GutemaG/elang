import { useEffect, useState } from 'react'
import { Link, useParams } from 'react-router-dom'

import { messageOf, useSession } from '../auth/SessionContext'
import { plural } from '../format'
import { routes } from '../tree/levels'
import type { AdminCourseProgress, AdminDayActivity, AdminLearnerDetail, SkillState } from '../types'
import { Badge } from '../ui/Badge'
import { cx } from '../ui/cx'
import { Icon } from '../ui/Icon'
import { Avatar, ErrorBanner, Panel, Progress } from './charts'
import { activity, count, formatDate, formatDay, lastSeen, parseDay, percent } from './report'

const WEEKS = 13
const DAY_MS = 86_400_000

/** One learner: their totals, the days they studied, how far they are
 * through each course, and their latest lessons. */
export function LearnerPage() {
  const { learnerId = '' } = useParams()
  const { api } = useSession()
  const [detail, setDetail] = useState<AdminLearnerDetail | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [attempt, setAttempt] = useState(0)

  useEffect(() => {
    let live = true
    api.get<AdminLearnerDetail>(routes.learner(learnerId)).then(
      (d) => {
        if (!live) return
        setDetail(d)
        setError(null)
      },
      (e: unknown) => live && setError(messageOf(e)),
    )
    return () => {
      live = false
    }
  }, [api, learnerId, attempt])

  const now = new Date()
  const l = detail?.learner
  const status = l ? activity(l.last_active_at, now) : null

  return (
    <main className="mx-auto max-w-6xl px-4 py-6 sm:px-6 lg:px-8 lg:py-8">
      <Link to="/learners" className="inline-flex items-center gap-1 text-sm font-semibold text-forest hover:underline">
        <Icon name="arrow_back" className="text-base" />
        All learners
      </Link>

      {error && <ErrorBanner message={error} onRetry={() => setAttempt((n) => n + 1)} />}
      {!detail && !error && <p className="mt-10 text-center text-sm text-stone">Loading the learner…</p>}

      {detail && l && status && (
        <>
          <header className="mt-4 flex flex-wrap items-center gap-4">
            <Avatar name={l.name} className="size-14 text-lg" />
            <div className="min-w-0 flex-1">
              <h1 className="flex flex-wrap items-center gap-3 text-[1.75rem] leading-9 font-bold tracking-[-0.02em] text-coffee">
                {l.name}
                <Badge tone={status.tone} dot>
                  {status.label}
                </Badge>
              </h1>
              <p className="mt-1 flex flex-wrap gap-x-3 gap-y-1 text-sm text-stone">
                <span>{l.email ?? 'No email'}</span>
                <span aria-hidden="true">•</span>
                <span>Joined {formatDate(l.joined_at)}</span>
                <span aria-hidden="true">•</span>
                <span>Studying {l.course_title}</span>
                <span aria-hidden="true">•</span>
                <span>
                  Signs in with {detail.auth_provider === 'apple' ? 'Apple' : 'Google'}
                </span>
              </p>
            </div>
          </header>

          <dl className="mt-6 grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-6">
            <Fact icon="bolt" label="XP" value={count(l.xp)} />
            <Fact icon="menu_book" label="Lessons" value={count(l.lessons)} note={`${plural(l.practice_sessions, 'practice session')}`} />
            <Fact icon="workspace_premium" label="Skills done" value={count(l.skills_completed)} />
            <Fact
              icon="local_fire_department"
              label="Streak"
              value={plural(l.current_streak, 'day')}
              note={`Longest ${plural(detail.longest_streak, 'day')}`}
            />
            <Fact icon="percent" label="Accuracy" value={percent(l.accuracy)} />
            <Fact icon="event_available" label="Days studied" value={count(detail.days_active)} note={`Last: ${lastSeen(l.last_active_at, now)}`} />
          </dl>

          <Panel
            className="mt-6"
            title="Days studied"
            icon="calendar_month"
            description={`The last ${WEEKS} weeks, Monday at the top. Darker means more XP; daily goal ${detail.daily_xp_target} XP.`}
          >
            <Calendar days={detail.activity} today={now} goal={detail.daily_xp_target} />
          </Panel>

          <div className="mt-6 grid gap-6 lg:grid-cols-[1fr_22rem]">
            <div className="space-y-6">
              {detail.courses.map((course) => (
                <CourseCard key={course.course_id} course={course} />
              ))}
            </div>

            <Panel flush title="Latest activity" icon="history" description="Newest first.">
              {detail.recent.length === 0 ? (
                <p className="px-6 py-10 text-center text-sm text-stone">No lessons yet.</p>
              ) : (
                <ol className="divide-y divide-line">
                  {detail.recent.map((r) => (
                    <li key={`${r.kind}-${r.at}`} className="flex items-start gap-3 px-4 py-2.5 sm:px-6">
                      <span
                        className={cx(
                          'mt-0.5 grid size-8 shrink-0 place-items-center rounded',
                          r.kind === 'lesson' ? 'bg-forest-tint text-forest' : 'bg-terracotta-tint text-terracotta',
                        )}
                      >
                        <Icon name={r.kind === 'lesson' ? 'menu_book' : 'fitness_center'} className="text-base" />
                      </span>
                      <span className="min-w-0 flex-1">
                        <span className="block truncate text-sm font-semibold text-coffee">
                          {r.kind === 'lesson' ? r.lesson_title : 'Practice'}
                        </span>
                        <span className="block truncate text-xs text-stone">
                          {r.kind === 'lesson' ? `${r.skill_title} · ` : ''}
                          {formatDate(r.at)}
                        </span>
                      </span>
                      <span className="text-right">
                        <span className="tnum block text-sm font-semibold text-forest">+{r.xp} XP</span>
                        <span className="tnum block text-xs text-stone">
                          {r.correct}/{r.answered} right
                        </span>
                      </span>
                    </li>
                  ))}
                </ol>
              )}
            </Panel>
          </div>
        </>
      )}
    </main>
  )
}

function Fact({ icon, label, value, note }: { icon: string; label: string; value: string; note?: string }) {
  return (
    <div className="rounded-md border border-line bg-surface p-3 shadow-e1">
      <dt className="flex items-center gap-1.5 text-xs font-semibold text-stone">
        <Icon name={icon} className="text-base text-forest" />
        {label}
      </dt>
      <dd className="tnum mt-1 text-xl leading-7 font-bold text-coffee">{value}</dd>
      {note && <dd className="text-xs text-stone">{note}</dd>}
    </div>
  )
}

const SHADES = ['bg-inset', 'bg-forest/25', 'bg-forest/50', 'bg-forest/75', 'bg-forest']

/** Thirteen weeks of days as a grid, a column a week. */
function Calendar({ days, today, goal }: { days: AdminDayActivity[]; today: Date; goal: number }) {
  const byDay = new Map(days.map((d) => [d.date, d]))
  const todayDay = formatDay(today)
  const todayTime = parseDay(todayDay).getTime()
  const weekday = (parseDay(todayDay).getUTCDay() + 6) % 7 // Monday 0
  const firstMonday = todayTime - (weekday + (WEEKS - 1) * 7) * DAY_MS
  const columns = Array.from({ length: WEEKS }, (_, w) =>
    Array.from({ length: 7 }, (_, d) => formatDay(new Date(firstMonday + (w * 7 + d) * DAY_MS))),
  )
  const shade = (xp: number) => (xp <= 0 ? 0 : xp >= goal * 2 ? 4 : xp >= goal ? 3 : xp >= goal / 2 ? 2 : 1)
  const studied = days.length

  return (
    <div>
      <div className="flex gap-1 overflow-x-auto pb-1" role="img" aria-label={`Studied on ${plural(studied, 'day')} in the last ${WEEKS} weeks`}>
        {columns.map((week) => (
          <div key={week[0]} className="flex flex-col gap-1">
            {week.map((day) => {
              const entry = byDay.get(day)
              const future = day > todayDay
              return (
                <span
                  key={day}
                  title={
                    future
                      ? undefined
                      : `${formatDate(`${day}T00:00:00Z`)}: ${
                          entry ? `${plural(entry.lessons, 'lesson')}, ${plural(entry.practice_sessions, 'practice session')}, ${entry.xp} XP` : 'nothing'
                        }`
                  }
                  className={cx(
                    'size-4 rounded-[3px] sm:size-5',
                    future ? 'bg-transparent' : SHADES[shade(entry?.xp ?? 0)],
                    day === todayDay && 'ring-2 ring-coffee/40',
                  )}
                />
              )
            })}
          </div>
        ))}
      </div>
      <p className="mt-3 flex flex-wrap items-center gap-2 text-xs text-stone">
        <span>{plural(studied, 'day')} studied.</span>
        <span className="ml-auto flex items-center gap-1">
          Less
          {SHADES.map((s) => (
            <span key={s} className={cx('size-3 rounded-[2px]', s)} />
          ))}
          More
        </span>
      </p>
    </div>
  )
}

const SKILL_STATES: Record<SkillState, { label: string; className: string; icon: string }> = {
  completed: { label: 'Done', className: 'border-forest-line bg-forest-tint text-forest', icon: 'check_circle' },
  started: { label: 'Started', className: 'border-terracotta-line bg-terracotta-tint text-terracotta', icon: 'pending' },
  not_started: { label: 'Not started', className: 'border-line bg-surface text-stone', icon: 'radio_button_unchecked' },
}

function CourseCard({ course }: { course: AdminCourseProgress }) {
  return (
    <Panel
      title={course.title}
      icon="school"
      actions={course.current ? <Badge tone="published" dot>Current course</Badge> : <Badge>Studied before</Badge>}
      description={`${course.skills_completed} of ${plural(course.skills_total, 'skill')} done · ${course.lessons_done} of ${plural(course.lessons_total, 'lesson')} finished at least once`}
    >
      <Progress done={course.skills_completed} total={course.skills_total} label={`${course.title}: skills done`} />
      {course.sections.length === 0 && <p className="mt-4 text-sm text-stone">This course has no sections yet.</p>}
      <ol className="mt-5 space-y-5">
        {course.sections.map((section) => {
          const done = section.skills.filter((s) => s.state === 'completed').length
          return (
            <li key={section.id}>
              <p className="flex items-baseline justify-between gap-2">
                <span className="font-semibold text-coffee">{section.title}</span>
                <span className="tnum text-xs text-stone">
                  {done}/{section.skills.length} skills
                </span>
              </p>
              <ul className="mt-2 flex flex-wrap gap-2">
                {section.skills.map((skill) => {
                  const state = SKILL_STATES[skill.state]
                  return (
                    <li
                      key={skill.id}
                      title={`${skill.title}: ${state.label}. ${skill.lessons_done} of ${plural(skill.lessons_total, 'lesson')}${
                        skill.crown_level ? `, crown level ${skill.crown_level}` : ''
                      }`}
                      className={cx('inline-flex items-center gap-1.5 rounded-full border px-2.5 py-1 text-xs font-semibold', state.className)}
                    >
                      <Icon name={state.icon} className="text-sm" filled={skill.state === 'completed'} />
                      {skill.title}
                      <span className="tnum font-normal opacity-80">
                        {skill.lessons_done}/{skill.lessons_total}
                      </span>
                      {skill.crown_level > 0 && (
                        <span className="inline-flex items-center opacity-90">
                          <Icon name="crown" className="text-sm" filled />
                          {skill.crown_level}
                        </span>
                      )}
                      <span className="sr-only">{state.label}</span>
                    </li>
                  )
                })}
              </ul>
            </li>
          )
        })}
      </ol>
    </Panel>
  )
}
