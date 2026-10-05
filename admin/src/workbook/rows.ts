// A lesson's rows on its Workbook page (intent 025, bolt 084): the form's
// draft, what Save sends, the order to check them in, and where "Next
// unrecorded" goes. Pure.

import type { CurriculumEntry, CurriculumRow, CurriculumStatus } from '../types'
import { orderedLessons } from './model'

export interface Draft {
  english: string
  text: string
  romanization: string
  blank: string
  /** Other accepted answers, one per line. */
  accepted: string
  notes: string
  status: CurriculumStatus
  comment: string
  audio_url: string
}

export type RowChange = Partial<{
  english: string
  text: string | null
  romanization: string | null
  blank: string | null
  accepted: string[]
  notes: string | null
  status: CurriculumStatus
  comment: string | null
  audio_url: string | null
}>

export function draftOf(row: CurriculumRow): Draft {
  return {
    english: row.english,
    text: row.text ?? '',
    romanization: row.romanization ?? '',
    blank: row.blank ?? '',
    accepted: row.accepted.join('\n'),
    notes: row.notes ?? '',
    status: row.status,
    comment: row.comment ?? '',
    audio_url: row.audio_url ?? '',
  }
}

const orNull = (value: string) => value.trim() || null
const answers = (value: string) =>
  value
    .split('\n')
    .map((a) => a.trim())
    .filter(Boolean)

/** Only what the draft changes. */
export function changesOf(draft: Draft, row: CurriculumRow): RowChange {
  const change: RowChange = {}
  if (draft.english.trim() !== row.english) change.english = draft.english.trim()
  for (const key of ['text', 'romanization', 'blank', 'notes', 'comment', 'audio_url'] as const) {
    if (orNull(draft[key]) !== row[key]) change[key] = orNull(draft[key])
  }
  const accepted = answers(draft.accepted)
  if (accepted.join('\n') !== row.accepted.join('\n')) change.accepted = accepted
  if (draft.status !== row.status) change.status = draft.status
  return change
}

/** A recorded row whose words change may not match its recording: the
 * server sends it back to Draft unless the status is set too. */
export function retexts(change: RowChange, row: CurriculumRow): boolean {
  return !!row.audio_url && ('text' in change || 'romanization' in change) && !('status' in change)
}

/** The word to blank must be in the sentence as written. */
export function blankProblem(draft: Draft, kind: CurriculumRow['kind']): string | null {
  const blank = draft.blank.trim()
  if (kind !== 'sentence' || !blank) return null
  return draft.text.includes(blank) ? null : `“${blank}” is not in the sentence.`
}

export type Order = 'check_first' | 'in_order'

const RISK = { low: 0, medium: 1, high: 2 } as const

/** "Check first": Low, then Medium confidence, then the rest; else by
 * position. */
export function ordered(rows: CurriculumRow[], order: Order): CurriculumRow[] {
  const byPosition = (a: CurriculumRow, b: CurriculumRow) => a.position - b.position || a.ref.localeCompare(b.ref)
  const risk = (r: CurriculumRow) => (r.confidence ? RISK[r.confidence] : 2)
  return [...rows].sort((a, b) => (order === 'check_first' ? risk(a) - risk(b) : 0) || byPosition(a, b))
}

/** The next row without a recording after `current`: in this lesson's
 * order, then in the lessons after it. */
export function nextUnrecorded(
  entries: CurriculumEntry[],
  rows: CurriculumRow[],
  lessonRef: string,
  current: string,
  order: Order,
): { lesson: string; row: string } | null {
  const lessons = orderedLessons(entries).map((l) => l.lesson.ref)
  const start = lessons.indexOf(lessonRef)
  for (const lesson of lessons.slice(Math.max(start, 0))) {
    const list = ordered(
      rows.filter((r) => r.lesson_ref === lesson),
      order,
    )
    const from = lesson === lessonRef ? list.findIndex((r) => r.ref === current) + 1 : 0
    const found = list.slice(from).find((r) => !r.audio_url)
    if (found) return { lesson, row: found.ref }
  }
  // Last, any skipped earlier in this lesson.
  const earlier = ordered(
    rows.filter((r) => r.lesson_ref === lessonRef),
    order,
  ).find((r) => !r.audio_url && r.ref !== current)
  return earlier ? { lesson: lessonRef, row: earlier.ref } : null
}
