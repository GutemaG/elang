// Shapes of the admin API, mirrored from backend/app/infrastructure/api/
// admin_schemas.py (and AuthResponse from schemas.py). Keep them in step.

export interface AuthResponse {
  session_token: string
  expires_at: string
}

export interface AdminMe {
  email: string
}

export interface AdminCourse {
  id: string
  title: string
  learning_language: string
  from_language: string
  /** Each language's name and its own name, from the languages table. */
  learning_language_name: string
  learning_language_native_name: string
  from_language_name: string
  from_language_native_name: string
  status: string
  section_count: number
}

export interface AdminCourseList {
  courses: AdminCourse[]
}

/** A language courses can teach or teach from; `course_count` courses use it. */
export interface AdminLanguage {
  code: string
  name: string
  native_name: string
  course_count: number
}

export interface AdminLanguageList {
  languages: AdminLanguage[]
}

/** Exercises with a clip only (listening and audio image choice): the
 * piano placeholder, a hosted https clip, or a local-backend `/media` clip. */
export type AudioStatus = 'placeholder' | 'hosted' | 'local'

export interface AdminTreeExercise {
  id: string
  order_index: number
  type: string
  prompt: string
  audio: AudioStatus | null
}

export interface AdminTreeLesson {
  id: string
  title: string
  order_index: number
  exercise_count: number
  exercises: AdminTreeExercise[]
}

export interface AdminTreeSkill {
  id: string
  title: string
  order_index: number
  lesson_count: number
  lessons: AdminTreeLesson[]
}

export interface AdminTreeSection {
  id: string
  title: string
  subtitle: string
  order_index: number
  skill_count: number
  skills: AdminTreeSkill[]
}

export interface AdminCourseTree {
  course: AdminCourse
  sections: AdminTreeSection[]
}

/** A section, skill or lesson after a write. */
export interface AdminNode {
  id: string
  title: string
  subtitle: string | null
  order_index: number
}

/** `details` of a refused or unconfirmed delete. */
export interface DeleteDetails {
  skills: number
  lessons: number
  exercises: number
  learners?: number
}

// --- Exercises (bolt 038), mirroring backend/app/domain/lesson/exercise_parts.py

/** A choice, word, letter or match-pairs tile. `id` is identity; `text` is
 * only what is shown, and may repeat (two tiles can both read "ላ").
 * `pronunciation` is the text in Latin letters (ቡና → bunna), shown under it
 * in the app; left out when there is none. */
export interface Tile {
  id: string
  text: string
  pronunciation?: string
}

/** The question's own word or sentence in Latin letters, shown under it in
 * the app. Not on a question that is only heard. */
interface Pronounced {
  pronunciation?: string
}

/** One picture of a picture question (bolt 050): `image_url` is an https
 * address, or a local-backend `/media/images/...` path; `alt_text` says
 * what it shows, for learners who can't see it. */
export interface PictureTile {
  id: string
  image_url: string
  alt_text: string
}

export type ExerciseType =
  | 'multiple_choice'
  | 'listening'
  | 'sentence_construction'
  | 'match_pairs'
  | 'gap_fill'
  | 'spell_tiles'
  | 'image_choice'
  | 'audio_image_choice'

export const EXERCISE_TYPES: readonly ExerciseType[] = [
  'multiple_choice',
  'listening',
  'gap_fill',
  'sentence_construction',
  'spell_tiles',
  'match_pairs',
  'image_choice',
  'audio_image_choice',
]

interface ChoiceKey {
  correct_choice_id: string
}

interface SequenceKey {
  correct_sequence: string[]
}

/** The type, prompt, content and answer key an exercise is written as --
 * exactly what `POST`/`PUT` send and what the server stores. */
export type ExerciseBody =
  | { type: 'multiple_choice'; prompt: string; content: { choices: Tile[] } & Pronounced; answer_key: ChoiceKey }
  | {
      type: 'listening'
      prompt: string
      content: { audio_url: string; choices: Tile[] }
      answer_key: ChoiceKey
    }
  | {
      type: 'gap_fill'
      prompt: string
      content: { sentence_before: string; sentence_after: string; choices: Tile[] } & Pronounced
      answer_key: ChoiceKey
    }
  | {
      type: 'sentence_construction'
      prompt: string
      content: { word_bank: Tile[] } & Pronounced
      answer_key: SequenceKey
    }
  | { type: 'spell_tiles'; prompt: string; content: { tiles: Tile[] } & Pronounced; answer_key: SequenceKey }
  | {
      type: 'match_pairs'
      prompt: string
      content: { left_tiles: Tile[]; right_tiles: Tile[] } & Pronounced
      answer_key: { correct_pairs: [string, string][] }
    }
  | {
      type: 'image_choice'
      prompt: string
      content: { choices: PictureTile[] } & Pronounced
      answer_key: ChoiceKey
    }
  | {
      type: 'audio_image_choice'
      prompt: string
      content: { audio_url: string; choices: PictureTile[] }
      answer_key: ChoiceKey
    }

export type AdminExercise = ExerciseBody & {
  id: string
  lesson_id: string
  order_index: number
  vocab_item_id: string | null
}

export interface AdminExerciseList {
  exercises: AdminExercise[]
}

// --- Vocabulary (bolt 040)

/** One exercise that practises a word, and where it sits: `number` is its
 * lesson's place in the course as the tree numbers it ("5.1.1"). */
export interface AdminVocabUse {
  exercise_id: string
  type: string
  prompt: string
  lesson_id: string
  number: string
  section_title: string
  skill_title: string
  lesson_title: string
}

/** A word Practice tracks. `learners` have spaced-repetition progress on it;
 * editing the text keeps that progress. */
export interface AdminVocabItem {
  id: string
  word: string
  translation: string
  learners: number
  used_by: AdminVocabUse[]
}

/** A course's words in curriculum order, unused ones last; `learners` is
 * the number of distinct learners practising any of them. */
export interface AdminVocabList {
  course: AdminCourse
  items: AdminVocabItem[]
  learners: number
}

/** A short-lived link for uploading one clip (bolt 036): PUT the file to
 * `upload_url` with exactly `headers`, then save `public_url` as the
 * exercise's `audio_url`. `public_url` is a relative `/media/...` path when
 * the local backend is the store (bolt 041). */
export interface AudioUploadResponse {
  upload_url: string
  method: 'PUT'
  headers: Record<string, string>
  key: string
  public_url: string
  expires_in: number
}

/** A short-lived link for uploading one picture (bolt 050): the same shape
 * as a clip's, with `public_url` saved as a choice's `image_url`. */
export type ImageUploadResponse = AudioUploadResponse

/** A pasted link the server has checked answers with audio. */
export interface AudioLinkResponse {
  url: string
  content_type: string
}

// --- learners and reports (026-learner-reports) ------------------------------

/** A learner with their all-time totals. `accuracy` is 0 to 1, null before
 * any answer; `current_streak` is 0 once the streak has lapsed. */
export interface AdminLearner {
  id: string
  name: string
  email: string | null
  joined_at: string
  course_id: string
  course_title: string
  lessons: number
  practice_sessions: number
  xp: number
  accuracy: number | null
  skills_completed: number
  current_streak: number
  last_active_at: string | null
}

/** One page of the learners matching a search; the counts cover them all. */
export interface AdminLearnerPage {
  learners: AdminLearner[]
  total: number
  active_today: number
  active_7_days: number
  not_started: number
}

export interface AdminDayActivity {
  date: string
  lessons: number
  practice_sessions: number
  xp: number
}

export type SkillState = 'completed' | 'started' | 'not_started'

export interface AdminSkillProgress {
  id: string
  title: string
  state: SkillState
  crown_level: number
  lessons_total: number
  lessons_done: number
}

export interface AdminCourseProgress {
  course_id: string
  title: string
  /** The course the learner is on now. */
  current: boolean
  skills_total: number
  skills_completed: number
  lessons_total: number
  lessons_done: number
  sections: { id: string; title: string; skills: AdminSkillProgress[] }[]
}

export interface AdminRecentAttempt {
  kind: 'lesson' | 'practice'
  at: string
  lesson_title: string | null
  skill_title: string | null
  course_title: string | null
  correct: number
  answered: number
  xp: number
}

/** One learner: `activity` holds only the days they studied, from the last
 * thirteen weeks. */
export interface AdminLearnerDetail {
  learner: AdminLearner
  auth_provider: string
  daily_xp_target: number
  longest_streak: number
  days_active: number
  activity: AdminDayActivity[]
  courses: AdminCourseProgress[]
  recent: AdminRecentAttempt[]
}

export type ReportPeriod = 'day' | 'week' | 'month'

export interface AdminTotals {
  new_learners: number
  active_learners: number
  lessons: number
  practice_sessions: number
  xp: number
  accuracy: number | null
  skills_completed: number
}

/** A day, a week (from Monday) or a month; `partial` while it is still
 * going on. Dates are UTC days, `YYYY-MM-DD`, both ends included. */
export interface AdminBucket {
  start: string
  end: string
  partial: boolean
  totals: AdminTotals
}

export interface AdminReport {
  period: ReportPeriod
  course_id: string | null
  start: string
  end: string
  totals: AdminTotals
  /** The same number of days, weeks or months just before. */
  previous: AdminTotals
  buckets: AdminBucket[]
  now: { total_learners: number; active_today: number; active_7_days: number; active_30_days: number }
  courses: {
    course_id: string
    title: string
    learners: number
    active_learners: number
    lessons: number
    xp: number
    skills_completed: number
  }[]
  top_learners: { id: string; name: string; email: string | null; xp: number; lessons: number; accuracy: number | null }[]
}

// Learner feedback (027-learner-feedback): sent from the app's Settings.
export type FeedbackCategory = 'bug' | 'idea' | 'content' | 'other'
export type FeedbackStatus = 'open' | 'resolved'

export interface AdminFeedbackItem {
  id: string
  category: FeedbackCategory
  /** 1 to 5, or null when the learner skipped it. */
  rating: number | null
  message: string
  status: FeedbackStatus
  platform: string | null
  created_at: string
  resolved_at: string | null
  learner_id: string
  learner_name: string
  learner_email: string | null
  course_id: string | null
  course_title: string | null
}

export interface AdminFeedbackPage {
  items: AdminFeedbackItem[]
  /** How many match the filters; the rest count all feedback. */
  total: number
  open: number
  resolved: number
  rated: number
  average_rating: number | null
  open_by_category: Record<FeedbackCategory, number>
}

/** What `GET /api/v1/config` sends the app: the builds it checks itself
 * against for updates (`backend/app/domain/settings.py`). */
export interface AdminAppConfig {
  /** The oldest Android build (versionCode) still allowed to run. */
  min_build_android: number
  /** The oldest iOS build still allowed to run. */
  min_build_ios: number
  /** The newest iOS build in the App Store, offered to older ones. */
  latest_build_ios: number
  /** The App Store page iOS updates open; "" until listed. */
  ios_store_url: string
}

export interface AdminAppConfigResponse {
  config: AdminAppConfig
}

// --- Sounds charts (`backend/app/infrastructure/api/sound_schemas.py`) ---

/** Text by app language: `en` always, `am` and `om` when translated. */
export type Localized = Partial<Record<string, string>>

export type SoundLetterStatus = 'draft' | 'needs_review' | 'ready'

export interface AdminSoundCounts {
  letters: number
  ready: number
  needs_review: number
  draft: number
  /** Letters that need a recording of their own and have none. */
  needs_recording: number
  /** Letters that play another letter's recording. */
  same_sound: number
}

/** What stops the chart being shown to learners. */
export interface AdminSoundGaps {
  no_letters: boolean
  no_romanization: number
  no_audio: number
}

export interface AdminSoundGroup {
  key: string
  names: Localized
  /** Set for a grid: that many letters to a row, under `column_labels`. */
  columns: number | null
  column_labels: string[]
}

export type SoundLetterKind = 'vowel' | 'consonant'

export interface AdminSoundLetter {
  id: string
  group: string
  position: number
  glyph: string
  romanization: string
  /** Shown by colour in the app; null when unmarked. */
  kind: SoundLetterKind | null
  hint: Localized
  audio_url: string | null
  same_as_id: string | null
  example_word: string | null
  example_romanization: string | null
  example_meaning: Localized
  example_audio_url: string | null
  status: SoundLetterStatus
  recorded_by: string | null
  updated_at: string
}

export interface AdminSoundChartSummary {
  language: string
  language_name: string
  title: Localized
  enabled: boolean
  version: number
  updated_at: string
  counts: AdminSoundCounts
  gaps: AdminSoundGaps
}

export interface AdminSoundChartList {
  charts: AdminSoundChartSummary[]
}

export interface AdminSoundChart extends AdminSoundChartSummary {
  groups: AdminSoundGroup[]
  letters: AdminSoundLetter[]
}

/** One letter's changes for `PATCH .../letters`: only the fields given
 * change, and `null` clears one. */
export type SoundLetterChange = { id: string } & Partial<Omit<AdminSoundLetter, 'id' | 'group' | 'position' | 'updated_at'>>

// --- Workbook (intent 025): a course's draft curriculum -----------------------

export type CurriculumEntryKind = 'section' | 'skill' | 'lesson'
export type CurriculumRowKind = 'word' | 'sentence'
export type CurriculumStatus = 'to_do' | 'draft' | 'needs_change' | 'reviewed'
export type CurriculumConfidence = 'high' | 'medium' | 'low'

export interface CurriculumCounts {
  rows: number
  /** Rows with their text in the course's language. */
  filled: number
  reviewed: number
  /** Rows with a recording. */
  recorded: number
  needs_change: number
}

export type CurriculumPublishState = 'not_published' | 'published' | 'changed'

export interface CurriculumEntry {
  ref: string
  kind: CurriculumEntryKind
  parent_ref: string | null
  position: number
  title: string
  goal: string | null
  grammar: string | null
  /** A lesson's rows counted; null for a section or skill. */
  counts: CurriculumCounts | null
  /** The live section, skill or lesson published from it (bolt 085). */
  published_id?: string | null
  published_at?: string | null
  /** A lesson's: since publishing, has anything changed? */
  publish_state?: CurriculumPublishState | null
  exercise_count?: number | null
}

export interface CurriculumRow {
  ref: string
  kind: CurriculumRowKind
  lesson_ref: string
  position: number
  english: string
  text: string | null
  romanization: string | null
  blank: string | null
  accepted: string[]
  notes: string | null
  confidence: CurriculumConfidence | null
  status: CurriculumStatus
  comment: string | null
  audio_url: string | null
  /** Sent back with an edit; an older one is `409 content_changed`. */
  version: number
  updated_by: string | null
  updated_at: string
}

export interface Curriculum {
  course_id: string
  course_title: string
  language: string
  entries: CurriculumEntry[]
  rows: CurriculumRow[]
  counts: CurriculumCounts
}

/** What an import sends: the plan and rows, without what the server keeps. */
export type CurriculumImportEntry = Omit<
  CurriculumEntry,
  'counts' | 'published_id' | 'published_at' | 'publish_state' | 'exercise_count'
>
export type CurriculumImportRow = Omit<CurriculumRow, 'audio_url' | 'version' | 'updated_by' | 'updated_at'>

export interface CurriculumImportRequest {
  entries: CurriculumImportEntry[]
  rows: CurriculumImportRow[]
  overwrite_reviewed: boolean
}

export interface CurriculumImportTally {
  added: number
  changed: number
  kept: number
  unchanged: number
}

export interface CurriculumImportResult {
  dry_run: boolean
  entries: CurriculumImportTally
  rows: CurriculumImportTally
  /** Rows the file would change but that are reviewed or recorded. */
  kept: string[]
  missing_entries: string[]
  missing_rows: string[]
}

/** One of a lesson's draft exercises (bolt 085): a body in the live format,
 * the word row it practises, and the body it was generated as with its
 * key (`mc:W001`), so an edited one can be kept or reset. */
export type DraftExercise = ExerciseBody & {
  vocab_ref: string | null
  generated: (ExerciseBody & { key: string }) | null
  edited: boolean
}

export interface DraftExerciseList {
  exercises: DraftExercise[]
}

export interface PublishLessonResult {
  category_id: string
  skill_id: string
  lesson_id: string
  exercise_ids: string[]
  created: ('section' | 'skill' | 'lesson')[]
}
