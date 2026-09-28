import { describe, expect, it } from 'vitest'

import { MC, PAIRS } from '../test/exercises'
import { lessonExercises } from '../test/exercises'
import { fileName } from './download'
import { readCsv } from './fromCsv'
import { exercisesToJson, readJson } from './json'
import { EXAMPLES, csvTemplate, jsonExample } from './templates'

describe('reading a JSON file', () => {
  it('takes a list of stored exercises exactly', () => {
    const { rows, error } = readJson(JSON.stringify([MC, PAIRS]))

    expect(error).toBeNull()
    expect(rows.map((r) => r.label)).toEqual(['Exercise 1', 'Exercise 2'])
    expect(rows.map((r) => r.body)).toEqual([MC, PAIRS])
  })

  it('takes an exported file, leaving out the keys only an export has', () => {
    const exercises = lessonExercises()
    const { rows } = readJson(exercisesToJson('Hello', exercises))

    expect(rows.map((r) => r.body)).toEqual(
      exercises.map(({ type, prompt, content, answer_key }) => ({ type, prompt, content, answer_key })),
    )
    expect(rows.every((r) => r.problem === null)).toBe(true)
  })

  it('drops keys like id and order_index from a list too', () => {
    const [stored] = lessonExercises()
    expect(readJson(JSON.stringify([stored])).rows[0]!.body).not.toHaveProperty('id')
  })

  it.each([
    ['{', /^This isn't valid JSON: /],
    ['{"exercises": 3}', /^Expected a list of exercises/],
    ['"hello"', /^Expected a list of exercises/],
    ['[]', /^There are no exercises in the file\.$/],
  ])('refuses %s', (text, error) => {
    const result = readJson(text)
    expect(result.rows).toEqual([])
    expect(result.error).toMatch(error)
  })

  it.each([
    [3, 'Each exercise must be an object.'],
    [{ ...MC, type: 1 }, '"type" must be text.'],
    [{ ...MC, prompt: null }, '"prompt" must be text.'],
    [{ ...MC, content: [] }, '"content" must be an object.'],
    [{ type: 'multiple_choice', prompt: 'x', content: {} }, '"answer_key" must be an object.'],
  ])('says what is wrong with an exercise: %j', (item, problem) => {
    const { rows } = readJson(JSON.stringify([MC, item]))
    expect(rows[0]!.problem).toBeNull()
    expect(rows[1]).toEqual({ label: 'Exercise 2', body: null, problem })
  })

  it('leaves an unknown type for the server to judge', () => {
    const { rows } = readJson(JSON.stringify([{ ...MC, type: 'essay' }]))
    expect(rows[0]!.problem).toBeNull()
  })
})

describe('the export file', () => {
  it('names its format, version and lesson', () => {
    const file = JSON.parse(exercisesToJson('Hello', lessonExercises())) as Record<string, unknown>
    expect(file).toMatchObject({ format: 'buna-exercises', version: 1, lesson: 'Hello' })
  })

  it('is named after the lesson', () => {
    expect(fileName('Hello, world!', '-exercises.csv')).toBe('Hello-world-exercises.csv')
    expect(fileName('ሰላምታ 1', '.json')).toBe('ሰላምታ-1.json')
    expect(fileName(' ?? ', '.json')).toBe('lesson.json')
  })
})

describe('the templates', () => {
  it('have one example of every type, and the CSV reads without a problem', () => {
    const { rows, error } = readCsv(csvTemplate())

    expect(error).toBeNull()
    expect(rows).toHaveLength(8)
    expect(new Set(rows.map((r) => r.body?.type)).size).toBe(8)
    expect(rows.every((r) => r.problem === null)).toBe(true)
    expect(rows.map((r) => r.body?.type)).toEqual(EXAMPLES.map((e) => e.type))
  })

  it('give the same exercises in JSON as in CSV', () => {
    const json = readJson(jsonExample())
    expect(json.error).toBeNull()
    expect(json.rows.map((r) => r.body)).toEqual(readCsv(csvTemplate()).rows.map((r) => r.body))
  })
})
