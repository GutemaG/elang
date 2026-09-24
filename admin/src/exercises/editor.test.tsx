import { screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import { API_BASE_URL } from '../config'
import { FakeServer, type Call } from '../test/fakeServer'
import { GAP, LISTENING, MC, PAIRS, SENTENCE, SPELL, lessonExercises } from '../test/exercises'
import { courseTree } from '../test/fixtures'
import { renderApp, withStoredSession } from '../test/renderApp'
import type { AdminExercise, Tile } from '../types'

vi.mock('../auth/GoogleButton', () => ({ GoogleButton: () => null }))

const A = '/api/v1/admin'
const LIST = `${A}/lessons/lesson-1/exercises`
const EDIT = '/courses/course-1/lessons/lesson-1/exercises'

let server: FakeServer
let stored: AdminExercise[]

/** Echoes a saved exercise back, as the server does. */
function acceptsSaves(id: string): void {
  server.on('PUT', `${A}/exercises/${id}`, (call: Call) => ({
    body: { ...(call.body as object), id, lesson_id: 'lesson-1', order_index: 1, vocab_item_id: null },
  }))
}

/** What was last sent for an exercise, loosely typed so tests can reach
 * any type's fields. */
interface Sent {
  prompt: string
  content: Record<string, unknown>
  answer_key: Record<string, unknown>
}
const sentTo = (id: string) => server.callsTo('PUT', `${A}/exercises/${id}`).at(-1)?.body as Sent

async function open(id: string): Promise<void> {
  renderApp(`${EDIT}/${id}`)
  await screen.findByRole('heading', { name: 'Edit exercise' })
}

async function save(): Promise<void> {
  await userEvent.click(screen.getByRole('button', { name: 'Save' }))
}

beforeEach(() => {
  withStoredSession()
  stored = lessonExercises()
  server = new FakeServer()
    .install()
    .on('GET', `${A}/me`, { body: { email: 'admin@example.com' } })
    .on('GET', `${A}/courses/course-1/tree`, { body: courseTree() })
    .on('GET', LIST, () => ({ body: { exercises: stored } }))
  for (const e of stored) acceptsSaves(e.id)
})

describe('the page', () => {
  it('names the course and lesson, and its type, which cannot be changed', async () => {
    await open('ex-mc')

    const crumbs = screen.getByRole('navigation', { name: 'Breadcrumb' })
    expect(within(crumbs).getByRole('link', { name: 'Amharic' })).toBeInTheDocument()
    expect(within(crumbs).getByRole('link', { name: 'Hello' })).toHaveAttribute(
      'href',
      '/courses/course-1?open=lesson-1',
    )
    expect(screen.getAllByText('Multiple choice').length).toBeGreaterThan(0)
    // Nothing on the page offers another type.
    expect(screen.queryByRole('combobox')).not.toBeInTheDocument()
    expect(screen.queryByRole('link', { name: /Listening/ })).not.toBeInTheDocument()
  })

  it('says when there are unsaved changes, and when they are saved', async () => {
    await open('ex-mc')
    expect(screen.getByRole('status')).toHaveTextContent('All changes saved')

    await userEvent.type(screen.getByLabelText('Prompt'), '!')
    expect(screen.getByText('Unsaved changes')).toBeInTheDocument()

    await save()
    expect(await screen.findByRole('status')).toHaveTextContent('Saved')
    expect(sentTo('ex-mc').prompt).toBe(`${MC.prompt}!`)
  })

  it('shows what the server saved, not what was typed', async () => {
    server.on('PUT', `${A}/exercises/ex-mc`, (call) => ({
      body: { ...(call.body as object), prompt: 'Trimmed by the server', id: 'ex-mc', lesson_id: 'lesson-1', order_index: 1, vocab_item_id: null },
    }))
    await open('ex-mc')

    await userEvent.type(screen.getByLabelText('Prompt'), '   ')
    await save()

    await waitFor(() => expect(screen.getByLabelText('Prompt')).toHaveValue('Trimmed by the server'))
  })

  it('says so for an exercise that is not in the lesson', async () => {
    renderApp(`${EDIT}/nope`)
    expect(await screen.findByRole('alert')).toHaveTextContent('This exercise does not exist')
  })
})

describe('choices', () => {
  it('the correct answer is set by marking a choice, not by typing an id', async () => {
    await open('ex-mc')

    await userEvent.click(screen.getByRole('radio', { name: 'Choice 3 is correct' }))
    await save()

    await waitFor(() => expect(sentTo('ex-mc').answer_key).toEqual({ correct_choice_id: 'c' }))
    expect(sentTo('ex-mc').content).toEqual(MC.content)
  })

  it('removing the correct choice blocks saving until another is marked', async () => {
    await open('ex-mc')

    await userEvent.click(screen.getByRole('button', { name: 'Remove choice 1' }))

    expect(screen.getByRole('button', { name: 'Save' })).toBeDisabled()
    expect(screen.getByText('Mark which choice is correct.')).toBeInTheDocument()

    await userEvent.click(screen.getByRole('radio', { name: 'Choice 2 is correct' }))
    await save()
    await waitFor(() => expect(sentTo('ex-mc').answer_key).toEqual({ correct_choice_id: 'c' }))
    expect(sentTo('ex-mc').content).toEqual({ choices: MC.content.choices.slice(1) })
  })

  it('a new choice gets the next letter', async () => {
    await open('ex-mc')

    await userEvent.click(screen.getByRole('button', { name: 'Add choice' }))
    await userEvent.type(screen.getByLabelText('Choice 5'), 'አይ')
    await save()

    await waitFor(() => expect(sentTo('ex-mc').content).toEqual({ choices: [...MC.content.choices, { id: 'e', text: 'አይ' }] }))
  })

  it('moving a choice moves its answer with it', async () => {
    await open('ex-mc')

    await userEvent.click(screen.getByRole('button', { name: 'Move choice 1 down' }))
    await save()

    await waitFor(() => expect((sentTo('ex-mc').content.choices as Tile[]).map((c) => c.id)).toEqual(['b', 'a', 'c', 'd']))
    expect(sentTo('ex-mc').answer_key).toEqual({ correct_choice_id: 'a' })
  })

  it('gap fill edits the text either side of the gap', async () => {
    await open('ex-gap')

    await userEvent.type(screen.getByLabelText('Text before the gap'), 'እኔ')
    await save()

    await waitFor(() =>
      expect(sentTo('ex-gap').content).toEqual({ ...GAP.content, sentence_before: 'እኔ' }),
    )
  })

  it('listening plays its clip from the backend, and a checked link replaces it', async () => {
    server.on('POST', `${A}/audio/links`, (call: Call) => ({
      body: { url: (call.body as { url: string }).url.trim(), content_type: 'audio/mp4' },
    }))
    await open('ex-listening')

    expect(screen.getByLabelText('Play the clip')).toHaveAttribute('src', `${API_BASE_URL}/media/audio/am/hello.m4a`)

    await userEvent.click(screen.getByRole('tab', { name: 'Link' }))
    await userEvent.type(screen.getByLabelText('Audio link'), 'https://cdn.example/hello.m4a')
    await userEvent.click(screen.getByRole('button', { name: 'Check link' }))
    await save()

    await waitFor(() =>
      expect(sentTo('ex-listening').content).toEqual({ ...LISTENING.content, audio_url: 'https://cdn.example/hello.m4a' }),
    )
  })
})

describe('building an answer from tiles', () => {
  it('records tiles in the order they are clicked, the same letter twice as two tiles', async () => {
    await open('ex-spell')
    const answer = screen.getByRole('list', { name: 'Correct answer' })

    for (let i = 0; i < 4; i++) await userEvent.click(within(answer).getByRole('button', { name: 'Remove answer 1' }))
    // Place ሰ, then the *second* ላ tile, then the first, then ም.
    await userEvent.click(screen.getByRole('button', { name: 'Add letter 1 to the answer' }))
    await userEvent.click(screen.getByRole('button', { name: 'Add letter 4 to the answer' }))
    await userEvent.click(screen.getByRole('button', { name: 'Add letter 2 to the answer' }))
    await userEvent.click(screen.getByRole('button', { name: 'Add letter 3 to the answer' }))
    await save()

    await waitFor(() => expect(sentTo('ex-spell').answer_key).toEqual({ correct_sequence: ['t1', 't4', 't2', 't3'] }))
    expect(sentTo('ex-spell').content).toEqual(SPELL.content)
  })

  it('an unused word stays in the bank as a distractor, out of the answer', async () => {
    await open('ex-sentence')

    expect(screen.getByText('Distractor')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Add word 3 to the answer' })).toBeInTheDocument()
    expect(within(screen.getByRole('list', { name: 'Correct answer' })).getAllByRole('listitem')).toHaveLength(2)
  })

  it('removing a placed word from the bank takes it out of the answer too', async () => {
    await open('ex-sentence')

    await userEvent.click(screen.getByRole('button', { name: 'Remove word 1' }))
    await save()

    await waitFor(() => expect(sentTo('ex-sentence').answer_key).toEqual({ correct_sequence: ['w2'] }))
    expect(sentTo('ex-sentence').content).toEqual({ word_bank: SENTENCE.content.word_bank.slice(1) })
  })

  it('an empty answer blocks saving', async () => {
    await open('ex-sentence')

    await userEvent.click(screen.getByRole('button', { name: 'Remove answer 1' }))
    await userEvent.click(screen.getByRole('button', { name: 'Remove answer 1' }))

    expect(screen.getByRole('button', { name: 'Save' })).toBeDisabled()
    expect(screen.getByText('Build the correct answer from the tiles.')).toBeInTheDocument()
  })
})

describe('match pairs', () => {
  it('edits a row without reordering the stored right column', async () => {
    await open('ex-pairs')

    await userEvent.clear(screen.getByLabelText('Pair 1 right'))
    await userEvent.type(screen.getByLabelText('Pair 1 right'), 'Buna')
    await save()

    await waitFor(() =>
      expect(sentTo('ex-pairs').content.right_tiles).toEqual([
        { id: 'r2', text: 'Tea' },
        { id: 'r1', text: 'Buna' },
      ]),
    )
    expect(sentTo('ex-pairs').answer_key).toEqual(PAIRS.answer_key)
  })

  it('adds and removes whole rows, keeping both columns and the pairs in step', async () => {
    await open('ex-pairs')

    await userEvent.click(screen.getByRole('button', { name: 'Add pair' }))
    await userEvent.type(screen.getByLabelText('Pair 3 left'), 'ውሃ')
    await userEvent.type(screen.getByLabelText('Pair 3 right'), 'Water')
    await userEvent.click(screen.getByRole('button', { name: 'Remove pair 1' }))
    await save()

    await waitFor(() =>
      expect(sentTo('ex-pairs').content).toEqual({
        left_tiles: [
          { id: 'l2', text: 'ሻይ' },
          { id: 'l3', text: 'ውሃ' },
        ],
        right_tiles: [
          { id: 'r2', text: 'Tea' },
          { id: 'r3', text: 'Water' },
        ],
      }),
    )
    expect(sentTo('ex-pairs').answer_key).toEqual({
      correct_pairs: [
        ['l2', 'r2'],
        ['l3', 'r3'],
      ],
    })
  })
})

describe('a refused save', () => {
  it('shows the error beside the field it names, in plain words', async () => {
    server.on('PUT', `${A}/exercises/ex-mc`, {
      status: 422,
      body: {
        error_code: 'invalid_exercise',
        message: 'content.choices[1].text must be a non-empty string',
        details: { field: 'content.choices[1].text' },
      },
    })
    await open('ex-mc')

    await userEvent.clear(screen.getByLabelText('Choice 2'))
    await save()

    const error = await screen.findByRole('alert')
    expect(error).toHaveTextContent('Must be a non-empty string')
    // Under choice 2: its row and the error share one list item.
    expect(screen.getByLabelText('Choice 2').closest('[class]')!.parentElement!.parentElement).toContainElement(error)
    expect(screen.getByText('Unsaved changes')).toBeInTheDocument()
  })

  it('an error about the whole list goes under the list', async () => {
    server.on('PUT', `${A}/exercises/ex-pairs`, {
      status: 422,
      body: {
        error_code: 'invalid_exercise',
        message: 'answer_key.correct_pairs must match every left tile to one right tile, once',
        details: { field: 'answer_key.correct_pairs' },
      },
    })
    await open('ex-pairs')

    await save()

    const error = await screen.findByRole('alert')
    expect(error).toHaveTextContent('Must match every left tile to one right tile, once')
    expect(error.previousElementSibling?.tagName).toBe('OL')
  })

  it('an error naming no field shows at the top', async () => {
    server.on('PUT', `${A}/exercises/ex-mc`, {
      status: 409,
      body: { error_code: 'conflict', message: 'Someone else changed this lesson' },
    })
    await open('ex-mc')

    await save()

    expect(await screen.findByRole('alert')).toHaveTextContent('Someone else changed this lesson')
  })

  it('clears once the admin edits again', async () => {
    server.on('PUT', `${A}/exercises/ex-mc`, {
      status: 422,
      body: { error_code: 'invalid_exercise', message: 'prompt must not be empty', details: { field: 'prompt' } },
    })
    await open('ex-mc')
    await save()
    await screen.findByRole('alert')

    await userEvent.type(screen.getByLabelText('Prompt'), '?')

    expect(screen.queryByRole('alert')).not.toBeInTheDocument()
  })
})

describe('a new exercise', () => {
  it('is created with the type chosen for it, then opened for editing', async () => {
    server.on('POST', LIST, (call) => {
      const created = { ...(call.body as object), id: 'ex-new', lesson_id: 'lesson-1', order_index: 7, vocab_item_id: null }
      stored = [...stored, created as AdminExercise]
      return { status: 201, body: created }
    })
    renderApp(`${EDIT}/new/multiple_choice`)
    await screen.findByRole('heading', { name: 'New exercise' })
    expect(screen.getByText('Not created yet')).toBeInTheDocument()

    await userEvent.type(screen.getByLabelText('Prompt'), 'Which is “yes”?')
    await userEvent.type(screen.getByLabelText('Choice 1'), 'አዎ')
    await userEvent.type(screen.getByLabelText('Choice 2'), 'አይ')
    await userEvent.click(screen.getByRole('radio', { name: 'Choice 1 is correct' }))
    await userEvent.click(screen.getByRole('button', { name: 'Create exercise' }))

    expect(await screen.findByRole('heading', { name: 'Edit exercise' })).toBeInTheDocument()
    expect(server.callsTo('POST', LIST)[0]!.body).toEqual({
      type: 'multiple_choice',
      prompt: 'Which is “yes”?',
      content: {
        choices: [
          { id: 'a', text: 'አዎ' },
          { id: 'b', text: 'አይ' },
        ],
      },
      answer_key: { correct_choice_id: 'a' },
    })
    expect(screen.getByLabelText('Prompt')).toHaveValue('Which is “yes”?')
    expect(screen.getByRole('status')).toHaveTextContent('Saved')
  })

  it.each([
    ['listening', 'Audio link'],
    ['gap_fill', 'Text before the gap'],
    ['sentence_construction', 'Word 1'],
    ['spell_tiles', 'Letter 2'],
    ['match_pairs', 'Pair 2 right'],
  ])('%s starts with its own fields', async (type, label) => {
    renderApp(`${EDIT}/new/${type}`)
    expect(await screen.findByLabelText(label)).toHaveValue('')
  })

  it('an unknown type is refused', async () => {
    renderApp(`${EDIT}/new/essay`)
    expect(await screen.findByRole('alert')).toHaveTextContent('There is no such exercise type.')
  })
})

describe('the learner preview', () => {
  const preview = () => within(screen.getByRole('region', { name: 'Learner preview' }))

  it('highlights the correct choice, and follows the form live', async () => {
    await open('ex-mc')

    const correct = () => preview().getByText('(correct)').closest('li')
    expect(correct()).toHaveTextContent('ሰላም')

    await userEvent.click(screen.getByRole('radio', { name: 'Choice 4 is correct' }))
    expect(correct()).toHaveTextContent('አዎ')
  })

  it('plays a listening clip from the backend', async () => {
    await open('ex-listening')
    expect(preview().getByLabelText('Clip the learner hears')).toHaveAttribute(
      'src',
      `${API_BASE_URL}/media/audio/am/hello.m4a`,
    )
    expect(preview().getByText('(correct)').closest('li')).toHaveTextContent('Goodbye')
  })

  it('fills the gap with the correct choice', async () => {
    await open('ex-gap')
    expect(preview().getByText('ደህና', { selector: 'p > span' })).toBeInTheDocument()
  })

  it('shows the answer in order, and marks distractors', async () => {
    await open('ex-sentence')
    const order = preview().getByRole('list', { name: 'Correct order' })
    expect(within(order).getAllByRole('listitem').map((li) => li.textContent)).toEqual(['ደህና', 'ነኝ'])
    expect(preview().getByText('(distractor)').closest('li')).toHaveTextContent('ጥሩ')
  })

  it('numbers each pair on both sides', async () => {
    await open('ex-pairs')
    const left = within(preview().getByRole('list', { name: 'Left column' }))
    const right = within(preview().getByRole('list', { name: 'Right column' }))
    expect(left.getByText('ቡና').closest('li')).toHaveTextContent('1')
    expect(right.getByText('Coffee').closest('li')).toHaveTextContent('1')
    expect(right.getByText('Tea').closest('li')).toHaveTextContent('2')
  })
})
