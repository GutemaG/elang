import { screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import { FakeServer } from '../test/fakeServer'
import { COURSE, courseTree, idTokenFor } from '../test/fixtures'
import { renderApp, withStoredSession } from '../test/renderApp'

vi.mock('../auth/GoogleButton', () => ({
  GoogleButton: ({ onCredential }: { onCredential: (token: string) => void }) => (
    <button type="button" onClick={() => onCredential(idTokenFor('admin@example.com'))}>
      Sign in with Google
    </button>
  ),
}))

beforeEach(() => {
  withStoredSession()
  new FakeServer()
    .install()
    .on('GET', '/api/v1/admin/me', { body: { email: 'admin@example.com' } })
    .on('GET', '/api/v1/admin/courses', { body: { courses: [COURSE] } })
})

describe('the guide', () => {
  it('is reached from the Courses page and from the menu', async () => {
    renderApp('/')
    await userEvent.click(await screen.findByRole('link', { name: 'How courses work' }))
    expect(await screen.findByRole('heading', { name: 'How a course is built' })).toBeInTheDocument()

    expect(screen.getByRole('link', { name: 'Guide' })).toHaveAttribute('aria-current', 'page')
  })

  it('draws one course opened down to its exercises', async () => {
    renderApp('/guide')

    const diagram = await screen.findByRole('figure', { name: /a course holds sections/ })
    for (const example of ['English to Amharic', 'Basics', 'Greetings', 'Hello']) {
      expect(within(diagram).getByText(example)).toBeInTheDocument()
    }
    expect(within(diagram).getByText('Which one means “hello”?')).toBeInTheDocument()
    expect(within(diagram).getByText(/Skill · Numbers/)).toBeInTheDocument()
  })

  it('lists the five levels, every exercise type and the six steps', async () => {
    renderApp('/guide')

    await screen.findByRole('heading', { name: 'How a course is built' })
    expect(screen.getAllByText(/^Level \d$/)).toHaveLength(5)
    expect(within(screen.getByRole('heading', { name: /exercise types/ }).closest('section')!).getAllByRole('listitem')).toHaveLength(8)
    expect(within(screen.getByRole('heading', { name: /six steps/ }).closest('section')!).getAllByRole('listitem')).toHaveLength(6)
  })
})

describe('the info button on a course', () => {
  it('shows the levels with this course’s own content, and closes on Escape', async () => {
    const tree = courseTree()
    new FakeServer()
      .install()
      .on('GET', '/api/v1/admin/me', { body: { email: 'admin@example.com' } })
      .on('GET', '/api/v1/admin/courses/course-1/tree', { body: tree })
    renderApp('/courses/course-1')

    const info = await screen.findByRole('button', { name: 'How a course is built' })
    expect(info).toHaveAttribute('aria-expanded', 'false')
    await userEvent.click(info)

    const panel = screen.getByRole('dialog', { name: 'How a course is built' })
    for (const own of ['Amharic', 'Basics', 'Greetings', 'Hello', 'Which means hello?']) {
      expect(within(panel).getByText(own)).toBeInTheDocument()
    }
    expect(within(panel).getByRole('link', { name: /Open the full guide/ })).toHaveAttribute('href', '/guide')

    await userEvent.keyboard('{Escape}')
    expect(screen.queryByRole('dialog', { name: 'How a course is built' })).not.toBeInTheDocument()
    expect(info).toHaveFocus()
  })

  it('fills an empty course’s levels with an example', async () => {
    const tree = { ...courseTree(), sections: [] }
    new FakeServer()
      .install()
      .on('GET', '/api/v1/admin/me', { body: { email: 'admin@example.com' } })
      .on('GET', '/api/v1/admin/courses/course-1/tree', { body: tree })
    renderApp('/courses/course-1')

    await userEvent.click(await screen.findByRole('button', { name: 'How a course is built' }))

    const panel = screen.getByRole('dialog', { name: 'How a course is built' })
    expect(within(panel).getByText('Basics')).toHaveClass('italic')
    expect(within(panel).getByText('Amharic')).not.toHaveClass('italic')
  })
})
