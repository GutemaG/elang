// A lesson's exercises from its rows (intent 025, bolt 086). Each one is
// written as a row of the lesson CSV import and built by its `rowToBody`,
// so generated and imported lessons follow the same rules and shuffles.
// Pure: the same rows always give the same exercises.

import { charactersOf, joinItems, seededShuffle, type CsvRow } from '../import/csvFormat'
import { rowToBody } from '../import/fromCsv'
import type { CurriculumEntry, CurriculumRow, DraftExercise, ExerciseBody } from '../types'

/** At most this many wrong options. */
const WRONG = 3

const EMPTY: CsvRow = {
  type: '',
  prompt: '',
  pronunciation: '',
  sentence: '',
  answer: '',
  answer_pronunciation: '',
  wrong: '',
  wrong_pronunciation: '',
  audio_url: '',
  descriptions: '',
}

/** What a generated exercise is, so generating again can find it. */
export const keyOf = (draft: DraftExercise): string | null => draft.generated?.key ?? null

const bodyOnly = ({ type, prompt, content, answer_key }: ExerciseBody): ExerciseBody =>
  ({ type, prompt, content, answer_key }) as ExerciseBody

function exercise(key: string, row: Partial<CsvRow>, vocabRef: string | null): DraftExercise {
  const body = rowToBody({ ...EMPTY, ...row })
  return { ...body, vocab_ref: vocabRef, generated: { key, ...body }, edited: false }
}

/** Other texts to choose from: this lesson's, then the skill's, then the
 * section's, in an order fixed by `seed`. */
function others(pool: CurriculumRow[][], not: string, seed: string): CurriculumRow[] {
  const seen = new Set([not])
  const out: CurriculumRow[] = []
  for (const group of pool) {
    for (const r of seededShuffle(group, seed)) {
      if (!r.text || seen.has(r.text)) continue
      seen.add(r.text)
      out.push(r)
    }
  }
  return out
}

const wrongOf = (rows: CurriculumRow[]) => ({
  wrong: joinItems(rows.map((r) => r.text!)),
  wrong_pronunciation: rows.every((r) => r.romanization) ? joinItems(rows.map((r) => r.romanization!)) : '',
})

/** The lesson's exercises from its rows. `entries` and `allRows` give the
 * skill and section the wrong options come from. Rows without text are
 * skipped (a ready lesson has none). */
export function generateExercises(lessonRef: string, entries: CurriculumEntry[], allRows: CurriculumRow[]): DraftExercise[] {
  const lesson = entries.find((e) => e.ref === lessonRef)
  const skill = entries.find((e) => e.ref === lesson?.parent_ref)
  const lessonsOf = (parent: string | undefined) => entries.filter((e) => e.kind === 'lesson' && e.parent_ref === parent).map((e) => e.ref)
  const skillsInSection = entries.filter((e) => e.kind === 'skill' && e.parent_ref === skill?.parent_ref).map((e) => e.ref)
  const skillLessons = new Set(lessonsOf(skill?.ref))
  const sectionLessons = new Set(skillsInSection.flatMap((s) => lessonsOf(s)))
  const filled = allRows.filter((r) => r.text)
  const rows = filled.filter((r) => r.lesson_ref === lessonRef).sort((a, b) => a.position - b.position)
  const words = rows.filter((r) => r.kind === 'word')
  const sentences = rows.filter((r) => r.kind === 'sentence')
  const poolOf = (kind: CurriculumRow['kind']) => [
    rows.filter((r) => r.kind === kind),
    filled.filter((r) => r.kind === kind && r.lesson_ref !== lessonRef && skillLessons.has(r.lesson_ref)),
    filled.filter((r) => r.kind === kind && !skillLessons.has(r.lesson_ref) && sectionLessons.has(r.lesson_ref)),
  ]
  const wordPool = poolOf('word')
  const sentencePool = poolOf('sentence')
  const out: DraftExercise[] = []

  for (const w of words) {
    const wrong = others(wordPool, w.text!, w.ref).slice(0, WRONG)
    if (wrong.length === 0) continue
    const answer = { answer: w.text!, answer_pronunciation: w.romanization ?? '', ...wrongOf(wrong) }
    out.push(exercise(`mc:${w.ref}`, { type: 'multiple_choice', prompt: `How do you say “${w.english}”?`, ...answer }, w.ref))
    if (w.audio_url) {
      out.push(
        exercise(`listen:${w.ref}`, { type: 'listening', prompt: 'What do you hear?', audio_url: w.audio_url, ...answer }, w.ref),
      )
    }
  }

  if (words.length >= 2) {
    const pairs = words.slice(0, 5)
    out.push(
      exercise(
        'pairs',
        {
          type: 'match_pairs',
          prompt: 'Match the pairs',
          answer: joinItems(pairs.map((w) => `${w.text}=${w.english}`)),
          answer_pronunciation: pairs.every((w) => w.romanization) ? joinItems(pairs.map((w) => `${w.romanization}=`)) : '',
        },
        null,
      ),
    )
  }

  for (const w of words) {
    const letters = charactersOf(w.text!)
    if (letters.length < 2 || letters.length > 10 || /\s/.test(w.text!.trim())) continue
    const extra = seededShuffle(
      [...new Set(words.filter((x) => x.ref !== w.ref).flatMap((x) => charactersOf(x.text!)))].filter((c) => !letters.includes(c)),
      w.ref,
    ).slice(0, 2)
    out.push(
      exercise(
        `spell:${w.ref}`,
        { type: 'spell_tiles', prompt: `Spell “${w.english}”`, answer: joinItems(letters), wrong: joinItems(extra) },
        w.ref,
      ),
    )
  }

  for (const s of sentences) {
    const tokens = s.text!.split(/\s+/).filter(Boolean)
    const spoken = s.romanization?.split(/\s+/).filter(Boolean) ?? []
    const extraWords = words.map((w) => w.text!).filter((t) => !tokens.includes(t) && !/\s/.test(t)).slice(0, 2)
    if (tokens.length >= 2) {
      out.push(
        exercise(
          `build:${s.ref}`,
          {
            type: 'sentence_construction',
            prompt: `Translate: “${s.english}”`,
            answer: joinItems(tokens),
            answer_pronunciation: spoken.length === tokens.length ? joinItems(spoken) : '',
            wrong: joinItems(extraWords),
          },
          null,
        ),
      )
    }
    const blank = s.blank?.trim()
    const at = blank ? s.text!.indexOf(blank) : -1
    const gapWrong = others(wordPool, blank ?? '', s.ref)
      .map((r) => r.text!)
      .filter((t) => t !== blank)
      .slice(0, WRONG)
    if (blank && at >= 0 && gapWrong.length > 0) {
      out.push(
        exercise(
          `gap:${s.ref}`,
          {
            type: 'gap_fill',
            prompt: `Fill in the gap: “${s.english}”`,
            sentence: `${s.text!.slice(0, at)}___${s.text!.slice(at + blank.length)}`,
            answer: blank,
            wrong: joinItems(gapWrong),
          },
          null,
        ),
      )
    }
    const wrongSentences = others(sentencePool, s.text!, s.ref).slice(0, WRONG)
    if (s.audio_url && wrongSentences.length > 0) {
      out.push(
        exercise(
          `listen:${s.ref}`,
          {
            type: 'listening',
            prompt: 'What do you hear?',
            audio_url: s.audio_url,
            answer: s.text!,
            answer_pronunciation: s.romanization ?? '',
            ...wrongOf(wrongSentences),
          },
          null,
        ),
      )
    }
  }
  return out
}

/** Generating again: fresh exercises, but an edited one stays in its
 * place. Returns the list to save and the keys of edits kept. */
export function regenerate(fresh: DraftExercise[], current: DraftExercise[]): { exercises: DraftExercise[]; kept: string[] } {
  const edited = new Map(current.filter((d) => d.edited && keyOf(d)).map((d) => [keyOf(d)!, d]))
  const kept: string[] = []
  const exercises = fresh.map((d) => {
    const mine = edited.get(keyOf(d)!)
    if (!mine) return d
    kept.push(keyOf(d)!)
    // Its generated copy is the new one, so Reset gives today's version.
    return { ...mine, generated: d.generated }
  })
  return { exercises, kept }
}

/** An edited exercise back as it was generated. */
export function reset(draft: DraftExercise): DraftExercise {
  if (!draft.generated) return draft
  return { ...bodyOnly(draft.generated), vocab_ref: draft.vocab_ref, generated: draft.generated, edited: false }
}

/** JSON with its keys sorted, so the same body always reads the same. */
function stable(value: unknown): string {
  return JSON.stringify(value, (_k, v: unknown) =>
    v && typeof v === 'object' && !Array.isArray(v)
      ? Object.fromEntries(Object.entries(v as Record<string, unknown>).sort(([a], [b]) => a.localeCompare(b)))
      : v,
  )
}

/** A draft after an edit: edited unless it is back to what was generated. */
export function edited(draft: DraftExercise, body: ExerciseBody): DraftExercise {
  const same = draft.generated !== null && stable(bodyOnly(draft.generated)) === stable(bodyOnly(body))
  return { ...bodyOnly(body), vocab_ref: draft.vocab_ref, generated: draft.generated, edited: !same }
}
