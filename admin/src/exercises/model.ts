// The exercise being edited, and every change a form can make to it.
//
// The draft *is* the stored shape (`ExerciseBody`): the forms never convert
// an exercise into some friendlier structure and back. Each change below
// copies only the part it touches and leaves every id, list order and key
// alone, so an exercise opened and saved unchanged goes back exactly as the
// server sent it (story 003's first criterion). Pure functions, no React.

import { API_BASE_URL } from '../config'
import type { AdminExercise, ExerciseBody, ExerciseType, Tile } from '../types'

export type ChoiceBody = Extract<ExerciseBody, { content: { choices: Tile[] } }>
export type SequenceBody = Extract<ExerciseBody, { answer_key: { correct_sequence: string[] } }>
export type PairsBody = Extract<ExerciseBody, { type: 'match_pairs' }>

export const TYPE_INFO: Record<ExerciseType, { name: string; icon: string; description: string }> = {
  multiple_choice: {
    name: 'Multiple choice',
    icon: 'checklist',
    description: 'A question with one correct choice.',
  },
  listening: {
    name: 'Listening',
    icon: 'headphones',
    description: 'Play a clip, then pick what was heard.',
  },
  gap_fill: {
    name: 'Gap fill',
    icon: 'space_bar',
    description: 'A sentence with a gap and choices to fill it.',
  },
  sentence_construction: {
    name: 'Sentence',
    icon: 'segment',
    description: 'Build a sentence from a bank of words.',
  },
  spell_tiles: {
    name: 'Spell tiles',
    icon: 'abc',
    description: 'Spell a word from letter tiles.',
  },
  match_pairs: {
    name: 'Match pairs',
    icon: 'join',
    description: 'Match each word to its partner.',
  },
}

export function isChoiceBody(body: ExerciseBody): body is ChoiceBody {
  return body.type === 'multiple_choice' || body.type === 'listening' || body.type === 'gap_fill'
}

export function isSequenceBody(body: ExerciseBody): body is SequenceBody {
  return body.type === 'sentence_construction' || body.type === 'spell_tiles'
}

/** The editable part of a stored exercise: a deep copy, so editing the
 * draft can never reach the copy it is compared against. */
export function bodyOf(exercise: AdminExercise): ExerciseBody {
  const { type, prompt, content, answer_key } = exercise
  return structuredClone({ type, prompt, content, answer_key } as ExerciseBody)
}

export function sameBody(a: ExerciseBody | null, b: ExerciseBody | null): boolean {
  return JSON.stringify(a) === JSON.stringify(b)
}

/** A new exercise of `type`, with the fewest tiles the server accepts. */
export function blank(type: ExerciseType): ExerciseBody {
  const choices = (): Tile[] => [
    { id: 'a', text: '' },
    { id: 'b', text: '' },
  ]
  switch (type) {
    case 'multiple_choice':
      return { type, prompt: '', content: { choices: choices() }, answer_key: { correct_choice_id: '' } }
    case 'listening':
      return {
        type,
        prompt: '',
        content: { audio_url: '', choices: choices() },
        answer_key: { correct_choice_id: '' },
      }
    case 'gap_fill':
      return {
        type,
        prompt: '',
        content: { sentence_before: '', sentence_after: '', choices: choices() },
        answer_key: { correct_choice_id: '' },
      }
    case 'sentence_construction':
      return {
        type,
        prompt: '',
        content: { word_bank: [{ id: 'w1', text: '' }] },
        answer_key: { correct_sequence: [] },
      }
    case 'spell_tiles':
      return {
        type,
        prompt: '',
        content: {
          tiles: [
            { id: 't1', text: '' },
            { id: 't2', text: '' },
          ],
        },
        answer_key: { correct_sequence: [] },
      }
    case 'match_pairs':
      return {
        type,
        prompt: '',
        content: {
          left_tiles: [
            { id: 'l1', text: '' },
            { id: 'l2', text: '' },
          ],
          right_tiles: [
            { id: 'r1', text: '' },
            { id: 'r2', text: '' },
          ],
        },
        answer_key: {
          correct_pairs: [
            ['l1', 'r1'],
            ['l2', 'r2'],
          ],
        },
      }
  }
}

// --- ids -----------------------------------------------------------------

const LETTERS = 'abcdefghijklmnopqrstuvwxyz'

/** A fresh id in the list's own convention: the next free letter for
 * lettered choices (`a`–`d` → `e`), otherwise prefix plus the next number
 * (`w4` → `w5`). `fallback` is the prefix for an empty or mixed list, or
 * `letter` for choices. Never one already in `taken`. */
export function nextId(taken: readonly string[], fallback: string): string {
  const used = new Set(taken)
  const lettered = taken.length === 0 ? fallback === 'letter' : taken.every((id) => /^[a-z]$/.test(id))
  if (lettered) {
    for (const letter of LETTERS) if (!used.has(letter)) return letter
  }
  const numbered = taken.map((id) => /^([a-z]+)(\d+)$/.exec(id))
  const prefixes = new Set(numbered.map((m) => m?.[1]))
  const shared = numbered.every(Boolean) && prefixes.size === 1 ? [...prefixes][0] : undefined
  const prefix = shared ?? (fallback === 'letter' ? 'c' : fallback)
  let n = 1
  for (const m of numbered) if (m && m[1] === prefix) n = Math.max(n, Number(m[2]) + 1)
  while (used.has(`${prefix}${n}`)) n += 1
  return `${prefix}${n}`
}

// --- shared text fields ----------------------------------------------------

export function setPrompt<B extends ExerciseBody>(body: B, prompt: string): B {
  return { ...body, prompt }
}

export function setAudioUrl(body: Extract<ExerciseBody, { type: 'listening' }>, audio_url: string) {
  return { ...body, content: { ...body.content, audio_url } }
}

export function setSentence(
  body: Extract<ExerciseBody, { type: 'gap_fill' }>,
  side: 'sentence_before' | 'sentence_after',
  text: string,
) {
  return { ...body, content: { ...body.content, [side]: text } }
}

// --- choices (multiple choice, listening, gap fill) --------------------------

function withChoices<B extends ChoiceBody>(body: B, choices: Tile[], correct?: string): B {
  return {
    ...body,
    content: { ...body.content, choices },
    answer_key: correct === undefined ? body.answer_key : { ...body.answer_key, correct_choice_id: correct },
  }
}

function swap<T>(items: readonly T[], index: number, by: -1 | 1): T[] | null {
  const target = index + by
  if (index < 0 || target < 0 || index >= items.length || target >= items.length) return null
  const next = [...items]
  ;[next[index], next[target]] = [next[target]!, next[index]!]
  return next
}

export function addChoice<B extends ChoiceBody>(body: B): B {
  const ids = body.content.choices.map((c) => c.id)
  return withChoices(body, [...body.content.choices, { id: nextId(ids, 'letter'), text: '' }])
}

export function setChoiceText<B extends ChoiceBody>(body: B, index: number, text: string): B {
  return withChoices(
    body,
    body.content.choices.map((c, i) => (i === index ? { ...c, text } : c)),
  )
}

/** Removing the correct choice clears the answer: the admin must mark
 * another before the exercise can be saved. */
export function removeChoice<B extends ChoiceBody>(body: B, index: number): B {
  const removed = body.content.choices[index]
  const choices = body.content.choices.filter((_, i) => i !== index)
  const cleared = removed && removed.id === body.answer_key.correct_choice_id ? '' : undefined
  return withChoices(body, choices, cleared)
}

export function moveChoice<B extends ChoiceBody>(body: B, index: number, by: -1 | 1): B {
  const choices = swap(body.content.choices, index, by)
  return choices ? withChoices(body, choices) : body
}

export function markCorrect<B extends ChoiceBody>(body: B, choiceId: string): B {
  return withChoices(body, body.content.choices, choiceId)
}

// --- tiles and the answer sequence (sentence, spell tiles) --------------------

export function tilesOf(body: SequenceBody): Tile[] {
  return body.type === 'sentence_construction' ? body.content.word_bank : body.content.tiles
}

function withTiles<B extends SequenceBody>(body: B, tiles: Tile[], sequence?: string[]): B {
  const answer_key =
    sequence === undefined ? body.answer_key : { ...body.answer_key, correct_sequence: sequence }
  // Both branches keep the member's own content key, so TypeScript needs
  // the cast to see that B is preserved.
  return (
    body.type === 'sentence_construction'
      ? { ...body, content: { ...body.content, word_bank: tiles }, answer_key }
      : { ...body, content: { ...body.content, tiles }, answer_key }
  ) as B
}

export function addTile<B extends SequenceBody>(body: B): B {
  const tiles = tilesOf(body)
  const prefix = body.type === 'sentence_construction' ? 'w' : 't'
  return withTiles(body, [...tiles, { id: nextId(tiles.map((t) => t.id), prefix), text: '' }])
}

export function setTileText<B extends SequenceBody>(body: B, index: number, text: string): B {
  return withTiles(
    body,
    tilesOf(body).map((t, i) => (i === index ? { ...t, text } : t)),
  )
}

/** A removed tile leaves the answer too, wherever it was in it. */
export function removeTile<B extends SequenceBody>(body: B, index: number): B {
  const tiles = tilesOf(body)
  const removed = tiles[index]
  return withTiles(
    body,
    tiles.filter((_, i) => i !== index),
    body.answer_key.correct_sequence.filter((id) => id !== removed?.id),
  )
}

/** Appends a tile to the answer. Each tile is used at most once, which is
 * what the server enforces; two tiles showing the same letter are still two
 * tiles, and both can be used. */
export function appendToAnswer<B extends SequenceBody>(body: B, tileId: string): B {
  const sequence = body.answer_key.correct_sequence
  if (sequence.includes(tileId) || !tilesOf(body).some((t) => t.id === tileId)) return body
  return withTiles(body, tilesOf(body), [...sequence, tileId])
}

export function removeFromAnswer<B extends SequenceBody>(body: B, position: number): B {
  return withTiles(
    body,
    tilesOf(body),
    body.answer_key.correct_sequence.filter((_, i) => i !== position),
  )
}

export function moveInAnswer<B extends SequenceBody>(body: B, position: number, by: -1 | 1): B {
  const sequence = swap(body.answer_key.correct_sequence, position, by)
  return sequence ? withTiles(body, tilesOf(body), sequence) : body
}

// --- match pairs ---------------------------------------------------------------
//
// A row is one entry of `correct_pairs`, in its stored order. The two
// columns keep their own stored order, which need not follow the pairs --
// a right column stored shuffled stays shuffled.

export interface PairRow {
  left: Tile | undefined
  right: Tile | undefined
}

export function pairRows(body: PairsBody): PairRow[] {
  const left = new Map(body.content.left_tiles.map((t) => [t.id, t]))
  const right = new Map(body.content.right_tiles.map((t) => [t.id, t]))
  return body.answer_key.correct_pairs.map(([l, r]) => ({ left: left.get(l), right: right.get(r) }))
}

export function addPair(body: PairsBody): PairsBody {
  const l = nextId(body.content.left_tiles.map((t) => t.id), 'l')
  const r = nextId(body.content.right_tiles.map((t) => t.id), 'r')
  return {
    ...body,
    content: {
      ...body.content,
      left_tiles: [...body.content.left_tiles, { id: l, text: '' }],
      right_tiles: [...body.content.right_tiles, { id: r, text: '' }],
    },
    answer_key: { ...body.answer_key, correct_pairs: [...body.answer_key.correct_pairs, [l, r]] },
  }
}

export function setPairText(body: PairsBody, row: number, side: 'left' | 'right', text: string): PairsBody {
  const pair = body.answer_key.correct_pairs[row]
  if (!pair) return body
  const id = side === 'left' ? pair[0] : pair[1]
  const key = side === 'left' ? 'left_tiles' : 'right_tiles'
  return {
    ...body,
    content: { ...body.content, [key]: body.content[key].map((t) => (t.id === id ? { ...t, text } : t)) },
  }
}

/** Removes the row and both of its tiles, so the columns stay equal. */
export function removePair(body: PairsBody, row: number): PairsBody {
  const pair = body.answer_key.correct_pairs[row]
  if (!pair) return body
  return {
    ...body,
    content: {
      ...body.content,
      left_tiles: body.content.left_tiles.filter((t) => t.id !== pair[0]),
      right_tiles: body.content.right_tiles.filter((t) => t.id !== pair[1]),
    },
    answer_key: {
      ...body.answer_key,
      correct_pairs: body.answer_key.correct_pairs.filter((_, i) => i !== row),
    },
  }
}

// --- before saving ----------------------------------------------------------

/** What the form itself can see is missing. Everything else -- empty text,
 * too few tiles, bad audio -- is left to the server, whose answer names the
 * field and is shown beside it. */
export function missingAnswer(body: ExerciseBody): string | null {
  if (isChoiceBody(body)) {
    const ok = body.content.choices.some((c) => c.id === body.answer_key.correct_choice_id)
    return ok ? null : 'Mark which choice is correct.'
  }
  if (isSequenceBody(body)) {
    return body.answer_key.correct_sequence.length > 0 ? null : 'Build the correct answer from the tiles.'
  }
  return null
}

// --- where a server error belongs ---------------------------------------------

/** The place in the form a `422`'s `details.field` belongs: a whole list,
 * one row of it, a text field, or `top` when nothing in the form names it. */
export type Slot =
  | 'prompt'
  | 'audio_url'
  | 'sentence'
  | 'choices'
  | 'tiles'
  | 'answer'
  | 'pairs'
  | 'top'
  | `choice:${number}`
  | `tile:${number}`
  | `pair:${number}`

export function placeError(field: string, message: string, body: ExerciseBody): Slot {
  if (field === 'prompt') return 'prompt'
  if (field === 'content.audio_url') return 'audio_url'
  if (field === 'content.sentence_before' || field === 'content.sentence_after') return 'sentence'

  const row = /^content\.(choices|word_bank|tiles|left_tiles|right_tiles)\[(\d+)\]/.exec(field)
  if (row) {
    const [, list, index] = row
    if (list === 'choices') return `choice:${Number(index)}`
    if (list === 'word_bank' || list === 'tiles') return `tile:${Number(index)}`
    if (body.type === 'match_pairs') {
      const tiles = list === 'left_tiles' ? body.content.left_tiles : body.content.right_tiles
      const id = tiles[Number(index)]?.id
      const at = body.answer_key.correct_pairs.findIndex(([l, r]) => l === id || r === id)
      return at >= 0 ? `pair:${at}` : 'pairs'
    }
  }
  const pair = /^answer_key\.correct_pairs\[(\d+)\]/.exec(field)
  if (pair) return `pair:${Number(pair[1])}`
  if (field.startsWith('answer_key.correct_sequence')) return 'answer'

  // A whole list, the answer key, or a rule about the content as a whole
  // ("requires at least 2 choices"): the list that rule is about.
  if (field.startsWith('content') || field.startsWith('answer_key')) {
    if (body.type === 'gap_fill' && /side of the gap/.test(message)) return 'sentence'
    if (isChoiceBody(body)) return 'choices'
    if (isSequenceBody(body)) return field.startsWith('answer_key') ? 'answer' : 'tiles'
    return 'pairs'
  }
  return 'top'
}

/** The server's message without the field path or class name it starts
 * with, for when it is already shown beside that field: "content.choices[1]
 * .text must be a non-empty string" reads "Must be a non-empty string"
 * under choice 2, and "MultipleChoiceContent requires at least 2 choices"
 * reads "Needs at least 2 choices" under the choices. */
export function plainMessage(message: string): string {
  const rest = message
    .replace(/^(?:prompt|(?:content|answer_key)(?:\.\w+|\[\d+\])*)\s+/, '')
    .replace(/^[A-Z]\w*(?:Content|AnswerKey)(?:\.\w+)?\s+requires\s+/, 'needs ')
    .replace(/^[A-Z]\w*(?:Content|AnswerKey)(?:\.\w+)?\s+/, '')
  return rest === message ? message : rest.charAt(0).toUpperCase() + rest.slice(1)
}

/** Where a listening clip can be played from: hosted clips as they are,
 * local `/media/...` paths from the backend the site talks to. */
export function playableUrl(url: string): string {
  return url.startsWith('/') ? `${API_BASE_URL}${url}` : url
}
