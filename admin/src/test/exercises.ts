import type { AdminExercise, ExerciseBody } from '../types'

// One exercise of each type, shaped like the seed (ids, key order), with
// the awkward cases the forms must survive: a repeated letter, a
// distractor, a right column stored in a different order from its pairs.

export const MC = {
  type: 'multiple_choice',
  prompt: "How do you say 'Hello' in Amharic?",
  content: {
    choices: [
      { id: 'a', text: 'ሰላም' },
      { id: 'b', text: 'ደህና ሁን' },
      { id: 'c', text: 'አመሰግናለሁ' },
      { id: 'd', text: 'አዎ' },
    ],
  },
  answer_key: { correct_choice_id: 'a' },
} satisfies ExerciseBody

export const LISTENING = {
  type: 'listening',
  prompt: 'What does this word mean?',
  content: {
    audio_url: '/media/audio/am/hello.m4a',
    choices: [
      { id: 'a', text: 'Hello' },
      { id: 'b', text: 'Goodbye' },
    ],
  },
  answer_key: { correct_choice_id: 'b' },
} satisfies ExerciseBody

export const GAP = {
  type: 'gap_fill',
  prompt: "Complete the sentence: 'I am fine'",
  content: {
    sentence_before: '',
    sentence_after: 'ነኝ',
    choices: [
      { id: 'a', text: 'ደህና' },
      { id: 'b', text: 'ጥሩ' },
    ],
  },
  answer_key: { correct_choice_id: 'a' },
} satisfies ExerciseBody

/** w3 is a distractor. */
export const SENTENCE = {
  type: 'sentence_construction',
  prompt: "Translate: 'I am fine'",
  content: {
    word_bank: [
      { id: 'w1', text: 'ደህና' },
      { id: 'w2', text: 'ነኝ' },
      { id: 'w3', text: 'ጥሩ' },
    ],
  },
  answer_key: { correct_sequence: ['w1', 'w2'] },
} satisfies ExerciseBody

/** t2 and t4 both read "ላ": the same letter, two tiles. */
export const SPELL = {
  type: 'spell_tiles',
  prompt: 'Spell it',
  content: {
    tiles: [
      { id: 't1', text: 'ሰ' },
      { id: 't2', text: 'ላ' },
      { id: 't3', text: 'ም' },
      { id: 't4', text: 'ላ' },
    ],
  },
  answer_key: { correct_sequence: ['t1', 't2', 't4', 't3'] },
} satisfies ExerciseBody

/** The right column is stored r2, r1 -- not in pair order. */
export const PAIRS = {
  type: 'match_pairs',
  prompt: 'Match each word to its meaning',
  content: {
    left_tiles: [
      { id: 'l1', text: 'ቡና' },
      { id: 'l2', text: 'ሻይ' },
    ],
    right_tiles: [
      { id: 'r2', text: 'Tea' },
      { id: 'r1', text: 'Coffee' },
    ],
  },
  answer_key: {
    correct_pairs: [
      ['l1', 'r1'],
      ['l2', 'r2'],
    ],
  },
} satisfies ExerciseBody

/** Hosted pictures, the correct one not first. */
export const IMAGE = {
  type: 'image_choice',
  prompt: "Choose the picture: 'ውሻ'",
  content: {
    choices: [
      { id: 'a', image_url: 'https://pub.example/am/lesson-1/water.webp', alt_text: 'A drop of water' },
      { id: 'b', image_url: 'https://pub.example/am/lesson-1/dog.webp', alt_text: 'A dog' },
      { id: 'c', image_url: 'https://pub.example/am/lesson-1/house.webp', alt_text: 'A house' },
    ],
  },
  answer_key: { correct_choice_id: 'b' },
} satisfies ExerciseBody

/** Local-backend pictures and clip, as the Picture Lab seed stores them. */
export const AUDIO_IMAGE = {
  type: 'audio_image_choice',
  prompt: 'Tap the picture you hear',
  content: {
    audio_url: '/media/audio/am/one.m4a',
    choices: [
      { id: 'a', image_url: '/media/images/samples/number-1.webp', alt_text: 'The number 1' },
      { id: 'b', image_url: '/media/images/samples/number-2.webp', alt_text: 'The number 2' },
      { id: 'c', image_url: '/media/images/samples/number-5.webp', alt_text: 'The number 5' },
      { id: 'd', image_url: '/media/images/samples/number-10.webp', alt_text: 'The number 10' },
    ],
  },
  answer_key: { correct_choice_id: 'a' },
} satisfies ExerciseBody

/** Stored exercises for lesson-1 of `courseTree()`, as the list endpoint
 * returns them: ex-mc, ex-listening, ex-gap, ex-sentence, ex-spell, ex-pairs. */
export function lessonExercises(): AdminExercise[] {
  const bodies: [string, ExerciseBody][] = [
    ['ex-mc', MC],
    ['ex-listening', LISTENING],
    ['ex-gap', GAP],
    ['ex-sentence', SENTENCE],
    ['ex-spell', SPELL],
    ['ex-pairs', PAIRS],
  ]
  return bodies.map(([id, body], i) => ({
    ...structuredClone(body),
    id,
    lesson_id: 'lesson-1',
    order_index: i + 1,
    vocab_item_id: null,
  }))
}
