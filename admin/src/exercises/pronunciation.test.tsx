// Romanization in the exercise editor: each choice, word, letter and pair
// tile can carry its pronunciation in Latin letters, and so can the
// question's own word or sentence. Every field is optional: left empty, no
// key is stored, so an exercise saved without any goes back unchanged.

import { screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import { FakeServer, type Call } from '../test/fakeServer'
import { GAP, MC, PAIRS, SENTENCE, lessonExercises } from '../test/exercises'
import { courseTree } from '../test/fixtures'
import { renderApp, withStoredSession } from '../test/renderApp'
import type { AdminExercise, ExerciseBody } from '../types'
import {
  isPronouncedBody,
  placeError,
  setChoicePronunciation,
  setPairPronunciation,
  setPronunciation,
  setTilePronunciation,
  type ChoiceBody,
  type PairsBody,
  type SequenceBody,
} from './model'

vi.mock('../auth/GoogleButton', () => ({ GoogleButton: () => null }))

describe('the model', () => {
  it('sets a pronunciation on a choice, a tile, a pair side and the question', () => {
    const mc = setChoicePronunciation(MC as ChoiceBody, 0, 'selam')
    const sentence = setTilePronunciation(SENTENCE as Extract<SequenceBody, { type: 'sentence_construction' }>, 1, 'negn')
    const pairs = setPairPronunciation(PAIRS as PairsBody, 0, 'left', 'selam')
    const asked = setPronunciation(GAP as Extract<ExerciseBody, { type: 'gap_fill' }>, '___ negn')

    expect(mc.content.choices[0]).toEqual({ id: 'a', text: 'ሰላም', pronunciation: 'selam' })
    expect(mc.content.choices[1]).toEqual(MC.content.choices[1])
    expect(sentence.content.word_bank[1]).toEqual({ id: 'w2', text: 'ነኝ', pronunciation: 'negn' })
    const leftId = PAIRS.answer_key.correct_pairs[0]![0]
    expect(pairs.content.left_tiles.find((t) => t.id === leftId)?.pronunciation).toBe('selam')
    expect(asked.content.pronunciation).toBe('___ negn')
  })

  it('takes the key away when the field is emptied, leaving the stored shape', () => {
    const set = setChoicePronunciation(MC as ChoiceBody, 0, 'selam')
    const cleared = setChoicePronunciation(set, 0, '')
    const gap = GAP as Extract<ExerciseBody, { type: 'gap_fill' }>
    const question = setPronunciation(setPronunciation(gap, 'x'), '')

    expect(cleared).toEqual(MC)
    expect(JSON.stringify(cleared)).toBe(JSON.stringify(MC))
    expect(question).toEqual(GAP)
  })

  it('offers a question pronunciation only on questions that are read', () => {
    expect(isPronouncedBody(MC)).toBe(true)
    expect(isPronouncedBody({ ...MC, type: 'listening', content: { audio_url: '', choices: [] } })).toBe(false)
  })

  it("places the server's errors beside the right field", () => {
    expect(placeError('content.pronunciation', 'must be a non-empty string', MC)).toBe('pronunciation')
    expect(placeError('content.choices[2].pronunciation', 'must be a non-empty string', MC)).toBe('choice:2')
    expect(placeError('content.word_bank[1].pronunciation', 'x', SENTENCE)).toBe('tile:1')
  })
})

const A = '/api/v1/admin'
const EDIT = '/courses/course-1/lessons/lesson-1/exercises'

let server: FakeServer
let stored: AdminExercise[]

interface Sent {
  content: Record<string, unknown>
}
const sentTo = (id: string) => server.callsTo('PUT', `${A}/exercises/${id}`).at(-1)?.body as Sent

async function open(id: string): Promise<void> {
  renderApp(`${EDIT}/${id}`)
  await screen.findByRole('heading', { name: 'Edit exercise' })
}

beforeEach(() => {
  withStoredSession()
  stored = lessonExercises()
  server = new FakeServer()
    .install()
    .on('GET', `${A}/me`, { body: { email: 'admin@example.com' } })
    .on('GET', `${A}/courses/course-1/tree`, { body: { ...courseTree() } })
    .on('GET', `${A}/lessons/lesson-1/exercises`, () => ({ body: { exercises: stored } }))
  for (const e of stored) {
    server.on('PUT', `${A}/exercises/${e.id}`, (call: Call) => ({
      body: { ...(call.body as object), id: e.id, lesson_id: 'lesson-1', order_index: 1, vocab_item_id: null },
    }))
  }
})

describe('the editor', () => {
  it("saves a choice's pronunciation and the question's, and previews them", async () => {
    await open('ex-mc')

    await userEvent.type(screen.getByLabelText('Choice 1 pronunciation'), 'selam')
    await userEvent.type(screen.getByLabelText('Pronunciation of the word or sentence in the prompt'), 'hello')
    expect(screen.getByRole('region', { name: 'Learner preview' })).toHaveTextContent('selam')
    await userEvent.click(screen.getByRole('button', { name: 'Save' }))

    const sent = sentTo('ex-mc')
    expect(sent.content.pronunciation).toBe('hello')
    expect((sent.content.choices as { pronunciation?: string }[])[0]?.pronunciation).toBe('selam')
    expect('pronunciation' in (sent.content.choices as object[])[1]!).toBe(false)
  })

  it('has no question pronunciation on a listening question', async () => {
    await open('ex-listening')

    expect(screen.queryByLabelText('Pronunciation of the word or sentence in the prompt')).not.toBeInTheDocument()
    expect(screen.getByLabelText('Choice 1 pronunciation')).toBeInTheDocument()
  })

  it("puts a gap fill's pronunciation with its sentence", async () => {
    await open('ex-gap')

    expect(screen.queryByLabelText('Pronunciation of the word or sentence in the prompt')).not.toBeInTheDocument()
    await userEvent.type(screen.getByLabelText('Pronunciation of the sentence'), '___ negn')
    await userEvent.click(screen.getByRole('button', { name: 'Save' }))

    expect(sentTo('ex-gap').content.pronunciation).toBe('___ negn')
  })

  it('saves word-bank pronunciations', async () => {
    await open('ex-sentence')
    await userEvent.type(screen.getByLabelText('Word 1 pronunciation'), 'dehna')
    await userEvent.click(screen.getByRole('button', { name: 'Save' }))
    expect((sentTo('ex-sentence').content.word_bank as { pronunciation?: string }[])[0]?.pronunciation).toBe('dehna')
  })

  it('saves an exercise opened and saved with no pronunciations exactly as it was', async () => {
    await open('ex-pairs')
    await userEvent.type(screen.getByLabelText('Pair 1 left pronunciation'), 'x')
    await userEvent.clear(screen.getByLabelText('Pair 1 left pronunciation'))
    await userEvent.type(screen.getByLabelText('Prompt'), '!')
    await userEvent.click(screen.getByRole('button', { name: 'Save' }))

    expect(sentTo('ex-pairs').content).toEqual(PAIRS.content)
  })
})
