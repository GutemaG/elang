import { screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import { FakeServer } from '../test/fakeServer'
import { COURSE, courseTree, idTokenFor } from '../test/fixtures'
import { renderApp, withStoredSession } from '../test/renderApp'
import type { AdminCourse, AdminCourseTree, AdminLanguage } from '../types'

vi.mock('../auth/GoogleButton', () => ({
  GoogleButton: ({ onCredential }: { onCredential: (token: string) => void }) => (
    <button type="button" onClick={() => onCredential(idTokenFor('admin@example.com'))}>
      Sign in with Google
    </button>
  ),
}))

const ME = '/api/v1/admin/me'
const COURSES = '/api/v1/admin/courses'
const LANGUAGES = '/api/v1/admin/languages'

const LANGS: AdminLanguage[] = [
  { code: 'am', name: 'Amharic', native_name: 'አማርኛ', course_count: 1 },
  { code: 'en', name: 'English', native_name: 'English', course_count: 1 },
  { code: 'ti', name: 'Tigrinya', native_name: 'ትግርኛ', course_count: 0 },
]

const TIGRINYA: AdminCourse = {
  id: 'course-ti',
  title: 'English to Tigrinya',
  learning_language: 'ti',
  from_language: 'en',
  learning_language_name: 'Tigrinya',
  learning_language_native_name: 'ትግርኛ',
  from_language_name: 'English',
  from_language_native_name: 'English',
  status: 'coming_soon',
  section_count: 0,
}

const emptyTree = (course: AdminCourse = TIGRINYA): AdminCourseTree => ({ course, sections: [] })

let server: FakeServer

beforeEach(() => {
  withStoredSession()
  server = new FakeServer()
    .install()
    .on('GET', ME, { body: { email: 'admin@example.com' } })
    .on('GET', COURSES, { body: { courses: [COURSE] } })
    .on('GET', LANGUAGES, { body: { languages: LANGS } })
})

async function openDialog() {
  renderApp('/')
  await userEvent.click(await screen.findByRole('button', { name: 'New course' }))
  const dialog = await screen.findByRole('dialog', { name: 'New course' })
  // The languages have arrived once the first choice is offered.
  await within(dialog).findAllByRole('option', { name: 'Tigrinya · ትግርኛ' })
  return within(dialog)
}

describe('creating a course', () => {
  it('names the course list by each language’s own data', async () => {
    renderApp('/')

    expect(await screen.findByText('Amharic for English speakers')).toBeInTheDocument()
    expect(screen.getByText('አ')).toBeInTheDocument()
  })

  it('offers every language, suggests a title and opens the new course', async () => {
    server
      .on('POST', COURSES, { status: 201, body: TIGRINYA })
      .on('GET', '/api/v1/admin/courses/course-ti/tree', { body: emptyTree() })
    const dialog = await openDialog()

    await userEvent.selectOptions(dialog.getByLabelText('Language to learn'), 'ti')
    await userEvent.selectOptions(dialog.getByLabelText('Learners speak'), 'en')
    expect(dialog.getByLabelText(/Title/)).toHaveAttribute('placeholder', 'English to Tigrinya')
    await userEvent.click(dialog.getByRole('button', { name: 'Create course' }))

    expect(server.callsTo('POST', COURSES)[0]!.body).toEqual({
      learning_language: 'ti',
      from_language: 'en',
      title: '',
    })
    expect(await screen.findByRole('heading', { name: 'English to Tigrinya' })).toBeInTheDocument()
    expect(screen.getByText('Tigrinya for English speakers')).toHaveTextContent('Coming soon')
  })

  it('sends a title typed in', async () => {
    server
      .on('POST', COURSES, { status: 201, body: { ...TIGRINYA, title: 'Tigrinya basics' } })
      .on('GET', '/api/v1/admin/courses/course-ti/tree', { body: emptyTree() })
    const dialog = await openDialog()

    await userEvent.selectOptions(dialog.getByLabelText('Language to learn'), 'ti')
    await userEvent.selectOptions(dialog.getByLabelText('Learners speak'), 'en')
    await userEvent.type(dialog.getByLabelText(/Title/), 'Tigrinya basics')
    await userEvent.click(dialog.getByRole('button', { name: 'Create course' }))

    await waitFor(() => expect(server.callsTo('POST', COURSES)).toHaveLength(1))
    expect(server.callsTo('POST', COURSES)[0]!.body).toMatchObject({ title: 'Tigrinya basics' })
  })

  it('refuses a pair that already has a course, before asking the server', async () => {
    const dialog = await openDialog()

    await userEvent.selectOptions(dialog.getByLabelText('Language to learn'), 'am')
    await userEvent.selectOptions(dialog.getByLabelText('Learners speak'), 'en')

    expect(dialog.getByRole('alert')).toHaveTextContent('“Amharic” already teaches Amharic to English speakers.')
    expect(dialog.getByRole('button', { name: 'Create course' })).toBeDisabled()
  })

  it('refuses the same language twice', async () => {
    const dialog = await openDialog()

    await userEvent.selectOptions(dialog.getByLabelText('Language to learn'), 'ti')
    await userEvent.selectOptions(dialog.getByLabelText('Learners speak'), 'ti')

    expect(dialog.getByRole('alert')).toHaveTextContent('Pick two different languages.')
    expect(dialog.getByRole('button', { name: 'Create course' })).toBeDisabled()
  })

  it('shows what the server says when it refuses', async () => {
    server.on('POST', COURSES, {
      status: 409,
      body: { error_code: 'content_exists', message: 'There is already a course teaching Tigrinya from English' },
    })
    const dialog = await openDialog()

    await userEvent.selectOptions(dialog.getByLabelText('Language to learn'), 'ti')
    await userEvent.selectOptions(dialog.getByLabelText('Learners speak'), 'en')
    await userEvent.click(dialog.getByRole('button', { name: 'Create course' }))

    expect(await dialog.findByRole('alert')).toHaveTextContent('There is already a course teaching Tigrinya')
    expect(screen.getByRole('dialog', { name: 'New course' })).toBeInTheDocument()
  })

  it('is not offered on the vocabulary list', async () => {
    renderApp('/vocabulary')

    await screen.findByText('Amharic for English speakers')
    expect(screen.queryByRole('button', { name: 'New course' })).not.toBeInTheDocument()
  })
})

describe('a course’s status', () => {
  it('makes a course with exercises available', async () => {
    const tree = courseTree()
    tree.course = { ...TIGRINYA, id: 'course-1', section_count: 2 }
    server.on('GET', '/api/v1/admin/courses/course-1/tree', () => ({ body: tree })).on(
      'PATCH',
      '/api/v1/admin/courses/course-1',
      () => {
        tree.course = { ...tree.course, status: 'available' }
        return { body: tree.course }
      },
    )
    renderApp('/courses/course-1')

    await userEvent.click(await screen.findByRole('button', { name: 'Make available' }))

    expect(server.callsTo('PATCH', '/api/v1/admin/courses/course-1')[0]!.body).toEqual({ status: 'available' })
    expect(await screen.findByRole('button', { name: 'Move to coming soon' })).toBeInTheDocument()
    expect(screen.getByText('Tigrinya for English speakers')).toHaveTextContent('Available')
  })

  it('cannot make an empty course available', async () => {
    server.on('GET', '/api/v1/admin/courses/course-ti/tree', { body: emptyTree() })
    renderApp('/courses/course-ti')

    expect(await screen.findByRole('button', { name: 'Make available' })).toBeDisabled()
  })

  it('shows why the server keeps a course available', async () => {
    const tree = courseTree()
    tree.course = { ...COURSE, status: 'available' }
    server.on('GET', '/api/v1/admin/courses/course-1/tree', { body: tree }).on('PATCH', '/api/v1/admin/courses/course-1', {
      status: 409,
      body: { error_code: 'content_in_use', message: '3 learner(s) are studying this course, so it stays available' },
    })
    renderApp('/courses/course-1')

    await userEvent.click(await screen.findByRole('button', { name: 'Move to coming soon' }))

    expect(await screen.findByRole('alert')).toHaveTextContent('3 learner(s) are studying this course')
  })
})

describe('deleting a course', () => {
  it('is offered for an empty course and goes back to the list', async () => {
    server
      .on('GET', '/api/v1/admin/courses/course-ti/tree', { body: emptyTree() })
      .on('DELETE', '/api/v1/admin/courses/course-ti', { status: 204 })
    renderApp('/courses/course-ti')

    await userEvent.click(await screen.findByRole('button', { name: 'Delete course' }))
    const dialog = screen.getByRole('dialog', { name: 'Delete course “English to Tigrinya”?' })
    await userEvent.click(within(dialog).getByRole('button', { name: 'Delete' }))

    expect(server.callsTo('DELETE', '/api/v1/admin/courses/course-ti')).toHaveLength(1)
    expect(await screen.findByRole('heading', { name: 'Courses' })).toBeInTheDocument()
  })

  it('is not offered once the course has sections', async () => {
    server.on('GET', '/api/v1/admin/courses/course-1/tree', { body: courseTree() })
    renderApp('/courses/course-1')

    await screen.findByRole('heading', { name: 'Amharic' })
    expect(screen.queryByRole('button', { name: 'Delete course' })).not.toBeInTheDocument()
  })
})
