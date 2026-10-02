import { screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import { FakeServer } from '../test/fakeServer'
import { COURSE, idTokenFor } from '../test/fixtures'
import { renderApp, withStoredSession } from '../test/renderApp'
import type { AdminFeedbackItem, AdminFeedbackPage } from '../types'

vi.mock('../auth/GoogleButton', () => ({
  GoogleButton: ({ onCredential }: { onCredential: (token: string) => void }) => (
    <button type="button" onClick={() => onCredential(idTokenFor('admin@example.com'))}>
      Sign in with Google
    </button>
  ),
}))

const ME = '/api/v1/admin/me'
const COURSES = '/api/v1/admin/courses'
const FEEDBACK = '/api/v1/admin/feedback'

const CRASH: AdminFeedbackItem = {
  id: 'f-crash',
  category: 'bug',
  rating: 2,
  message: 'The app closes when I start a lesson.\nEvery time.',
  status: 'open',
  platform: 'android',
  created_at: '2026-10-02T09:00:00Z',
  resolved_at: null,
  learner_id: 'u-abebe',
  learner_name: 'Abebe',
  learner_email: 'abebe@example.com',
  course_id: COURSE.id,
  course_title: 'English to Amharic',
}

const IDEA: AdminFeedbackItem = {
  ...CRASH,
  id: 'f-idea',
  category: 'idea',
  rating: null,
  message: 'Please add Tigrinya',
  platform: 'ios',
  learner_id: 'u-sara',
  learner_name: 'Sara',
  learner_email: 'sara@example.com',
}

function page(items: AdminFeedbackItem[]): AdminFeedbackPage {
  return {
    items,
    total: items.length,
    open: 2,
    resolved: 1,
    rated: 3,
    average_rating: 3.666,
    open_by_category: { bug: 1, idea: 1, content: 0, other: 0 },
  }
}

let server: FakeServer
let items: AdminFeedbackItem[]

beforeEach(() => {
  withStoredSession()
  items = [CRASH, IDEA]
  server = new FakeServer()
    .install()
    .on('GET', ME, { body: { email: 'admin@example.com' } })
    .on('GET', COURSES, { body: { courses: [COURSE] } })
    .on('GET', FEEDBACK, (call) => {
      const q = new URLSearchParams(call.query)
      const shown = items.filter(
        (i) =>
          (!q.get('status') || i.status === q.get('status')) &&
          (!q.get('category') || i.category === q.get('category')) &&
          (!q.get('user_id') || i.learner_id === q.get('user_id')),
      )
      return { body: page(shown) }
    })
    .on('PATCH', `${FEEDBACK}/f-crash`, (call) => {
      const status = (call.body as { status: AdminFeedbackItem['status'] }).status
      items = items.map((i) => (i.id === 'f-crash' ? { ...i, status } : i))
      return { status: 204 }
    })
})

const lastQuery = () => new URLSearchParams(server.callsTo('GET', FEEDBACK).at(-1)!.query)

describe('the feedback page', () => {
  it('is in the menu and lists open feedback with who sent it', async () => {
    renderApp('/')
    await userEvent.click(await screen.findByRole('link', { name: 'Feedback' }))

    expect(await screen.findByRole('heading', { name: 'Feedback', level: 1 })).toBeInTheDocument()
    expect(lastQuery().get('status')).toBe('open')

    const crash = await screen.findByRole('listitem', { name: 'Problem from Abebe' })
    expect(within(crash).getByText(/closes when I start a lesson/)).toBeInTheDocument()
    expect(within(crash).getByRole('img', { name: 'Rated 2 out of 5' })).toBeInTheDocument()
    expect(within(crash).getByText('Android')).toBeInTheDocument()
    expect(within(crash).getByText('English to Amharic')).toBeInTheDocument()
    expect(within(crash).getByRole('link', { name: /Abebe/ })).toHaveAttribute('href', '/learners/u-abebe')
    expect(screen.getByRole('listitem', { name: 'Idea from Sara' })).toHaveTextContent('iPhone')

    const rating = screen.getByText(/Average rating/, { selector: 'dt' }).closest('div')!.parentElement!
    expect(within(rating).getByText('3.7 / 5')).toBeInTheDocument()
  })

  it('marks a message resolved, and it leaves the open list', async () => {
    renderApp('/feedback')
    const crash = await screen.findByRole('listitem', { name: 'Problem from Abebe' })

    await userEvent.click(within(crash).getByRole('button', { name: 'Mark resolved' }))

    expect(server.callsTo('PATCH', `${FEEDBACK}/f-crash`)[0]!.body).toEqual({ status: 'resolved' })
    await waitFor(() => expect(screen.queryByRole('listitem', { name: 'Problem from Abebe' })).not.toBeInTheDocument())

    await userEvent.click(screen.getByRole('button', { name: 'Resolved' }))
    const resolved = await screen.findByRole('listitem', { name: 'Problem from Abebe' })
    expect(lastQuery().get('status')).toBe('resolved')
    await userEvent.click(within(resolved).getByRole('button', { name: 'Reopen' }))
    expect(server.callsTo('PATCH', `${FEEDBACK}/f-crash`)[1]!.body).toEqual({ status: 'open' })
  })

  it('filters by kind, and shows everything', async () => {
    renderApp('/feedback')
    await screen.findByRole('listitem', { name: 'Idea from Sara' })

    await userEvent.selectOptions(screen.getByRole('combobox', { name: 'Kind' }), 'idea')
    await waitFor(() => expect(lastQuery().get('category')).toBe('idea'))
    await waitFor(() => expect(screen.queryByRole('listitem', { name: 'Problem from Abebe' })).not.toBeInTheDocument())

    await userEvent.click(screen.getByRole('button', { name: 'All' }))
    await waitFor(() => expect(lastQuery().has('status')).toBe(false))
  })

  it("shows one learner's feedback, from their page", async () => {
    renderApp('/feedback?status=all&learner=u-sara')

    expect(await screen.findByText('From Sara')).toBeInTheDocument()
    expect(lastQuery().get('user_id')).toBe('u-sara')
    expect(screen.queryByRole('listitem', { name: 'Problem from Abebe' })).not.toBeInTheDocument()

    await userEvent.click(screen.getByRole('button', { name: 'Show feedback from everyone' }))
    await waitFor(() => expect(lastQuery().has('user_id')).toBe(false))
  })

  it('says when nothing is open', async () => {
    items = []
    renderApp('/feedback')

    expect(await screen.findByText('Nothing open. All caught up.')).toBeInTheDocument()
  })
})
