// The JSON file for importing and exporting a lesson's exercises (bolt
// 056): the stored shape, exactly. Import takes either a list of exercises
// or an export file; nothing is shuffled and ids are kept. Keys an export
// adds (`id`, `order_index`…) are left out of what is sent.

import type { AdminExercise, ExerciseBody } from '../types'
import type { ImportRow, ReadResult } from './fromCsv'

export const FORMAT = 'buna-exercises'

export interface ExportFile {
  format: typeof FORMAT
  version: 1
  lesson: string
  exercises: ExerciseBody[]
}

const isObject = (value: unknown): value is Record<string, unknown> =>
  typeof value === 'object' && value !== null && !Array.isArray(value)

export function readJson(text: string): ReadResult {
  const fail = (error: string): ReadResult => ({ rows: [], error })
  let data: unknown
  try {
    data = JSON.parse(text.replace(/^\uFEFF/, ''))
  } catch (e) {
    return fail(`This isn't valid JSON: ${e instanceof Error ? e.message : String(e)}`)
  }
  const list = Array.isArray(data) ? data : isObject(data) ? data.exercises : undefined
  if (!Array.isArray(list)) return fail('Expected a list of exercises, or an exported file with an "exercises" list.')
  if (list.length === 0) return fail('There are no exercises in the file.')
  return {
    rows: list.map((item, i) => itemToRow(item, `Exercise ${i + 1}`)),
    error: null,
  }
}

function itemToRow(item: unknown, label: string): ImportRow {
  const problem = (text: string): ImportRow => ({
    label,
    body: null,
    problem: text,
  })
  if (!isObject(item)) return problem('Each exercise must be an object.')
  if (typeof item.type !== 'string') return problem('"type" must be text.')
  if (typeof item.prompt !== 'string') return problem('"prompt" must be text.')
  if (!isObject(item.content)) return problem('"content" must be an object.')
  if (!isObject(item.answer_key)) return problem('"answer_key" must be an object.')
  // The type and the parts inside are the server's to judge, row by row.
  const body = {
    type: item.type,
    prompt: item.prompt,
    content: item.content,
    answer_key: item.answer_key,
  }
  return { label, body: body as unknown as ExerciseBody, problem: null }
}

export function exercisesToJson(lesson: string, exercises: readonly AdminExercise[]): string {
  const file: ExportFile = {
    format: FORMAT,
    version: 1,
    lesson,
    exercises: exercises.map(
      ({ type, prompt, content, answer_key }) => ({ type, prompt, content, answer_key }) as ExerciseBody,
    ),
  }
  return JSON.stringify(file, null, 2) + '\n'
}
