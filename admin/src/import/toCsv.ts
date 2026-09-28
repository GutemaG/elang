// Exercises to CSV rows (bolt 056): the reverse of `fromCsv.ts`, for
// export. Reading a row back gives the same prompt, answer and choices;
// only the choices' ids and order may differ.

import type { ExerciseBody, Tile } from '../types'
import { joinItems, writeCsv, type CsvRow } from './csvFormat'

export function bodyToRow(body: ExerciseBody): Partial<CsvRow> {
  const base = { type: body.type, prompt: body.prompt }
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
      const text = (tiles: Tile[], id: string) => tiles.find((t) => t.id === id)?.text ?? ''
      return {
        ...base,
        answer: joinItems(
          body.answer_key.correct_pairs.map(
            ([l, r]) => `${text(body.content.left_tiles, l)}=${text(body.content.right_tiles, r)}`,
          ),
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

function choiceCells(choices: Tile[], correctId: string): Partial<CsvRow> {
  return {
    answer: joinItems(choices.filter((c) => c.id === correctId).map((c) => c.text)),
    wrong: joinItems(choices.filter((c) => c.id !== correctId).map((c) => c.text)),
  }
}

/** The answer's tiles in order, joined by `|` (so a tile of several
 * letters, or a word with a space, survives), and the extra tiles. */
function sequenceCells(tiles: Tile[], sequence: string[]): Partial<CsvRow> {
  const byId = new Map(tiles.map((t) => [t.id, t.text]))
  const used = new Set(sequence)
  return {
    answer: joinItems(sequence.map((id) => byId.get(id) ?? '')),
    wrong: joinItems(tiles.filter((t) => !used.has(t.id)).map((t) => t.text)),
  }
}

export function exercisesToCsv(bodies: readonly ExerciseBody[]): string {
  return writeCsv(bodies.map(bodyToRow))
}
