import type { BadgeTone } from './ui/Badge'

export function plural(n: number, word: string): string {
  return `${n} ${word}${n === 1 ? '' : 's'}`
}

/** The first letter of a language's own name, in its own script (አ for
 * አማርኛ), for a course or language tile -- the same letter the app shows. */
export function languageGlyph(nativeName: string): string {
  return Array.from(nativeName.trim())[0] ?? '?'
}

/** "Amharic for English speakers". */
export function courseAudience(course: {
  learning_language_name: string
  from_language_name: string
}): string {
  return `${course.learning_language_name} for ${course.from_language_name} speakers`
}

// CourseStatus in backend/app/domain/course.py.
const STATUSES: Record<string, { label: string; tone: BadgeTone }> = {
  available: { label: 'Available', tone: 'published' },
  coming_soon: { label: 'Coming soon', tone: 'draft' },
}

export function courseStatus(status: string): { label: string; tone: BadgeTone } {
  return STATUSES[status] ?? { label: status, tone: 'neutral' }
}
