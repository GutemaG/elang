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
  status: string
  section_count: number
}

export interface AdminCourseList {
  courses: AdminCourse[]
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
 * only what is shown, and may repeat (two tiles can both read "ላ"). */
export interface Tile {
  id: string
  text: string
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
  | { type: 'multiple_choice'; prompt: string; content: { choices: Tile[] }; answer_key: ChoiceKey }
  | {
      type: 'listening'
      prompt: string
      content: { audio_url: string; choices: Tile[] }
      answer_key: ChoiceKey
    }
  | {
      type: 'gap_fill'
      prompt: string
      content: { sentence_before: string; sentence_after: string; choices: Tile[] }
      answer_key: ChoiceKey
    }
  | {
      type: 'sentence_construction'
      prompt: string
      content: { word_bank: Tile[] }
      answer_key: SequenceKey
    }
  | { type: 'spell_tiles'; prompt: string; content: { tiles: Tile[] }; answer_key: SequenceKey }
  | {
      type: 'match_pairs'
      prompt: string
      content: { left_tiles: Tile[]; right_tiles: Tile[] }
      answer_key: { correct_pairs: [string, string][] }
    }
  | { type: 'image_choice'; prompt: string; content: { choices: PictureTile[] }; answer_key: ChoiceKey }
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
