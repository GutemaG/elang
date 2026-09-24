import { act, screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

import { API_BASE_URL } from '../config'
import { FakeServer, type Call } from '../test/fakeServer'
import { LISTENING, lessonExercises } from '../test/exercises'
import { courseTree } from '../test/fixtures'
import { renderApp, withStoredSession } from '../test/renderApp'
import type { AdminExercise } from '../types'

vi.mock('../auth/GoogleButton', () => ({ GoogleButton: () => null }))

const A = '/api/v1/admin'
const LIST = `${A}/lessons/lesson-1/exercises`
const EDIT = '/courses/course-1/lessons/lesson-1/exercises'
const UPLOADS = `${A}/audio/uploads`
const LINKS = `${A}/audio/links`
// The store's side of an upload: a signed link on another host.
const STORE_PATH = '/am/lesson-1/0123456789ab.m4a'
const PUBLIC_URL = '/media/audio/am/lesson-1/0123456789ab.m4a'
const AAC = 'audio/mp4;codecs=mp4a.40.2'

let server: FakeServer
let stored: AdminExercise[]

// --- a browser microphone, faked -------------------------------------------

const track = { stop: vi.fn() }
let getUserMedia: ReturnType<typeof vi.fn>
let takeBytes = 4000

class FakeRecorder {
  static supported: string[] = [AAC, 'audio/mp4', 'audio/webm']
  static made: FakeRecorder[] = []
  static isTypeSupported(type: string) {
    return FakeRecorder.supported.includes(type)
  }

  state: 'inactive' | 'recording' = 'inactive'
  readonly mimeType: string
  ondataavailable: ((e: { data: Blob }) => void) | null = null
  onstop: (() => void) | null = null

  constructor(
    readonly stream: unknown,
    options?: { mimeType?: string },
  ) {
    // As browsers do: `audio/webm` is reported with its codec.
    this.mimeType = options?.mimeType === 'audio/webm' ? 'audio/webm;codecs=opus' : (options?.mimeType ?? '')
    FakeRecorder.made.push(this)
  }

  start() {
    this.state = 'recording'
  }

  stop() {
    this.state = 'inactive'
    this.ondataavailable?.({ data: new Blob([new Uint8Array(takeBytes)], { type: this.mimeType }) })
    this.onstop?.()
  }
}

let objectUrls = 0
const createObjectURL = vi.fn(() => `blob:clip-${++objectUrls}`)
const revokeObjectURL = vi.fn()

function withMicrophone(answer: 'granted' | 'NotAllowedError' | 'NotFoundError' = 'granted') {
  getUserMedia = vi.fn(() =>
    answer === 'granted'
      ? Promise.resolve({ getTracks: () => [track] })
      : Promise.reject(new DOMException('no', answer)),
  )
  Object.defineProperty(navigator, 'mediaDevices', { value: { getUserMedia }, configurable: true })
  vi.stubGlobal('MediaRecorder', FakeRecorder)
}

// --- the page ----------------------------------------------------------------

/** Echoes a saved exercise back, as the server does. */
function acceptsSaves(id: string): void {
  server.on('PUT', `${A}/exercises/${id}`, (call: Call) => ({
    body: { ...(call.body as object), id, lesson_id: 'lesson-1', order_index: 2, vocab_item_id: null },
  }))
}

/** The admin API's upload link, signed for whatever type was asked for. */
function handsOutUploadLinks(): void {
  server.on('POST', UPLOADS, (call: Call) => ({
    status: 201,
    body: {
      upload_url: `https://store.example${STORE_PATH}?X-Amz-Signature=abc`,
      method: 'PUT',
      headers: { 'Content-Type': (call.body as { content_type: string }).content_type },
      key: STORE_PATH.slice(1),
      public_url: PUBLIC_URL,
      expires_in: 600,
    },
  }))
  server.on('PUT', STORE_PATH, { status: 200 })
}

async function openListening(audioUrl?: string): Promise<void> {
  if (audioUrl !== undefined) {
    const listening = stored.find((e) => e.id === 'ex-listening')
    if (listening?.type === 'listening') listening.content.audio_url = audioUrl
  }
  renderApp(`${EDIT}/ex-listening`)
  await screen.findByRole('heading', { name: 'Edit exercise' })
}

const button = (name: string | RegExp) => screen.getByRole('button', { name })
const click = async (name: string | RegExp) => userEvent.click(button(name))
const tab = async (name: string) => userEvent.click(screen.getByRole('tab', { name }))
const currentClip = () => screen.getByLabelText('Play the clip')
const presigns = () => server.callsTo('POST', UPLOADS)
const storePuts = () => server.callsTo('PUT', STORE_PATH)
const sentExercise = () =>
  server.callsTo('PUT', `${A}/exercises/ex-listening`).at(-1)?.body as { content: { audio_url: string } }

async function recordATake(): Promise<void> {
  await click('Start recording')
  await screen.findByRole('button', { name: 'Stop' })
  await click('Stop')
  await screen.findByLabelText('Play the recording')
}

beforeEach(() => {
  withStoredSession()
  stored = lessonExercises()
  server = new FakeServer()
    .install()
    .on('GET', `${A}/me`, { body: { email: 'admin@example.com' } })
    .on('GET', `${A}/courses/course-1/tree`, { body: courseTree() })
    .on('GET', LIST, () => ({ body: { exercises: stored } }))
  acceptsSaves('ex-listening')
  handsOutUploadLinks()

  FakeRecorder.supported = [AAC, 'audio/mp4', 'audio/webm']
  FakeRecorder.made = []
  takeBytes = 4000
  track.stop.mockClear()
  objectUrls = 0
  createObjectURL.mockClear()
  revokeObjectURL.mockClear()
  URL.createObjectURL = createObjectURL
  URL.revokeObjectURL = revokeObjectURL
  withMicrophone()
})

afterEach(() => {
  Reflect.deleteProperty(navigator, 'mediaDevices')
  vi.useRealTimers()
})

describe('the audio section', () => {
  it('shows the current clip, playing from the backend, and offers Record, Upload and Link', async () => {
    await openListening()

    expect(currentClip()).toHaveAttribute('src', `${API_BASE_URL}/media/audio/am/hello.m4a`)
    expect(screen.getByText('Local backend only')).toBeInTheDocument()
    expect(screen.queryByText('Not saved yet')).not.toBeInTheDocument()
    expect(screen.getAllByRole('tab').map((t) => t.textContent)).toEqual(['micRecord', 'upload_fileUpload', 'linkLink'])
    expect(screen.getByRole('tab', { name: 'Record' })).toHaveAttribute('aria-selected', 'true')
  })

  it.each([
    ['https://cdn.example/hello.mp3', 'Hosted'],
    ['https://www.kozco.com/tech/piano2-CoolEdit.mp3', 'Placeholder clip'],
  ])('labels %s as %s, and plays it as it is', async (url, label) => {
    await openListening(url)
    expect(screen.getByText(label)).toBeInTheDocument()
    expect(currentClip()).toHaveAttribute('src', url)
  })

  it('says a new listening exercise has no audio yet', async () => {
    renderApp(`${EDIT}/new/listening`)
    expect(await screen.findByText('No audio yet. Add a clip below.')).toBeInTheDocument()
    expect(screen.queryByLabelText('Play the clip')).not.toBeInTheDocument()
  })

  it('keeps a take when switching tabs and back', async () => {
    await openListening()
    await recordATake()
    await tab('Link')
    await tab('Record')
    expect(screen.getByLabelText('Play the recording')).toHaveAttribute('src', 'blob:clip-1')
  })
})

describe('recording', () => {
  it('records AAC, and nothing is sent until the take is used', async () => {
    await openListening()
    expect(screen.queryByText(/iPhones may not/)).not.toBeInTheDocument()

    await click('Start recording')
    expect(getUserMedia).toHaveBeenCalledWith({ audio: true })
    expect(await screen.findByRole('timer', { name: 'Recording time' })).toHaveTextContent('0:00 / 2:00')
    expect(FakeRecorder.made[0]?.mimeType).toBe(AAC)
    expect(FakeRecorder.made[0]?.state).toBe('recording')

    await click('Stop')
    expect(track.stop).toHaveBeenCalled()
    expect(screen.getByLabelText('Play the recording')).toHaveAttribute('src', 'blob:clip-1')
    expect(screen.getByText(/4 KB · not uploaded yet/)).toBeInTheDocument()
    expect(presigns()).toHaveLength(0)
    expect(storePuts()).toHaveLength(0)
    expect(screen.getByRole('status')).toHaveTextContent('All changes saved')
  })

  it('discards a take, freeing it, and records again', async () => {
    await openListening()
    await recordATake()

    await click('Discard')
    expect(revokeObjectURL).toHaveBeenCalledWith('blob:clip-1')
    expect(screen.queryByLabelText('Play the recording')).not.toBeInTheDocument()

    await recordATake()
    await click('Record again')
    expect(revokeObjectURL).toHaveBeenCalledWith('blob:clip-2')
    await click('Stop')
    expect(screen.getByLabelText('Play the recording')).toHaveAttribute('src', 'blob:clip-3')

    expect(getUserMedia).toHaveBeenCalledTimes(3)
    expect(presigns()).toHaveLength(0)
  })

  it('uploads a used take to the signed link, then Save stores its address', async () => {
    await openListening()
    await recordATake()
    await click('Use this recording')

    await waitFor(() => expect(currentClip()).toHaveAttribute('src', `${API_BASE_URL}${PUBLIC_URL}`))
    expect(presigns()).toHaveLength(1)
    expect(presigns()[0]?.body).toEqual({ lesson_id: 'lesson-1', content_type: 'audio/mp4', size: 4000 })
    expect(presigns()[0]?.token).toBe('session-abc')

    const put = storePuts()[0]
    expect(put?.query).toBe('?X-Amz-Signature=abc')
    // Exactly the signed headers: the base type, no codec, no bearer token.
    expect(put?.headers).toEqual({ 'Content-Type': 'audio/mp4' })
    expect(put?.raw).toBeInstanceOf(Blob)
    expect((put?.raw as Blob).size).toBe(4000)

    expect(screen.getByText('Not saved yet')).toBeInTheDocument()
    expect(screen.getByText('Unsaved changes')).toBeInTheDocument()
    expect(screen.queryByLabelText('Play the recording')).not.toBeInTheDocument()
    const preview = within(screen.getByRole('region', { name: 'Learner preview' }))
    expect(preview.getByLabelText('Clip the learner hears')).toHaveAttribute('src', `${API_BASE_URL}${PUBLIC_URL}`)

    await click('Save')
    await waitFor(() => expect(sentExercise().content).toEqual({ ...LISTENING.content, audio_url: PUBLIC_URL }))
    await waitFor(() => expect(screen.queryByText('Not saved yet')).not.toBeInTheDocument())
  })

  it('warns when the browser can only record WebM, and uploads it as audio/webm', async () => {
    FakeRecorder.supported = ['audio/webm']
    await openListening()
    expect(screen.getByText(/This browser records WebM/)).toHaveTextContent(/but iPhones may not\./)

    await recordATake()
    await click('Use this recording')
    await waitFor(() => expect(storePuts()).toHaveLength(1))
    expect(presigns()[0]?.body).toMatchObject({ content_type: 'audio/webm' })
    expect(storePuts()[0]?.headers).toEqual({ 'Content-Type': 'audio/webm' })
  })

  it('warns when the browser records mp4 without AAC', async () => {
    FakeRecorder.supported = ['audio/mp4', 'audio/webm']
    await openListening()
    expect(screen.getByText(/This browser records mp4 without AAC/)).toBeInTheDocument()
  })

  it('refuses a recording over 5 MB before any upload', async () => {
    takeBytes = 5 * 1024 * 1024 + 1
    await openListening()
    await recordATake()
    await click('Use this recording')
    expect(screen.getByRole('alert')).toHaveTextContent('The recording is 5.0 MB; clips can be 5 MB at most.')
    expect(presigns()).toHaveLength(0)
  })

  it('stops by itself at two minutes', async () => {
    vi.useFakeTimers({ shouldAdvanceTime: true })
    await openListening()
    await click('Start recording')
    await screen.findByRole('button', { name: 'Stop' })

    act(() => vi.advanceTimersByTime(60_000))
    expect(screen.getByRole('timer')).toHaveTextContent('1:00 / 2:00')
    expect(FakeRecorder.made[0]?.state).toBe('recording')

    act(() => vi.advanceTimersByTime(60_000))
    expect(FakeRecorder.made[0]?.state).toBe('inactive')
    expect(track.stop).toHaveBeenCalled()
    expect(screen.getByLabelText('Play the recording')).toBeInTheDocument()
  })

  it('turns the microphone off when the page is left mid-take', async () => {
    await openListening()
    await click('Start recording')
    await screen.findByRole('button', { name: 'Stop' })

    await userEvent.click(screen.getByRole('link', { name: /Back to lesson/ }))
    await screen.findByRole('heading', { name: /Amharic/ })
    expect(track.stop).toHaveBeenCalled()
    expect(FakeRecorder.made[0]?.state).toBe('inactive')
  })
})

describe('when recording is not possible', () => {
  it.each([
    ['NotAllowedError', /microphone is blocked for this site/],
    ['NotFoundError', /No microphone was found/],
  ] as const)('explains %s, and Upload and Link still work', async (error, message) => {
    withMicrophone(error)
    server.on('POST', LINKS, { body: { url: 'https://cdn.example/a.mp3', content_type: 'audio/mpeg' } })
    await openListening()

    await click('Start recording')
    expect(await screen.findByRole('alert')).toHaveTextContent(message)
    expect(button('Try again')).toBeEnabled()

    await tab('Link')
    await userEvent.type(screen.getByLabelText('Audio link'), 'https://cdn.example/a.mp3')
    await click('Check link')
    await waitFor(() => expect(currentClip()).toHaveAttribute('src', 'https://cdn.example/a.mp3'))
  })

  it('says so in a browser without a recorder, and the other tabs still work', async () => {
    vi.stubGlobal('MediaRecorder', undefined)
    await openListening()
    expect(screen.getByText('This browser can’t record audio. Use Upload or Link instead.')).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'Start recording' })).not.toBeInTheDocument()

    await tab('Upload')
    expect(screen.getByLabelText('Audio file')).toBeEnabled()
  })
})

describe('uploading a file', () => {
  const user = () => userEvent.setup({ applyAccept: false })
  const file = (name: string, type: string, size = 2048) => new File([new Uint8Array(size)], name, { type })

  it('plays a chosen file, and uploads it only when used', async () => {
    await openListening()
    await tab('Upload')
    const clip = file('salam.mp3', 'audio/mpeg')
    await user().upload(screen.getByLabelText('Audio file'), clip)

    expect(screen.getByLabelText('Play the chosen file')).toHaveAttribute('src', 'blob:clip-1')
    expect(screen.getByText('salam.mp3 · 2 KB · not uploaded yet')).toBeInTheDocument()
    expect(presigns()).toHaveLength(0)

    await click('Use this file')
    await waitFor(() => expect(currentClip()).toHaveAttribute('src', `${API_BASE_URL}${PUBLIC_URL}`))
    expect(presigns()[0]?.body).toEqual({ lesson_id: 'lesson-1', content_type: 'audio/mpeg', size: 2048 })
    expect(storePuts()[0]?.raw).toBe(clip)
    expect(storePuts()[0]?.headers).toEqual({ 'Content-Type': 'audio/mpeg' })
    expect(screen.queryByLabelText('Play the chosen file')).not.toBeInTheDocument()
  })

  it('knows an .m4a the browser gave no type', async () => {
    await openListening()
    await tab('Upload')
    await user().upload(screen.getByLabelText('Audio file'), file('salam.m4a', ''))
    await click('Use this file')
    await waitFor(() => expect(presigns()).toHaveLength(1))
    expect(presigns()[0]?.body).toMatchObject({ content_type: 'audio/mp4' })
  })

  it.each([
    ['a file over 5 MB', () => file('big.mp3', 'audio/mpeg', 5 * 1024 * 1024 + 1), 'That file is 5.0 MB. Clips can be 5 MB at most.'],
    ['a picture', () => file('photo.png', 'image/png'), 'That isn’t an audio file. Use an m4a, mp3, webm or ogg file.'],
    ['a WAV file', () => file('take.wav', 'audio/wav'), 'That audio format can’t be stored. Use an m4a, mp3, webm or ogg file.'],
    ['an empty file', () => file('empty.mp3', 'audio/mpeg', 0), 'That file is empty.'],
  ])('refuses %s before any request', async (_, clip, message) => {
    await openListening()
    await tab('Upload')
    await user().upload(screen.getByLabelText('Audio file'), clip())

    expect(screen.getByRole('alert')).toHaveTextContent(message)
    expect(screen.queryByRole('button', { name: 'Use this file' })).not.toBeInTheDocument()
    expect(presigns()).toHaveLength(0)
    expect(createObjectURL).not.toHaveBeenCalled()
  })
})

describe('an upload that fails', () => {
  async function useATake(): Promise<void> {
    await openListening()
    await recordATake()
    await click('Use this recording')
  }

  it('explains a server with nowhere to store audio, and keeps the take', async () => {
    server.on('POST', UPLOADS, {
      status: 503,
      body: { error_code: 'audio_storage_not_configured', message: 'Audio storage is not configured on this server' },
    })
    await useATake()

    expect(await screen.findByRole('alert')).toHaveTextContent(/nowhere to store audio yet.*Paste a link instead/)
    expect(storePuts()).toHaveLength(0)
    expect(button('Use this recording')).toBeEnabled()
    expect(currentClip()).toHaveAttribute('src', `${API_BASE_URL}/media/audio/am/hello.m4a`)
  })

  it('shows a refused type or size in plain words', async () => {
    server.on('POST', UPLOADS, {
      status: 422,
      body: {
        error_code: 'invalid_content',
        message: 'size Audio must be between 1 byte and 5 MB',
        details: { field: 'size' },
      },
    })
    await useATake()
    expect(await screen.findByRole('alert')).toHaveTextContent('Audio must be between 1 byte and 5 MB')
  })

  it('explains a refused or expired link, and a retry can succeed', async () => {
    server.on('PUT', STORE_PATH, { status: 403 })
    await useATake()

    expect(await screen.findByRole('alert')).toHaveTextContent(/refused the upload, perhaps because its link expired/)
    expect(currentClip()).toHaveAttribute('src', `${API_BASE_URL}/media/audio/am/hello.m4a`)
    expect(screen.getByRole('status')).toHaveTextContent('All changes saved')

    server.on('PUT', STORE_PATH, { status: 200 })
    await click('Use this recording')
    await waitFor(() => expect(currentClip()).toHaveAttribute('src', `${API_BASE_URL}${PUBLIC_URL}`))
    expect(presigns()).toHaveLength(2)
    expect(screen.queryByRole('alert')).not.toBeInTheDocument()
  })

  it('names any other refusal by its status', async () => {
    server.on('PUT', STORE_PATH, { status: 500 })
    await useATake()
    expect(await screen.findByRole('alert')).toHaveTextContent('The audio store refused the upload (500). Try again.')
  })

  it('explains a store that cannot be reached', async () => {
    server.on('PUT', STORE_PATH, () => {
      throw new TypeError('Failed to fetch')
    })
    await useATake()
    expect(await screen.findByRole('alert')).toHaveTextContent(
      /Could not reach the audio store.*may not allow uploads from this site yet/,
    )
    expect(button('Use this recording')).toBeEnabled()
  })
})

describe('a pasted link', () => {
  it('is checked by the server and becomes the clip', async () => {
    server.on('POST', LINKS, (call: Call) => ({
      body: { url: (call.body as { url: string }).url.trim(), content_type: 'audio/mpeg' },
    }))
    await openListening()
    await tab('Link')
    await userEvent.type(screen.getByLabelText('Audio link'), 'https://cdn.example/salam.mp3')
    await click('Check link')

    await waitFor(() => expect(currentClip()).toHaveAttribute('src', 'https://cdn.example/salam.mp3'))
    expect(server.callsTo('POST', LINKS)[0]?.body).toEqual({ url: 'https://cdn.example/salam.mp3' })
    expect(screen.getByLabelText('Audio link')).toHaveValue('')
    expect(screen.getByText(/The link plays audio\/mpeg/)).toBeInTheDocument()
    expect(screen.getByText('Hosted')).toBeInTheDocument()
    expect(screen.getByText('Not saved yet')).toBeInTheDocument()
  })

  it('shows a refusal inline and leaves the clip alone', async () => {
    server.on('POST', LINKS, {
      status: 422,
      body: {
        error_code: 'invalid_audio_link',
        message: 'That address is not on the public internet',
        details: { reason: 'private_address' },
      },
    })
    await openListening()
    await tab('Link')
    await userEvent.type(screen.getByLabelText('Audio link'), 'https://192.168.1.4/a.mp3')
    await click('Check link')

    const alert = await screen.findByRole('alert')
    expect(alert).toHaveTextContent('That address is not on the public internet')
    expect(screen.getByRole('tabpanel', { name: 'Link' })).toContainElement(alert)
    expect(currentClip()).toHaveAttribute('src', `${API_BASE_URL}/media/audio/am/hello.m4a`)
    expect(screen.getByRole('status')).toHaveTextContent('All changes saved')

    await userEvent.type(screen.getByLabelText('Audio link'), 'x')
    expect(screen.queryByRole('alert')).not.toBeInTheDocument()
  })

  it('is checked on Enter, and not at all when empty', async () => {
    server.on('POST', LINKS, { body: { url: 'https://cdn.example/a.mp3', content_type: 'audio/mpeg' } })
    await openListening()
    await tab('Link')
    expect(button('Check link')).toBeDisabled()

    await userEvent.type(screen.getByLabelText('Audio link'), 'https://cdn.example/a.mp3{Enter}')
    await waitFor(() => expect(server.callsTo('POST', LINKS)).toHaveLength(1))
  })
})
