// Romanization in CSV and JSON files: optional columns for the question's
// pronunciation and for each answer and wrong item's, read by position,
// written back on export, and shown in both downloadable samples.

import { describe, expect, it } from 'vitest'

import type { ExerciseBody, Tile } from '../types'
import { readCsv, rowToBody } from './fromCsv'
import { csvTemplate, jsonExample } from './templates'
import { exercisesToCsv } from './toCsv'
import { COLUMNS, type CsvRow } from './csvFormat'

const row = (cells: Partial<CsvRow>): CsvRow =>
  Object.fromEntries(COLUMNS.map((c) => [c, cells[c] ?? ''])) as CsvRow

const tilesOf = (body: ExerciseBody): Tile[] => {
  const content = body.content as Record<string, unknown>
  return (content.choices ?? content.word_bank ?? content.tiles) as Tile[]
}
const spokenOf = (body: ExerciseBody) =>
  Object.fromEntries(tilesOf(body).map((t) => [t.text, t.pronunciation]))

describe('reading pronunciations from a CSV row', () => {
  it('gives each choice its own, and the question its own', () => {
    const body = rowToBody(
      row({
        type: 'multiple_choice',
        prompt: "What does 'ሰላም' mean?",
        pronunciation: 'selam',
        answer: 'ሰላም',
        answer_pronunciation: 'selam',
        wrong: 'ቻው | እሺ',
        wrong_pronunciation: ' | ishi',
      }),
    )

    expect((body.content as { pronunciation?: string }).pronunciation).toBe('selam')
    expect(spokenOf(body)).toEqual({ ሰላም: 'selam', ቻው: undefined, እሺ: 'ishi' })
    // No key at all for the one without.
    expect(tilesOf(body).find((t) => t.text === 'ቻው')).not.toHaveProperty('pronunciation')
  })

  it('keeps the same choice order whether or not pronunciations are added', () => {
    const plain = row({ type: 'multiple_choice', prompt: 'Hi', answer: 'ሰላም', wrong: 'ቻው | እሺ | አዎ' })
    const spoken = { ...plain, answer_pronunciation: 'selam', wrong_pronunciation: 'chaw | ishi | awo' }

    expect(tilesOf(rowToBody(spoken)).map((t) => t.text)).toEqual(tilesOf(rowToBody(plain)).map((t) => t.text))
  })

  it('splits sentence words on spaces or |, and letters on |', () => {
    const sentence = rowToBody(
      row({
        type: 'sentence_construction',
        prompt: 'Say it',
        answer: 'ቡና እፈልጋለሁ',
        answer_pronunciation: 'bunna ifeligalehu',
        wrong: 'ውሃ',
        wrong_pronunciation: 'wuha',
      }),
    )
    const spell = rowToBody(
      row({ type: 'spell_tiles', prompt: 'Spell', answer: 'ቡና', answer_pronunciation: 'bu | na', wrong: 'ሻ' }),
    )

    expect(spokenOf(sentence)).toEqual({ ቡና: 'bunna', እፈልጋለሁ: 'ifeligalehu', ውሃ: 'wuha' })
    expect(spokenOf(spell)).toEqual({ ቡ: 'bu', ና: 'na', ሻ: undefined })
  })

  it('reads match pairs as left=right, either side optional', () => {
    const body = rowToBody(
      row({
        type: 'match_pairs',
        prompt: 'Match',
        answer: 'ሰላም=hello | ቡና=coffee',
        answer_pronunciation: 'selam= | =',
      }),
    )
    if (body.type !== 'match_pairs') throw new Error('not pairs')

    expect(body.content.left_tiles).toEqual([
      { id: 'l1', text: 'ሰላም', pronunciation: 'selam' },
      { id: 'l2', text: 'ቡና' },
    ])
    expect(body.content.right_tiles).toEqual([
      { id: 'r1', text: 'hello' },
      { id: 'r2', text: 'coffee' },
    ])
  })

  it('refuses more pronunciations than items, and a question pronunciation on a heard question', () => {
    const { rows } = readCsv(
      [
        'type,prompt,answer,wrong,wrong_pronunciation,pronunciation,audio_url',
        'multiple_choice,Hi,ሰላም,ቻው,chaw | ishi,,',
        'listening,What did you hear?,ሰላም,ቻው,,selam,https://example.com/a.mp3',
      ].join('\n'),
    )

    expect(rows[0]!.problem).toBe('"wrong_pronunciation" has 2 pronunciations but there are 1 items to go with them.')
    expect(rows[1]!.problem).toBe('Listening doesn\'t use "pronunciation"; leave it empty.')
  })

  it('still reads a file written before these columns existed', () => {
    const { rows, error } = readCsv('type,prompt,answer,wrong\nmultiple_choice,Hi,ሰላም,ቻው | እሺ\n')

    expect(error).toBeNull()
    expect(rows[0]!.problem).toBeNull()
    expect(tilesOf(rows[0]!.body!).every((t) => !('pronunciation' in t))).toBe(true)
  })
})

describe('writing pronunciations to CSV', () => {
  it('reads back what it writes, for every sample (choices may be reordered)', () => {
    const samples = JSON.parse(jsonExample()) as ExerciseBody[]
    const { rows } = readCsv(exercisesToCsv(samples))
    // Each tile's pronunciation by its text, and the question's: what an
    // export must keep, whatever order the choices come back in.
    const spoken = (body: ExerciseBody) => {
      const content = body.content as Record<string, unknown>
      const lists = ['choices', 'word_bank', 'tiles', 'left_tiles', 'right_tiles']
      const tiles = lists.flatMap((key) => (content[key] as Tile[] | undefined) ?? [])
      return {
        question: content.pronunciation,
        tiles: Object.fromEntries(tiles.filter((t) => 'text' in t).map((t) => [t.text, t.pronunciation])),
      }
    }

    expect(rows).toHaveLength(samples.length)
    rows.forEach((read, i) => {
      expect(read.problem).toBeNull()
      expect(spoken(read.body!)).toEqual(spoken(samples[i]!))
    })
  })
})

describe('the downloadable samples', () => {
  it('show pronunciations in the CSV template and in the JSON example', () => {
    const header = csvTemplate().slice(1).split('\r\n')[0]

    expect(header).toContain('pronunciation')
    expect(header).toContain('answer_pronunciation')
    expect(header).toContain('wrong_pronunciation')
    expect(csvTemplate()).toContain('selam')
    const samples = JSON.parse(jsonExample()) as ExerciseBody[]
    const mc = samples.find((b) => b.type === 'multiple_choice')!
    expect(tilesOf(mc).some((t) => t.pronunciation === 'selam')).toBe(true)
    const gap = samples.find((b) => b.type === 'gap_fill')!
    expect((gap.content as { pronunciation?: string }).pronunciation).toBe('bunna ___ ifeligalehu')
    // A heard question has none of its own.
    const listening = samples.find((b) => b.type === 'listening')!
    expect(listening.content).not.toHaveProperty('pronunciation')
  })

  it('every sample row reads without a problem', () => {
    const { rows, error } = readCsv(csvTemplate())

    expect(error).toBeNull()
    expect(rows.map((r) => r.problem)).toEqual(rows.map(() => null))
  })
})
