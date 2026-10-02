import { screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import { FakeServer } from '../test/fakeServer'
import { COURSE, idTokenFor } from '../test/fixtures'
import { renderApp, withStoredSession } from '../test/renderApp'
import type { AdminLearner, AdminLearnerDetail, AdminLearnerPage, AdminReport, AdminTotals } from '../types'

vi.mock('../auth/GoogleButton', () => ({
  GoogleButton: ({ onCredential }: { onCredential: (token: string) => void }) => (
    <button type="button" onClick={() => onCredential(idTokenFor('admin@example.com'))}>
      Sign in with Google
    </button>
  ),
}))

const ME = '/api/v1/admin/me'
const COURSES = '/api/v1/admin/courses'
const LEARNERS = '/api/v1/admin/learners'
const REPORTS = '/api/v1/admin/reports'

const today = new Date().toISOString()

function totals(over: Partial<AdminTotals> = {}): AdminTotals {
  return {
    new_learners: 0,
    active_learners: 0,
    lessons: 0,
    practice_sessions: 0,
    xp: 0,
    accuracy: null,
    skills_completed: 0,
    ...over,
  }
}

function report(over: Partial<AdminReport> = {}): AdminReport {
  return {
    period: 'week',
    course_id: null,
    start: '2026-09-21',
    end: '2026-10-04',
    totals: totals({ active_learners: 4, new_learners: 2, lessons: 30, xp: 600, accuracy: 0.8 }),
    previous: totals({ active_learners: 2, new_learners: 2, lessons: 40, xp: 500, accuracy: 0.75 }),
    buckets: [
      { start: '2026-09-21', end: '2026-09-27', partial: false, totals: totals({ lessons: 12, active_learners: 3 }) },
      { start: '2026-09-28', end: '2026-10-04', partial: true, totals: totals({ lessons: 18, active_learners: 4 }) },
    ],
    now: { total_learners: 9, active_today: 1, active_7_days: 4, active_30_days: 6 },
    courses: [{ course_id: COURSE.id, title: 'English to Amharic', learners: 7, active_learners: 4, lessons: 30, xp: 600, skills_completed: 3 }],
    top_learners: [{ id: 'u-abebe', name: 'Abebe', email: 'abebe@example.com', xp: 320, lessons: 14, accuracy: 0.9 }],
    ...over,
  }
}

const ABEBE: AdminLearner = {
  id: 'u-abebe',
  name: 'Abebe',
  email: 'abebe@example.com',
  joined_at: '2026-09-01T09:00:00Z',
  course_id: COURSE.id,
  course_title: 'English to Amharic',
  lessons: 14,
  practice_sessions: 2,
  xp: 320,
  accuracy: 0.9,
  skills_completed: 2,
  current_streak: 3,
  last_active_at: today,
}

const SARA: AdminLearner = {
  ...ABEBE,
  id: 'u-sara',
  name: 'Sara',
  email: 'sara@example.com',
  lessons: 0,
  practice_sessions: 0,
  xp: 0,
  accuracy: null,
  skills_completed: 0,
  current_streak: 0,
  last_active_at: null,
}

function learnerPage(learners = [ABEBE, SARA]): AdminLearnerPage {
  return { learners, total: learners.length, active_today: 1, active_7_days: 1, not_started: 1 }
}

const DETAIL: AdminLearnerDetail = {
  learner: ABEBE,
  auth_provider: 'google',
  daily_xp_target: 20,
  longest_streak: 5,
  days_active: 6,
  activity: [{ date: today.slice(0, 10), lessons: 2, practice_sessions: 1, xp: 44 }],
  courses: [
    {
      course_id: COURSE.id,
      title: 'English to Amharic',
      current: true,
      skills_total: 3,
      skills_completed: 1,
      lessons_total: 6,
      lessons_done: 3,
      sections: [
        {
          id: 'sec-1',
          title: 'Basics',
          skills: [
            { id: 'sk-1', title: 'Greetings', state: 'completed', crown_level: 1, lessons_total: 2, lessons_done: 2 },
            { id: 'sk-2', title: 'Numbers', state: 'started', crown_level: 0, lessons_total: 2, lessons_done: 1 },
            { id: 'sk-3', title: 'Family', state: 'not_started', crown_level: 0, lessons_total: 2, lessons_done: 0 },
          ],
        },
      ],
    },
  ],
  recent: [
    { kind: 'practice', at: today, lesson_title: null, skill_title: null, course_title: null, correct: 4, answered: 5, xp: 8 },
    { kind: 'lesson', at: today, lesson_title: 'Hello', skill_title: 'Greetings', course_title: 'English to Amharic', correct: 8, answered: 10, xp: 16 },
  ],
}

let server: FakeServer

beforeEach(() => {
  withStoredSession()
  server = new FakeServer()
    .install()
    .on('GET', ME, { body: { email: 'admin@example.com' } })
    .on('GET', COURSES, { body: { courses: [COURSE] } })
    .on('GET', REPORTS, (call) => ({ body: report({ period: new URLSearchParams(call.query).get('period') as AdminReport['period'] }) }))
    .on('GET', LEARNERS, (call) => {
      const search = new URLSearchParams(call.query).get('search') ?? ''
      return { body: learnerPage([ABEBE, SARA].filter((l) => l.name.toLowerCase().includes(search.toLowerCase()))) }
    })
    .on('GET', `${LEARNERS}/u-abebe`, { body: DETAIL })
})

const lastQuery = (path: string) => new URLSearchParams(server.callsTo('GET', path).at(-1)!.query)

describe('the dashboard', () => {
  it('is in the menu and shows this range against the one before', async () => {
    renderApp('/')
    await userEvent.click(await screen.findByRole('link', { name: 'Dashboard' }))

    expect(await screen.findByRole('heading', { name: 'Dashboard', level: 1 })).toBeInTheDocument()
    expect(lastQuery(REPORTS).get('period')).toBe('week')
    expect(lastQuery(REPORTS).get('count')).toBe('12')

    const active = (await screen.findByText('Active learners', { selector: 'dt' })).closest('div')!.parentElement!
    expect(within(active).getByText('4')).toBeInTheDocument()
    expect(within(active).getByText('+100%')).toBeInTheDocument()
    const lessons = screen.getByText('Lessons completed', { selector: 'dt' }).closest('div')!.parentElement!
    expect(within(lessons).getByText('−25%')).toBeInTheDocument()
    const accuracy = screen.getByText('Accuracy', { selector: 'dt' }).closest('div')!.parentElement!
    expect(within(accuracy).getByText('80%')).toBeInTheDocument()
    expect(within(accuracy).getByText('+5 pts')).toBeInTheDocument()

    // The weekly table, newest first, with the week still going marked.
    const table = screen.getByRole('table', { name: 'Weekly figures' })
    expect(within(table).getAllByRole('rowheader')[0]).toHaveTextContent('Week of 28 Sept 2026so far')
    expect(screen.getByRole('link', { name: /Abebe/ })).toHaveAttribute('href', '/learners/u-abebe')
  })

  it('counts by month and for one course when asked', async () => {
    renderApp('/dashboard')
    await screen.findByText('Right now')

    await userEvent.click(screen.getByRole('button', { name: 'Monthly' }))
    await waitFor(() => expect(lastQuery(REPORTS).get('period')).toBe('month'))
    expect(screen.getByRole('button', { name: 'Monthly' })).toHaveAttribute('aria-pressed', 'true')

    await userEvent.selectOptions(screen.getByRole('combobox', { name: 'Course' }), COURSE.id)
    await waitFor(() => expect(lastQuery(REPORTS).get('course_id')).toBe(COURSE.id))
    expect(lastQuery(REPORTS).get('period')).toBe('month')
  })

  it('steps back to the range before, and forward again', async () => {
    renderApp('/dashboard')
    await screen.findByText('Right now')
    expect(screen.getByRole('button', { name: 'Later weeks' })).toBeDisabled()

    await userEvent.click(screen.getByRole('button', { name: 'Earlier weeks' }))

    await waitFor(() => expect(lastQuery(REPORTS).get('end')).toBe('2026-09-20'))
    await userEvent.click(screen.getByRole('button', { name: 'Latest' }))
    await waitFor(() => expect(lastQuery(REPORTS).has('end')).toBe(false))
  })
})

describe('the learner list', () => {
  it('lists learners with their progress and how recently they studied', async () => {
    renderApp('/')
    await userEvent.click(await screen.findByRole('link', { name: 'Learners' }))

    const abebe = (await screen.findByRole('rowheader', { name: /Abebe/ })).closest('tr')!
    expect(within(abebe).getByText('Today')).toBeInTheDocument()
    expect(within(abebe).getByText('Active today')).toBeInTheDocument()
    expect(within(abebe).getByText('320')).toBeInTheDocument()
    expect(within(abebe).getByText('90%')).toBeInTheDocument()
    const sara = screen.getByRole('rowheader', { name: /Sara/ }).closest('tr')!
    expect(within(sara).getByText('Never')).toBeInTheDocument()
    expect(within(sara).getByText('Not started')).toBeInTheDocument()
    expect(within(sara).getByText('—')).toBeInTheDocument()
  })

  it('searches once typing pauses, and sorts', async () => {
    renderApp('/learners')
    await screen.findByRole('rowheader', { name: /Sara/ })

    await userEvent.type(screen.getByRole('searchbox', { name: 'Search by name or email' }), 'sar')

    await waitFor(() => expect(screen.queryByRole('rowheader', { name: /Abebe/ })).not.toBeInTheDocument())
    expect(lastQuery(LEARNERS).get('search')).toBe('sar')
    expect(server.callsTo('GET', LEARNERS).filter((c) => c.query.includes('search=s'))).toHaveLength(1)

    await userEvent.selectOptions(screen.getByRole('combobox', { name: 'Sort by' }), 'xp')
    await waitFor(() => expect(lastQuery(LEARNERS).get('sort')).toBe('xp'))
    await userEvent.click(screen.getByRole('button', { name: /Highest first/ }))
    await waitFor(() => expect(lastQuery(LEARNERS).get('order')).toBe('asc'))
  })

  it('opens a learner: totals, progress through each skill and latest lessons', async () => {
    renderApp('/learners')
    await userEvent.click(await screen.findByRole('link', { name: /Abebe/ }))

    expect(await screen.findByRole('heading', { name: /Abebe/, level: 1 })).toBeInTheDocument()
    expect(screen.getByText('Longest 5 days')).toBeInTheDocument()
    expect(screen.getByRole('progressbar', { name: 'English to Amharic: skills done' })).toHaveAttribute('aria-valuenow', '1')
    expect(screen.getByText('Greetings', { selector: 'li' })).toHaveTextContent('Done')
    expect(screen.getByText('Numbers', { selector: 'li' })).toHaveTextContent('1/2Started')
    expect(screen.getByText('Family', { selector: 'li' })).toHaveTextContent('Not started')
    expect(screen.getByRole('img', { name: 'Studied on 1 day in the last 13 weeks' })).toBeInTheDocument()
    expect(screen.getByText('Hello')).toBeInTheDocument()
    expect(screen.getByText('8/10 right')).toBeInTheDocument()

    await userEvent.click(screen.getByRole('link', { name: 'All learners' }))
    expect(await screen.findByRole('heading', { name: 'Learners', level: 1 })).toBeInTheDocument()
  })

  it('says so when a learner cannot be found', async () => {
    server.on('GET', `${LEARNERS}/gone`, { status: 404, body: { error_code: 'content_not_found', message: "No learner has id 'gone'" } })
    renderApp('/learners/gone')

    expect(await screen.findByRole('alert')).toHaveTextContent('No learner')
  })
})
