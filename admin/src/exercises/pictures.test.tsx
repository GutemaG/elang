// The two picture question types in the real editor page, against the fake
// server (bolt 052): the slots, uploading, what blocks saving, the round
// trip and the preview. jsdom has no canvas, so shrinking is replaced by a
// stand-in; its own rules are tested in pictures/shrink.test.ts.

import { fireEvent, screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import { API_BASE_URL } from '../config'
import { PictureProblem, type ShrunkPicture } from '../pictures/shrink'
import { FakeServer, type Call } from '../test/fakeServer'
import { AUDIO_IMAGE, IMAGE, lessonExercises } from '../test/exercises'
import { courseTree } from '../test/fixtures'
import { renderApp, withStoredSession } from '../test/renderApp'
import type { AdminExercise, ExerciseBody } from '../types'

vi.mock('../auth/GoogleButton', () => ({ GoogleButton: () => null }))

const shrinkPicture = vi.hoisted(() => vi.fn<(file: Blob) => Promise<ShrunkPicture>>())
vi.mock('../pictures/shrink', async (original) => ({
  ...(await original<typeof import('../pictures/shrink')>()),
  shrinkPicture,
}))

const A = '/api/v1/admin'
const LIST = `${A}/lessons/lesson-1/exercises`
const EDIT = '/courses/course-1/lessons/lesson-1/exercises'
const UPLOADS = `${A}/images/uploads`
const LINKS = `${A}/audio/links`

let server: FakeServer
let stored: AdminExercise[]
let uploaded = 0

/** A shrunk picture, as the real shrinker would make it. */
const webp = (): ShrunkPicture => ({
  blob: new Blob([new Uint8Array(20_000)], { type: 'image/webp' }),
  type: 'image/webp',
  width: 512,
  height: 384,
})

const photo = (name = 'photo.jpg') => new File([new Uint8Array(3_000_000)], name, { type: 'image/jpeg' })

/** Hands out one link per request; each picture gets its own address. */
function handsOutUploadLinks(): void {
  server.on('POST', UPLOADS, () => {
    uploaded += 1
    const key = `am/lesson-1/${String(uploaded).padStart(12, '0')}.webp`
    return {
      status: 201,
      body: {
        upload_url: `https://store.example/${key}?sig=1`,
        method: 'PUT',
        headers: { 'Content-Type': 'image/webp' },
        key,
        public_url: `/media/images/${key}`,
        expires_in: 600,
      },
    }
  })
  for (let n = 1; n <= 9; n += 1) {
    server.on('PUT', `/am/lesson-1/${String(n).padStart(12, '0')}.webp`, { status: 200 })
  }
}

const address = (n: number) => `/media/images/am/lesson-1/${String(n).padStart(12, '0')}.webp`

function acceptsSaves(id: string): void {
  server.on('PUT', `${A}/exercises/${id}`, (call: Call) => ({
    body: { ...(call.body as object), id, lesson_id: 'lesson-1', order_index: 1, vocab_item_id: null },
  }))
}

function acceptsCreates(): void {
  server.on('POST', LIST, (call) => {
    const created = { ...(call.body as object), id: 'ex-new', lesson_id: 'lesson-1', order_index: 9, vocab_item_id: null }
    stored = [...stored, created as AdminExercise]
    return { status: 201, body: created }
  })
}

const stored_ = (id: string, body: ExerciseBody): AdminExercise => ({
  ...structuredClone(body),
  id,
  lesson_id: 'lesson-1',
  order_index: 7,
  vocab_item_id: null,
})

beforeEach(() => {
  withStoredSession()
  uploaded = 0
  shrinkPicture.mockReset()
  shrinkPicture.mockImplementation(async () => webp())
  stored = [...lessonExercises(), stored_('ex-image', IMAGE), stored_('ex-audio-image', AUDIO_IMAGE)]
  server = new FakeServer()
    .install()
    .on('GET', `${A}/me`, { body: { email: 'admin@example.com' } })
    .on('GET', `${A}/courses/course-1/tree`, { body: courseTree() })
    .on('GET', LIST, () => ({ body: { exercises: stored } }))
  acceptsSaves('ex-image')
  acceptsSaves('ex-audio-image')
  acceptsCreates()
  handsOutUploadLinks()
})

async function open(id: string): Promise<void> {
  renderApp(`${EDIT}/${id}`)
  await screen.findByRole('heading', { name: 'Edit exercise' })
}

async function openNew(type: string): Promise<void> {
  renderApp(`${EDIT}/new/${type}`)
  await screen.findByRole('heading', { name: 'New exercise' })
}

const slot = (n: number) => screen.getByLabelText(`Picture ${n} description`).closest('.rounded-md.border') as HTMLElement
// An <img> whose alt text is still empty has no `img` role, so it is found as an element.
const thumbnail = (n: number) => slot(n).querySelector('img')
const button = (name: string | RegExp) => screen.getByRole('button', { name })
const saveButton = () => screen.queryByRole('button', { name: 'Save' }) ?? button('Create exercise')
const preview = () => within(screen.getByRole('region', { name: 'Learner preview' }))

/** Types into a field in one go: pasting, not a keystroke at a time,
 * keeps these long flows quick. */
async function write(label: string, text: string): Promise<void> {
  await userEvent.click(screen.getByLabelText(label))
  await userEvent.paste(text)
}

async function choosePicture(n: number, file = photo()): Promise<void> {
  await userEvent.upload(screen.getByLabelText(`Picture ${n} file`), file)
}

async function fillSlot(n: number, alt: string): Promise<void> {
  await choosePicture(n)
  await waitFor(() => expect(thumbnail(n)).toBeInTheDocument())
  await write(`Picture ${n} description`, alt)
}

// --- starting one -------------------------------------------------------------------

describe('a new picture question', () => {
  it.each([
    ['image_choice', 'Image choice'],
    ['audio_image_choice', 'Audio image choice'],
  ])('%s starts with two empty slots and nothing marked', async (type, name) => {
    await openNew(type)

    expect(screen.getByTitle(/type is chosen once/)).toHaveTextContent(name)
    expect(screen.getAllByRole('radio')).toHaveLength(2)
    expect(screen.getByLabelText('Picture 1 description')).toHaveValue('')
    expect(screen.getByLabelText('Picture 2 description')).toHaveValue('')
    expect(button('Choose picture 1')).toBeEnabled()
    expect(saveButton()).toBeDisabled()
  })

  it('image choice is built, uploaded and created', async () => {
    await openNew('image_choice')

    await write('Prompt', "Choose the picture: 'ውሻ'")
    await fillSlot(1, 'A cat')
    await fillSlot(2, 'A dog')
    await userEvent.click(screen.getByRole('radio', { name: 'Picture 2 is correct' }))
    expect(saveButton()).toBeEnabled()
    await userEvent.click(button('Create exercise'))

    expect(await screen.findByRole('heading', { name: 'Edit exercise' })).toBeInTheDocument()
    expect(server.callsTo('POST', LIST)[0]!.body).toEqual({
      type: 'image_choice',
      prompt: "Choose the picture: 'ውሻ'",
      content: {
        choices: [
          { id: 'a', image_url: address(1), alt_text: 'A cat' },
          { id: 'b', image_url: address(2), alt_text: 'A dog' },
        ],
      },
      answer_key: { correct_choice_id: 'b' },
    })
  })

  it('the audio type has the audio field, and needs a clip before it can be saved', async () => {
    server.on('POST', LINKS, { body: { url: 'https://cdn.example/one.m4a', content_type: 'audio/mp4' } })
    await openNew('audio_image_choice')

    await write('Prompt', 'Tap the picture you hear')
    await fillSlot(1, 'The number 1')
    await fillSlot(2, 'The number 2')
    await userEvent.click(screen.getByRole('radio', { name: 'Picture 1 is correct' }))

    expect(screen.getByText('No audio yet. Add a clip below.')).toBeInTheDocument()
    expect(button('Create exercise')).toBeDisabled()
    expect(button('Create exercise')).toHaveAttribute('title', 'Add the clip the learner hears.')

    await userEvent.click(screen.getByRole('tab', { name: 'Link' }))
    await write('Audio link', 'https://cdn.example/one.m4a')
    await userEvent.click(button('Check link'))
    await waitFor(() => expect(button('Create exercise')).toBeEnabled())
    await userEvent.click(button('Create exercise'))

    await screen.findByRole('heading', { name: 'Edit exercise' })
    expect(server.callsTo('POST', LIST)[0]!.body).toEqual({
      type: 'audio_image_choice',
      prompt: 'Tap the picture you hear',
      content: {
        audio_url: 'https://cdn.example/one.m4a',
        choices: [
          { id: 'a', image_url: address(1), alt_text: 'The number 1' },
          { id: 'b', image_url: address(2), alt_text: 'The number 2' },
        ],
      },
      answer_key: { correct_choice_id: 'a' },
    })
  })
})

// --- the slots ------------------------------------------------------------------------

describe('the slots', () => {
  it('adding stops at 4, and removing stops at 2', async () => {
    await openNew('image_choice')
    expect(button('Remove picture 1')).toBeDisabled()
    expect(button('Remove picture 2')).toBeDisabled()

    await userEvent.click(button('Add picture'))
    await userEvent.click(button('Add picture'))

    expect(screen.getAllByRole('radio')).toHaveLength(4)
    expect(screen.queryByRole('button', { name: 'Add picture' })).not.toBeInTheDocument()
    expect(screen.getByText('A question can have 4 pictures at most.')).toBeInTheDocument()
    expect(button('Remove picture 3')).toBeEnabled()

    await userEvent.click(button('Remove picture 3'))
    expect(screen.getAllByRole('radio')).toHaveLength(3)
    expect(button('Add picture')).toBeInTheDocument()
  })

  it('a new slot gets the next letter', async () => {
    await open('ex-image')
    await userEvent.click(button('Add picture'))
    await fillSlot(4, 'The sun')
    await userEvent.click(button('Save'))

    await waitFor(() => expect(server.callsTo('PUT', `${A}/exercises/ex-image`)).toHaveLength(1))
    const sent = server.callsTo('PUT', `${A}/exercises/ex-image`)[0]!.body as typeof IMAGE
    expect(sent.content.choices.map((c) => c.id)).toEqual(['a', 'b', 'c', 'd'])
  })

  it('a chosen picture is shrunk, uploaded, and shown from its new address', async () => {
    await open('ex-image')
    const file = photo('big-photo.jpg')

    await choosePicture(1, file)

    await waitFor(() => expect(thumbnail(1)).toHaveAttribute('src', `${API_BASE_URL}${address(1)}`))
    expect(shrinkPicture).toHaveBeenCalledWith(file, expect.anything())
    expect(server.callsTo('POST', UPLOADS)[0]!.body).toEqual({
      lesson_id: 'lesson-1',
      content_type: 'image/webp',
      size: 20_000,
    })
    expect(server.callsTo('PUT', '/am/lesson-1/000000000001.webp')).toHaveLength(1)
    expect(button('Replace picture 1')).toBeInTheDocument()
    expect(screen.getByText('Unsaved changes')).toBeInTheDocument()
  })

  it('a failed upload shows why, and keeps the picture the slot had', async () => {
    server.on('PUT', '/am/lesson-1/000000000001.webp', { status: 500 })
    await open('ex-image')

    await choosePicture(2)

    expect(await within(slot(2).parentElement!).findByRole('alert')).toHaveTextContent(
      'The picture store refused the upload (500). Try again.',
    )
    expect(thumbnail(2)).toHaveAttribute('src', IMAGE.content.choices[1]!.image_url)
    expect(screen.getByText('All changes saved')).toBeInTheDocument()
  })

  it('a picture that cannot be shrunk is refused, and nothing is uploaded', async () => {
    shrinkPicture.mockRejectedValue(new PictureProblem('This file isn’t a JPEG, PNG or WebP picture. Choose one of those.'))
    await open('ex-image')

    // (The file picker itself only offers JPEG, PNG and WebP.)
    await choosePicture(1, photo('damaged.jpg'))

    expect(await screen.findByRole('alert')).toHaveTextContent('isn’t a JPEG, PNG or WebP picture')
    expect(server.callsTo('POST', UPLOADS)).toHaveLength(0)
    expect(thumbnail(1)).toHaveAttribute('src', IMAGE.content.choices[0]!.image_url)
  })

  it('Save waits while a picture uploads, and an edit made meanwhile is kept', async () => {
    let finish: (picture: ShrunkPicture) => void = () => {}
    shrinkPicture.mockImplementation(() => new Promise((resolve) => (finish = resolve)))
    await open('ex-image')

    await choosePicture(1)
    expect(await screen.findByText('Uploading picture 1…')).toBeInTheDocument()
    await write('Picture 3 description', ' with a red door')
    expect(button('Save')).toBeDisabled()
    expect(button('Save')).toHaveAttribute('title', 'Wait for the picture to finish uploading.')

    finish(webp())
    await waitFor(() => expect(button('Save')).toBeEnabled())
    await userEvent.click(button('Save'))

    await waitFor(() => expect(server.callsTo('PUT', `${A}/exercises/ex-image`)).toHaveLength(1))
    const sent = server.callsTo('PUT', `${A}/exercises/ex-image`)[0]!.body as typeof IMAGE
    expect(sent.content.choices[0]!.image_url).toBe(address(1))
    expect(sent.content.choices[2]!.alt_text).toBe('A house with a red door')
  })
})

// --- what blocks saving -------------------------------------------------------------------

describe('what blocks saving', () => {
  it('each slot says what it still needs, and Save names the first', async () => {
    await openNew('image_choice')

    expect(within(slot(1).parentElement!).getByText('Choose a picture.')).toBeInTheDocument()
    expect(button('Create exercise')).toHaveAttribute('title', 'Choose a picture.')

    await choosePicture(1)
    await waitFor(() =>
      expect(within(slot(1).parentElement!).getByText('Describe the picture for learners who can’t see it.')).toBeInTheDocument(),
    )
    await write('Picture 1 description', 'A cat')
    expect(within(slot(1).parentElement!).queryByText(/Choose a picture|Describe the picture/)).not.toBeInTheDocument()

    await fillSlot(2, 'A dog')
    expect(screen.getByText('Mark which picture is correct.')).toBeInTheDocument()
    expect(button('Create exercise')).toBeDisabled()

    await userEvent.click(screen.getByRole('radio', { name: 'Picture 1 is correct' }))
    expect(button('Create exercise')).toBeEnabled()
  })

  it('a description of only spaces still blocks', async () => {
    await open('ex-image')
    await userEvent.clear(screen.getByLabelText('Picture 1 description'))
    await write('Picture 1 description', '   ')
    expect(button('Save')).toBeDisabled()
  })

  it('descriptions stop at 200 characters, the server’s limit', async () => {
    await open('ex-image')
    expect(screen.getByLabelText('Picture 1 description')).toHaveAttribute('maxLength', '200')
  })

  it('removing the correct picture blocks saving until another is marked', async () => {
    await open('ex-image')

    await userEvent.click(button('Remove picture 2'))

    expect(screen.getByText('Mark which picture is correct.')).toBeInTheDocument()
    expect(button('Save')).toBeDisabled()
    await userEvent.click(screen.getByRole('radio', { name: 'Picture 1 is correct' }))
    expect(button('Save')).toBeEnabled()
  })
})

// --- round trip and server errors -------------------------------------------------------------

describe('saved and reopened', () => {
  it.each([
    ['ex-image', IMAGE],
    ['ex-audio-image', AUDIO_IMAGE],
  ] as const)('%s goes back exactly as it was stored', async (id, body) => {
    await open(id)

    await userEvent.click(button('Save'))

    await waitFor(() => expect(server.callsTo('PUT', `${A}/exercises/${id}`)).toHaveLength(1))
    expect(server.callsTo('PUT', `${A}/exercises/${id}`)[0]!.body).toEqual(body)
    expect(await screen.findByRole('status')).toHaveTextContent('Saved')
  })

  it('stored pictures and descriptions fill the slots, the correct one marked', async () => {
    await open('ex-audio-image')

    expect(screen.getAllByRole('radio')).toHaveLength(4)
    expect(screen.getByRole('radio', { name: 'Picture 1 is correct' })).toBeChecked()
    expect(screen.getByLabelText('Picture 4 description')).toHaveValue('The number 10')
    expect(thumbnail(4)).toHaveAttribute('src', `${API_BASE_URL}/media/images/samples/number-10.webp`)
    expect(screen.getByLabelText('Play the clip')).toHaveAttribute('src', `${API_BASE_URL}/media/audio/am/one.m4a`)
  })

  it('a server error about one picture shows beside it', async () => {
    server.on('PUT', `${A}/exercises/ex-image`, {
      status: 422,
      body: {
        error_code: 'invalid_exercise',
        message: 'content.choices[2].image_url must be a full https:// address',
        details: { field: 'content.choices[2].image_url' },
      },
    })
    await open('ex-image')
    await write('Picture 3 description', '!')

    await userEvent.click(button('Save'))

    const error = await screen.findByRole('alert')
    expect(error).toHaveTextContent('Must be a full https:// address')
    expect(slot(3).parentElement).toContainElement(error)
  })

  it('a server error about the whole list goes under the pictures', async () => {
    server.on('PUT', `${A}/exercises/ex-image`, {
      status: 422,
      body: {
        error_code: 'invalid_exercise',
        message: 'ImageChoiceContent requires 2 to 4 choices',
        details: { field: 'content.choices' },
      },
    })
    await open('ex-image')
    await write('Prompt', '!')

    await userEvent.click(button('Save'))

    const error = await screen.findByRole('alert')
    expect(error).toHaveTextContent('Needs 2 to 4 choices')
    expect(screen.getByRole('radiogroup', { name: 'Correct picture' }).parentElement).toContainElement(error)
  })
})

// --- the preview ------------------------------------------------------------------------------

describe('the learner preview', () => {
  it('shows the prompt above a 2×2 grid, the correct picture marked', async () => {
    await open('ex-image')

    expect(preview().getByText("Choose the picture: 'ውሻ'")).toBeInTheDocument()
    const grid = preview().getByRole('list', { name: 'Pictures' })
    expect(grid).toHaveClass('grid-cols-2')
    expect(within(grid).getAllByRole('listitem')).toHaveLength(3)
    expect(preview().getByText('(correct)').closest('li')).toContainElement(preview().getByAltText('A dog'))

    await userEvent.click(screen.getByRole('radio', { name: 'Picture 3 is correct' }))
    expect(preview().getByText('(correct)').closest('li')).toContainElement(preview().getByAltText('A house'))
  })

  it('the audio type has the instruction and the play button above the pictures', async () => {
    await open('ex-audio-image')

    expect(preview().getByText('Tap the picture you hear')).toBeInTheDocument()
    expect(preview().getByLabelText('Clip the learner hears')).toHaveAttribute(
      'src',
      `${API_BASE_URL}/media/audio/am/one.m4a`,
    )
    expect(preview().getByAltText('The number 1')).toHaveAttribute(
      'src',
      `${API_BASE_URL}/media/images/samples/number-1.webp`,
    )
    expect(within(preview().getByRole('list', { name: 'Pictures' })).getAllByRole('listitem')).toHaveLength(4)
  })

  it('a picture that fails to load shows its description instead', async () => {
    await open('ex-image')

    fireEvent.error(preview().getByAltText('A dog'))

    expect(preview().queryByAltText('A dog')).not.toBeInTheDocument()
    expect(preview().getByText('A dog')).toBeInTheDocument()
  })

  it('an empty slot shows as "No picture"', async () => {
    await openNew('image_choice')
    expect(preview().getAllByText('No picture')).toHaveLength(2)
  })
})
