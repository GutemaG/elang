// A small curriculum and a stand-in for its endpoints (intent 025), shared by
// the Workbook tests. The server keeps what is imported and edited, and
// counts as the backend does.

import type {
  Curriculum,
  CurriculumCounts,
  DraftExercise,
  CurriculumEntry,
  CurriculumImportRequest,
  CurriculumImportResult,
  CurriculumRow,
} from '../types'
import { SENTENCE_HEADERS, WORD_HEADERS, PLAN_HEADERS, type Sheet } from '../workbook/model'
import type { Call, FakeServer } from './fakeServer'

export const COURSE_ID = 'course-1'
export const CURRICULUM = `/api/v1/admin/courses/${COURSE_ID}/curriculum`

export function entry(ref: string, kind: CurriculumEntry['kind'], parent: string | null, position: number, title: string): CurriculumEntry {
  return { ref, kind, parent_ref: parent, position, title, goal: null, grammar: null, counts: null }
}

export function row(ref: string, lesson: string, position: number, extra: Partial<CurriculumRow> = {}): CurriculumRow {
  return {
    ref,
    kind: ref.startsWith('S') ? 'sentence' : 'word',
    lesson_ref: lesson,
    position,
    english: `english ${ref}`,
    text: `ቃል ${ref}`,
    romanization: `qal ${ref}`,
    blank: null,
    accepted: [],
    notes: null,
    confidence: 'high',
    status: 'draft',
    comment: null,
    audio_url: null,
    version: 1,
    updated_by: 'admin@example.com',
    updated_at: '2026-10-05T12:00:00Z',
    ...extra,
  }
}

function countsOf(rows: CurriculumRow[]): CurriculumCounts {
  return {
    rows: rows.length,
    filled: rows.filter((r) => r.text).length,
    reviewed: rows.filter((r) => r.status === 'reviewed').length,
    recorded: rows.filter((r) => r.audio_url).length,
    needs_change: rows.filter((r) => r.status === 'needs_change').length,
  }
}

/** Counts filled in, as the server sends them. */
export function curriculumOf(entries: CurriculumEntry[], rows: CurriculumRow[]): Curriculum {
  return {
    course_id: COURSE_ID,
    course_title: 'English to Amharic',
    language: 'am',
    entries: entries.map((e) => ({
      ...e,
      counts: e.kind === 'lesson' ? countsOf(rows.filter((r) => r.lesson_ref === e.ref)) : null,
    })),
    rows,
    counts: countsOf(rows),
  }
}

/** Two lessons of one skill: the first ready to publish, the second with
 * a row that needs change and none recorded. */
export function smallCurriculum(): Curriculum {
  const recorded = { status: 'reviewed' as const, audio_url: 'https://pub.example/am/curriculum/x/a.m4a' }
  return curriculumOf(
    [
      entry('S1', 'section', null, 1, 'First conversations'),
      entry('S1-U01', 'skill', 'S1', 1, 'Greetings'),
      entry('S1-U01-L1', 'lesson', 'S1-U01', 1, 'Hello & goodbye'),
      entry('S1-U01-L2', 'lesson', 'S1-U01', 2, 'How are you?'),
    ],
    [
      row('W001', 'S1-U01-L1', 1, recorded),
      row('S001', 'S1-U01-L1', 2, { ...recorded, blank: 'S001' }),
      row('W002', 'S1-U01-L2', 1, { status: 'needs_change', comment: 'Use the polite form' }),
      row('W003', 'S1-U01-L2', 2, { confidence: 'low' }),
    ],
  )
}

/** The workbook's tabs with a few rows, as the Excel reader gives them. */
export function smallWorkbook(): Sheet[] {
  const fill = (headers: string[], values: Record<string, unknown>) => headers.map((h) => values[h] ?? null)
  return [
    {
      sheet: 'Plan',
      data: [
        PLAN_HEADERS,
        fill(PLAN_HEADERS, { 'Lesson ID': 'S0-U00-L1', Section: 'Section 0 · Sounds & writing', 'Skill #': 0, Skill: 'Sounds', 'Lesson #': 1, Lesson: 'Vowels' }),
        fill(PLAN_HEADERS, { 'Lesson ID': 'S1-U01-L1', Section: 'Section 1 · First conversations', 'Skill #': 1, Skill: 'Greetings', 'Lesson #': 1, Lesson: 'Hello & goodbye' }),
      ],
    },
    {
      sheet: 'Words',
      data: [
        WORD_HEADERS,
        fill(WORD_HEADERS, { 'Word ID': 'W001', 'Lesson ID': 'S1-U01-L1', English: 'hello', 'Amharic (Fidel)': 'ሰላም', 'Amharic romanization': 'selam', 'Claude confidence: Amharic': 'High', 'Status: Amharic': 'Draft' }),
        fill(WORD_HEADERS, { 'Word ID': 'W002', 'Lesson ID': 'S1-U01-L1', English: 'goodbye', 'Status: Amharic': 'To do' }),
      ],
    },
    {
      sheet: 'Sentences',
      data: [
        SENTENCE_HEADERS,
        fill(SENTENCE_HEADERS, { 'Sentence ID': 'S001', 'Lesson ID': 'S1-U01-L1', English: 'Hello, goodbye', 'Amharic (Fidel)': 'ሰላም፣ ደህና ሁን', 'Amharic word to blank': 'ሰላም', 'Status: Amharic': 'Draft' }),
      ],
    },
  ]
}

export const UPLOADS = `${CURRICULUM}/audio/uploads`
export const STORE_PATH = '/am/curriculum/W003/0123456789ab.m4a'
export const PUBLIC_URL = `https://pub.example${STORE_PATH}`
export const rowPath = (ref: string) => `${CURRICULUM}/rows/${ref}`
export const exercisesPath = (lesson: string) => `${CURRICULUM}/lessons/${lesson}/exercises`
export const publishPath = (lesson: string) => `${CURRICULUM}/lessons/${lesson}/publish`

/** A lesson's state after something in it changed. */
function touched(curriculum: Curriculum, lesson: string): Curriculum {
  return {
    ...curriculum,
    entries: curriculum.entries.map((e) =>
      e.ref === lesson && e.publish_state === 'published' ? { ...e, publish_state: 'changed' } : e,
    ),
  }
}

/** The curriculum endpoints over `state`; a dry run counts every row as
 * new or unchanged, by ref. Edits check the version and send a recorded
 * row back to Draft when its words change, as the server does. */
export function serveCurriculum(
  server: FakeServer,
  state: { curriculum: Curriculum; exercises?: Record<string, DraftExercise[]> },
  refs = ['W001', 'W002', 'W003', 'S001'],
  lessons = ['S1-U01-L1', 'S1-U01-L2'],
) {
  const drafts = (state.exercises ??= {})
  for (const lesson of lessons) {
    server
      .on('GET', exercisesPath(lesson), () => ({ body: { exercises: drafts[lesson] ?? [] } }))
      .on('PUT', exercisesPath(lesson), (call: Call) => {
        const entry = state.curriculum.entries.find((e) => e.ref === lesson)!
        const c = entry.counts!
        if (!(c.rows > 0 && c.reviewed === c.rows && c.recorded === c.rows)) {
          return { status: 409, body: { error_code: 'lesson_not_ready', message: 'not ready', details: { reason: 'rows' } } }
        }
        drafts[lesson] = (call.body as { exercises: DraftExercise[] }).exercises
        state.curriculum = touched(
          {
            ...state.curriculum,
            entries: state.curriculum.entries.map((e) =>
              e.ref === lesson ? { ...e, exercise_count: drafts[lesson]!.length } : e,
            ),
          },
          lesson,
        )
        return { body: { exercises: drafts[lesson] } }
      })
      .on('POST', publishPath(lesson), () => {
        const first = !state.curriculum.entries.find((e) => e.ref === lesson)!.published_id
        state.curriculum = {
          ...state.curriculum,
          entries: state.curriculum.entries.map((e) =>
            e.ref === lesson ? { ...e, publish_state: 'published', published_id: `live-${lesson}` } : e,
          ),
        }
        return {
          body: {
            category_id: 'live-S1',
            skill_id: 'live-S1-U01',
            lesson_id: `live-${lesson}`,
            exercise_ids: (drafts[lesson] ?? []).map((_, i) => `ex-${i}`),
            created: first ? ['section', 'skill', 'lesson'] : [],
          },
        }
      })
  }

  for (const ref of refs) {
    server.on('PATCH', rowPath(ref), (call: Call) => {
      const { version, ...change } = call.body as { version: number } & Partial<CurriculumRow>
      const old = state.curriculum.rows.find((r) => r.ref === ref)!
      if (version !== old.version) {
        return {
          status: 409,
          body: { error_code: 'content_changed', message: 'changed', details: { current_version: old.version } },
        }
      }
      const reset = !!old.audio_url && ('text' in change || 'romanization' in change) && !('status' in change)
      const fresh: CurriculumRow = { ...old, ...change, ...(reset ? { status: 'draft' } : {}), version: old.version + 1 }
      state.curriculum = touched(
        curriculumOf(
          state.curriculum.entries,
          state.curriculum.rows.map((r) => (r.ref === ref ? fresh : r)),
        ),
        old.lesson_ref,
      )
      return { body: { row: fresh, reset_to_draft: reset } }
    })
  }
  server
    .on('POST', UPLOADS, (call: Call) => ({
      status: 201,
      body: {
        upload_url: `https://store.example${STORE_PATH}?X-Amz-Signature=abc`,
        method: 'PUT',
        headers: { 'Content-Type': (call.body as { content_type: string }).content_type },
        key: STORE_PATH.slice(1),
        public_url: PUBLIC_URL,
        expires_in: 600,
      },
    }))
    .on('PUT', STORE_PATH, { status: 200 })
    .on('GET', '/api/v1/admin/me', { body: { email: 'admin@example.com' } })
    .on('GET', CURRICULUM, () => ({ body: state.curriculum }))
    .on('PUT', CURRICULUM, (call: Call) => {
      const body = call.body as CurriculumImportRequest
      const have = new Set(state.curriculum.rows.map((r) => r.ref))
      const haveEntries = new Set(state.curriculum.entries.map((e) => e.ref))
      const added = body.rows.filter((r) => !have.has(r.ref)).length
      const addedEntries = body.entries.filter((e) => !haveEntries.has(e.ref)).length
      const result: CurriculumImportResult = {
        dry_run: call.query.includes('dry_run=true'),
        entries: { added: addedEntries, changed: 0, kept: 0, unchanged: body.entries.length - addedEntries },
        rows: { added, changed: 0, kept: 0, unchanged: body.rows.length - added },
        kept: [],
        missing_entries: [],
        missing_rows: [],
      }
      if (!result.dry_run) {
        state.curriculum = curriculumOf(
          [...state.curriculum.entries, ...body.entries.filter((e) => !haveEntries.has(e.ref)).map((e) => ({ ...e, counts: null }))],
          [
            ...state.curriculum.rows,
            ...body.rows
              .filter((r) => !have.has(r.ref))
              .map((r) => ({ ...r, audio_url: null, version: 1, updated_by: 'admin@example.com', updated_at: '2026-10-05T12:00:00Z' })),
          ],
        )
      }
      return { body: result }
    })
}
