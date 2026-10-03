// Exercises to CSV rows (bolt 056): the reverse of `fromCsv.ts`, for
// export. Reading a row back gives the same prompt, answer and choices;
// only the choices' ids and order may differ.

import type { ExerciseBody, Tile } from '../types'
import { joinItems, writeCsv, type CsvRow } from './csvFormat'

export function bodyToRow(body: ExerciseBody): Partial<CsvRow> {
  const question = 'pronunciation' in body.content ? body.content.pronunciation : undefined
  const base = { type: body.type, prompt: body.prompt, ...(question ? { pronunciation: question } : {}) }
  switch (body.type) {
    case 'multiple_choice':
      return {
        ...base,
        ...choiceCells(body.content.choices, body.answer_key.correct_choice_id),
      }
    case 'listening':
      return {
        ...base,
        ...choiceCells(body.content.choices, body.answer_key.correct_choice_id),
        audio_url: body.content.audio_url,
      }
    case 'gap_fill': {
      const { sentence_before: before, sentence_after: after } = body.content
      return {
        ...base,
        sentence: [before, '___', after].filter(Boolean).join(' '),
        ...choiceCells(body.content.choices, body.answer_key.correct_choice_id),
      }
    }
    case 'sentence_construction':
      return {
        ...base,
        ...sequenceCells(body.content.word_bank, body.answer_key.correct_sequence),
      }
    case 'spell_tiles':
      return {
        ...base,
        ...sequenceCells(body.content.tiles, body.answer_key.correct_sequence),
      }
    case 'match_pairs': {
      const find = (tiles: Tile[], id: string) => tiles.find((t) => t.id === id)
      const pairs = body.answer_key.correct_pairs.map(
        ([l, r]) => [find(body.content.left_tiles, l), find(body.content.right_tiles, r)] as const,
      )
      return {
        ...base,
        answer: joinItems(pairs.map(([l, r]) => `${l?.text ?? ''}=${r?.text ?? ''}`)),
        answer_pronunciation: spokenCell(
          pairs.map(([l, r]) => (l?.pronunciation || r?.pronunciation ? `${l?.pronunciation ?? ''}=${r?.pronunciation ?? ''}` : '')),
        ),
      }
    }
    case 'image_choice':
    case 'audio_image_choice': {
      const correct = body.answer_key.correct_choice_id
      const ordered = [
        ...body.content.choices.filter((p) => p.id === correct),
        ...body.content.choices.filter((p) => p.id !== correct),
      ]
      const [answer, ...wrong] = ordered
      const descriptions = ordered.map((p) => p.alt_text.trim())
      return {
        ...base,
        answer: answer?.image_url ?? '',
        wrong: joinItems(wrong.map((p) => p.image_url)),
        ...(body.type === 'audio_image_choice' ? { audio_url: body.content.audio_url } : {}),
        // Empty places are kept (`a |  | c`) so each description stays
        // with its picture; none at all is an empty cell.
        descriptions: descriptions.some(Boolean) ? descriptions.map((d) => d.replaceAll('|', '\\|')).join(' | ') : '',
      }
    }
  }
}

/** Pronunciations by place, empty places kept (`bunna |  | wuha`) so each
 * stays with its item; none at all is an empty cell. */
function spokenCell(items: readonly string[]): string {
  return items.some(Boolean) ? items.map((item) => item.replaceAll('|', '\\|')).join(' | ') : ''
}

function choiceCells(choices: Tile[], correctId: string): Partial<CsvRow> {
  const right = choices.filter((c) => c.id === correctId)
  const wrong = choices.filter((c) => c.id !== correctId)
  return {
    answer: joinItems(right.map((c) => c.text)),
    answer_pronunciation: right[0]?.pronunciation ?? '',
    wrong: joinItems(wrong.map((c) => c.text)),
    wrong_pronunciation: spokenCell(wrong.map((c) => c.pronunciation ?? '')),
  }
}

/** The answer's tiles in order, joined by `|` (so a tile of several
 * letters, or a word with a space, survives), and the extra tiles. */
function sequenceCells(tiles: Tile[], sequence: string[]): Partial<CsvRow> {
  const byId = new Map(tiles.map((t) => [t.id, t]))
  const used = new Set(sequence)
  const extra = tiles.filter((t) => !used.has(t.id))
  return {
    answer: joinItems(sequence.map((id) => byId.get(id)?.text ?? '')),
    answer_pronunciation: spokenCell(sequence.map((id) => byId.get(id)?.pronunciation ?? '')),
    wrong: joinItems(extra.map((t) => t.text)),
    wrong_pronunciation: spokenCell(extra.map((t) => t.pronunciation ?? '')),
  }
}

export function exercisesToCsv(bodies: readonly ExerciseBody[]): string {
  return writeCsv(bodies.map(bodyToRow))
}
