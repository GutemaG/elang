// The curriculum workbook (intent 025): reading its Plan, Words and
// Sentences tabs into what the backend stores, writing them back out, and
// adding up a course's progress. Pure, so the real workbook is tested
// directly.

import type {
  Curriculum,
  CurriculumConfidence,
  CurriculumCounts,
  CurriculumEntry,
  CurriculumImportEntry,
  CurriculumImportRow,
  CurriculumRow,
  CurriculumStatus,
} from '../types'

/** One tab as the Excel reader gives it: rows of cells. */
export interface Sheet {
  sheet: string
  data: unknown[][]
}

export interface WorkbookProblem {
  tab: string
  /** The spreadsheet's row number (the header is row 1); null for the tab. */
  row: number | null
  message: string
}

export interface ParsedWorkbook {
  entries: CurriculumImportEntry[]
  rows: CurriculumImportRow[]
  problems: WorkbookProblem[]
  /** Rows of Section 0 (sounds and writing), which the Sounds tab covers. */
  skipped: number
  /** Where each ref came from, to point at the server's problems. */
  where: Record<string, { tab: string; row: number }>
}

export const STATUS_LABELS: Record<CurriculumStatus, string> = {
  to_do: 'To do',
  draft: 'Draft',
  needs_change: 'Needs change',
  reviewed: 'Reviewed',
}

export const CONFIDENCE_LABELS: Record<CurriculumConfidence, string> = {
  high: 'High',
  medium: 'Medium',
  low: 'Low',
}

export const TABS = { plan: 'Plan', words: 'Words', sentences: 'Sentences' } as const

/** The workbook's headers, in its order. Both languages share the file. */
export const PLAN_HEADERS = [
  'Lesson ID',
  'Section',
  'Skill #',
  'Skill',
  'Lesson #',
  'Lesson',
  'Can-do goal (CEFR)',
  'Grammar: Amharic',
  'Grammar: Afaan Oromo',
]
export const WORD_HEADERS = [
  'Word ID',
  'Lesson ID',
  'Section',
  'Skill',
  'Lesson',
  'English',
  'Amharic (Fidel)',
  'Amharic romanization',
  'Afaan Oromo',
  'Notes',
  'Claude confidence: Amharic',
  'Claude confidence: Oromo',
  'Status: Amharic',
  'Status: Oromo',
  'Audio: Amharic',
  'Audio: Oromo',
  'Reviewer comments',
]
export const SENTENCE_HEADERS = [
  'Sentence ID',
  'Lesson ID',
  'Section',
  'Lesson',
  'English',
  'Amharic (Fidel)',
  'Amharic romanization',
  'Amharic word to blank',
  'Other accepted Amharic',
  'Afaan Oromo',
  'Oromo word to blank',
  'Other accepted Oromo',
  'Notes',
  'Claude confidence: Amharic',
  'Claude confidence: Oromo',
  'Status: Amharic',
  'Status: Oromo',
  'Audio: Amharic',
  'Audio: Oromo',
  'Reviewer comments',
]

interface LanguageColumns {
  name: string
  text: string
  romanization: string | null
  blank: string
  accepted: string
  confidence: string
  status: string
  audio: string
  grammar: string
}

/** Which columns a course reads, by its learning language. */
export const LANGUAGE_COLUMNS: Record<string, LanguageColumns> = {
  am: {
    name: 'Amharic',
    text: 'Amharic (Fidel)',
    romanization: 'Amharic romanization',
    blank: 'Amharic word to blank',
    accepted: 'Other accepted Amharic',
    confidence: 'Claude confidence: Amharic',
    status: 'Status: Amharic',
    audio: 'Audio: Amharic',
    grammar: 'Grammar: Amharic',
  },
  om: {
    name: 'Afaan Oromo',
    text: 'Afaan Oromo',
    // Qubee is the Latin alphabet: nothing to romanize.
    romanization: null,
    blank: 'Oromo word to blank',
    accepted: 'Other accepted Oromo',
    confidence: 'Claude confidence: Oromo',
    status: 'Status: Oromo',
    audio: 'Audio: Oromo',
    grammar: 'Grammar: Afaan Oromo',
  },
}

const LESSON_ID = /^S(\d+)-U(\d+)-L(\d+)$/

const fold = (text: string) => text.trim().toLowerCase().replace(/[\s-]+/g, ' ')

/** A cell as text: trimmed, or null when empty. */
function text(cell: unknown): string | null {
  if (cell === null || cell === undefined) return null
  if (cell instanceof Date) return cell.toISOString()
  const value = String(cell).trim()
  return value || null
}

function wholeNumber(cell: unknown): number | null {
  const value = typeof cell === 'number' ? cell : Number(text(cell))
  return Number.isInteger(value) && value >= 0 ? value : null
}

function labelOf<K extends string>(labels: Record<K, string>, cell: unknown): K | undefined {
  const value = text(cell)
  if (value === null) return undefined
  const wanted = fold(value)
  return (Object.keys(labels) as K[]).find((k) => fold(labels[k]) === wanted || fold(k.replace(/_/g, ' ')) === wanted)
}

/** A tab's rows as objects by header, with their spreadsheet row numbers. */
function readTab(
  sheets: Sheet[],
  tab: string,
  wanted: (string | null)[],
  problems: WorkbookProblem[],
): { row: number; get: (header: string) => unknown }[] | null {
  const sheet = sheets.find((s) => fold(s.sheet) === fold(tab))
  if (!sheet) {
    problems.push({ tab, row: null, message: `The workbook has no ${tab} tab.` })
    return null
  }
  const headers = (sheet.data[0] ?? []).map((h) => fold(text(h) ?? ''))
  const missing = wanted.filter((h): h is string => h !== null && !headers.includes(fold(h)))
  if (missing.length > 0) {
    const list = missing.map((h) => `“${h}”`).join(', ')
    problems.push({ tab, row: 1, message: `The ${tab} tab has no ${list} column.` })
    return null
  }
  return sheet.data
    .map((cells, i) => ({ cells, row: i + 1 }))
    .slice(1)
    .filter(({ cells }) => cells.some((c) => text(c) !== null))
    .map(({ cells, row }) => ({ row, get: (header: string) => cells[headers.indexOf(fold(header))] }))
}

/** Reads the workbook for one course language. */
export function parseWorkbook(sheets: Sheet[], language: string): ParsedWorkbook {
  const result: ParsedWorkbook = { entries: [], rows: [], problems: [], skipped: 0, where: {} }
  const cols = LANGUAGE_COLUMNS[language]
  if (!cols) {
    const known = Object.values(LANGUAGE_COLUMNS)
      .map((c) => c.name)
      .join(' and ')
    result.problems.push({
      tab: TABS.plan,
      row: null,
      message: `The workbook has columns for ${known} only, not this course's language (${language}).`,
    })
    return result
  }
  const problems = result.problems
  const plan = readTab(sheets, TABS.plan, ['Lesson ID', 'Section', 'Skill #', 'Skill', 'Lesson #', 'Lesson', 'Can-do goal (CEFR)', cols.grammar], problems)
  const rowColumns = [cols.text, cols.romanization, cols.confidence, cols.status, 'English', 'Lesson ID', 'Notes', 'Reviewer comments']
  const words = readTab(sheets, TABS.words, ['Word ID', ...rowColumns], problems)
  const sentences = readTab(sheets, TABS.sentences, ['Sentence ID', cols.blank, cols.accepted, ...rowColumns], problems)
  if (!plan || !words || !sentences) return result

  const seen = new Set<string>()
  const lessons = new Set<string>()
  for (const r of plan) {
    const id = text(r.get('Lesson ID'))
    const match = id ? LESSON_ID.exec(id) : null
    if (!id || !match) {
      problems.push({ tab: TABS.plan, row: r.row, message: `The Lesson ID “${id ?? ''}” is not like S1-U06-L1.` })
      continue
    }
    const section = Number(match[1])
    if (section === 0) {
      result.skipped += 1
      continue
    }
    const sectionRef = `S${match[1]}`
    const skillRef = id.replace(/-L\d+$/, '')
    if (!seen.has(sectionRef)) {
      seen.add(sectionRef)
      const sectionText = text(r.get('Section')) ?? `Section ${section}`
      const title = sectionText.includes('·') ? sectionText.split('·').slice(1).join('·').trim() : sectionText
      result.entries.push({ ref: sectionRef, kind: 'section', parent_ref: null, position: section, title, goal: null, grammar: null })
      result.where[sectionRef] = { tab: TABS.plan, row: r.row }
    }
    if (!seen.has(skillRef)) {
      seen.add(skillRef)
      result.entries.push({
        ref: skillRef,
        kind: 'skill',
        parent_ref: sectionRef,
        position: wholeNumber(r.get('Skill #')) ?? Number(match[2]),
        title: text(r.get('Skill')) ?? skillRef,
        goal: null,
        grammar: null,
      })
      result.where[skillRef] = { tab: TABS.plan, row: r.row }
    }
    if (lessons.has(id)) {
      problems.push({ tab: TABS.plan, row: r.row, message: `The lesson ${id} is in the plan twice.` })
      continue
    }
    lessons.add(id)
    result.entries.push({
      ref: id,
      kind: 'lesson',
      parent_ref: skillRef,
      position: wholeNumber(r.get('Lesson #')) ?? Number(match[3]),
      title: text(r.get('Lesson')) ?? id,
      goal: text(r.get('Can-do goal (CEFR)')),
      grammar: text(r.get(cols.grammar)),
    })
    result.where[id] = { tab: TABS.plan, row: r.row }
  }

  const byLesson = new Map<string, CurriculumImportRow[]>()
  const readRows = (tab: string, rows: typeof words, kind: 'word' | 'sentence') => {
    const idHeader = kind === 'word' ? 'Word ID' : 'Sentence ID'
    for (const r of rows) {
      const ref = text(r.get(idHeader))
      const lesson = text(r.get('Lesson ID'))
      if (lesson?.startsWith('S0-')) {
        result.skipped += 1
        continue
      }
      const before = problems.length
      if (!ref) problems.push({ tab, row: r.row, message: `The row has no ${idHeader}.` })
      if (!lesson || !lessons.has(lesson)) {
        problems.push({ tab, row: r.row, message: `The lesson “${lesson ?? ''}” is not in the Plan tab.` })
      }
      const status = text(r.get(cols.status)) === null ? 'to_do' : labelOf(STATUS_LABELS, r.get(cols.status))
      if (!status) {
        const shown = text(r.get(cols.status))
        problems.push({ tab, row: r.row, message: `The status must be To do, Draft, Needs change or Reviewed, not “${shown}”.` })
      }
      const confidenceCell = r.get(cols.confidence)
      const confidence = text(confidenceCell) === null ? null : labelOf(CONFIDENCE_LABELS, confidenceCell)
      if (confidence === undefined) {
        const shown = text(confidenceCell)
        problems.push({ tab, row: r.row, message: `The confidence must be High, Medium, Low or blank, not “${shown}”.` })
      }
      if (problems.length > before || !ref || !lesson || !status || confidence === undefined) continue
      const row: CurriculumImportRow = {
        ref,
        kind,
        lesson_ref: lesson,
        position: 0,
        english: text(r.get('English')) ?? '',
        text: text(r.get(cols.text)),
        romanization: cols.romanization ? text(r.get(cols.romanization)) : null,
        blank: kind === 'sentence' ? text(r.get(cols.blank)) : null,
        accepted:
          kind === 'sentence'
            ? (text(r.get(cols.accepted)) ?? '')
                .split('|')
                .map((a) => a.trim())
                .filter(Boolean)
            : [],
        notes: text(r.get('Notes')),
        confidence,
        status,
        comment: text(r.get('Reviewer comments')),
      }
      result.where[ref] = { tab, row: r.row }
      byLesson.set(lesson, [...(byLesson.get(lesson) ?? []), row])
    }
  }
  readRows(TABS.words, words, 'word')
  readRows(TABS.sentences, sentences, 'sentence')
  // A lesson's words in file order, then its sentence.
  for (const rows of byLesson.values()) {
    rows.sort((a, b) => (a.kind === b.kind ? 0 : a.kind === 'word' ? -1 : 1))
    rows.forEach((row, i) => {
      row.position = i + 1
      result.rows.push(row)
    })
  }
  return result
}

/** Where the server's problem points, in the workbook's terms. */
export function locate(parsed: ParsedWorkbook, problem: { ref: string; field: string; message: string }): WorkbookProblem {
  const at = parsed.where[problem.ref]
  return { tab: at?.tab ?? TABS.plan, row: at?.row ?? null, message: `${problem.ref}: ${problem.message}` }
}

// --- writing it back out ---------------------------------------------------------

type Cell = string | number | null

/** The course's curriculum as the workbook's three tabs, with this
 * language's columns filled and the other's left empty. */
export function curriculumToSheets(curriculum: Curriculum): { sheet: string; data: Cell[][] }[] {
  const cols = LANGUAGE_COLUMNS[curriculum.language]
  const byRef = new Map(curriculum.entries.map((e) => [e.ref, e]))
  const sectionNumber = (ref: string | null) => {
    const entry = ref ? byRef.get(ref) : undefined
    const match = entry ? /^S(\d+)$/.exec(entry.ref) : null
    return match ? Number(match[1]) : (entry?.position ?? null)
  }
  const fill = (headers: string[], values: Record<string, Cell>): Cell[] =>
    headers.map((h) => (h in values ? values[h]! : null))
  const lessons = orderedLessons(curriculum.entries)

  const plan = lessons.map(({ lesson, skill, section }) =>
    fill(PLAN_HEADERS, {
      'Lesson ID': lesson.ref,
      Section: section ? `Section ${sectionNumber(section.ref)} · ${section.title}` : null,
      'Skill #': skill?.position ?? null,
      Skill: skill?.title ?? null,
      'Lesson #': lesson.position,
      Lesson: lesson.title,
      'Can-do goal (CEFR)': lesson.goal,
      ...(cols ? { [cols.grammar]: lesson.grammar } : {}),
    }),
  )
  const order = new Map(lessons.map(({ lesson }, i) => [lesson.ref, i]))
  const rows = [...curriculum.rows].sort(
    (a, b) => (order.get(a.lesson_ref) ?? 0) - (order.get(b.lesson_ref) ?? 0) || a.position - b.position,
  )
  const common = (r: CurriculumRow): Record<string, Cell> => {
    const lesson = byRef.get(r.lesson_ref)
    const skill = lesson?.parent_ref ? byRef.get(lesson.parent_ref) : undefined
    return {
      'Lesson ID': r.lesson_ref,
      Section: sectionNumber(skill?.parent_ref ?? null),
      Skill: skill?.title ?? null,
      Lesson: lesson?.title ?? null,
      English: r.english,
      Notes: r.notes,
      'Reviewer comments': r.comment,
      ...(cols
        ? {
            [cols.text]: r.text,
            ...(cols.romanization ? { [cols.romanization]: r.romanization } : {}),
            [cols.confidence]: r.confidence ? CONFIDENCE_LABELS[r.confidence] : null,
            [cols.status]: STATUS_LABELS[r.status],
            [cols.audio]: r.audio_url ? 'Y' : 'N',
          }
        : {}),
    }
  }
  const words = rows.filter((r) => r.kind === 'word').map((r) => fill(WORD_HEADERS, { 'Word ID': r.ref, ...common(r) }))
  const sentences = rows
    .filter((r) => r.kind === 'sentence')
    .map((r) =>
      fill(SENTENCE_HEADERS, {
        'Sentence ID': r.ref,
        ...common(r),
        ...(cols ? { [cols.blank]: r.blank, [cols.accepted]: r.accepted.join(' | ') || null } : {}),
      }),
    )
  return [
    { sheet: TABS.plan, data: [PLAN_HEADERS, ...plan] },
    { sheet: TABS.words, data: [WORD_HEADERS, ...words] },
    { sheet: TABS.sentences, data: [SENTENCE_HEADERS, ...sentences] },
  ]
}

// --- the outline and its progress ---------------------------------------------------

export interface LessonLine {
  lesson: CurriculumEntry
  skill: CurriculumEntry | undefined
  section: CurriculumEntry | undefined
}

const byPosition = (a: CurriculumEntry, b: CurriculumEntry) => a.position - b.position || a.ref.localeCompare(b.ref)

/** Every lesson in course order: by section, then skill, then lesson. */
export function orderedLessons(entries: CurriculumEntry[]): LessonLine[] {
  return outline(entries).flatMap((s) =>
    s.skills.flatMap((k) => k.lessons.map((lesson) => ({ lesson, skill: k.skill, section: s.section }))),
  )
}

export interface SkillNode {
  skill: CurriculumEntry
  lessons: CurriculumEntry[]
}

export interface SectionNode {
  section: CurriculumEntry
  skills: SkillNode[]
}

export function outline(entries: CurriculumEntry[]): SectionNode[] {
  const children = (ref: string, kind: CurriculumEntry['kind']) =>
    entries.filter((e) => e.kind === kind && e.parent_ref === ref).sort(byPosition)
  return entries
    .filter((e) => e.kind === 'section')
    .sort(byPosition)
    .map((section) => ({
      section,
      skills: children(section.ref, 'skill').map((skill) => ({ skill, lessons: children(skill.ref, 'lesson') })),
    }))
}

export const NO_COUNTS: CurriculumCounts = { rows: 0, filled: 0, reviewed: 0, recorded: 0, needs_change: 0 }

export function sumCounts(lessons: CurriculumEntry[]): CurriculumCounts {
  return lessons.reduce(
    (sum, l) => {
      const c = l.counts ?? NO_COUNTS
      return {
        rows: sum.rows + c.rows,
        filled: sum.filled + c.filled,
        reviewed: sum.reviewed + c.reviewed,
        recorded: sum.recorded + c.recorded,
        needs_change: sum.needs_change + c.needs_change,
      }
    },
    { ...NO_COUNTS },
  )
}

/** Every row reviewed and recorded, and there is at least one. */
export const isReady = (c: CurriculumCounts | null): boolean =>
  !!c && c.rows > 0 && c.reviewed === c.rows && c.recorded === c.rows

/** A file name for the export: the course's title, letters and digits. */
export function workbookName(title: string): string {
  const stem = title
    .trim()
    .replace(/[^\p{L}\p{N}]+/gu, '-')
    .replace(/^-+|-+$/g, '')
  return `${stem || 'curriculum'}-workbook.xlsx`
}
