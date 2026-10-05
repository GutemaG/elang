// The Sounds pages' rules, kept apart from the screens so they can be
// tested on their own: what a letter's state is, which file is which
// letter, and the CSV a chart is exported to and imported from.

import Papa from 'papaparse'

import type { ApiClient } from '../api'
import { routes } from '../tree/levels'
import { uploadThroughLink } from '../upload/link'
import type {
  AdminSoundChart,
  AdminSoundGroup,
  AdminSoundLetter,
  Localized,
  SoundLetterChange,
  SoundLetterKind,
  SoundLetterStatus,
} from '../types'

/** The app languages names and meanings are written in. */
export const APP_LANGUAGES = [
  { code: 'en', name: 'English' },
  { code: 'am', name: 'Amharic' },
  { code: 'om', name: 'Afaan Oromo' },
] as const

export const TEMPLATES = [
  {
    id: 'fidel',
    name: 'Fidel',
    description: 'The 34 families in their seven vowel orders, and the labialised letters: 260 letters.',
  },
  {
    id: 'qubee',
    name: 'Qubee',
    description: 'A to Z with the vowels marked, letter pairs and long vowels: 37 sounds.',
  },
  { id: 'empty', name: 'Empty', description: 'No letters yet; add each one yourself.' },
] as const

export const KIND_LABELS: Record<SoundLetterKind, string> = {
  vowel: 'Vowel',
  consonant: 'Consonant',
}

export const STATUS_LABELS: Record<SoundLetterStatus, string> = {
  draft: 'Draft',
  needs_review: 'Needs review',
  ready: 'Ready',
}

/** How a letter shows on the chart: its review state, or that it has no
 * recording yet, or that it plays another letter's. */
export type LetterState = SoundLetterStatus | 'no_audio' | 'same_sound'

export const STATE_LABELS: Record<LetterState, string> = {
  ...STATUS_LABELS,
  no_audio: 'No audio',
  same_sound: 'Same sound',
}

export function stateOf(letter: AdminSoundLetter): LetterState {
  if (letter.same_as_id) return 'same_sound'
  if (!letter.audio_url) return 'no_audio'
  return letter.status
}

/** A name in English, the fallback for every other language. */
export const englishOf = (names: Localized): string => names.en ?? Object.values(names)[0] ?? ''

export function lettersOf(chart: AdminSoundChart, group: string): AdminSoundLetter[] {
  return chart.letters.filter((x) => x.group === group)
}

/** The letters that still need a recording of their own, in chart order. */
export function needingRecording(chart: AdminSoundChart): AdminSoundLetter[] {
  return chart.letters.filter((x) => !x.same_as_id && !x.audio_url)
}

/** The rows of a grid group: `columns` letters at a time. */
export function rowsOf(group: AdminSoundGroup, letters: AdminSoundLetter[]): AdminSoundLetter[][] {
  const size = group.columns ?? letters.length
  const rows: AdminSoundLetter[][] = []
  for (let i = 0; i < letters.length; i += size) rows.push(letters.slice(i, i + size))
  return rows
}

/** Stores one recording for `language`'s chart and returns its address. */
export function uploadSound(api: ApiClient, language: string, clip: Blob, type: string): Promise<string> {
  return uploadThroughLink(api, routes.soundUploads(language), {}, clip, type, {
    notConfigured: 'This server has nowhere to store audio yet, so recordings can’t be uploaded. Paste a link instead.',
    store: 'audio store',
  })
}

// --- files to letters ------------------------------------------------------------

const norm = (text: string) => text.normalize('NFC').trim().toLowerCase()

/** The names a file may be given for a letter: its romanization (`hu`),
 * its glyph (`ሁ`), or one of the glyph's forms (`Dh` or `dh` for
 * "Dh dh"). Apostrophes may be left out (`ta` for `t'a`). */
function namesOf(letter: AdminSoundLetter): string[] {
  const names = [letter.romanization, letter.glyph, ...letter.glyph.split(/\s+/)]
  const all = names.map(norm).filter(Boolean)
  return [...new Set([...all, ...all.map((n) => n.replace(/'/g, ''))])]
}

export interface FileMatch {
  file: File
  /** The letter it will be saved to, or null when none or many fit. */
  letter: AdminSoundLetter | null
  /** Several letters share that name; the admin picks one. */
  ambiguous: boolean
}

/** Pairs each file with the letter its name means. Only letters with a
 * sound of their own can take one. */
export function matchFiles(files: File[], letters: AdminSoundLetter[]): FileMatch[] {
  const recordable = letters.filter((x) => !x.same_as_id)
  const byName = new Map<string, AdminSoundLetter[]>()
  for (const letter of recordable) {
    for (const name of namesOf(letter)) byName.set(name, [...(byName.get(name) ?? []), letter])
  }
  return files.map((file) => {
    const stem = norm(file.name.replace(/\.[^.]+$/, ''))
    const found = byName.get(stem) ?? byName.get(stem.replace(/'/g, '')) ?? []
    const unique = [...new Map(found.map((x) => [x.id, x])).values()]
    return { file, letter: unique.length === 1 ? unique[0]! : null, ambiguous: unique.length > 1 }
  })
}

/** The letters a search names, best first: an exact romanization or
 * glyph, then the same without apostrophes, then romanizations that start
 * with it, then any that contain it,
 * then English hints. Apostrophes may be left out, as in file names. An
 * empty search keeps every letter in chart order. */
export function searchLetters(letters: AdminSoundLetter[], query: string): AdminSoundLetter[] {
  const q = norm(query)
  if (!q) return letters
  const bare = q.replace(/'/g, '')
  const rank = (x: AdminSoundLetter): number => {
    const roman = norm(x.romanization)
    const romans = [roman, roman.replace(/'/g, '')]
    const glyphs = [norm(x.glyph), ...x.glyph.split(/\s+/).map(norm)]
    if (roman === q || glyphs.includes(q)) return 0
    if (romans.includes(bare)) return 1
    if (romans.some((r) => r.startsWith(bare))) return 2
    if (romans.some((r) => r.includes(bare)) || glyphs.some((g) => g.includes(q))) return 3
    if (norm(x.hint.en ?? '').includes(q)) return 4
    return -1
  }
  return letters
    .map((x, i) => ({ x, i, r: rank(x) }))
    .filter((m) => m.r >= 0)
    .sort((a, b) => a.r - b.r || a.i - b.i)
    .map((m) => m.x)
}

// --- CSV ---------------------------------------------------------------------------

/** The columns, in order. `id` ties a row to its letter; the rest are what
 * native speakers fill in. Recordings are uploaded, not typed. */
export const CSV_COLUMNS = [
  'id',
  'group',
  'glyph',
  'romanization',
  'kind',
  'hint_en',
  'hint_am',
  'hint_om',
  'example_word',
  'example_romanization',
  'meaning_en',
  'meaning_am',
  'meaning_om',
  'status',
  'recorded_by',
] as const

export function chartToCsv(chart: AdminSoundChart): string {
  const data = chart.letters.map((x) => [
    x.id,
    x.group,
    x.glyph,
    x.romanization,
    x.kind ?? '',
    x.hint.en ?? '',
    x.hint.am ?? '',
    x.hint.om ?? '',
    x.example_word ?? '',
    x.example_romanization ?? '',
    x.example_meaning.en ?? '',
    x.example_meaning.am ?? '',
    x.example_meaning.om ?? '',
    x.status,
    x.recorded_by ?? '',
  ])
  // The byte-order mark makes Excel read Ethiopic as UTF-8.
  return '\uFEFF' + Papa.unparse({ fields: [...CSV_COLUMNS], data }, { newline: '\r\n' })
}

export interface CsvResult {
  /** One change per row that differs from the chart. */
  changes: SoundLetterChange[]
  /** Rows that could not be used, by line number (the header is line 1). */
  problems: { line: number; message: string }[]
}

const localizedFrom = (row: Record<string, string>, prefix: string): Localized => {
  const out: Localized = {}
  for (const { code } of APP_LANGUAGES) {
    const value = (row[`${prefix}_${code}`] ?? '').trim()
    if (value) out[code] = value
  }
  return out
}

const sameLocalized = (a: Localized, b: Localized) => JSON.stringify(sortKeys(a)) === JSON.stringify(sortKeys(b))
const sortKeys = (o: Localized) => Object.fromEntries(Object.entries(o).sort(([x], [y]) => x.localeCompare(y)))
const orNull = (text: string | undefined) => (text ?? '').trim() || null

/** Reads an exported CSV back, as changes to the letters it names. Rows
 * are matched by `id`, or by `group` and `glyph` when the id is blank. A
 * blank cell clears that field. */
export function csvToChanges(text: string, chart: AdminSoundChart): CsvResult {
  const parsed = Papa.parse<Record<string, string>>(text.replace(/^\uFEFF/, ''), {
    header: true,
    skipEmptyLines: 'greedy',
    transformHeader: (h) => h.trim().toLowerCase(),
  })
  const problems: CsvResult['problems'] = []
  const missing = ['glyph', 'romanization'].filter((c) => !parsed.meta.fields?.includes(c))
  if (missing.length) {
    return { changes: [], problems: [{ line: 1, message: `The file has no ${missing.join(' or ')} column.` }] }
  }
  const fields = parsed.meta.fields ?? []
  // A column left out of the file leaves that field alone.
  const has = (prefix: string) => APP_LANGUAGES.some(({ code }) => fields.includes(`${prefix}_${code}`))
  const byId = new Map(chart.letters.map((x) => [x.id, x]))
  const byGlyph = new Map(chart.letters.map((x) => [`${x.group}\u0000${norm(x.glyph)}`, x]))
  const changes: SoundLetterChange[] = []

  parsed.data.forEach((row, index) => {
    const line = index + 2
    const id = (row.id ?? '').trim()
    const letter = id ? byId.get(id) : byGlyph.get(`${(row.group ?? '').trim()}\u0000${norm(row.glyph ?? '')}`)
    if (!letter) {
      problems.push({ line, message: id ? 'No letter in this chart has that id.' : 'No letter in that group has that glyph.' })
      return
    }
    const change: SoundLetterChange = { id: letter.id }
    const glyph = (row.glyph ?? '').trim()
    if (!glyph) {
      problems.push({ line, message: 'The glyph is empty.' })
      return
    }
    if (glyph !== letter.glyph) change.glyph = glyph
    const romanization = (row.romanization ?? '').trim()
    if (romanization !== letter.romanization) change.romanization = romanization
    if ('kind' in row) {
      const kind = orNull(row.kind)?.toLowerCase() ?? null
      if (kind !== null && !(kind in KIND_LABELS)) {
        problems.push({ line, message: `The kind must be vowel, consonant or blank, not “${row.kind!.trim()}”.` })
        return
      }
      if (kind !== letter.kind) change.kind = kind as SoundLetterKind | null
    }
    const hint = localizedFrom(row, 'hint')
    if (has('hint') && !sameLocalized(hint, letter.hint)) change.hint = hint
    const meaning = localizedFrom(row, 'meaning')
    if (has('meaning') && !sameLocalized(meaning, letter.example_meaning)) change.example_meaning = meaning
    if ('example_word' in row && orNull(row.example_word) !== letter.example_word) {
      change.example_word = orNull(row.example_word)
    }
    if ('example_romanization' in row && orNull(row.example_romanization) !== letter.example_romanization) {
      change.example_romanization = orNull(row.example_romanization)
    }
    if ('recorded_by' in row && orNull(row.recorded_by) !== letter.recorded_by) {
      change.recorded_by = orNull(row.recorded_by)
    }
    const status = (row.status ?? '').trim()
    if (status) {
      if (!(status in STATUS_LABELS)) {
        problems.push({ line, message: `The status must be draft, needs_review or ready, not “${status}”.` })
        return
      }
      if (status !== letter.status) change.status = status as SoundLetterStatus
    }
    if (Object.keys(change).length > 1) changes.push(change)
  })
  return { changes, problems }
}

/** The CSV file's name for a chart. */
export const csvName = (chart: AdminSoundChart) => `sounds-${chart.language}.csv`
