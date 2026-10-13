import { screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import { FakeServer } from '../test/fakeServer'
import { COURSE, courseTree, idTokenFor } from '../test/fixtures'
import { renderApp, withStoredSession } from '../test/renderApp'
import type { AdminCourse } from '../types'
import type { TeamMember } from './api'

vi.mock('../auth/GoogleButton', () => ({
  GoogleButton: ({ onCredential }: { onCredential: (token: string) => void }) => (
    <button type="button" onClick={() => onCredential(idTokenFor('admin@example.com'))}>
      Sign in with Google
    </button>
  ),
}))

const ME = '/api/v1/admin/me'
const TEAM = '/api/v1/admin/team'
const COURSES = '/api/v1/admin/courses'
const CHARTS = '/api/v1/admin/sound-charts'

const OROMO: AdminCourse = {
  ...COURSE,
  id: 'course-2',
  title: 'English to Afaan Oromo',
  learning_language: 'om',
  learning_language_name: 'Afaan Oromo',
}

const SUPER = { email: 'admin@example.com', role: 'super_admin', is_owner: true, course_ids: null }
const HELPER = { email: 'admin@example.com', role: 'course_admin', is_owner: false, course_ids: ['course-1'] }

function member(email: string, extra: Partial<TeamMember> = {}): TeamMember {
  return {
    id: `id-${email}`,
    email,
    role: 'course_admin',
    is_owner: false,
    courses: [],
    last_signed_in_at: null,
    created_by: 'admin@example.com',
    created_at: '2026-10-13T09:00:00Z',
    updated_by: 'admin@example.com',
    updated_at: '2026-10-13T09:00:00Z',
    ...extra,
  }
}

let server: FakeServer
let team: TeamMember[]

beforeEach(() => {
  withStoredSession()
  team = [
    member('admin@example.com', { id: null, role: 'super_admin', is_owner: true, created_by: null }),
    member('lead@example.com', { role: 'super_admin', last_signed_in_at: '2026-10-12T08:00:00Z' }),
    member('helper@example.com', { courses: [{ id: 'course-1', title: 'Amharic' }] }),
  ]
  server = new FakeServer()
    .install()
    .on('GET', ME, { body: SUPER })
    .on('GET', TEAM, () => ({ body: { members: team } }))
    .on('GET', COURSES, { body: { courses: [COURSE, OROMO] } })
})

const nav = () => within(screen.getByRole('navigation', { name: 'Sections' }))
const row = (email: string) =>
  within(within(screen.getByRole('main')).getByText(email, { selector: 'span' }).closest('li')!)

describe('the navigation', () => {
  it('groups configuration for a super admin', async () => {
    renderApp('/')

    await screen.findByRole('heading', { name: 'Courses' })
    const groups = nav().getAllByText(/^(Workspace|Learners|Configuration|App)$/, { selector: 'p' }).map((g) => g.textContent)
    expect(groups).toEqual(['Workspace', 'Learners', 'Configuration'])
    for (const name of ['Team', 'Languages', 'Voices', 'App updates']) {
      expect(nav().getByRole('link', { name })).toBeInTheDocument()
    }
  })

  it('shows a course admin only the workspace', async () => {
    server.on('GET', ME, { body: HELPER })
    renderApp('/')

    await screen.findByRole('heading', { name: 'Courses' })
    expect(nav().getByText('Workspace')).toBeInTheDocument()
    for (const name of ['Team', 'Languages', 'Voices', 'App updates', 'Dashboard', 'Learners', 'Feedback']) {
      expect(nav().queryByRole('link', { name })).not.toBeInTheDocument()
    }
  })

  it.each(['/team', '/languages', '/voices', '/app-updates', '/dashboard', '/learners', '/feedback'])(
    'sends a course admin from %s to the workspace',
    async (path) => {
      server.on('GET', ME, { body: HELPER })
      renderApp(path)

      expect(await screen.findByRole('heading', { name: 'Courses' })).toBeInTheDocument()
    },
  )
})

describe('an account not on the team', () => {
  it('is told to ask a super admin', async () => {
    server.on('GET', ME, { status: 403, body: { error_code: 'not_admin', message: 'Not an admin' } })
    renderApp('/')

    expect(await screen.findByRole('heading', { name: 'Not authorised' })).toBeInTheDocument()
    expect(screen.getByText(/is signed in, but is not on the team/)).toBeInTheDocument()
    expect(screen.getByText('Ask a super admin to add this address.')).toBeInTheDocument()
    expect(screen.queryByText('ADMIN_EMAILS')).not.toBeInTheDocument()
  })
})

describe('the team page', () => {
  it('lists owners, super admins and course admins with their courses', async () => {
    renderApp('/')
    await userEvent.click(await screen.findByRole('link', { name: 'Team' }))

    expect(await screen.findByRole('heading', { name: 'Team' })).toBeInTheDocument()
    const me = row('admin@example.com')
    expect(me.getByText('Owner')).toBeInTheDocument()
    expect(me.getByText('You')).toBeInTheDocument()
    expect(me.getByText('Set in the server’s ADMIN_EMAILS')).toBeInTheDocument()
    expect(me.queryByRole('button')).not.toBeInTheDocument()
    expect(row('lead@example.com').getByText('All courses')).toBeInTheDocument()
    expect(row('lead@example.com').getByText(/Last signed in 12 Oct 2026/)).toBeInTheDocument()
    const helper = row('helper@example.com')
    expect(helper.getByText('Course admin')).toBeInTheDocument()
    expect(helper.getByText('Amharic')).toBeInTheDocument()
    expect(helper.getByText('Not signed in yet')).toBeInTheDocument()
  })

  it('adds a course admin with their courses', async () => {
    server.on('POST', TEAM, (call) => {
      team = [...team, member('new@example.com', { courses: [{ id: 'course-2', title: OROMO.title }] })]
      return { status: 201, body: call.body }
    })
    renderApp('/team')

    await userEvent.click(await screen.findByRole('button', { name: 'Add admin' }))
    const dialog = within(screen.getByRole('dialog', { name: 'Add admin' }))
    expect(dialog.getByText('They sign in with Google using this address. No email is sent.')).toBeInTheDocument()
    expect(dialog.getByRole('radio', { name: /Course admin/ })).toBeChecked()
    await userEvent.type(dialog.getByLabelText('Email'), ' new@example.com ')
    await userEvent.click(await dialog.findByRole('checkbox', { name: OROMO.title }))
    await userEvent.click(dialog.getByRole('button', { name: 'Add admin' }))

    expect(server.callsTo('POST', TEAM)[0]!.body).toEqual({
      email: 'new@example.com',
      role: 'course_admin',
      course_ids: ['course-2'],
    })
    expect(await screen.findByText('new@example.com')).toBeInTheDocument()
    expect(screen.queryByRole('dialog')).not.toBeInTheDocument()
  })

  it('adds a super admin with no course list', async () => {
    server.on('POST', TEAM, (call) => ({ status: 201, body: call.body }))
    renderApp('/team')

    await userEvent.click(await screen.findByRole('button', { name: 'Add admin' }))
    const dialog = within(screen.getByRole('dialog', { name: 'Add admin' }))
    await userEvent.type(dialog.getByLabelText('Email'), 'boss@example.com')
    await userEvent.click(dialog.getByRole('radio', { name: /Super admin/ }))
    expect(dialog.queryByRole('checkbox')).not.toBeInTheDocument()
    await userEvent.click(dialog.getByRole('button', { name: 'Add admin' }))

    expect(server.callsTo('POST', TEAM)[0]!.body).toEqual({
      email: 'boss@example.com',
      role: 'super_admin',
      course_ids: [],
    })
  })

  it('shows the server’s field error under the field', async () => {
    server.on('POST', TEAM, {
      status: 409,
      body: {
        error_code: 'admin_member_exists',
        message: 'helper@example.com is already on the team',
        details: { field: 'email' },
      },
    })
    renderApp('/team')

    await userEvent.click(await screen.findByRole('button', { name: 'Add admin' }))
    const dialog = within(screen.getByRole('dialog', { name: 'Add admin' }))
    await userEvent.type(dialog.getByLabelText('Email'), 'helper@example.com')
    await userEvent.click(dialog.getByRole('button', { name: 'Add admin' }))

    expect(await dialog.findByRole('alert')).toHaveTextContent('helper@example.com is already on the team')
  })

  it('edits a course admin’s courses with the email fixed', async () => {
    server.on('PUT', `${TEAM}/id-helper@example.com`, (call) => ({ body: call.body }))
    renderApp('/team')

    await userEvent.click(await screen.findByRole('button', { name: 'Edit helper@example.com' }))
    const dialog = within(screen.getByRole('dialog', { name: 'Edit helper@example.com' }))
    expect(dialog.getByLabelText('Email')).toBeDisabled()
    expect(await dialog.findByRole('checkbox', { name: 'Amharic' })).toBeChecked()
    await userEvent.click(dialog.getByRole('button', { name: 'Select all' }))
    await userEvent.click(dialog.getByRole('button', { name: 'Save' }))

    const body = server.callsTo('PUT', `${TEAM}/id-helper@example.com`)[0]!.body as { course_ids: string[] }
    expect(body).toMatchObject({ role: 'course_admin' })
    expect([...body.course_ids].sort()).toEqual(['course-1', 'course-2'])
  })

  it('removes an admin after asking', async () => {
    server.on('DELETE', `${TEAM}/id-helper@example.com`, () => {
      team = team.filter((m) => m.email !== 'helper@example.com')
      return { status: 204 }
    })
    renderApp('/team')

    await userEvent.click(await screen.findByRole('button', { name: 'Remove helper@example.com' }))
    const dialog = within(screen.getByRole('dialog', { name: 'Remove helper@example.com?' }))
    expect(dialog.getByText('They lose access on their next click.')).toBeInTheDocument()
    await userEvent.click(dialog.getByRole('button', { name: 'Remove' }))

    await waitFor(() =>
      expect(within(screen.getByRole('main')).queryByText('helper@example.com')).not.toBeInTheDocument(),
    )
  })
})

describe('a course admin’s workspace', () => {
  beforeEach(() => {
    server.on('GET', ME, { body: HELPER }).on('GET', COURSES, { body: { courses: [COURSE] } })
  })

  it('has no New course, and says how to get a course when there is none', async () => {
    server.on('GET', COURSES, { body: { courses: [] } })
    renderApp('/')

    expect(await screen.findByText('No courses yet. Ask a super admin to give you one.')).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'New course' })).not.toBeInTheDocument()
  })

  it('works inside a course without renaming, publishing or deleting it', async () => {
    const tree = courseTree()
    server.on('GET', `${COURSES}/course-1/tree`, { body: tree })
    renderApp('/courses/course-1')

    expect(await screen.findByRole('button', { name: 'Add section' })).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'Rename course' })).not.toBeInTheDocument()
    expect(screen.queryByRole('button', { name: /Make available|Move to coming soon/ })).not.toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'Delete course' })).not.toBeInTheDocument()
  })

  it('has no New chart on the Sounds page', async () => {
    server.on('GET', CHARTS, { body: { charts: [] } })
    renderApp('/sounds')

    expect(await screen.findByText(/Ask a super admin to start one/)).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'New chart' })).not.toBeInTheDocument()
  })
})
