import { describe, expect, it } from 'vitest'

import { API_BASE_URL } from '../config'
import type { AdminExercise, ExerciseBody } from '../types'
import {
  addChoice,
  addPair,
  addPicture,
  addTile,
  appendToAnswer,
  blank,
  bodyOf,
  markCorrect,
  markPictureCorrect,
  missingAnswer,
  moveChoice,
  moveInAnswer,
  nextId,
  pairRows,
  pictureProblems,
  placeError,
  plainMessage,
  playableUrl,
  removeChoice,
  removeFromAnswer,
  removePair,
  removePicture,
  removeTile,
  setAltText,
  setAudioUrl,
  setChoiceText,
  setPairText,
  setPictureUrl,
  setTileText,
  type ChoiceBody,
  type PairsBody,
  type PictureBody,
  type SequenceBody,
} from './model'
import { AUDIO_IMAGE, GAP, IMAGE, MC, PAIRS, SENTENCE, SPELL } from '../test/exercises'

/** Deep-frozen, so any change made in place instead of copied throws. */
function frozen<T>(value: T): T {
  if (value && typeof value === 'object') {
    Object.values(value).forEach(frozen)
    Object.freeze(value)
  }
  return value
}

const mc = () => frozen(structuredClone(MC)) as ChoiceBody
const spell = () => frozen(structuredClone(SPELL)) as SequenceBody
const sentence = () => frozen(structuredClone(SENTENCE)) as SequenceBody
const pairs = () => frozen(structuredClone(PAIRS)) as PairsBody

describe('ids', () => {
  it.each([
    [['a', 'b', 'c', 'd'], 'letter', 'e'],
    [['a', 'c'], 'letter', 'b'],
    [[], 'letter', 'a'],
    [['w1', 'w2', 'w3', 'w4'], 'w', 'w5'],
    [['t1', 't3'], 't', 't4'],
    [[], 'w', 'w1'],
    [['l1', 'l2'], 'l', 'l3'],
    // A list that follows no single convention gets the fallback prefix.
    [['a', 'w2'], 'letter', 'c1'],
    [['x7', 'y2'], 't', 't1'],
  ])('%j with %s gives %s', (taken, fallback, expected) => {
    expect(nextId(taken, fallback)).toBe(expected)
  })

  it('moves on to numbers once every letter is taken', () => {
    const letters = [...'abcdefghijklmnopqrstuvwxyz']
    expect(nextId(letters, 'letter')).toBe('c1')
    expect(nextId([...letters.slice(0, 25)], 'letter')).toBe('z')
  })

  it('never returns an id already taken', () => {
    expect(nextId(['c1', 'x'], 'letter')).toBe('c2')
  })
})

describe('a stored exercise', () => {
  it('is copied, so editing the draft cannot reach the original', () => {
    const stored = { ...structuredClone(MC), id: 'ex', lesson_id: 'l', order_index: 1, vocab_item_id: null }
    const body = bodyOf(stored as AdminExercise) as ChoiceBody

    body.content.choices[0]!.text = 'changed'

    expect(stored.content.choices[0]!.text).not.toBe('changed')
    expect(body).not.toHaveProperty('id')
  })

  it.each(['multiple_choice', 'listening', 'gap_fill', 'sentence_construction', 'spell_tiles', 'match_pairs'] as const)(
    'a blank %s has the fewest tiles the server accepts',
    (type) => {
      const body = blank(type)
      expect(body.type).toBe(type)
      expect(body.prompt).toBe('')
    },
  )
})

describe('choices', () => {
  it('marking one sets the answer to its id', () => {
    expect(markCorrect(mc(), 'c').answer_key.correct_choice_id).toBe('c')
  })

  it('a new choice gets the next free letter and empty text', () => {
    expect(addChoice(mc()).content.choices.at(-1)).toEqual({ id: 'e', text: '' })
  })

  it('editing text keeps every id and the answer', () => {
    const next = setChoiceText(mc(), 1, 'ደህና')
    expect(next.content.choices.map((c) => c.id)).toEqual(['a', 'b', 'c', 'd'])
    expect(next.content.choices[1]!.text).toBe('ደህና')
    expect(next.answer_key).toEqual(MC.answer_key)
  })

  it('removing the correct choice clears the answer', () => {
    const next = removeChoice(mc(), 0)
    expect(next.content.choices.map((c) => c.id)).toEqual(['b', 'c', 'd'])
    expect(next.answer_key.correct_choice_id).toBe('')
    expect(missingAnswer(next)).toMatch(/Mark which choice is correct/)
  })

  it('removing another choice keeps the answer', () => {
    expect(removeChoice(mc(), 2).answer_key.correct_choice_id).toBe('a')
  })

  it('moving keeps the answer with its choice', () => {
    const next = moveChoice(mc(), 0, 1)
    expect(next.content.choices.map((c) => c.id)).toEqual(['b', 'a', 'c', 'd'])
    expect(next.answer_key.correct_choice_id).toBe('a')
    expect(moveChoice(mc(), 0, -1)).toEqual(MC)
  })

  it('gap fill keeps its sentence when choices change', () => {
    const next = addChoice(frozen(structuredClone(GAP)) as ChoiceBody)
    expect(next.content).toMatchObject({ sentence_before: GAP.content.sentence_before })
  })
})

describe('tiles and the answer', () => {
  it('two tiles showing the same letter are both placed, as themselves', () => {
    // SPELL has t2 and t4 both reading "ላ".
    let next = spell()
    next = removeFromAnswer(removeFromAnswer(removeFromAnswer(removeFromAnswer(next, 0), 0), 0), 0)
    for (const id of ['t1', 't4', 't2', 't3']) next = appendToAnswer(next, id)
    expect(next.answer_key.correct_sequence).toEqual(['t1', 't4', 't2', 't3'])
  })

  it('a tile is used at most once, and unknown ids are ignored', () => {
    expect(appendToAnswer(spell(), 't1')).toEqual(SPELL)
    expect(appendToAnswer(spell(), 'nope')).toEqual(SPELL)
  })

  it('a removed tile leaves the answer too, wherever it was', () => {
    const next = removeTile(spell(), 1)
    expect(next.content).toEqual({ tiles: SPELL.content.tiles.filter((t) => t.id !== 't2') })
    expect(next.answer_key.correct_sequence).toEqual(['t1', 't4', 't3'])
  })

  it('a distractor can be removed without touching the answer', () => {
    const next = removeTile(sentence(), 2)
    expect(next.answer_key).toEqual(SENTENCE.answer_key)
  })

  it('new tiles follow the list: w for words, t for letters', () => {
    expect(addTile(sentence()).content).toMatchObject({ word_bank: expect.arrayContaining([{ id: 'w4', text: '' }]) })
    expect(addTile(spell()).content).toMatchObject({ tiles: expect.arrayContaining([{ id: 't5', text: '' }]) })
  })

  it('editing a tile keeps the answer', () => {
    const next = setTileText(spell(), 0, 'ሶ')
    expect(next.answer_key).toEqual(SPELL.answer_key)
  })

  it('placed tiles move and come out by position', () => {
    expect(moveInAnswer(spell(), 0, 1).answer_key.correct_sequence).toEqual(['t2', 't1', 't4', 't3'])
    expect(moveInAnswer(spell(), 3, 1)).toEqual(SPELL)
    expect(removeFromAnswer(spell(), 1).answer_key.correct_sequence).toEqual(['t1', 't4', 't3'])
  })

  it('an empty answer is missing', () => {
    let next = spell()
    for (let i = 0; i < 4; i++) next = removeFromAnswer(next, 0)
    expect(missingAnswer(next)).toMatch(/Build the correct answer/)
  })
})

describe('pairs', () => {
  it('rows follow the stored pairs, whatever order the right column is in', () => {
    // PAIRS stores its right column as r2, r1.
    expect(pairRows(pairs()).map((r) => [r.left?.text, r.right?.text])).toEqual([
      ['ቡና', 'Coffee'],
      ['ሻይ', 'Tea'],
    ])
  })

  it('editing a row edits its own right tile, and no column is reordered', () => {
    const next = setPairText(pairs(), 0, 'right', 'Buna')
    expect(next.content.right_tiles).toEqual([
      { id: 'r2', text: 'Tea' },
      { id: 'r1', text: 'Buna' },
    ])
    expect(next.answer_key).toEqual(PAIRS.answer_key)
  })

  it('adding a row adds a tile to each side and the pair', () => {
    const next = addPair(pairs())
    expect(next.content.left_tiles.at(-1)).toEqual({ id: 'l3', text: '' })
    expect(next.content.right_tiles.at(-1)).toEqual({ id: 'r3', text: '' })
    expect(next.answer_key.correct_pairs.at(-1)).toEqual(['l3', 'r3'])
  })

  it('removing a row removes both of its tiles, keeping the columns equal', () => {
    const next = removePair(pairs(), 1)
    expect(next.content.left_tiles).toEqual([{ id: 'l1', text: 'ቡና' }])
    expect(next.content.right_tiles).toEqual([{ id: 'r1', text: 'Coffee' }])
    expect(next.answer_key.correct_pairs).toEqual([['l1', 'r1']])
  })
})

describe('where a server error goes', () => {
  const at = (field: string, body: ExerciseBody, message = 'x') => placeError(field, message, body)

  it.each([
    ['prompt', MC, 'prompt'],
    ['content.choices[1].text', MC, 'choice:1'],
    ['content.choices', MC, 'choices'],
    ['content', MC, 'choices'],
    ['answer_key.correct_choice_id', MC, 'choices'],
    ['content.sentence_after', GAP, 'sentence'],
    ['content.word_bank[2].id', SENTENCE, 'tile:2'],
    ['content.tiles[0].text', SPELL, 'tile:0'],
    ['content', SPELL, 'tiles'],
    ['answer_key.correct_sequence[1]', SPELL, 'answer'],
    ['answer_key.correct_sequence', SENTENCE, 'answer'],
    ['answer_key', SPELL, 'answer'],
    ['answer_key.correct_pairs[1]', PAIRS, 'pair:1'],
    ['answer_key.correct_pairs', PAIRS, 'pairs'],
    ['content', PAIRS, 'pairs'],
    ['type', MC, 'top'],
    ['something.else', MC, 'top'],
  ] as const)('%s → %s', (field, body, slot) => {
    expect(at(field, body as ExerciseBody)).toBe(slot)
  })

  it('a match-pairs tile error goes to the row that holds the tile', () => {
    // right_tiles[0] is r2, which is in the second pair.
    expect(at('content.right_tiles[0].text', PAIRS as ExerciseBody)).toBe('pair:1')
    expect(at('content.left_tiles[0].text', PAIRS as ExerciseBody)).toBe('pair:0')
  })

  it('a gap-fill rule about the gap goes to the sentence', () => {
    expect(at('content', GAP as ExerciseBody, 'GapFillContent requires text on at least one side of the gap')).toBe(
      'sentence',
    )
  })

  it.each([
    ['content.choices[1].text must be a non-empty string', 'Must be a non-empty string'],
    ['content.audio_url must be a full https:// address', 'Must be a full https:// address'],
    ['prompt must not be empty', 'Must not be empty'],
    ['MultipleChoiceContent requires at least 2 choices', 'Needs at least 2 choices'],
    ['ListeningContent.audio_url must be a non-empty string', 'Must be a non-empty string'],
    ["answer_key.correct_sequence[1] 't9' is not one of the tiles", "'t9' is not one of the tiles"],
    ['Something else went wrong', 'Something else went wrong'],
  ])('reads "%s" as "%s"', (message, plain) => {
    expect(plainMessage(message)).toBe(plain)
  })
})

describe('audio addresses', () => {
  it('local paths play from the backend; hosted ones as they are', () => {
    expect(playableUrl('/media/audio/am/hello.m4a')).toBe(`${API_BASE_URL}/media/audio/am/hello.m4a`)
    expect(playableUrl('https://cdn.example/a.mp3')).toBe('https://cdn.example/a.mp3')
  })
})

// --- pictures (bolt 052) ------------------------------------------------------------

const image = () => frozen(structuredClone(IMAGE)) as PictureBody
const audioImage = () => frozen(structuredClone(AUDIO_IMAGE)) as PictureBody

describe('pictures', () => {
  it('a new picture question starts with two empty slots and no answer', () => {
    for (const type of ['image_choice', 'audio_image_choice'] as const) {
      const body = blank(type) as PictureBody
      expect(body.content.choices).toEqual([
        { id: 'a', image_url: '', alt_text: '' },
        { id: 'b', image_url: '', alt_text: '' },
      ])
      expect(body.answer_key.correct_choice_id).toBe('')
    }
    expect(blank('audio_image_choice')).toMatchObject({ content: { audio_url: '' } })
    expect(blank('image_choice').content).not.toHaveProperty('audio_url')
  })

  it('a new slot gets the next free letter, up to 4 slots', () => {
    const four = addPicture(image())
    expect(four.content.choices.map((p) => p.id)).toEqual(['a', 'b', 'c', 'd'])
    expect(four.content.choices[3]).toEqual({ id: 'd', image_url: '', alt_text: '' })
    expect(addPicture(four)).toBe(four)
  })

  it('removing stops at 2 slots', () => {
    const two = removePicture(image(), 'c')
    expect(two.content.choices.map((p) => p.id)).toEqual(['a', 'b'])
    expect(removePicture(two, 'a')).toBe(two)
  })

  it('removing the correct picture clears the answer; removing another keeps it', () => {
    expect(removePicture(image(), 'b').answer_key.correct_choice_id).toBe('')
    expect(removePicture(image(), 'a').answer_key.correct_choice_id).toBe('b')
  })

  it('pictures and descriptions are set by id, touching nothing else', () => {
    const body = setAltText(setPictureUrl(image(), 'c', 'https://pub.example/new.webp'), 'a', 'Water')
    expect(body.content.choices).toEqual([
      { id: 'a', image_url: IMAGE.content.choices[0]!.image_url, alt_text: 'Water' },
      IMAGE.content.choices[1],
      { id: 'c', image_url: 'https://pub.example/new.webp', alt_text: 'A house' },
    ])
    expect(body.answer_key).toEqual(IMAGE.answer_key)
  })

  it('an id no longer in the list changes nothing', () => {
    expect(setPictureUrl(image(), 'z', 'https://pub.example/x.webp').content).toEqual(IMAGE.content)
  })

  it('marking a picture sets the answer to its id', () => {
    expect(markPictureCorrect(image(), 'c').answer_key).toEqual({ correct_choice_id: 'c' })
  })

  it('the audio question keeps its clip through every change, and can change it', () => {
    const body = markPictureCorrect(addPicture(audioImage()), 'b')
    expect(body).toMatchObject({ content: { audio_url: '/media/audio/am/one.m4a' } })
    expect(setAudioUrl(audioImage() as typeof AUDIO_IMAGE, 'https://cdn.example/one.m4a').content.audio_url).toBe(
      'https://cdn.example/one.m4a',
    )
  })
})

describe('what a picture question still needs', () => {
  it('nothing, when complete', () => {
    expect(pictureProblems(image())).toEqual({ slots: [null, null, null], audio: null, answer: null })
    expect(pictureProblems(audioImage())).toEqual({ slots: [null, null, null, null], audio: null, answer: null })
    expect(missingAnswer(image())).toBeNull()
  })

  it('a picture first, then its description', () => {
    const body = setAltText(setPictureUrl(image(), 'a', ''), 'b', '   ')
    expect(pictureProblems(body).slots).toEqual([
      'Choose a picture.',
      'Describe the picture for learners who can’t see it.',
      null,
    ])
  })

  it('a clip, for the audio type only', () => {
    const silent = setAudioUrl(audioImage() as typeof AUDIO_IMAGE, ' ') as PictureBody
    expect(pictureProblems(silent).audio).toBe('Add the clip the learner hears.')
    expect(missingAnswer(silent)).toBe('Add the clip the learner hears.')
  })

  it('an answer that names a picture', () => {
    const body = removePicture(image(), 'b')
    expect(pictureProblems(body).answer).toBe('Mark which picture is correct.')
    expect(missingAnswer(body)).toBe('Mark which picture is correct.')
  })

  it('Save names the slots first, then the clip, then the answer', () => {
    // Empty slots, no clip and no answer: the slots come first.
    const empty = blank('audio_image_choice') as PictureBody
    expect(missingAnswer(empty)).toBe('Choose a picture.')
    const pictured = setAltText(setAltText(setPictureUrl(setPictureUrl(empty, 'a', 'https://p/a.webp'), 'b', 'https://p/b.webp'), 'a', 'A'), 'b', 'B')
    expect(missingAnswer(pictured)).toBe('Add the clip the learner hears.')
  })
})

describe('where a server error about a picture goes', () => {
  it.each([
    ['content.choices[2].alt_text', 'choice:2'],
    ['content.choices[0].image_url', 'choice:0'],
    ['content.choices', 'choices'],
    ['answer_key.correct_choice_id', 'choices'],
    ['content.audio_url', 'audio_url'],
    ['prompt', 'prompt'],
  ] as const)('%s → %s', (field, slot) => {
    expect(placeError(field, 'x', AUDIO_IMAGE as ExerciseBody)).toBe(slot)
    if (field !== 'content.audio_url') expect(placeError(field, 'x', IMAGE as ExerciseBody)).toBe(slot)
  })

  it('reads the picture messages plainly', () => {
    expect(plainMessage('content.choices[2].alt_text must be at most 200 characters')).toBe(
      'Must be at most 200 characters',
    )
    expect(plainMessage('ImageChoiceContent requires 2 to 4 choices')).toBe('Needs 2 to 4 choices')
  })

  it('local pictures load from the backend', () => {
    expect(playableUrl('/media/images/samples/dog.webp')).toBe(`${API_BASE_URL}/media/images/samples/dog.webp`)
  })
})

describe('an exercise opened and saved unchanged', () => {
  it.each([
    ['image choice', IMAGE],
    ['audio image choice', AUDIO_IMAGE],
  ] as const)('%s is copied exactly', (_, body) => {
    const stored = { ...structuredClone(body), id: 'x', lesson_id: 'l', order_index: 1, vocab_item_id: null }
    expect(bodyOf(stored as AdminExercise)).toEqual(body)
  })
})
