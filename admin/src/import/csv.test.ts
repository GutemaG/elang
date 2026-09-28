import { describe, expect, it } from 'vitest'

import { AUDIO_IMAGE, GAP, IMAGE, LISTENING, MC, PAIRS, SENTENCE, SPELL } from '../test/exercises'
import type { ExerciseBody, Tile } from '../types'
import { charactersOf, columnOf, joinItems, seededShuffle, splitItems, typeOf, writeCsv } from './csvFormat'
import { NOT_UTF8, readCsv, type ImportRow } from './fromCsv'
import { exercisesToCsv } from './toCsv'

const HEADER = 'type,prompt,sentence,answer,wrong,audio_url,descriptions'

/** The one row of a CSV made of `HEADER` and `line`. */
function one(line: string, header = HEADER): ImportRow {
  const { rows, error } = readCsv(`${header}\n${line}\n`)
  expect(error).toBeNull()
  expect(rows).toHaveLength(1)
  return rows[0]!
}

function body(line: string, header = HEADER): ExerciseBody {
  const row = one(line, header)
  expect(row.problem).toBeNull()
  return row.body!
}

const problem = (line: string, header = HEADER) => one(line, header).problem

const texts = (tiles: Tile[], ids: string[]) => ids.map((id) => tiles.find((t) => t.id === id)?.text)

/** What an exercise asks and accepts, without ids or order: what must
 * survive export and import. */
function meaning(b: ExerciseBody): unknown {
  const sorted = (xs: string[]) => [...xs].sort()
  switch (b.type) {
    case 'multiple_choice':
    case 'listening':
    case 'gap_fill': {
      const answer = b.content.choices.find((c) => c.id === b.answer_key.correct_choice_id)?.text
      const rest = { ...b.content, choices: undefined }
      return { prompt: b.prompt, rest, answer, all: sorted(b.content.choices.map((c) => c.text)) }
    }
    case 'sentence_construction':
    case 'spell_tiles': {
      const tiles = b.type === 'spell_tiles' ? b.content.tiles : b.content.word_bank
      return {
        prompt: b.prompt,
        answer: texts(tiles, b.answer_key.correct_sequence),
        all: sorted(tiles.map((t) => t.text)),
      }
    }
    case 'match_pairs':
      return {
        prompt: b.prompt,
        pairs: b.answer_key.correct_pairs.map(([l, r]) => [
          texts(b.content.left_tiles, [l])[0],
          texts(b.content.right_tiles, [r])[0],
        ]),
      }
    case 'image_choice':
    case 'audio_image_choice':
      return {
        prompt: b.prompt,
        audio: 'audio_url' in b.content ? b.content.audio_url : null,
        answer: b.content.choices.find((c) => c.id === b.answer_key.correct_choice_id)?.image_url,
        all: sorted(b.content.choices.map((c) => `${c.image_url} ${c.alt_text}`)),
      }
  }
}

describe('the CSV cells', () => {
  it('split on |, trimmed, with \\| for a literal bar', () => {
    expect(splitItems(' a | b|c ')).toEqual(['a', 'b', 'c'])
    expect(splitItems('a | | b')).toEqual(['a', 'b'])
    expect(splitItems('a | | b', { keepEmpty: true })).toEqual(['a', '', 'b'])
    expect(splitItems('yes \\| no | maybe')).toEqual(['yes | no', 'maybe'])
    expect(splitItems('  ')).toEqual([])
    expect(splitItems(joinItems(['yes | no', 'x']))).toEqual(['yes | no', 'x'])
  })

  it('name columns in any case, with spaces', () => {
    expect(columnOf(' Audio URL ')).toBe('audio_url')
    expect(columnOf('PROMPT')).toBe('prompt')
    expect(columnOf('answr')).toBeNull()
  })

  it('name a type by its key or its name in the site', () => {
    expect(typeOf('gap_fill')).toBe('gap_fill')
    expect(typeOf(' Gap fill ')).toBe('gap_fill')
    expect(typeOf('Multiple choice')).toBe('multiple_choice')
    expect(typeOf('essay')).toBeNull()
  })

  it('split a word into letters as a reader sees them', () => {
    expect(charactersOf('ቡና')).toEqual(['ቡ', 'ና'])
    expect(charactersOf('ሰ ላም')).toEqual(['ሰ', 'ላ', 'ም'])
  })

  it('shuffle the same way every time for the same seed', () => {
    const items = ['a', 'b', 'c', 'd', 'e']
    expect(seededShuffle(items, 'x')).toEqual(seededShuffle(items, 'x'))
    expect(seededShuffle(items, 'x').sort()).toEqual(items)
    const firsts = new Set(Array.from({ length: 30 }, (_, i) => seededShuffle(items, `seed ${i}`)[0]))
    expect(firsts.size).toBeGreaterThan(2)
  })

  it('are written with a byte-order mark, every column, and CRLF', () => {
    const text = writeCsv([{ type: 'multiple_choice', prompt: 'Hi, "you"', answer: 'ሰላም' }])
    expect(text.startsWith('\uFEFF')).toBe(true)
    expect(text.slice(1)).toBe(`${HEADER}\r\nmultiple_choice,"Hi, ""you""",,ሰላም,,,`)
  })
})

describe('reading a CSV file', () => {
  it('turns a choice row into lettered choices with the answer among them', () => {
    const b = body('multiple_choice,Say hello,,ሰላም,ቻው | እሺ,,')

    expect(b.type).toBe('multiple_choice')
    if (b.type !== 'multiple_choice') return
    expect(b.prompt).toBe('Say hello')
    expect(b.content.choices.map((c) => c.id)).toEqual(['a', 'b', 'c'])
    expect(b.content.choices.map((c) => c.text).sort()).toEqual(['ሰላም', 'ቻው', 'እሺ'].sort())
    expect(b.content.choices.find((c) => c.id === b.answer_key.correct_choice_id)?.text).toBe('ሰላም')
  })

  it('does not always put the answer first, and gives the same order every time', () => {
    const lines = Array.from({ length: 20 }, (_, i) => `multiple_choice,Question ${i},,right,w1 | w2 | w3,,`)
    const firsts = lines.map((line) => {
      const b = body(line) as Extract<ExerciseBody, { type: 'multiple_choice' }>
      return b.answer_key.correct_choice_id
    })
    expect(new Set(firsts).size).toBeGreaterThan(1)
    expect(body(lines[0]!)).toEqual(body(lines[0]!))
  })

  it('reads listening with its clip', () => {
    const b = body('listening,What did you hear?,,ሰላም,ቻው,https://x.example/a.mp3,')
    expect(b.type === 'listening' && b.content.audio_url).toBe('https://x.example/a.mp3')
  })

  it('splits a gap fill sentence at the gap', () => {
    const b = body('gap_fill,Fill it,ቡና ___ እፈልጋለሁ,እባክህ,ውሃ,,')
    if (b.type !== 'gap_fill') throw new Error(b.type)
    expect(b.content.sentence_before).toBe('ቡና')
    expect(b.content.sentence_after).toBe('እፈልጋለሁ')

    const start = body('gap_fill,Fill it,_____ ነኝ,ደህና,ጥሩ,,')
    expect(start.type === 'gap_fill' && [start.content.sentence_before, start.content.sentence_after]).toEqual([
      '',
      'ነኝ',
    ])
  })

  it('needs exactly one gap', () => {
    expect(problem('gap_fill,Fill it,ቡና እፈልጋለሁ,እባክህ,ውሃ,,')).toBe('Mark the gap in "sentence" with ___, once.')
    expect(problem('gap_fill,Fill it,___ and ___,እባክህ,ውሃ,,')).toBe('Mark the gap in "sentence" with ___, once.')
  })

  it('builds a sentence from words split by spaces or bars, with extra words', () => {
    const spaced = body('sentence_construction,Say it,,ቡና እፈልጋለሁ,ውሃ,,')
    if (spaced.type !== 'sentence_construction') throw new Error(spaced.type)
    expect(spaced.content.word_bank.map((t) => t.id).sort()).toEqual(['w1', 'w2', 'w3'])
    expect(texts(spaced.content.word_bank, spaced.answer_key.correct_sequence)).toEqual(['ቡና', 'እፈልጋለሁ'])

    const barred = body('sentence_construction,Say it,,good morning | friend,,,')
    expect(barred.type === 'sentence_construction' && barred.content.word_bank.map((t) => t.text).sort()).toEqual([
      'friend',
      'good morning',
    ])
  })

  it('spells a word one tile per letter, a repeated letter twice', () => {
    const b = body('spell_tiles,Spell it,,ሰላላም,ሻ,,')
    if (b.type !== 'spell_tiles') throw new Error(b.type)
    expect(b.content.tiles).toHaveLength(5)
    expect(texts(b.content.tiles, b.answer_key.correct_sequence)).toEqual(['ሰ', 'ላ', 'ላ', 'ም'])
    expect(new Set(b.answer_key.correct_sequence).size).toBe(4)
  })

  it('spells with tiles of several letters when split by bars', () => {
    const b = body('spell_tiles,Spell it,,ሰ | ላም,,,')
    expect(b.type === 'spell_tiles' && texts(b.content.tiles, b.answer_key.correct_sequence)).toEqual(['ሰ', 'ላም'])
  })

  it('reads match pairs in order', () => {
    const b = body('match_pairs,Match,,ሰላም=hello | ቡና = coffee,,,')
    expect(b).toEqual({
      type: 'match_pairs',
      prompt: 'Match',
      content: {
        left_tiles: [
          { id: 'l1', text: 'ሰላም' },
          { id: 'l2', text: 'ቡና' },
        ],
        right_tiles: [
          { id: 'r1', text: 'hello' },
          { id: 'r2', text: 'coffee' },
        ],
      },
      answer_key: {
        correct_pairs: [
          ['l1', 'r1'],
          ['l2', 'r2'],
        ],
      },
    })
    expect(problem('match_pairs,Match,,ሰላም=hello | ቡና,,,')).toBe('Write each pair as left=right, not "ቡና".')
  })

  it('keeps each picture with its description', () => {
    const b = body('image_choice,ቡና,,https://p/coffee.png,https://p/tea.png | https://p/water.png,, | Tea')
    if (b.type !== 'image_choice') throw new Error(b.type)
    const alt = Object.fromEntries(b.content.choices.map((c) => [c.image_url, c.alt_text]))
    expect(alt).toEqual({ 'https://p/coffee.png': '', 'https://p/tea.png': 'Tea', 'https://p/water.png': '' })
    expect(b.content.choices.find((c) => c.id === b.answer_key.correct_choice_id)?.image_url).toBe(
      'https://p/coffee.png',
    )
    expect(problem('image_choice,ቡና,,https://p/a.png,https://p/b.png,,A | B | C')).toBe(
      'There are 3 descriptions but 2 pictures.',
    )
  })

  it('reads an audio picture question with its clip', () => {
    const b = body('audio_image_choice,Tap,,https://p/a.png,https://p/b.png,https://x/a.mp3,')
    expect(b.type === 'audio_image_choice' && b.content.audio_url).toBe('https://x/a.mp3')
  })

  it.each([
    [',Say hi,,ሰላም,ቻው,,', 'Add a type.'],
    ['essay,Say hi,,ሰላም,ቻው,,', 'Unknown type "essay".'],
    ['multiple_choice, ,,ሰላም,ቻው,,', 'Add a prompt.'],
    ['multiple_choice,Say hi,,,ቻው,,', 'Add the choice in "answer".'],
    ['multiple_choice,Say hi,,ሰላም | ቻው,,,', '"answer" holds one choice; put the others in "wrong".'],
    ['multiple_choice,Say hi,,ሰላም,,,', 'Add at least one wrong choice in "wrong".'],
    ['multiple_choice,Say hi,,ሰላም,ሰላም | ቻው,,', 'The answer is in "wrong" too.'],
    ['multiple_choice,Say hi,,ሰላም,ቻው,https://x/a.mp3,', 'Multiple choice doesn\'t use "audio_url"; leave it empty.'],
    ['match_pairs,Match,,a=b,c,,', 'Match pairs doesn\'t use "wrong"; leave it empty.'],
    ['listening,Hear,,ሰላም,ቻው,,', 'Add the clip\'s address in "audio_url".'],
    ['spell_tiles,Spell,,,ሻ,,', 'Add the answer in "answer".'],
  ])('says what is wrong with %s', (line, message) => {
    expect(problem(line)).toBe(message)
  })

  it('takes columns in any order, named loosely, and leaves out unused ones', () => {
    const b = body('ሰላም,Say hi,ቻው,multiple_choice', 'Answer,Prompt,Wrong,Type')
    expect(b.type).toBe('multiple_choice')
  })

  it('reads quoted cells with commas, quotes and line breaks, and a byte-order mark', () => {
    const { rows } = readCsv(`\uFEFF${HEADER}\r\nmultiple_choice,"Hello, ""friend""\nhow are you?",,"a, b",c,,\r\n`)
    expect(rows[0]!.body?.prompt).toBe('Hello, "friend"\nhow are you?')
    expect(
      rows[0]!.body?.type === 'multiple_choice' && rows[0]!.body.content.choices.map((c) => c.text).sort(),
    ).toEqual(['a, b', 'c'])
  })

  it('skips empty rows but numbers rows as a spreadsheet does', () => {
    const { rows } = readCsv(`${HEADER}\nmultiple_choice,A,,x,y,,\n,,,,,,\n\nessay,B,,x,y,,\n`)
    expect(rows.map((r) => r.label)).toEqual(['Row 2', 'Row 5'])
    expect(rows[1]!.problem).toBe('Unknown type "essay".')
  })

  it.each([
    [
      'type,prompt,answr\n',
      'Unknown column "answr". The columns are: type, prompt, sentence, answer, wrong, audio_url, descriptions.',
    ],
    ['type,prompt\nmultiple_choice,x\n', 'The file needs a "answer" column.'],
    ['type,prompt,answer,Answer\n', 'The column "answer" appears twice.'],
    ['', 'The file is empty.'],
    [`${HEADER}\n`, 'There are no exercises in the file, only its header.'],
    [`${HEADER}\nmultiple_choice,"open,,x,y,,\n`, 'Row 2: a quoted cell is never closed.'],
  ])('refuses a file it cannot read: %j', (text, error) => {
    expect(readCsv(text)).toEqual({ rows: [], error })
  })

  it('refuses a file that is not UTF-8', () => {
    expect(readCsv(`${HEADER}\nmultiple_choice,Say \uFFFD,,x,y,,\n`).error).toBe(NOT_UTF8)
  })
})

describe('exporting to CSV', () => {
  it.each([MC, LISTENING, GAP, SENTENCE, SPELL, PAIRS, IMAGE, AUDIO_IMAGE] as ExerciseBody[])(
    'reads a $type back with the same prompt, answer and choices',
    (exercise) => {
      const { rows, error } = readCsv(exercisesToCsv([exercise]))

      expect(error).toBeNull()
      expect(rows[0]!.problem).toBeNull()
      expect(meaning(rows[0]!.body!)).toEqual(meaning(exercise))
    },
  )

  it('writes the answer first and the rest in wrong', () => {
    const [, line] = exercisesToCsv([MC]).slice(1).split('\r\n')
    expect(line).toBe(`multiple_choice,How do you say 'Hello' in Amharic?,,ሰላም,ደህና ሁን | አመሰግናለሁ | አዎ,,`)
  })

  it('writes the gap as ___', () => {
    const [, line] = exercisesToCsv([GAP]).slice(1).split('\r\n')
    expect(line).toContain(',___ ነኝ,')
  })
})
