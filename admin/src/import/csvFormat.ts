// The CSV layout for importing and exporting a lesson's exercises (bolt
// 056): one row per exercise, the same columns for every type. What each
// column holds per type is in `fromCsv.ts`; the help panel and the template
// show it too.

import Papa from 'papaparse'

import { TYPE_INFO } from '../exercises/model'
import { EXERCISE_TYPES, type ExerciseType } from '../types'

export const COLUMNS = ['type', 'prompt', 'sentence', 'answer', 'wrong', 'audio_url', 'descriptions'] as const
export type Column = (typeof COLUMNS)[number]
export type CsvRow = Record<Column, string>

/** Three or more underscores: the gap in a gap fill's sentence. */
export const GAP = /_{3,}/g

/** A header as written ("Audio URL", " Prompt ") to its column name
 * (`audio_url`, `prompt`), or null for one we don't know. */
export function columnOf(header: string): Column | null {
  const name = header
    .trim()
    .toLowerCase()
    .replace(/[\s-]+/g, '_')
  return (COLUMNS as readonly string[]).includes(name) ? (name as Column) : null
}

/** The type named in a cell: its key (`gap_fill`) or the name the admin
 * site shows ("Gap fill"), in any case. */
export function typeOf(cell: string): ExerciseType | null {
  const wanted = cell.trim().toLowerCase()
  return (
    EXERCISE_TYPES.find((t) => t === wanted.replace(/[\s-]+/g, '_') || TYPE_INFO[t].name.toLowerCase() === wanted) ??
    null
  )
}

/** A cell's items, split on `|` (`\|` is a literal `|`), trimmed. Empty
 * items are dropped, unless `keepEmpty`, where their place matters. */
export function splitItems(cell: string, { keepEmpty = false } = {}): string[] {
  if (!cell.trim()) return []
  const items = cell.split(/(?<!\\)\|/).map((item) => item.replaceAll('\\|', '|').trim())
  return keepEmpty ? items : items.filter(Boolean)
}

/** The reverse of `splitItems`. */
export function joinItems(items: readonly string[]): string {
  return items.map((item) => item.replaceAll('|', '\\|')).join(' | ')
}

/** A word's tiles, one per character as a reader sees it (ቡ is one, even
 * with a combining mark), spaces left out. */
export function charactersOf(word: string): string[] {
  const text = word.replace(/\s+/g, '')
  if (typeof Intl !== 'undefined' && 'Segmenter' in Intl) {
    return [...new Intl.Segmenter(undefined, { granularity: 'grapheme' }).segment(text)].map((s) => s.segment)
  }
  return Array.from(text)
}

/** `items` in an order that depends only on `seed`: the same file always
 * gives the same order, and the answer is not always first. */
export function seededShuffle<T>(items: readonly T[], seed: string): T[] {
  // FNV-1a to seed mulberry32, then Fisher–Yates.
  let hash = 2166136261
  for (let i = 0; i < seed.length; i++) {
    hash ^= seed.charCodeAt(i)
    hash = Math.imul(hash, 16777619)
  }
  let state = hash >>> 0
  const random = () => {
    state = (state + 0x6d2b79f5) >>> 0
    let t = state
    t = Math.imul(t ^ (t >>> 15), t | 1)
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61)
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296
  }
  const out = [...items]
  for (let i = out.length - 1; i > 0; i--) {
    const j = Math.floor(random() * (i + 1))
    const kept = out[i]!
    out[i] = out[j]!
    out[j] = kept
  }
  return out
}

/** A byte-order mark, so Excel reads the file as UTF-8 and keeps Amharic. */
const BOM = '\uFEFF'

/** Rows to CSV text, with every column, in order. */
export function writeCsv(rows: readonly Partial<CsvRow>[]): string {
  const data = rows.map((row) => COLUMNS.map((c) => row[c] ?? ''))
  return BOM + Papa.unparse({ fields: [...COLUMNS], data }, { newline: '\r\n' })
}
