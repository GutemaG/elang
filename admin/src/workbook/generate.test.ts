import { writeFileSync } from 'node:fs'
import { resolve } from 'node:path'
import readExcelFile from 'read-excel-file/node'
import { beforeAll, describe, expect, it } from 'vitest'

import type { CurriculumEntry, CurriculumRow } from '../types'
import { edited, generateExercises, keyOf, regenerate, reset } from './generate'
import { parseWorkbook } from './model'

// Tests run from `admin/`.
const WORKBOOK = resolve(process.cwd(), '../curriculum/a1-english-speakers.xlsx')

let entries: CurriculumEntry[]
let rows: CurriculumRow[]

/** Section 1 of the real workbook, as if reviewed and recorded. */
beforeAll(async () => {
  const sheets = (await readExcelFile(WORKBOOK)).map((s) => ({ sheet: s.sheet, data: s.data as unknown[][] }))
  const parsed = parseWorkbook(sheets, 'am')
  entries = parsed.entries.map((e) => ({ ...e, counts: null }))
  rows = parsed.rows.map((r) => ({
    ...r,
    status: 'reviewed',
    audio_url: `https://pub.example/am/curriculum/${r.ref}/a.m4a`,
    version: 1,
    updated_by: null,
    updated_at: '2026-10-05T12:00:00Z',
  }))
})

describe('generating a lesson’s exercises', () => {
  it('makes each word’s questions, the pairs, the spelling and the sentence’s', () => {
    const drafts = generateExercises('S1-U01-L1', entries, rows)

    const lesson = rows.filter((r) => r.lesson_ref === 'S1-U01-L1')
    const words = lesson.filter((r) => r.kind === 'word')
    const keys = drafts.map(keyOf)
    for (const w of words) {
      expect(keys).toContain(`mc:${w.ref}`)
      expect(keys).toContain(`listen:${w.ref}`)
    }
    expect(keys).toContain('pairs')
    expect(keys).toContain('build:S001')
    expect(keys).toContain('gap:S001')
    expect(keys).toContain('listen:S001')

    const mc = drafts.find((d) => keyOf(d) === 'mc:W001')!
    expect(mc.type).toBe('multiple_choice')
    expect(mc.prompt).toBe('How do you say “hello”?')
    expect(mc.vocab_ref).toBe('W001')
    if (mc.type !== 'multiple_choice') throw new Error()
    const answer = mc.content.choices.find((c) => c.id === mc.answer_key.correct_choice_id)!
    expect(answer).toEqual({ id: answer.id, text: 'ሰላም', pronunciation: 'selam' })
    expect(mc.content.choices.length).toBeGreaterThanOrEqual(2)
    expect(mc.content.choices.length).toBeLessThanOrEqual(4)
    const listening = drafts.find((d) => keyOf(d) === 'listen:W001')!
    expect(listening.type === 'listening' && listening.content.audio_url).toBe('https://pub.example/am/curriculum/W001/a.m4a')
    const gap = drafts.find((d) => keyOf(d) === 'gap:S001')!
    expect(gap.type === 'gap_fill' && gap.content.sentence_before).toBe('ደህና ይሁኑ፣ ደህና')
    expect(drafts.every((d) => !d.edited && d.generated?.key === keyOf(d))).toBe(true)
  })

  it('gives the same exercises every time', () => {
    expect(generateExercises('S1-U03-L2', entries, rows)).toEqual(generateExercises('S1-U03-L2', entries, rows))
  })

  it('draws wrong options from the lesson, then its skill and section', () => {
    const skillLessons = new Set(entries.filter((e) => e.parent_ref === 'S1-U01').map((e) => e.ref))
    const sectionTexts = new Set(rows.filter((r) => r.lesson_ref.startsWith('S1-')).map((r) => r.text))
    for (const d of generateExercises('S1-U01-L1', entries, rows)) {
      if (d.type !== 'multiple_choice') continue
      for (const c of d.content.choices) expect(sectionTexts.has(c.text)).toBe(true)
    }
    expect(skillLessons.size).toBeGreaterThan(1)
  })

  it('makes exercises for every lesson of Section 1, for the server to check', () => {
    const lessons = entries.filter((e) => e.kind === 'lesson' && e.ref.startsWith('S1-'))
    const all = lessons.map((l) => ({ lesson: l.ref, exercises: generateExercises(l.ref, entries, rows) }))

    for (const { exercises } of all) expect(exercises.length).toBeGreaterThanOrEqual(6)
    // Set WRITE_GENERATED to a file path to check them with the backend's
    // validate_exercise by hand.
    if (process.env.WRITE_GENERATED) writeFileSync(process.env.WRITE_GENERATED, JSON.stringify(all))
  })
})

describe('editing and generating again', () => {
  it('keeps an edited exercise when generating again, and resets it on request', () => {
    const drafts = generateExercises('S1-U01-L1', entries, rows)
    const first = drafts[0]!
    const changed = edited(first, { ...first, prompt: 'Which one means “hello”?' } as typeof first)
    expect(changed.edited).toBe(true)
    expect(edited(changed, first).edited).toBe(false)

    const again = regenerate(generateExercises('S1-U01-L1', entries, rows), [changed, ...drafts.slice(1)])

    expect(again.kept).toEqual([keyOf(first)])
    expect(again.exercises[0]!.prompt).toBe('Which one means “hello”?')
    expect(again.exercises.slice(1)).toEqual(drafts.slice(1))
    const back = reset(again.exercises[0]!)
    expect(back.edited).toBe(false)
    expect(back.prompt).toBe(first.prompt)
  })
})
