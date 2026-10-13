// The Audio library (intent 029): every stored audio file, what uses it,
// the trash, and the backup export. Super admins only.

import { TYPE_INFO } from '../exercises/model'
import type { ExerciseType } from '../types'

export const LIBRARY = '/api/v1/admin/audio-files'
export const LIBRARY_EXPORT = `${LIBRARY}/export`
export const LIBRARY_TRASH = `${LIBRARY}/trash`
export const LIBRARY_RESTORE = `${LIBRARY}/trash/restore`
export const LIBRARY_DELETE = `${LIBRARY}/trash/delete`

export type UsePlace = 'exercise' | 'workbook' | 'sound' | 'sound_example'

export interface AudioUse {
  place: UsePlace
  language: string
  /** Where the use opens in this site, e.g. an exercise's editor. */
  admin_path: string
  course_id: string | null
  course_title: string | null
  section: string | null
  skill: string | null
  lesson: string | null
  exercise_id: string | null
  exercise_number: number | null
  exercise_type: string | null
  prompt: string | null
  text: string | null
  english: string | null
  letter: string | null
}

export interface AudioFile {
  key: string
  url: string
  size: number
  uploaded_at: string
  language: string
  source: 'recorded' | 'generated'
  status: 'in_use' | 'unused'
  /** Nothing uses it and it is more than a day old. */
  can_trash: boolean
  uses: AudioUse[]
}

export interface MissingAudio {
  key: string
  url: string
  uses: AudioUse[]
}

export interface TrashedAudio {
  key: string
  original_key: string
  size: number
  moved_at: string
}

export interface AudioLibrary {
  storage: 'r2' | 'local'
  totals: {
    files: number
    bytes: number
    in_use: number
    unused: number
    missing: number
    trash: number
    trash_bytes: number
  }
  files: AudioFile[]
  missing: MissingAudio[]
  trash: TrashedAudio[]
  external_links: number
  courses: { id: string; title: string; learning_language: string }[]
}

export interface ExportFile {
  zip_path: string
  key: string
  size: number
  download_url: string
}

export interface ExportRow {
  zip_path: string
  status: 'in_use' | 'unused' | 'missing'
  key: string
  url: string
  size: number | null
  uploaded_at: string | null
  use: AudioUse | null
}

export interface AudioExport {
  name: string
  files: ExportFile[]
  rows: ExportRow[]
}

export const typeLabel = (type: string | null) =>
  type ? (TYPE_INFO[type as ExerciseType]?.name ?? type) : ''

/** "English to Amharic › Greetings › Saying hi › Exercise 2 (Listening)". */
export function describeUse(use: AudioUse): string {
  if (use.place === 'exercise') {
    return [use.course_title, use.section, use.lesson, `Exercise ${use.exercise_number} (${typeLabel(use.exercise_type)})`]
      .filter(Boolean)
      .join(' › ')
  }
  if (use.place === 'workbook') {
    return [use.course_title, 'Workbook', use.lesson, use.english].filter(Boolean).join(' › ')
  }
  const what = use.place === 'sound' ? 'sound' : `example word${use.text ? ` ${use.text}` : ''}`
  return `Sounds › ${use.language} › ${use.letter ?? ''} ${what}`.replace(/\s+/g, ' ')
}

/** A use as a table cell: what it is, then where it sits. */
export function partsOfUse(use: AudioUse): { title: string; where: string } {
  if (use.place === 'exercise') {
    return {
      title: `Exercise ${use.exercise_number} · ${typeLabel(use.exercise_type)}`,
      where: [use.course_title, use.section, use.lesson].filter(Boolean).join(' › '),
    }
  }
  if (use.place === 'workbook') {
    return {
      title: `Workbook · ${use.english ?? use.text ?? ''}`.trim(),
      where: [use.course_title, use.lesson].filter(Boolean).join(' › '),
    }
  }
  return {
    title: use.place === 'sound' ? `Letter ${use.letter ?? ''}`.trim() : `Example word ${use.text ?? ''}`.trim(),
    where: `Sounds › ${use.language}${use.place === 'sound_example' && use.letter ? ` › ${use.letter}` : ''}`,
  }
}

/** "MP3", from a key's extension. */
export const formatOf = (key: string) => (key.includes('.') ? key.slice(key.lastIndexOf('.') + 1).toUpperCase() : '')

export const fileNameOf = (key: string) => key.slice(key.lastIndexOf('/') + 1)
export const folderOf = (key: string) => (key.includes('/') ? key.slice(0, key.lastIndexOf('/') + 1) : '')

export function formatBytes(bytes: number): string {
  if (bytes < 1024) return `${bytes} B`
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(bytes < 10 * 1024 ? 1 : 0)} KB`
  if (bytes < 1024 ** 3) return `${(bytes / 1024 ** 2).toFixed(1)} MB`
  return `${(bytes / 1024 ** 3).toFixed(2)} GB`
}
