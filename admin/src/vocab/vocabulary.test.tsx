import { screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import { FakeServer, type Call } from '../test/fakeServer'
import { COURSE, courseTree, idTokenFor } from '../test/fixtures'
import { renderApp, withStoredSession } from '../test/renderApp'
import type { AdminVocabItem, AdminVocabList } from '../types'

vi.mock('../auth/GoogleButton', () => ({
  GoogleButton: ({ onCredential }: { onCredential: (token: string) => void }) => (
    <button type="button" onClick={() => onCredential(idTokenFor('admin@example.com'))}>
      Sign in with Google
    </button>
  ),
}))

const A = '/api/v1/admin'
const VOCAB = `${A}/courses/course-1/vocab`

function word(id: string, text: string, translation: string, more: Partial<AdminVocabItem> = {}): AdminVocabItem {
  return { id, word: text, translation, learners: 0, used_by: [], ...more }
}

/** Three words: two in exercises (one practised by two learners), one unused. */
function vocabList(): AdminVocabList {
  return {
    course: COURSE,
    learners: 2,
    items: [
      word('v-hello', 'ሰላም', 'Hello', {
        learners: 2,
        used_by: [
          {
            exercise_id: 'ex-1',
            type: 'multiple_choice',
            prompt: 'Which means hello?',
            lesson_id: 'lesson-1',
            number: '1.1.1',
            section_title: 'Basics',
            skill_title: 'Greetings',
            lesson_title: 'Hello',
          },
        ],
      }),
      word('v-bye', 'ደህና ሁን', 'Goodbye', {
        used_by: [
          {
            exercise_id: 'ex-9',
            type: 'gap_fill',
            prompt: 'Fill the gap',
            lesson_id: 'lesson-2',
            number: '1.1.2',
            section_title: 'Basics',
            skill_title: 'Greetings',
            lesson_title: 'Goodbye',
          },
        ],
      }),
      word('v-tea', 'ሻይ', 'Tea'),
    ],
  }
}

let server: FakeServer
let list: AdminVocabList

beforeEach(() => {
  withStoredSession()
  list = vocabList()
  server = new FakeServer()
    .install()
    .on('GET', `${A}/me`, { body: { email: 'admin@example.com' } })
    .on('GET', `${A}/courses`, { body: { courses: [COURSE] } })
    .on('GET', `${A}/courses/course-1/tree`, { body: courseTree() })
    .on('GET', VOCAB, () => ({ body: list }))
})

async function openVocabulary(): Promise<void> {
  renderApp('/courses/course-1/vocabulary')
  await screen.findByRole('heading', { name: 'Amharic', level: 1 })
}

const rowOf = (text: string) => within(screen.getByText(text).closest('li')!)

/** A stat tile's number. */
const tile = (label: string) =>
  screen.getByText(label, { selector: 'dt' }).closest('div.rounded-md')!.querySelector('dd')!.textContent

/** The page itself, not the sidebar (both link to Vocabulary and Curriculum). */
const page = () => within(screen.getByRole('main'))

describe('the vocabulary page', () => {
  it('lists the words with their translations, uses and learners', async () => {
    await openVocabulary()

    const words = within(screen.getByRole('heading', { name: 'Words' }).closest('section')!)
    const texts = words.getAllByText(/^(ሰላም|ደህና ሁን|ሻይ)$/).map((el) => el.textContent)
    expect(texts).toEqual(['ሰላም', 'ደህና ሁን', 'ሻይ'])

    const hello = rowOf('ሰላም')
    expect(hello.getByText('Hello', { selector: 'p' })).toBeInTheDocument()
    expect(hello.getByTitle('Learners practising this word')).toHaveTextContent('2')
    const link = hello.getByRole('link', { name: /1\.1\.1/ })
    expect(link).toHaveTextContent('Hello · Multiple choice')
    expect(link).toHaveAttribute('href', '/courses/course-1/lessons/lesson-1/exercises/ex-1')
    expect(link).toHaveAttribute('title', 'Basics › Greetings › Hello')

    expect(rowOf('ሻይ').getByText('Not in any exercise')).toBeInTheDocument()
    expect(rowOf('ሻይ').queryByRole('link')).toBeNull()
  })

  it('counts words, used, unused and learners in the stat tiles', async () => {
    await openVocabulary()

    expect(tile('Words')).toBe('3')
    expect(tile('In exercises')).toBe('2')
    expect(tile('Not used')).toBe('1')
    expect(tile('Learners practising')).toBe('2')
  })

  it('narrows the list by word or translation as you type', async () => {
    await openVocabulary()
    const search = screen.getByRole('searchbox', { name: 'Search words' })

    await userEvent.type(search, 'good')
    expect(screen.getByText('ደህና ሁን')).toBeInTheDocument()
    expect(screen.queryByText('ሰላም')).toBeNull()
    expect(screen.getByText(/1 of 3 words/)).toBeInTheDocument()

    await userEvent.clear(search)
    await userEvent.type(search, 'ሻ')
    expect(screen.getByText('ሻይ')).toBeInTheDocument()
    expect(screen.queryByText('ደህና ሁን')).toBeNull()

    await userEvent.clear(search)
    await userEvent.type(search, 'zzz')
    expect(screen.getByText('No word matches “zzz”.')).toBeInTheDocument()
  })

  it('edits a word, saves it trimmed and shows the saved text', async () => {
    server.on('PATCH', `${A}/vocab/v-hello`, (call: Call) => {
      const body = call.body as { word: string; translation: string }
      list.items[0] = { ...list.items[0]!, ...body }
      return { body: list.items[0] }
    })
    await openVocabulary()

    await userEvent.click(screen.getByRole('button', { name: 'Edit ሰላም' }))
    const form = within(screen.getByRole('form', { name: 'Edit ሰላም' }))
    expect(form.getByText(/Learners keep their progress/)).toBeInTheDocument()
    const translation = form.getByLabelText('Translation')
    await userEvent.clear(translation)
    await userEvent.type(translation, '  Hi there ')
    await userEvent.click(form.getByRole('button', { name: 'Save' }))

    await waitFor(() => expect(screen.queryByRole('form')).toBeNull())
    expect(server.callsTo('PATCH', `${A}/vocab/v-hello`)[0]!.body).toEqual({ word: 'ሰላም', translation: 'Hi there' })
    expect(server.callsTo('GET', VOCAB)).toHaveLength(2)
    expect(rowOf('ሰላም').getByText('Hi there')).toBeInTheDocument()
  })

  it('will not save an empty field, and Cancel or Escape closes the form unsaved', async () => {
    await openVocabulary()

    await userEvent.click(screen.getByRole('button', { name: 'Edit ሰላም' }))
    let form = within(screen.getByRole('form', { name: 'Edit ሰላም' }))
    await userEvent.clear(form.getByLabelText('Word'))
    expect(form.getByRole('button', { name: 'Save' })).toBeDisabled()
    await userEvent.click(form.getByRole('button', { name: 'Cancel' }))
    expect(screen.queryByRole('form')).toBeNull()

    await userEvent.click(screen.getByRole('button', { name: 'Edit ሰላም' }))
    form = within(screen.getByRole('form', { name: 'Edit ሰላም' }))
    await userEvent.type(form.getByLabelText('Word'), 'x{Escape}')
    expect(screen.queryByRole('form')).toBeNull()
    expect(server.callsTo('PATCH', `${A}/vocab/v-hello`)).toHaveLength(0)
  })

  it('shows a refused field under that field and keeps the form open', async () => {
    server.on('PATCH', `${A}/vocab/v-hello`, {
      status: 422,
      body: {
        error_code: 'invalid_content',
        message: 'translation must be at most 255 characters',
        details: { field: 'translation' },
      },
    })
    await openVocabulary()

    await userEvent.click(screen.getByRole('button', { name: 'Edit ሰላም' }))
    const form = within(screen.getByRole('form', { name: 'Edit ሰላም' }))
    await userEvent.type(form.getByLabelText('Translation'), '!')
    await userEvent.click(form.getByRole('button', { name: 'Save' }))

    const error = await form.findByRole('alert')
    expect(error).toHaveTextContent('translation must be at most 255 characters')
    expect(form.getByLabelText('Translation')).toHaveAttribute('aria-invalid', 'true')
    expect(form.getByLabelText('Word')).not.toHaveAttribute('aria-invalid')
    expect(screen.getByRole('form', { name: 'Edit ሰላም' })).toBeInTheDocument()
  })

  it('shows any other failure in the banner and reloads the list', async () => {
    server.on('PATCH', `${A}/vocab/v-hello`, {
      status: 404,
      body: { error_code: 'content_not_found', message: 'No such vocab' },
    })
    await openVocabulary()

    await userEvent.click(screen.getByRole('button', { name: 'Edit ሰላም' }))
    await userEvent.click(screen.getByRole('button', { name: 'Save' }))

    expect(await screen.findByText('No such vocab')).toBeInTheDocument()
    await waitFor(() => expect(server.callsTo('GET', VOCAB)).toHaveLength(2))
  })

  it('says so when the course has no words', async () => {
    list.items = []
    list.learners = 0
    await openVocabulary()

    expect(screen.getByText('This course has no practice words yet.')).toBeInTheDocument()
    expect(screen.queryByRole('searchbox')).toBeNull()
  })

  it('says so when the course does not exist', async () => {
    server.on('GET', VOCAB, { status: 404, body: { error_code: 'content_not_found', message: 'No such course' } })
    renderApp('/courses/course-1/vocabulary')

    expect(await screen.findByRole('alert')).toHaveTextContent('This course does not exist.')
    expect(screen.queryByRole('button', { name: 'Try again' })).toBeNull()
  })

  it('offers to try again when the server cannot be reached', async () => {
    server.on('GET', VOCAB, () => {
      throw new Error('offline')
    })
    renderApp('/courses/course-1/vocabulary')

    expect(await screen.findByRole('alert')).toHaveTextContent('Could not reach the server')
    server.on('GET', VOCAB, () => ({ body: list }))
    await userEvent.click(screen.getByRole('button', { name: 'Try again' }))
    expect(await screen.findByText('ሰላም')).toBeInTheDocument()
  })
})

describe('getting there', () => {
  it('from the sidebar: Vocabulary lists the courses, and a course opens its words', async () => {
    renderApp('/')
    await screen.findByRole('heading', { name: 'Courses' })
    const nav = within(screen.getByRole('navigation', { name: 'Sections' }))
    expect(nav.getByRole('link', { name: 'Curriculum' })).toHaveAttribute('aria-current', 'page')
    expect(screen.queryByText('Soon')).toBeNull()

    await userEvent.click(nav.getByRole('link', { name: 'Vocabulary' }))
    expect(nav.getByRole('link', { name: 'Vocabulary' })).toHaveAttribute('aria-current', 'page')
    expect(nav.getByRole('link', { name: 'Curriculum' })).not.toHaveAttribute('aria-current')
    await userEvent.click(await screen.findByRole('link', { name: /Amharic.*Open vocabulary/ }))

    expect(await screen.findByText('ሰላም')).toBeInTheDocument()
    expect(nav.getByRole('link', { name: 'Vocabulary' })).toHaveAttribute('aria-current', 'page')
  })

  it('from the course page, and back to the curriculum from the words', async () => {
    renderApp('/courses/course-1')
    await screen.findByRole('heading', { name: 'Amharic' })

    await userEvent.click(page().getByRole('link', { name: 'Vocabulary' }))
    expect(await screen.findByText('ሰላም')).toBeInTheDocument()

    await userEvent.click(page().getByRole('link', { name: 'Curriculum' }))
    expect(await screen.findByText('Basics')).toBeInTheDocument()
  })
})
