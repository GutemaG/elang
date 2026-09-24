// The load-bearing test of bolt 038 (story 003's first criterion), written
// before the rest: every exercise the seed creates is opened in the real
// editor page and saved unchanged, and the server must receive exactly what
// it stored. The data is the backend's own seed, exported by
// backend/scripts/export_exercise_fixtures.py.

import { screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import seeded from '../test/data/seeded-exercises.json'
import { FakeServer } from '../test/fakeServer'
import { courseTree } from '../test/fixtures'
import { renderApp, withStoredSession } from '../test/renderApp'
import type { AdminExercise, ExerciseBody } from '../types'

vi.mock('../auth/GoogleButton', () => ({ GoogleButton: () => null }))

type Seeded = ExerciseBody & { id: string }

const EXERCISES = seeded as unknown as Seeded[]
const LESSON = 'lesson-1'
const LIST = `/api/v1/admin/lessons/${LESSON}/exercises`

let server: FakeServer

beforeEach(() => {
  withStoredSession()
  const stored = EXERCISES.map(
    (e, i): AdminExercise => ({
      ...structuredClone(e),
      lesson_id: LESSON,
      order_index: i + 1,
      vocab_item_id: null,
    }),
  )
  server = new FakeServer()
    .install()
    .on('GET', '/api/v1/admin/me', { body: { email: 'admin@example.com' } })
    .on('GET', '/api/v1/admin/courses/course-1/tree', { body: courseTree() })
    .on('GET', LIST, { body: { exercises: stored } })
})

describe('the seed export', () => {
  it('holds every exercise type', () => {
    const types = new Set(EXERCISES.map((e) => e.type))
    expect([...types].sort()).toEqual(
      ['gap_fill', 'listening', 'match_pairs', 'multiple_choice', 'sentence_construction', 'spell_tiles'].sort(),
    )
    expect(EXERCISES.length).toBeGreaterThan(100)
  })
})

describe('every seeded exercise, opened and saved unchanged', () => {
  it.each(EXERCISES.map((e) => [`${e.type} ${e.id.slice(0, 8)}: ${e.prompt}`, e] as const))(
    '%s',
    async (_name, exercise) => {
      const path = `/api/v1/admin/exercises/${exercise.id}`
      server.on('PUT', path, (call) => ({ body: { ...(call.body as object), id: exercise.id } }))
      renderApp(`/courses/course-1/lessons/${LESSON}/exercises/${exercise.id}`)

      await userEvent.click(await screen.findByRole('button', { name: 'Save' }))

      await waitFor(() => expect(server.callsTo('PUT', path)).toHaveLength(1))
      const { type, prompt, content, answer_key } = exercise
      expect(server.callsTo('PUT', path)[0]!.body).toEqual({ type, prompt, content, answer_key })
    },
  )
})
