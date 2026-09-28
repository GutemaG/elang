import { screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import { FakeServer } from './test/fakeServer'
import { COURSE, courseTree, idTokenFor } from './test/fixtures'
import { renderApp, withStoredSession } from './test/renderApp'
import type { AdminCourseTree } from './types'

vi.mock('./auth/GoogleButton', () => ({
  GoogleButton: ({ onCredential }: { onCredential: (token: string) => void }) => (
    <button type="button" onClick={() => onCredential(idTokenFor('admin@example.com'))}>
      Sign in with Google
    </button>
  ),
}))

const ME = '/api/v1/admin/me'
const COURSES = '/api/v1/admin/courses'
const TREE = '/api/v1/admin/courses/course-1/tree'

let server: FakeServer
let tree: AdminCourseTree

beforeEach(() => {
  withStoredSession()
  // Set by the tests that leave the course at a scroll position.
  Object.defineProperty(window, 'scrollY', { configurable: true, value: 0 })
  tree = courseTree()
  server = new FakeServer()
    .install()
    .on('GET', ME, { body: { email: 'admin@example.com' } })
    .on('GET', COURSES, { body: { courses: [COURSE] } })
    .on('GET', TREE, () => ({ body: tree }))
})

/** Opens the course page and waits for the tree. */
async function openCourse(): Promise<void> {
  renderApp('/courses/course-1')
  await screen.findByRole('heading', { name: 'Amharic' })
}

const actions = (label: string) => within(screen.getByRole('group', { name: `Actions for ${label}` }))

async function expand(label: string): Promise<void> {
  await userEvent.click(screen.getByRole('button', { name: `Expand ${label}` }))
}

/** Opens section → skill → lesson, the path used by most tests. */
async function openToLesson(): Promise<void> {
  await expand('section Basics')
  await expand('skill Greetings')
  await expand('lesson Hello')
}

describe('the tree', () => {
  it('shows the course, its sections and their counts', async () => {
    await openCourse()

    expect(screen.getByText(/Amharic for English speakers/)).toHaveTextContent('active')
    expect(screen.getByText('Basics')).toBeInTheDocument()
    expect(screen.getByText('First words', { exact: false })).toBeInTheDocument()
    expect(actions('section Basics').getByRole('button', { name: 'Rename' })).toBeInTheDocument()
    expect(screen.getAllByText('2 skills')).toHaveLength(1)
    expect(screen.getByText('0 skills')).toBeInTheDocument()
  })

  it('reaches skills, lessons and exercises, marking placeholder and local audio', async () => {
    await openCourse()

    await expand('section Basics')
    expect(screen.getByText('Greetings')).toBeInTheDocument()
    expect(screen.getByText('2 lessons')).toBeInTheDocument()

    await expand('skill Greetings')
    expect(screen.getByText('Hello')).toBeInTheDocument()
    expect(screen.getByText('3 exercises')).toBeInTheDocument()

    await expand('lesson Hello')
    expect(screen.getByText('Which means hello?')).toBeInTheDocument()
    expect(screen.getAllByText('Listening')).toHaveLength(2)
    expect(screen.getByText('placeholder audio')).toBeInTheDocument()
    expect(screen.getByText('local audio')).toBeInTheDocument()

    await expand('lesson Goodbye')
    expect(screen.getByText('No exercises yet.')).toBeInTheDocument()
  })

  it('orders siblings by their order_index, whatever order they arrive in', async () => {
    tree.sections.reverse()
    await openCourse()

    const titles = screen.getAllByText(/Basics|Travel/).map((el) => el.textContent)
    expect(titles).toEqual(['Basics', 'Travel'])
  })

  it('says so when the course does not exist', async () => {
    server.on('GET', TREE, { status: 404, body: { error_code: 'not_found', message: 'No such course' } })
    renderApp('/courses/course-1')

    expect(await screen.findByRole('alert')).toHaveTextContent('This course does not exist.')
  })

  it('is reached from the course list', async () => {
    renderApp('/')

    await userEvent.click(await screen.findByRole('link', { name: /Amharic/ }))

    expect(await screen.findByRole('heading', { name: 'Amharic' })).toBeInTheDocument()
  })
})

describe('renaming', () => {
  it('saves a lesson title and shows the server-s tree afterwards', async () => {
    server.on('PATCH', '/api/v1/admin/lessons/lesson-1', () => {
      tree.sections[0]!.skills[0]!.lessons[0]!.title = 'Hello there'
      return { body: { id: 'lesson-1', title: 'Hello there', subtitle: null, order_index: 1 } }
    })
    await openCourse()
    await openToLesson()

    await userEvent.click(actions('lesson Hello').getByRole('button', { name: 'Rename' }))
    const form = screen.getByRole('form', { name: 'Rename lesson' })
    await userEvent.clear(within(form).getByLabelText('Title'))
    await userEvent.type(within(form).getByLabelText('Title'), 'Hello there')
    await userEvent.click(within(form).getByRole('button', { name: 'Save' }))

    expect(await screen.findByText('Hello there')).toBeInTheDocument()
    expect(server.callsTo('PATCH', '/api/v1/admin/lessons/lesson-1')[0]!.body).toEqual({ title: 'Hello there' })
    // Reloaded from the server, rather than patched locally.
    expect(server.callsTo('GET', TREE)).toHaveLength(2)
  })

  it('sends a section-s subtitle as well as its title', async () => {
    server.on('PATCH', '/api/v1/admin/sections/sec-1', { body: { id: 'sec-1', title: 'Start', subtitle: 'Day one', order_index: 1 } })
    await openCourse()

    await userEvent.click(actions('section Basics').getByRole('button', { name: 'Rename' }))
    const form = screen.getByRole('form', { name: 'Rename section' })
    await userEvent.clear(within(form).getByLabelText('Title'))
    await userEvent.type(within(form).getByLabelText('Title'), 'Start')
    await userEvent.clear(within(form).getByLabelText('Subtitle'))
    await userEvent.type(within(form).getByLabelText('Subtitle'), 'Day one')
    await userEvent.click(within(form).getByRole('button', { name: 'Save' }))

    await waitFor(() =>
      expect(server.callsTo('PATCH', '/api/v1/admin/sections/sec-1')[0]!.body).toEqual({
        title: 'Start',
        subtitle: 'Day one',
      }),
    )
  })

  it('renames the course', async () => {
    server.on('PATCH', '/api/v1/admin/courses/course-1', { body: { ...COURSE, title: 'Amharic A1' } })
    await openCourse()

    await userEvent.click(screen.getByRole('button', { name: 'Rename course' }))
    const form = screen.getByRole('form', { name: 'Rename course' })
    await userEvent.clear(within(form).getByLabelText('Title'))
    await userEvent.type(within(form).getByLabelText('Title'), 'Amharic A1')
    await userEvent.click(within(form).getByRole('button', { name: 'Save' }))

    await waitFor(() =>
      expect(server.callsTo('PATCH', '/api/v1/admin/courses/course-1')[0]!.body).toEqual({ title: 'Amharic A1' }),
    )
  })

  it('cannot be saved empty, and Cancel sends nothing', async () => {
    await openCourse()

    await userEvent.click(actions('section Basics').getByRole('button', { name: 'Rename' }))
    const form = screen.getByRole('form', { name: 'Rename section' })
    await userEvent.clear(within(form).getByLabelText('Title'))

    expect(within(form).getByRole('button', { name: 'Save' })).toBeDisabled()

    await userEvent.click(within(form).getByRole('button', { name: 'Cancel' }))

    expect(screen.queryByRole('form', { name: 'Rename section' })).not.toBeInTheDocument()
    expect(server.calls.filter((c) => c.method === 'PATCH')).toHaveLength(0)
  })
})

describe('adding', () => {
  it('adds a section to the course', async () => {
    server.on('POST', '/api/v1/admin/courses/course-1/sections', {
      status: 201,
      body: { id: 'sec-3', title: 'Food', subtitle: 'Eating out', order_index: 3 },
    })
    await openCourse()

    await userEvent.click(screen.getByRole('button', { name: 'Add section' }))
    const form = screen.getByRole('form', { name: 'Add section' })
    await userEvent.type(within(form).getByLabelText('Title'), 'Food')
    await userEvent.type(within(form).getByLabelText('Subtitle'), 'Eating out')
    await userEvent.click(within(form).getByRole('button', { name: 'Add section' }))

    await waitFor(() =>
      expect(server.callsTo('POST', '/api/v1/admin/courses/course-1/sections')[0]!.body).toEqual({
        title: 'Food',
        subtitle: 'Eating out',
      }),
    )
  })

  it('adds a skill to a section and opens the section to show it', async () => {
    server.on('POST', '/api/v1/admin/sections/sec-1/skills', () => {
      tree.sections[0]!.skills.push({ id: 'skill-3', title: 'Colours', order_index: 3, lesson_count: 0, lessons: [] })
      return { status: 201, body: { id: 'skill-3', title: 'Colours', subtitle: null, order_index: 3 } }
    })
    await openCourse()

    await userEvent.click(actions('section Basics').getByRole('button', { name: 'Add skill' }))
    const form = screen.getByRole('form', { name: 'Add skill' })
    await userEvent.type(within(form).getByLabelText('Title'), 'Colours')
    await userEvent.click(within(form).getByRole('button', { name: 'Add skill' }))

    expect(await screen.findByText('Colours')).toBeInTheDocument()
    expect(server.callsTo('POST', '/api/v1/admin/sections/sec-1/skills')[0]!.body).toEqual({ title: 'Colours' })
  })

  it('offers exercises, and nothing else, below a lesson', async () => {
    await openCourse()
    await openToLesson()

    const adds = actions('lesson Hello').getAllByRole('button', { name: /^Add / })
    expect(adds.map((b) => b.textContent)).toEqual([expect.stringContaining('Add exercise')])
  })
})

describe('reordering', () => {
  const SECTION_ORDER = '/api/v1/admin/courses/course-1/sections/order'
  const LESSON_ORDER = '/api/v1/admin/skills/skill-1/lessons/order'
  const puts = () => server.calls.filter((c) => c.method === 'PUT')
  const saveBar = () => screen.queryByRole('region', { name: 'Unsaved order' })
  const sectionTitles = () => screen.getAllByRole('heading', { level: 2 }).map((h) => h.textContent).filter((t) => t !== 'Curriculum')

  /** The keyboard's way to drag: focus the handle, press an arrow. */
  async function press(label: string, key: '{ArrowUp}' | '{ArrowDown}'): Promise<void> {
    screen.getByRole('button', { name: `Move ${label}` }).focus()
    await userEvent.keyboard(key)
  }

  it('every row has a handle, and the up and down buttons are gone', async () => {
    await openCourse()
    await openToLesson()

    for (const label of ['section Basics', 'section Travel', 'skill Greetings', 'lesson Hello', 'exercise 1', 'exercise 3']) {
      expect(screen.getByRole('button', { name: `Move ${label}` })).toBeEnabled()
    }
    expect(screen.queryByRole('button', { name: 'Move up' })).not.toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'Move down' })).not.toBeInTheDocument()
  })

  it('a move changes the page only, renumbers it, and keeps the handle focused', async () => {
    await openCourse()

    await press('section Basics', '{ArrowDown}')

    expect(sectionTitles()).toEqual(['Travel', 'Basics'])
    expect(screen.getByText('Section 01').closest('li')).toHaveTextContent('Travel')
    expect(screen.getByRole('button', { name: 'Move section Basics' })).toHaveFocus()
    expect(screen.getByText('section Basics moved to position 2 of 2. Not saved yet.')).toBeInTheDocument()
    expect(saveBar()).toHaveTextContent('New order not saved (1 list)')
    expect(puts()).toHaveLength(0)
  })

  it('cannot move past either end', async () => {
    await openCourse()

    await press('section Basics', '{ArrowUp}')
    await press('section Travel', '{ArrowDown}')

    expect(sectionTitles()).toEqual(['Basics', 'Travel'])
    expect(saveBar()).not.toBeInTheDocument()
  })

  it('Save sends one PUT per changed list, with every id, then shows the saved tree', async () => {
    server
      .on('PUT', SECTION_ORDER, () => {
        tree.sections[0]!.order_index = 2
        tree.sections[1]!.order_index = 1
        return { body: { items: [] } }
      })
      .on('PUT', LESSON_ORDER, { body: { items: [] } })
    await openCourse()
    await expand('section Basics')
    await expand('skill Greetings')

    await press('section Basics', '{ArrowDown}')
    await press('lesson Goodbye', '{ArrowUp}')
    expect(saveBar()).toHaveTextContent('(2 lists)')
    await userEvent.click(within(saveBar()!).getByRole('button', { name: 'Save order' }))

    await waitFor(() => expect(saveBar()).not.toBeInTheDocument())
    expect(server.callsTo('PUT', SECTION_ORDER).map((c) => c.body)).toEqual([{ ids: ['sec-2', 'sec-1'] }])
    expect(server.callsTo('PUT', LESSON_ORDER).map((c) => c.body)).toEqual([{ ids: ['lesson-2', 'lesson-1'] }])
    expect(server.callsTo('GET', TREE)).toHaveLength(2)
    expect(sectionTitles()).toEqual(['Travel', 'Basics'])
  })

  it('Discard puts every list back and sends nothing', async () => {
    await openCourse()
    await expand('section Basics')

    await press('section Basics', '{ArrowDown}')
    await press('skill Greetings', '{ArrowDown}')
    await userEvent.click(within(saveBar()!).getByRole('button', { name: 'Discard' }))

    expect(sectionTitles()).toEqual(['Basics', 'Travel'])
    expect(screen.getByText('1.1').parentElement).toHaveTextContent('Greetings')
    expect(saveBar()).not.toBeInTheDocument()
    expect(puts()).toHaveLength(0)
  })

  it('while a new order is unsaved, other edits wait, and moving does not', async () => {
    await openCourse()
    await openToLesson()

    await press('exercise 1', '{ArrowDown}')

    for (const button of [
      screen.getByRole('button', { name: 'Rename course' }),
      screen.getByRole('button', { name: 'Add section' }),
      actions('section Basics').getByRole('button', { name: 'Rename' }),
      actions('section Basics').getByRole('button', { name: 'Delete' }),
      actions('section Basics').getByRole('button', { name: /Add skill/ }),
      actions('lesson Hello').getByRole('button', { name: /Add exercise/ }),
    ]) {
      expect(button).toBeDisabled()
    }
    expect(actions('section Basics').getByRole('button', { name: 'Rename' })).toHaveAttribute(
      'title',
      'Save or discard the new order first',
    )
    expect(screen.getByRole('button', { name: 'Move section Basics' })).toBeEnabled()
  })

  it('a refused save shows why, and the tree as the server has it', async () => {
    server.on('PUT', SECTION_ORDER, {
      status: 422,
      body: { error_code: 'invalid_content', message: 'ids must list every section', details: { field: 'ids' } },
    })
    await openCourse()

    await press('section Basics', '{ArrowDown}')
    await userEvent.click(within(saveBar()!).getByRole('button', { name: 'Save order' }))

    expect(await screen.findByRole('alert')).toHaveTextContent('ids must list every section')
    await waitFor(() => expect(server.callsTo('GET', TREE)).toHaveLength(2))
    expect(saveBar()).not.toBeInTheDocument()
    expect(sectionTitles()).toEqual(['Basics', 'Travel'])
  })

  it('an unsaved order asks before the tab is closed', async () => {
    await openCourse()
    const quiet = new Event('beforeunload', { cancelable: true })
    window.dispatchEvent(quiet)
    expect(quiet.defaultPrevented).toBe(false)

    await press('section Basics', '{ArrowDown}')

    const leaving = new Event('beforeunload', { cancelable: true })
    window.dispatchEvent(leaving)
    expect(leaving.defaultPrevented).toBe(true)
  })
})

describe('deleting', () => {
  const SECTION = '/api/v1/admin/sections/sec-1'

  it('asks the server first, then shows what would go, and confirms', async () => {
    let confirmed = false
    server.on('DELETE', SECTION, (call) => {
      if (call.query.includes('confirm=true')) {
        confirmed = true
        tree.sections.shift()
        return { status: 204 }
      }
      return {
        status: 409,
        body: {
          error_code: 'confirmation_required',
          message: 'Deleting this section also deletes everything in it; repeat with confirm=true',
          details: { skills: 2, lessons: 2, exercises: 3 },
        },
      }
    })
    await openCourse()

    await userEvent.click(actions('section Basics').getByRole('button', { name: 'Delete' }))

    const dialog = await screen.findByRole('dialog')
    expect(within(dialog).getByRole('heading')).toHaveTextContent('Delete section “Basics”?')
    expect(dialog).toHaveTextContent('This also deletes 2 skills, 2 lessons and 3 exercises.')
    // Nothing is gone until it is confirmed.
    expect(confirmed).toBe(false)

    await userEvent.click(within(dialog).getByRole('button', { name: 'Delete' }))

    await waitFor(() => expect(screen.queryByRole('dialog')).not.toBeInTheDocument())
    expect(server.callsTo('DELETE', SECTION)[1]!.query).toBe('?confirm=true')
    expect(screen.queryByText('Basics')).not.toBeInTheDocument()
  })

  it('refuses outright when learners have progress, with no way to force it', async () => {
    server.on('DELETE', SECTION, {
      status: 409,
      body: {
        error_code: 'content_in_use',
        message: '3 learner(s) have progress here, so it cannot be deleted',
        details: { learners: 3, skills: 2, lessons: 2, exercises: 3 },
      },
    })
    await openCourse()

    await userEvent.click(actions('section Basics').getByRole('button', { name: 'Delete' }))

    const dialog = await screen.findByRole('dialog')
    expect(dialog).toHaveTextContent('3 learners have progress in this section')
    expect(within(dialog).queryByRole('button', { name: 'Delete' })).not.toBeInTheDocument()

    await userEvent.click(within(dialog).getByRole('button', { name: 'Close' }))

    expect(screen.queryByRole('dialog')).not.toBeInTheDocument()
    expect(server.callsTo('DELETE', SECTION)).toHaveLength(1)
    expect(screen.getByText('Basics')).toBeInTheDocument()
  })

  it('sends nothing more when the confirmation is cancelled', async () => {
    server.on('DELETE', SECTION, {
      status: 409,
      body: { error_code: 'confirmation_required', message: 'Repeat with confirm=true', details: { skills: 0, lessons: 0, exercises: 0 } },
    })
    await openCourse()

    await userEvent.click(actions('section Basics').getByRole('button', { name: 'Delete' }))
    const dialog = await screen.findByRole('dialog')
    expect(dialog).toHaveTextContent('Nothing else is inside it.')

    await userEvent.click(within(dialog).getByRole('button', { name: 'Cancel' }))

    expect(screen.queryByRole('dialog')).not.toBeInTheDocument()
    expect(server.callsTo('DELETE', SECTION)).toHaveLength(1)
  })

  it('deletes an empty lesson outright when the server allows it', async () => {
    server.on('DELETE', '/api/v1/admin/lessons/lesson-2', () => {
      tree.sections[0]!.skills[0]!.lessons.pop()
      return { status: 204 }
    })
    await openCourse()
    await expand('section Basics')
    await expand('skill Greetings')

    await userEvent.click(actions('lesson Goodbye').getByRole('button', { name: 'Delete' }))

    await waitFor(() => expect(screen.queryByText('Goodbye')).not.toBeInTheDocument())
    // No dialog: the server accepted it, so there was nothing to confirm.
    expect(screen.queryByRole('dialog')).not.toBeInTheDocument()
    expect(server.callsTo('DELETE', '/api/v1/admin/lessons/lesson-2')[0]!.query).toBe('')
  })
})

describe('a write the server refuses', () => {
  it('shows its message and leaves the tree as the server has it', async () => {
    server.on('PATCH', '/api/v1/admin/lessons/lesson-1', {
      status: 422,
      body: { error_code: 'invalid_content', message: 'title must not be blank', details: { field: 'title' } },
    })
    await openCourse()
    await openToLesson()

    await userEvent.click(actions('lesson Hello').getByRole('button', { name: 'Rename' }))
    const form = screen.getByRole('form', { name: 'Rename lesson' })
    await userEvent.clear(within(form).getByLabelText('Title'))
    await userEvent.type(within(form).getByLabelText('Title'), '   x')
    await userEvent.click(within(form).getByRole('button', { name: 'Save' }))

    expect(await screen.findByRole('alert')).toHaveTextContent('title must not be blank')
    // The form stays open with what was typed, so it can be corrected...
    expect(within(form).getByLabelText('Title')).toHaveValue('   x')
    // ...and the tree behind it is refreshed from the server, so the title
    // the server still has is what is shown.
    await waitFor(() => expect(server.callsTo('GET', TREE)).toHaveLength(2))
    await userEvent.click(within(form).getByRole('button', { name: 'Cancel' }))
    expect(screen.getByText('Hello')).toBeInTheDocument()

    await userEvent.click(screen.getByRole('button', { name: 'Dismiss' }))
    expect(screen.queryByRole('alert')).not.toBeInTheDocument()
  })

  it('ends the session when a write is refused with 401', async () => {
    server.on('PATCH', '/api/v1/admin/sections/sec-1', {
      status: 401,
      body: { error_code: 'invalid_session', message: 'Session token is unknown or expired' },
    })
    await openCourse()

    await userEvent.click(actions('section Basics').getByRole('button', { name: 'Rename' }))
    const form = screen.getByRole('form', { name: 'Rename section' })
    await userEvent.type(within(form).getByLabelText('Title'), '!')
    await userEvent.click(within(form).getByRole('button', { name: 'Save' }))

    expect(await screen.findByRole('button', { name: 'Sign in with Google' })).toBeInTheDocument()
    expect(sessionStorage.getItem('buna_admin.session_token')).toBeNull()
  })
})

describe('exercises in the tree', () => {
  const LIST = '/api/v1/admin/lessons/lesson-1/exercises'
  const exerciseActions = (n: number) => within(screen.getByRole('group', { name: `Actions for exercise ${n}` }))

  /** Full exercises for lesson-1, matching the tree's summary of it. */
  function serveLesson(): void {
    server.on('GET', LIST, {
      body: {
        exercises: tree.sections[0]!.skills[0]!.lessons[0]!.exercises.map((e) => ({
          id: e.id,
          lesson_id: 'lesson-1',
          order_index: e.order_index,
          vocab_item_id: null,
          type: e.type,
          prompt: e.prompt,
          content:
            e.type === 'listening'
              ? { audio_url: '/media/audio/am/hello.m4a', choices: [{ id: 'a', text: 'Hello' }, { id: 'b', text: 'Bye' }] }
              : { choices: [{ id: 'a', text: 'ሰላም' }, { id: 'b', text: 'ቻው' }] },
          answer_key: { correct_choice_id: 'a' },
        })),
      },
    })
  }

  it('a lesson offers every type, and each leads to a new exercise of it', async () => {
    await openCourse()
    await openToLesson()

    await userEvent.click(actions('lesson Hello').getByRole('button', { name: /Add exercise/ }))
    const menu = within(screen.getByRole('navigation', { name: 'Exercise type' }))
    expect(menu.getAllByRole('link').map((a) => a.querySelector('.font-semibold')?.textContent)).toEqual([
      'Multiple choice',
      'Listening',
      'Gap fill',
      'Sentence',
      'Spell tiles',
      'Match pairs',
      'Image choice',
      'Audio image choice',
    ])

    await userEvent.click(menu.getByRole('link', { name: /Gap fill/ }))

    expect(await screen.findByRole('heading', { name: 'New exercise' })).toBeInTheDocument()
    expect(screen.getByLabelText('Text before the gap')).toBeInTheDocument()
  })

  it('moving an exercise waits for Save, then sends the whole lesson in its new order', async () => {
    server.on('PUT', `${LIST}/order`, { body: { exercises: [] } })
    await openCourse()
    await openToLesson()

    screen.getByRole('button', { name: 'Move exercise 1' }).focus()
    await userEvent.keyboard('{ArrowDown}')

    // Renumbered on the page; its editor waits, as leaving would lose the order.
    expect(exerciseActions(2).getByRole('button', { name: 'Edit' })).toBeDisabled()
    expect(screen.getByText('Which means hello?').closest('li')).toContainElement(
      screen.getByRole('group', { name: 'Actions for exercise 2' }),
    )
    expect(screen.queryByRole('link', { name: 'Which means hello?' })).not.toBeInTheDocument()
    expect(server.callsTo('PUT', `${LIST}/order`)).toHaveLength(0)

    await userEvent.click(screen.getByRole('button', { name: 'Save order' }))

    await waitFor(() =>
      expect(server.callsTo('PUT', `${LIST}/order`)[0]!.body).toEqual({ ids: ['ex-2', 'ex-1', 'ex-3'] }),
    )
    expect(server.callsTo('GET', TREE)).toHaveLength(2)
  })

  it('deleting an exercise asks first, and Cancel sends nothing', async () => {
    server.on('DELETE', '/api/v1/admin/exercises/ex-2', () => {
      tree.sections[0]!.skills[0]!.lessons[0]!.exercises.splice(1, 1)
      return { status: 204 }
    })
    await openCourse()
    await openToLesson()

    await userEvent.click(exerciseActions(2).getByRole('button', { name: 'Delete' }))
    let dialog = screen.getByRole('dialog', { name: 'Delete exercise 2?' })
    expect(dialog).toHaveTextContent('What do you hear?')
    await userEvent.click(within(dialog).getByRole('button', { name: 'Cancel' }))
    expect(server.callsTo('DELETE', '/api/v1/admin/exercises/ex-2')).toHaveLength(0)

    await userEvent.click(exerciseActions(2).getByRole('button', { name: 'Delete' }))
    dialog = screen.getByRole('dialog', { name: 'Delete exercise 2?' })
    await userEvent.click(within(dialog).getByRole('button', { name: 'Delete' }))

    await waitFor(() => expect(screen.queryByText('What do you hear?')).not.toBeInTheDocument())
    expect(server.callsTo('DELETE', '/api/v1/admin/exercises/ex-2')[0]!.query).toBe('')
    expect(screen.queryByRole('dialog')).not.toBeInTheDocument()
  })

  it('an exercise opens in the editor', async () => {
    serveLesson()
    await openCourse()
    await openToLesson()

    await userEvent.click(exerciseActions(1).getByRole('link', { name: 'Edit' }))

    expect(await screen.findByRole('heading', { name: 'Edit exercise' })).toBeInTheDocument()
    expect(screen.getByLabelText('Prompt')).toHaveValue('Which means hello?')
  })

  it('previews the saved exercise with its answer', async () => {
    serveLesson()
    await openCourse()
    await openToLesson()

    await userEvent.click(exerciseActions(2).getByRole('button', { name: 'Preview' }))

    const dialog = await screen.findByRole('dialog', { name: 'Preview' })
    const correct = await within(dialog).findByText('(correct)')
    expect(correct.closest('li')).toHaveTextContent('Hello')
    await userEvent.click(within(dialog).getByRole('button', { name: 'Close' }))
    expect(screen.queryByRole('dialog')).not.toBeInTheDocument()
  })

  it('coming back from an exercise reopens its lesson', async () => {
    renderApp('/courses/course-1?open=lesson-1')

    expect(await screen.findByText('Which means hello?')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Collapse lesson Hello' })).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Expand lesson Goodbye' })).toBeInTheDocument()
  })

  /** Leaves the course for exercise 1's editor, with the page at `y`. */
  async function leaveForExercise(y: number): Promise<void> {
    serveLesson()
    Object.defineProperty(window, 'scrollY', { configurable: true, value: y })
    await userEvent.click(exerciseActions(1).getByRole('link', { name: 'Edit' }))
    await screen.findByRole('heading', { name: 'Edit exercise' })
  }

  it.each([
    ['the breadcrumb', 'crumb'],
    ['Back to lesson', 'back'],
  ])('coming back by %s finds the tree as it was left, scrolled as it was', async (_, way) => {
    const scrollTo = vi.spyOn(window, 'scrollTo').mockImplementation(() => {})
    await openCourse()
    await expand('section Basics')
    await expand('section Travel')
    await expand('skill Greetings')
    await expand('lesson Hello')
    await leaveForExercise(640)

    if (way === 'crumb') {
      const crumbs = within(screen.getByRole('navigation', { name: 'Breadcrumb' }))
      await userEvent.click(crumbs.getAllByRole('link')[1]!)
    } else {
      await userEvent.click(screen.getByRole('link', { name: /Back to lesson/ }))
    }

    expect(await screen.findByText('Which means hello?')).toBeInTheDocument()
    for (const open of ['section Basics', 'section Travel', 'skill Greetings', 'lesson Hello']) {
      expect(screen.getByRole('button', { name: `Collapse ${open}` })).toBeInTheDocument()
    }
    expect(screen.getByRole('button', { name: 'Expand lesson Goodbye' })).toBeInTheDocument()
    expect(scrollTo).toHaveBeenCalledWith(0, 640)
  })

  it("coming back by the browser's Back button, which lands on the plain course address, finds it as it was left", async () => {
    const scrollTo = vi.spyOn(window, 'scrollTo').mockImplementation(() => {})
    const first = renderApp('/courses/course-1')
    await screen.findByRole('heading', { name: 'Amharic' })
    await openToLesson()
    await expand('section Travel')
    await userEvent.click(screen.getByRole('button', { name: 'Collapse section Travel' }))
    await leaveForExercise(300)
    first.unmount()

    renderApp('/courses/course-1')

    expect(await screen.findByText('Which means hello?')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Collapse lesson Hello' })).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Expand section Travel' })).toBeInTheDocument()
    expect(scrollTo).toHaveBeenCalledWith(0, 300)
  })
})
