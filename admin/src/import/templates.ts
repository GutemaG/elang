// The examples the import page shows and offers to download (bolt 056):
// one exercise of each type. Made here, from the same rows, so the CSV
// template, the JSON example and the help can never disagree with the
// reader.

import { COLUMNS, writeCsv, type CsvRow } from './csvFormat'
import { rowToBody } from './fromCsv'

const CLIP = 'https://example.com/audio/selam.mp3'
const picture = (name: string) => `https://example.com/pictures/${name}.png`

export const EXAMPLES: readonly Partial<CsvRow>[] = [
  // Pronunciations (the Fidel in Latin letters) are optional everywhere;
  // these show each way of writing them.
  {
    type: 'multiple_choice',
    prompt: 'How do you say "hello"?',
    answer: 'ሰላም',
    answer_pronunciation: 'selam',
    wrong: 'ቻው | አመሰግናለሁ',
    wrong_pronunciation: 'chaw | ameseginalehu',
  },
  {
    type: 'listening',
    prompt: 'What did you hear?',
    answer: 'ሰላም',
    answer_pronunciation: 'selam',
    wrong: 'ቻው | እሺ',
    wrong_pronunciation: 'chaw | ishi',
    audio_url: CLIP,
  },
  {
    type: 'gap_fill',
    prompt: 'Fill the gap',
    pronunciation: 'bunna ___ ifeligalehu',
    sentence: 'ቡና ___ እፈልጋለሁ',
    answer: 'እባክህ',
    answer_pronunciation: 'ibakih',
    wrong: 'ውሃ | ዳቦ',
    wrong_pronunciation: 'wuha | dabo',
  },
  {
    type: 'sentence_construction',
    prompt: 'Say "I want coffee"',
    answer: 'ቡና | እፈልጋለሁ',
    answer_pronunciation: 'bunna | ifeligalehu',
    wrong: 'ውሃ',
    wrong_pronunciation: 'wuha',
  },
  {
    type: 'spell_tiles',
    prompt: 'Spell "coffee"',
    pronunciation: 'bunna',
    answer: 'ቡና',
    answer_pronunciation: 'bu | na',
    wrong: 'ሻ',
    wrong_pronunciation: 'sha',
  },
  {
    type: 'match_pairs',
    prompt: 'Match the words',
    answer: 'ሰላም=hello | ቡና=coffee | ውሃ=water',
    answer_pronunciation: 'selam= | bunna= | wuha=',
  },
  {
    type: 'image_choice',
    prompt: 'ቡና',
    pronunciation: 'bunna',
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
