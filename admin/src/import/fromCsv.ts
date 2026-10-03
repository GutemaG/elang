// CSV rows to exercises (bolt 056). Each row becomes the stored
// `ExerciseBody`, with ids in the editor's own convention, so the server
// only ever receives whole exercises. A row that cannot become one says
// why, in the words of the spreadsheet (its row and column), and the rest
// of the file is still read.

import Papa from 'papaparse'

import { TYPE_INFO } from '../exercises/model'
import type { ExerciseBody, ExerciseType, PictureTile, Tile } from '../types'
import {
  COLUMNS,
  GAP,
  charactersOf,
  columnOf,
  seededShuffle,
  splitItems,
  typeOf,
  type Column,
  type CsvRow,
} from './csvFormat'

/** One exercise of a file: what it became, or why it could not. */
export interface ImportRow {
  /** Where it is in the file: "Row 3" (the header is row 1, as in a
   * spreadsheet) or "Exercise 3" (JSON). */
  label: string
  body: ExerciseBody | null
  problem: string | null
}

/** A whole file: its rows, or why none could be read. */
export interface ReadResult {
  rows: ImportRow[]
  error: string | null
}

export const NOT_UTF8 =
  "This file isn't saved as UTF-8, so Amharic text would be lost. In Excel choose File › Save As › CSV UTF-8, then try again."

class RowProblem extends Error {}

const LETTERS = 'abcdefghijklmnopqrstuvwxyz'

/** The columns each type reads. Anything written in another column is a
 * mistake worth hearing about, not something to drop quietly. */
const USES: Record<ExerciseType, readonly Column[]> = {
  multiple_choice: ['pronunciation', 'answer', 'answer_pronunciation', 'wrong', 'wrong_pronunciation'],
  listening: ['answer', 'answer_pronunciation', 'wrong', 'wrong_pronunciation', 'audio_url'],
  gap_fill: ['pronunciation', 'sentence', 'answer', 'answer_pronunciation', 'wrong', 'wrong_pronunciation'],
  sentence_construction: ['pronunciation', 'answer', 'answer_pronunciation', 'wrong', 'wrong_pronunciation'],
  spell_tiles: ['pronunciation', 'answer', 'answer_pronunciation', 'wrong', 'wrong_pronunciation'],
  match_pairs: ['pronunciation', 'answer', 'answer_pronunciation'],
  image_choice: ['pronunciation', 'answer', 'wrong', 'descriptions'],
  audio_image_choice: ['answer', 'wrong', 'audio_url', 'descriptions'],
}

const SEED_COLUMNS = ['type', 'prompt', 'sentence', 'answer', 'wrong', 'audio_url', 'descriptions'] as const

/** A tile with its pronunciation, when it has one: the key is left out
 * otherwise, as the editor does. */
function tile(id: string, text: string, pronunciation: string | undefined): Tile {
  return pronunciation ? { id, text, pronunciation } : { id, text }
}

/** The pronunciation of each of `count` items, by position: `cell` split
 * on `|` (an empty place is an item without one), or, for `spaced` cells
 * written without `|`, on spaces. Empty: none at all. */
function pronunciations(row: CsvRow, column: Column, count: number, { spaced = false } = {}): (string | undefined)[] {
  const cell = row[column]
  if (!cell.trim()) return []
  const items = cell.includes('|') || !spaced ? splitItems(cell, { keepEmpty: true }) : cell.trim().split(/\s+/)
  if (items.length > count)
    throw new RowProblem(`"${column}" has ${items.length} pronunciations but there are ${count} items to go with them.`)
  return items.map((item) => item || undefined)
}

/** The question's own pronunciation, in `content`, when there is one. */
function withQuestion<B extends ExerciseBody>(body: B, row: CsvRow): B {
  const spoken = row.pronunciation.trim()
  return spoken ? ({ ...body, content: { ...body.content, pronunciation: spoken } } as B) : body
}

export function readCsv(text: string): ReadResult {
  const fail = (error: string): ReadResult => ({ rows: [], error })
  if (text.includes('\uFFFD')) return fail(NOT_UTF8)

  const parsed = Papa.parse<string[]>(text.replace(/^\uFEFF/, ''), {
    skipEmptyLines: false,
  })
  const broken = parsed.errors.find((e) => e.type === 'Quotes')
  if (broken) return fail(`Row ${(broken.row ?? 0) + 1}: a quoted cell is never closed.`)
  const [header = [], ...records] = parsed.data

  const columns: (Column | null)[] = []
  for (const name of header) {
    if (!name.trim()) {
      columns.push(null)
      continue
    }
    const column = columnOf(name)
    if (!column) return fail(`Unknown column "${name.trim()}". The columns are: ${COLUMNS.join(', ')}.`)
    if (columns.includes(column)) return fail(`The column "${column}" appears twice.`)
    columns.push(column)
  }
  if (columns.every((c) => c === null)) return fail('The file is empty.')
  for (const needed of ['type', 'prompt', 'answer'] as const) {
    if (!columns.includes(needed)) return fail(`The file needs a "${needed}" column.`)
  }

  const rows: ImportRow[] = []
  records.forEach((cells, i) => {
    if (cells.every((cell) => !cell.trim())) return
    const row = Object.fromEntries(COLUMNS.map((c) => [c, ''])) as CsvRow
    columns.forEach((column, at) => {
      if (column) row[column] = cells[at] ?? ''
    })
    const label = `Row ${i + 2}`
    try {
      rows.push({ label, body: rowToBody(row), problem: null })
    } catch (e) {
      if (!(e instanceof RowProblem)) throw e
      rows.push({ label, body: null, problem: e.message })
    }
  })
  if (rows.length === 0) return fail('There are no exercises in the file, only its header.')
  return { rows, error: null }
}

/** One row as an exercise, or a `RowProblem` saying what to fix. */
export function rowToBody(row: CsvRow): ExerciseBody {
  if (!row.type.trim()) throw new RowProblem('Add a type.')
  const type = typeOf(row.type)
  if (!type) throw new RowProblem(`Unknown type "${row.type.trim()}".`)
  const prompt = row.prompt.trim()
  if (!prompt) throw new RowProblem('Add a prompt.')
  for (const column of [
    'pronunciation',
    'sentence',
    'answer_pronunciation',
    'wrong',
    'wrong_pronunciation',
    'audio_url',
    'descriptions',
  ] as const) {
    if (row[column].trim() && !USES[type].includes(column))
      throw new RowProblem(`${TYPE_INFO[type].name} doesn't use "${column}"; leave it empty.`)
  }
  // Every cell but the pronunciations, so a change anywhere else in the row
  // may reorder its choices, and nothing outside the row does. Adding
  // pronunciations to a file keeps its order.
  const seed = SEED_COLUMNS.map((c) => row[c]).join('\u0000')
  return withQuestion(bodyOfType(type, prompt, row, seed), row)
}

function bodyOfType(type: ExerciseType, prompt: string, row: CsvRow, seed: string): ExerciseBody {
  switch (type) {
    case 'multiple_choice':
      return { type, prompt, ...choices(row, seed) }
    case 'listening': {
      const { content, answer_key } = choices(row, seed)
      return {
        type,
        prompt,
        content: { audio_url: audioUrl(row), ...content },
        answer_key,
      }
    }
    case 'gap_fill': {
      const { content, answer_key } = choices(row, seed)
      const parts = row.sentence.split(GAP)
      if (parts.length !== 2) throw new RowProblem('Mark the gap in "sentence" with ___, once.')
      const [before = '', after = ''] = parts.map((part) => part.trim())
      return {
        type,
        prompt,
        content: { sentence_before: before, sentence_after: after, ...content },
        answer_key,
      }
    }
    case 'sentence_construction': {
      const words = row.answer.includes('|') ? splitItems(row.answer) : row.answer.trim().split(/\s+/).filter(Boolean)
      const { tiles, sequence } = sequenceTiles(words, row, 'w', seed, { spaced: true })
      return {
        type,
        prompt,
        content: { word_bank: tiles },
        answer_key: { correct_sequence: sequence },
      }
    }
    case 'spell_tiles': {
      const letters = row.answer.includes('|') ? splitItems(row.answer) : charactersOf(row.answer)
      const { tiles, sequence } = sequenceTiles(letters, row, 't', seed, { spaced: true })
      return {
        type,
        prompt,
        content: { tiles },
        answer_key: { correct_sequence: sequence },
      }
    }
    case 'match_pairs':
      return { type, prompt, ...pairs(row) }
    case 'image_choice':
      return { type, prompt, ...pictures(row, seed) }
    case 'audio_image_choice': {
      const { content, answer_key } = pictures(row, seed)
      return {
        type,
        prompt,
        content: { audio_url: audioUrl(row), ...content },
        answer_key,
      }
    }
  }
}

function audioUrl(row: CsvRow): string {
  const url = row.audio_url.trim()
  if (!url) throw new RowProblem('Add the clip\'s address in "audio_url".')
  return url
}

/** The one answer and the wrong ones, which must not include it. */
function answerAndWrong(row: CsvRow, what: string): [string, string[]] {
  const answer = splitItems(row.answer)
  if (answer.length === 0) throw new RowProblem(`Add the ${what} in "answer".`)
  if (answer.length > 1) throw new RowProblem(`"answer" holds one ${what}; put the others in "wrong".`)
  const one = answer[0]!
  const wrong = splitItems(row.wrong)
  if (wrong.length === 0) throw new RowProblem(`Add at least one wrong ${what} in "wrong".`)
  if (wrong.includes(one)) throw new RowProblem(`The answer is in "wrong" too.`)
  return [one, wrong]
}

function lettered<T>(items: readonly T[]): (T & { id: string })[] {
  if (items.length > LETTERS.length) throw new RowProblem(`At most ${LETTERS.length} choices.`)
  return items.map((item, i) => ({ ...item, id: LETTERS.charAt(i) }))
}

function choices(
  row: CsvRow,
  seed: string,
): { content: { choices: Tile[] }; answer_key: { correct_choice_id: string } } {
  const [answer, wrong] = answerAndWrong(row, 'choice')
  // The answer is one choice, so its pronunciation is the whole cell.
  const answerSpoken = row.answer_pronunciation.trim() || undefined
  const wrongSpoken = pronunciations(row, 'wrong_pronunciation', wrong.length)
  const items = [
    { text: answer, spoken: answerSpoken },
    ...wrong.map((text, i) => ({ text, spoken: wrongSpoken[i] })),
  ]
  // Shuffled by text alone, so adding pronunciations never reorders them.
  const order = seededShuffle(
    items.map((_, i) => i),
    seed,
  )
  const shuffled = lettered(order.map((i) => items[i]!))
  return {
    content: { choices: shuffled.map(({ id, text, spoken }) => tile(id, text, spoken)) },
    answer_key: {
      correct_choice_id: shuffled.find((c) => c.text === answer)!.id,
    },
  }
}

function pictures(
  row: CsvRow,
  seed: string,
): {
  content: { choices: PictureTile[] }
  answer_key: { correct_choice_id: string }
} {
  const [answer, wrong] = answerAndWrong(row, 'picture address')
  const urls = [answer, ...wrong]
  const descriptions = splitItems(row.descriptions, { keepEmpty: true })
  if (descriptions.length > urls.length)
    throw new RowProblem(`There are ${descriptions.length} descriptions but ${urls.length} pictures.`)
  const shuffled = lettered(
    seededShuffle(
      urls.map((image_url, i) => ({
        image_url,
        alt_text: descriptions[i] ?? '',
      })),
      seed,
    ),
  )
  return {
    content: {
      choices: shuffled.map(({ id, image_url, alt_text }) => ({
        id,
        image_url,
        alt_text,
      })),
    },
    answer_key: {
      correct_choice_id: shuffled.find((p) => p.image_url === answer)!.id,
    },
  }
}

/** The answer's tiles in order plus the extra ones, shuffled together and
 * numbered (`w1`, `w2`…); the answer is their ids in the answer's order. */
function sequenceTiles(
  answer: string[],
  row: CsvRow,
  prefix: string,
  seed: string,
  { spaced = false } = {},
): { tiles: Tile[]; sequence: string[] } {
  if (answer.length === 0) throw new RowProblem('Add the answer in "answer".')
  const wrong = splitItems(row.wrong)
  const spoken = [
    ...padded(pronunciations(row, 'answer_pronunciation', answer.length, { spaced }), answer.length),
    ...pronunciations(row, 'wrong_pronunciation', wrong.length),
  ]
  const all = [...answer, ...wrong].map((text, at) => ({
    text,
    at,
  }))
  const tiles = seededShuffle(all, seed).map((tile, i) => ({
    ...tile,
    id: `${prefix}${i + 1}`,
  }))
  const idOf = new Map(tiles.map((tile) => [tile.at, tile.id]))
  return {
    tiles: tiles.map(({ id, text, at }) => tile(id, text, spoken[at])),
    sequence: answer.map((_, at) => idOf.get(at)!),
  }
}

/** `items` made `count` long, so the next list's places line up. */
function padded<T>(items: T[], count: number): (T | undefined)[] {
  return [...items, ...Array<undefined>(count - items.length).fill(undefined)]
}

function pairs(row: CsvRow): {
  content: { left_tiles: Tile[]; right_tiles: Tile[] }
  answer_key: { correct_pairs: [string, string][] }
} {
  const items = splitItems(row.answer)
  if (items.length === 0) throw new RowProblem('Add the pairs in "answer", as left=right | left=right.')
  const split = items.map((item) => {
    const at = item.indexOf('=')
    const [left, right] = at < 0 ? ['', ''] : [item.slice(0, at).trim(), item.slice(at + 1).trim()]
    if (!left || !right) throw new RowProblem(`Write each pair as left=right, not "${item}".`)
    return [left, right] as const
  })
  // One `left=right` per pair, either side may be empty: `selam= | bunna=`.
  const spoken = pronunciations(row, 'answer_pronunciation', split.length).map((item) => {
    if (!item) return [undefined, undefined] as const
    const at = item.indexOf('=')
    if (at < 0) throw new RowProblem(`Write each pair's pronunciations as left=right, not "${item}".`)
    return [item.slice(0, at).trim() || undefined, item.slice(at + 1).trim() || undefined] as const
  })
  // In order: the app shuffles each column itself.
  return {
    content: {
      left_tiles: split.map(([text], i) => tile(`l${i + 1}`, text, spoken[i]?.[0])),
      right_tiles: split.map(([, text], i) => tile(`r${i + 1}`, text, spoken[i]?.[1])),
    },
    answer_key: {
      correct_pairs: split.map((_, i) => [`l${i + 1}`, `r${i + 1}`]),
    },
  }
}
