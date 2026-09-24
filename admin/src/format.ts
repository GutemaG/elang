import type { BadgeTone } from './ui/Badge'

export function plural(n: number, word: string): string {
  return `${n} ${word}${n === 1 ? '' : 's'}`
}

// The languages Buna teaches or teaches from. Anything else shows its code.
const LANGUAGES: Record<string, { name: string; glyph: string }> = {
  am: { name: 'Amharic', glyph: 'አ' },
  ti: { name: 'Tigrinya', glyph: 'ት' },
  om: { name: 'Afaan Oromoo', glyph: 'O' },
  en: { name: 'English', glyph: 'En' },
}

export function languageName(code: string): string {
  return LANGUAGES[code]?.name ?? code
}

/** A letter of the language's own script, for the course tile. */
export function languageGlyph(code: string): string {
  return LANGUAGES[code]?.glyph ?? code.slice(0, 2).toUpperCase()
}

// CourseStatus in backend/app/domain/course.py.
const STATUSES: Record<string, { label: string; tone: BadgeTone }> = {
  available: { label: 'Available', tone: 'published' },
  coming_soon: { label: 'Coming soon', tone: 'draft' },
}

export function courseStatus(status: string): { label: string; tone: BadgeTone } {
  return STATUSES[status] ?? { label: status, tone: 'neutral' }
}
