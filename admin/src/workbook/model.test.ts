import readExcelFile from 'read-excel-file/node'
import { resolve } from 'node:path'
import { beforeAll, describe, expect, it } from 'vitest'

import type { Curriculum, CurriculumEntry, CurriculumRow } from '../types'
import {
  curriculumToSheets,
  isReady,
  outline,
  parseWorkbook,
  sumCounts,
  workbookName,
  type ParsedWorkbook,
  type Sheet,
} from './model'

// Tests run from `admin/`.
const WORKBOOK = resolve(process.cwd(), '../curriculum/a1-english-speakers.xlsx')

let sheets: Sheet[]

beforeAll(async () => {
  sheets = (await readExcelFile(WORKBOOK)).map((s) => ({ sheet: s.sheet, data: s.data as unknown[][] }))
})

/** What the server would store from an import, and send back. */
function stored(parsed: ParsedWorkbook, language: string): Curriculum {
  const rows: CurriculumRow[] = parsed.rows.map((r) => ({
    ...r,
    audio_url: r.ref === 'W001' ? 'https://pub.example/am/curriculum/W001/a.m4a' : null,
    version: 1,
    updated_by: 'admin@example.com',
    updated_at: '2026-10-05T12:00:00Z',
  }))
  const entries: CurriculumEntry[] = parsed.entries.map((e) => ({ ...e, counts: null }))
  return {
    course_id: 'c',
    course_title: 'English to Amharic',
    language,
    entries,
    rows,
    counts: { rows: rows.length, filled: 0, reviewed: 0, recorded: 0, needs_change: 0 },
  }
}

describe('reading the A1 workbook', () => {
  it('reads the plan and rows for Amharic, skipping Section 0', () => {
    const started = performance.now()
    const parsed = parseWorkbook(sheets, 'am')
    expect(performance.now() - started).toBeLessThan(3000)

    expect(parsed.problems).toEqual([])
    const kinds = (k: string) => parsed.entries.filter((e) => e.kind === k)
    expect(kinds('section').map((e) => [e.ref, e.title])).toEqual([
      ['S1', 'First conversations (A1.1)'],
      ['S2', 'Daily life (A1.2)'],
    ])
    expect(kinds('skill')).toHaveLength(22)
    expect(kinds('lesson')).toHaveLength(66)
    expect(parsed.rows.filter((r) => r.kind === 'word')).toHaveLength(268)
    expect(parsed.rows.filter((r) => r.kind === 'sentence')).toHaveLength(66)
    expect(parsed.skipped).toBe(3)

    const lesson = parsed.entries.find((e) => e.ref === 'S1-U01-L1')!
    expect(lesson).toMatchObject({ kind: 'lesson', parent_ref: 'S1-U01', position: 1, title: 'Hello & goodbye' })
    expect(lesson.goal).toBeTruthy()
    expect(parsed.entries.find((e) => e.ref === 'S1-U01')).toMatchObject({ parent_ref: 'S1', title: 'Greetings' })

    const hello = parsed.rows.find((r) => r.ref === 'W001')!
    expect(hello).toMatchObject({
      kind: 'word',
      lesson_ref: 'S1-U01-L1',
      english: 'hello',
      text: 'ሰላም',
      romanization: 'selam',
      confidence: 'high',
      status: 'draft',
      blank: null,
    })
    const sentence = parsed.rows.find((r) => r.ref === 'S001')!
    expect(sentence).toMatchObject({ kind: 'sentence', text: 'ደህና ይሁኑ፣ ደህና ይደሩ', blank: 'ይደሩ', accepted: [] })
    // A lesson's words come first, then its sentence.
    const first = parsed.rows.filter((r) => r.lesson_ref === 'S1-U01-L1')
    expect(first.map((r) => [r.ref, r.position]).at(-1)).toEqual(['S001', first.length])
    // Section 2 has only English so far.
    const later = parsed.rows.find((r) => r.lesson_ref.startsWith('S2-'))!
    expect(later.text).toBeNull()
    expect(later.status).toBe('to_do')
    expect(parsed.where.W001).toEqual({ tab: 'Words', row: 2 })
  })

  it('reads the Oromo columns for Afaan Oromo, with no romanization', () => {
    const parsed = parseWorkbook(sheets, 'om')

    expect(parsed.problems).toEqual([])
    expect(parsed.rows.find((r) => r.ref === 'W001')).toMatchObject({ text: 'Akkam', romanization: null })
    expect(parsed.rows.find((r) => r.ref === 'S001')).toMatchObject({ blank: 'halkan' })
    expect(parsed.rows.find((r) => r.ref === 'S002')!.confidence).toBe('low')
  })

  it('refuses a language the workbook has no columns for', () => {
    const parsed = parseWorkbook(sheets, 'ti')

    expect(parsed.rows).toEqual([])
    expect(parsed.problems[0]!.message).toMatch(/Amharic and Afaan Oromo only/)
  })

  it('names a missing tab or column', () => {
    const noWords = sheets.filter((s) => s.sheet !== 'Words')
    expect(parseWorkbook(noWords, 'am').problems).toEqual([
      { tab: 'Words', row: null, message: 'The workbook has no Words tab.' },
    ])
    const renamed = sheets.map((s) =>
      s.sheet === 'Plan' ? { ...s, data: [s.data[0]!.map((h) => (h === 'Lesson ID' ? 'Lesson' : h)), ...s.data.slice(1)] } : s,
    )
    expect(parseWorkbook(renamed, 'am').problems[0]).toMatchObject({ tab: 'Plan', row: 1 })
  })

  it('lists bad rows with their row numbers', () => {
    const edited = sheets.map((s) => {
      if (s.sheet !== 'Words') return s
      const data = s.data.map((r) => [...r])
      const status = data[0]!.indexOf('Status: Amharic')
      const confidence = data[0]!.indexOf('Claude confidence: Amharic')
      const lesson = data[0]!.indexOf('Lesson ID')
      data[1]![status] = 'Done'
      data[2]![confidence] = 'Sure'
      data[3]![lesson] = 'S9-U01-L1'
      return { ...s, data }
    })

    const parsed = parseWorkbook(edited, 'am')

    expect(parsed.problems.map((p) => [p.tab, p.row])).toEqual([
      ['Words', 2],
      ['Words', 3],
      ['Words', 4],
    ])
    expect(parsed.problems[0]!.message).toBe('The status must be To do, Draft, Needs change or Reviewed, not “Done”.')
    expect(parsed.rows.some((r) => r.ref === 'W001')).toBe(false)
  })
})

describe('writing it back out', () => {
  it('exports what reads back the same', () => {
    for (const language of ['am', 'om']) {
      const parsed = parseWorkbook(sheets, language)
      const curriculum = stored(parsed, language)

      const again = parseWorkbook(curriculumToSheets(curriculum), language)

      expect(again.problems).toEqual([])
      expect(again.entries).toEqual(parsed.entries)
      expect(again.rows).toEqual(parsed.rows)
    }
  })

  it('marks recorded rows and leaves the other language empty', () => {
    const tabs = curriculumToSheets(stored(parseWorkbook(sheets, 'am'), 'am'))
    const words = tabs.find((t) => t.sheet === 'Words')!.data
    const col = (name: string) => words[0]!.indexOf(name)

    expect(words[1]![col('Audio: Amharic')]).toBe('Y')
    expect(words[2]![col('Audio: Amharic')]).toBe('N')
    expect(words[1]![col('Afaan Oromo')]).toBeNull()
    expect(words[1]![col('Status: Amharic')]).toBe('Draft')
  })

  it('names the file after the course', () => {
    expect(workbookName('English to Amharic')).toBe('English-to-Amharic-workbook.xlsx')
  })
})

describe('progress', () => {
  it('adds up lessons and knows when one is ready', () => {
    const lesson = (ref: string, reviewed: number, recorded: number): CurriculumEntry => ({
      ref,
      kind: 'lesson',
      parent_ref: 'S1-U01',
      position: Number(ref.at(-1)),
      title: ref,
      goal: null,
      grammar: null,
      counts: { rows: 2, filled: 2, reviewed, recorded, needs_change: 0 },
    })
    const entries: CurriculumEntry[] = [
      { ref: 'S1', kind: 'section', parent_ref: null, position: 1, title: 'One', goal: null, grammar: null, counts: null },
      { ref: 'S1-U01', kind: 'skill', parent_ref: 'S1', position: 1, title: 'Greetings', goal: null, grammar: null, counts: null },
      lesson('S1-U01-L2', 1, 2),
      lesson('S1-U01-L1', 2, 2),
    ]

    const [section] = outline(entries)

    expect(section!.skills[0]!.lessons.map((l) => l.ref)).toEqual(['S1-U01-L1', 'S1-U01-L2'])
    expect(sumCounts(section!.skills[0]!.lessons)).toEqual({ rows: 4, filled: 4, reviewed: 3, recorded: 4, needs_change: 0 })
    expect(isReady(entries[3]!.counts)).toBe(true)
    expect(isReady(entries[2]!.counts)).toBe(false)
    expect(isReady({ rows: 0, filled: 0, reviewed: 0, recorded: 0, needs_change: 0 })).toBe(false)
  })
})
