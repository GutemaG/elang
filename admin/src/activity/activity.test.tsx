import { screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import { FakeServer } from '../test/fakeServer'
import { idTokenFor } from '../test/fixtures'
import { renderApp, withStoredSession } from '../test/renderApp'
import type { ActivityEntry, ActivityPage } from './api'
import { detailRows, relativeTime } from './api'

vi.mock('../auth/GoogleButton', () => ({
  GoogleButton: ({ onCredential }: { onCredential: (token: string) => void }) => (
    <button type="button" onClick={() => onCredential(idTokenFor('admin@example.com'))}>
      Sign in with Google
    </button>
  ),
}))

const ME = '/api/v1/admin/me'
const ACTIVITY = '/api/v1/admin/activity'
const SUPER = { email: 'admin@example.com', role: 'super_admin', is_owner: true, course_ids: null }
const HELPER = { email: 'admin@example.com', role: 'course_admin', is_owner: false, course_ids: ['course-1'] }

function entry(id: string, extra: Partial<ActivityEntry> = {}): ActivityEntry {
  return {
    id,
    created_at: new Date(Date.now() - 5 * 60_000).toISOString(),
    admin_email: 'helper@example.com',
    admin_role: 'course_admin',
    method: 'PUT',
    route: '/api/v1/admin/exercises/{exercise_id}',
    area: 'curriculum',
    action: 'Edited exercise',
    target_kind: 'exercise',
    target_id: 'ex-1',
    target_name: 'listening in Saying hi',
    course_id: 'course-1',
    link: '/courses/course-1/lessons/l1/exercises/ex-1',
    details: {},
    ...extra,
  }
}

let server: FakeServer
let page: ActivityPage

beforeEach(() => {
  withStoredSession()
  page = {
    items: [
      entry('e1'),
      entry('e2', {
        admin_email: 'admin@example.com',
        admin_role: 'super_admin',
        method: 'DELETE',
        area: 'languages',
        action: 'Deleted language',
        target_kind: 'language',
        target_id: 'ti',
        target_name: 'Tigrinya',
        course_id: null,
        link: null,
      }),
      entry('e3', {
        area: 'leagues',
        action: 'Adjusted weekly XP',
        target_name: 'Abebe · abebe@example.com',
        course_id: null,
        link: '/leagues?week=2026-10-12',
        details: { reason: 'Lost lessons', adjustment: 40 },
      }),
    ],
    total: 3,
    next_cursor: null,
    admins: ['admin@example.com', 'helper@example.com'],
    areas: ['curriculum', 'languages', 'leagues'],
    courses: [{ id: 'course-1', title: 'English to Amharic' }],
  }
  server = new FakeServer()
    .install()
    .on('GET', ME, { body: SUPER })
    .on('GET', ACTIVITY, () => ({ body: page }))
})

const main = () => within(screen.getByRole('main'))
const opened = () => screen.findByRole('heading', { name: 'Activity log' })
const row = (action: string) => within(main().getByRole('button', { name: action }).closest('tr')!)

describe('activity helpers', () => {
  it('says how long ago', () => {
    const now = new Date('2026-10-15T12:00:00Z')
    expect(relativeTime('2026-10-15T11:59:30Z', now)).toBe('Just now')
    expect(relativeTime('2026-10-15T11:55:00Z', now)).toBe('5 min ago')
    expect(relativeTime('2026-10-15T09:00:00Z', now)).toBe('3 h ago')
    expect(relativeTime('2026-10-14T09:00:00Z', now)).toBe('Yesterday')
    expect(relativeTime('2026-10-01T09:00:00Z', now)).toBe('1 Oct 2026')
  })

  it('labels details', () => {
    expect(detailRows({ reason: 'Bot', role: 'course_admin', fields: ['min_build', 'store_url'] })).toEqual([
      { label: 'Reason', value: 'Bot' },
      { label: 'Role', value: 'course admin' },
      { label: 'Settings changed', value: 'min_build, store_url' },
    ])
  })
})

describe('the activity log', () => {
  it('is in Configuration for a super admin only', async () => {
    renderApp('/')
    expect(await screen.findByRole('link', { name: 'Activity log' })).toBeInTheDocument()
  })

  it('sends a course admin back to the workspace', async () => {
    server.on('GET', ME, { body: HELPER }).on('GET', '/api/v1/admin/courses', { body: { courses: [] } })
    renderApp('/activity')

    expect(await screen.findByRole('heading', { name: 'Courses' })).toBeInTheDocument()
    expect(screen.queryByRole('link', { name: 'Activity log' })).not.toBeInTheDocument()
  })

  it('lists each change with who, what, where and Open', async () => {
    renderApp('/activity')
    await opened()

    const edit = await main().findByRole('button', { name: 'Edited exercise' })
    const r = within(edit.closest('tr')!)
    expect(r.getByText('5 min ago')).toBeInTheDocument()
    expect(r.getByText('helper@example.com')).toBeInTheDocument()
    expect(r.getByText('Course admin')).toBeInTheDocument()
    expect(r.getByText('Curriculum')).toBeInTheDocument()
    expect(r.getByText('listening in Saying hi')).toBeInTheDocument()
    expect(r.getByText('English to Amharic')).toBeInTheDocument()
    expect(r.getByRole('link', { name: 'Open listening in Saying hi' })).toHaveAttribute(
      'href',
      '/courses/course-1/lessons/l1/exercises/ex-1',
    )
    const deleted = row('Deleted language')
    expect(deleted.getByText('Deleted')).toBeInTheDocument()
    expect(deleted.queryByRole('link')).not.toBeInTheDocument()
    expect(main().getByText('3 changes')).toBeInTheDocument()
  })

  it('expands a row to show its details', async () => {
    renderApp('/activity')
    await opened()

    await userEvent.click(await main().findByRole('button', { name: 'Adjusted weekly XP' }))

    expect(main().getByRole('button', { name: 'Adjusted weekly XP' })).toHaveAttribute('aria-expanded', 'true')
    expect(main().getByText('Lost lessons')).toBeInTheDocument()
    expect(main().getByText('PUT /api/v1/admin/exercises/{exercise_id}')).toBeInTheDocument()
  })

  it('sends the filters and clears them', async () => {
    renderApp('/activity')
    await opened()
    await main().findByRole('button', { name: 'Edited exercise' })

    await userEvent.selectOptions(main().getByLabelText('Area'), 'Leagues')
    await userEvent.selectOptions(main().getByLabelText('Admin'), 'helper@example.com')
    await userEvent.selectOptions(main().getByLabelText('Course'), 'English to Amharic')

    await waitFor(() =>
      expect(server.callsTo('GET', ACTIVITY).at(-1)!.query).toBe(
        '?admin=helper%40example.com&area=leagues&course_id=course-1',
      ),
    )
    await userEvent.type(main().getByRole('searchbox'), 'tigr')
    await waitFor(() => expect(server.callsTo('GET', ACTIVITY).at(-1)!.query).toContain('search=tigr'))

    await userEvent.click(main().getByRole('button', { name: 'Clear filters' }))
    await waitFor(() => expect(server.callsTo('GET', ACTIVITY).at(-1)!.query).toBe(''))
  })

  it('loads older changes from the cursor', async () => {
    page.next_cursor = 'c1'
    server.on('GET', ACTIVITY, (call) =>
      call.query.includes('cursor=c1')
        ? { body: { ...page, items: [entry('e4', { action: 'Published lesson', area: 'workbook' })], next_cursor: null } }
        : { body: page },
    )
    renderApp('/activity')
    await opened()

    await userEvent.click(await main().findByRole('button', { name: 'Load older changes' }))

    expect(await main().findByRole('button', { name: 'Published lesson' })).toBeInTheDocument()
    expect(main().getByRole('button', { name: 'Edited exercise' })).toBeInTheDocument()
    expect(main().queryByRole('button', { name: 'Load older changes' })).not.toBeInTheDocument()
  })

  it('says when nothing matches', async () => {
    page = { ...page, items: [], total: 0 }
    renderApp('/activity?area=team')
    await opened()

    expect(await main().findByText('No changes match these filters.')).toBeInTheDocument()
  })
})
