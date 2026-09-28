// The examples the import page shows and offers to download (bolt 056):
// one exercise of each type. Made here, from the same rows, so the CSV
// template, the JSON example and the help can never disagree with the
// reader.

import { COLUMNS, writeCsv, type CsvRow } from './csvFormat'
import { rowToBody } from './fromCsv'

const CLIP = 'https://example.com/audio/selam.mp3'
const picture = (name: string) => `https://example.com/pictures/${name}.png`

export const EXAMPLES: readonly Partial<CsvRow>[] = [
  {
    type: 'multiple_choice',
    prompt: 'How do you say "hello"?',
    answer: 'ሰላም',
    wrong: 'ቻው | አመሰግናለሁ',
  },
  {
    type: 'listening',
    prompt: 'What did you hear?',
    answer: 'ሰላም',
    wrong: 'ቻው | እሺ',
    audio_url: CLIP,
  },
  {
    type: 'gap_fill',
    prompt: 'Fill the gap',
    sentence: 'ቡና ___ እፈልጋለሁ',
    answer: 'እባክህ',
    wrong: 'ውሃ | ዳቦ',
  },
  {
    type: 'sentence_construction',
    prompt: 'Say "I want coffee"',
    answer: 'ቡና | እፈልጋለሁ',
    wrong: 'ውሃ',
  },
  { type: 'spell_tiles', prompt: 'Spell "coffee"', answer: 'ቡና', wrong: 'ሻ' },
  {
    type: 'match_pairs',
    prompt: 'Match the words',
    answer: 'ሰላም=hello | ቡና=coffee | ውሃ=water',
  },
  {
    type: 'image_choice',
    prompt: 'ቡና',
    answer: picture('coffee'),
    wrong: `${picture('tea')} | ${picture('water')}`,
    descriptions: 'A cup of coffee | A glass of tea | A glass of water',
  },
  {
    type: 'audio_image_choice',
    prompt: 'Tap what you hear',
    answer: picture('coffee'),
    wrong: picture('bread'),
    audio_url: CLIP,
  },
]

const full = (row: Partial<CsvRow>): CsvRow => Object.fromEntries(COLUMNS.map((c) => [c, row[c] ?? ''])) as CsvRow

export function csvTemplate(): string {
  return writeCsv(EXAMPLES)
}

export function jsonExample(): string {
  return (
    JSON.stringify(
      EXAMPLES.map((row) => rowToBody(full(row))),
      null,
      2,
    ) + '\n'
  )
}
