import { fireEvent, render, screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { useState } from 'react'
import { MemoryRouter } from 'react-router-dom'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import { SessionProvider } from '../auth/SessionContext'
import { FakeServer } from '../test/fakeServer'
import { prepared } from '../test/clips'
import { withStoredSession } from '../test/renderApp'
import type { VoiceSettingsList } from '../voices/api'
import { AudioField, generatedVoiceOf } from './AudioField'
import { prepareClip } from './codec'
import type { VoiceSource } from './GeneratePanel'

// Reading a clip needs a browser's audio engine: by default a take can't be
// read (as in `audio.test.tsx`), and the trimming tests hand over samples.
vi.mock('./codec', async (original) => ({
  ...(await original<typeof import('./codec')>()),
  prepareClip: vi.fn(async () => null),
  playPcm: vi.fn((_pcm: unknown, onEnd: () => void) => () => onEnd()),
}))

// The Generate tab (intent 027, bolt 096): rendered as its own field, as
// the Workbook, Sounds and exercises will use it (bolt 098).

const SETTINGS = '/api/v1/admin/voice/settings'
const VOICES = '/api/v1/admin/voice/voices'
const GENERATE = '/api/v1/admin/voice/generate'

let server: FakeServer
let settings: VoiceSettingsList

const take = (name = 'Obse', seconds = '1.96') => ({
  body: new Blob(['mp3'], { type: 'audio/mpeg' }),
  headers: { 'Content-Type': 'audio/mpeg', 'X-Voice-Id': 'om-obse', 'X-Voice-Name': name, 'X-Duration-Seconds': seconds },
})

beforeEach(() => {
  withStoredSession()
  localStorage.clear()
  settings = {
    configured: true,
    languages: [
      { language: 'am', language_name: 'Amharic', male_voice_id: 'am-yohanes-calm', female_voice_id: 'am-loza', speed: 50, updated_by: null, updated_at: null },
      { language: 'om', language_name: 'Afaan Oromo', male_voice_id: 'om-diriba', female_voice_id: 'om-obse', speed: 40, updated_by: null, updated_at: null },
    ],
  }
  server = new FakeServer()
    .install()
    .on('GET', SETTINGS, () => ({ body: settings }))
    .on('GET', VOICES, (call) => {
      const code = new URLSearchParams(call.query).get('language')
      const voices =
        code === 'om'
          ? [
              { id: 'om-diriba', name: 'Diriba', descriptor: '', gender: 'male', style: 'Narration', preview_audio_url: null },
              { id: 'om-obse', name: 'Obse', descriptor: '', gender: 'female', style: 'Narration', preview_audio_url: null },
            ]
          : []
      return { body: { language: code, voices } }
    })
    .on('POST', GENERATE, () => take())
  URL.createObjectURL = vi.fn(() => 'blob:take-1')
  URL.revokeObjectURL = vi.fn()
})

function Field({ voice }: { voice?: VoiceSource }) {
  const [url, setUrl] = useState('')
  return <AudioField upload={async () => 'https://x/clip.m4a'} url={url} savedUrl={null} onChange={setUrl} voice={voice} />
}

function renderField(voice?: VoiceSource, second?: VoiceSource) {
  return render(
    <MemoryRouter>
      <SessionProvider>
        <Field voice={voice} />
        {second && <Field voice={second} />}
      </SessionProvider>
    </MemoryRouter>,
  )
}

async function openGenerate(voice: VoiceSource = { language: 'om', text: 'Maqaan koo … dha' }) {
  renderField(voice)
  await userEvent.click(screen.getByRole('tab', { name: 'Generate' }))
  return within(screen.getByRole('tabpanel', { name: 'Generate' }))
}

describe('the Generate tab', () => {
  it('is offered only to fields that say what the clip is for', () => {
    const { unmount } = renderField()
    expect(screen.getAllByRole('tab').map((t) => t.textContent)).toEqual(['micRecord', 'upload_fileUpload', 'linkLink'])
    unmount()

    renderField({ language: 'om' })
    expect(screen.getByRole('tab', { name: 'Generate' })).toBeInTheDocument()
    expect(screen.getAllByRole('tab')).toHaveLength(4)
  })

  it('fills in the item’s words and names the language’s voices', async () => {
    const panel = await openGenerate()

    expect(await panel.findByRole('radio', { name: 'Female · Obse' })).toBeChecked()
    expect(panel.getByRole('radio', { name: 'Male · Diriba' })).not.toBeChecked()
    expect(panel.getByLabelText('Words to say')).toHaveValue('Maqaan koo … dha')
    expect(panel.getByLabelText('Words to say')).toHaveAttribute('lang', 'om')
    expect(panel.getByText('16 / 500')).toBeInTheDocument()
    expect(panel.getByLabelText('Speed')).toHaveValue('40')
  })

  it('generates the words in the chosen voice and speed, and plays the take', async () => {
    const panel = await openGenerate()
    await userEvent.click(await panel.findByRole('radio', { name: 'Male · Diriba' }))
    fireEvent.change(panel.getByLabelText('Speed'), { target: { value: '30' } })

    await userEvent.click(panel.getByRole('button', { name: 'Generate' }))

    expect(await panel.findByLabelText('Play the generated clip')).toHaveAttribute('src', 'blob:take-1')
    expect(panel.getByText('Obse · 2.0 s · not stored yet')).toBeInTheDocument()
    expect(server.callsTo('POST', GENERATE)[0]!.body).toEqual({
      language: 'om',
      text: 'Maqaan koo … dha',
      gender: 'male',
      speed: 30,
    })
    expect(panel.getByRole('button', { name: 'Generate again' })).toBeEnabled()
  })

  it('asks the server for a lesson’s language when only the lesson is known', async () => {
    const panel = await openGenerate({ lessonId: 'lesson-1' })

    expect(await panel.findByRole('radio', { name: 'Female' })).toBeChecked()
    expect(panel.getByLabelText('Words to say')).toHaveAttribute('placeholder', 'Type the words the learner should hear')
    expect(panel.getByLabelText('Speed')).toHaveValue('50')
    await userEvent.type(panel.getByLabelText('Words to say'), 'Akkam')
    await userEvent.click(panel.getByRole('button', { name: 'Generate' }))

    await panel.findByLabelText('Play the generated clip')
    expect(server.callsTo('POST', GENERATE)[0]!.body).toEqual({
      lesson_id: 'lesson-1',
      text: 'Akkam',
      gender: 'female',
      speed: 50,
    })
  })

  it('remembers the voice chosen', async () => {
    const panel = await openGenerate()
    await userEvent.click(await panel.findByRole('radio', { name: 'Male · Diriba' }))

    expect(localStorage.getItem('buna.admin.voiceGender')).toBe('male')
  })

  it('opens on the voice chosen last time', async () => {
    localStorage.setItem('buna.admin.voiceGender', 'male')
    const panel = await openGenerate()

    expect(await panel.findByRole('radio', { name: 'Male · Diriba' })).toBeChecked()
  })

  it('still works when the browser blocks storage', async () => {
    // Only the voice choice is blocked: the session lives in storage too.
    const getItem = Storage.prototype.getItem
    const setItem = Storage.prototype.setItem
    vi.spyOn(Storage.prototype, 'getItem').mockImplementation(function (this: Storage, key: string) {
      if (key === 'buna.admin.voiceGender') throw new Error('blocked')
      return getItem.call(this, key)
    })
    vi.spyOn(Storage.prototype, 'setItem').mockImplementation(function (this: Storage, key: string, value: string) {
      if (key === 'buna.admin.voiceGender') throw new Error('blocked')
      setItem.call(this, key, value)
    })
    const panel = await openGenerate()

    expect(await panel.findByRole('radio', { name: 'Female · Obse' })).toBeChecked()
    await userEvent.click(panel.getByRole('radio', { name: 'Male · Diriba' }))
    expect(panel.getByRole('radio', { name: 'Male · Diriba' })).toBeChecked()
  })

  it('follows the item’s words until the admin edits them', async () => {
    function Changing() {
      const [text, setText] = useState('Maqaa')
      return (
        <>
          <button type="button" onClick={() => setText('Maqaan koo')}>
            Change the item
          </button>
          <Field voice={{ language: 'om', text }} />
        </>
      )
    }
    render(
      <MemoryRouter>
        <SessionProvider>
          <Changing />
        </SessionProvider>
      </MemoryRouter>,
    )
    await userEvent.click(screen.getByRole('tab', { name: 'Generate' }))
    const panel = within(screen.getByRole('tabpanel', { name: 'Generate' }))
    const box = await panel.findByLabelText('Words to say')

    await userEvent.click(screen.getByRole('button', { name: 'Change the item' }))
    expect(box).toHaveValue('Maqaan koo')

    await userEvent.type(box, ' dha')
    expect(box).toHaveValue('Maqaan koo dha')
  })

  it('can’t generate nothing, or more than 500 characters', async () => {
    const panel = await openGenerate({ language: 'om' })
    const generate = await panel.findByRole('button', { name: 'Generate' })
    expect(generate).toBeDisabled()

    fireEvent.change(panel.getByLabelText('Words to say'), { target: { value: 'a'.repeat(501) } })
    expect(generate).toBeDisabled()
    expect(panel.getByText('501 / 500')).toBeInTheDocument()
  })

  it('says it is generating, and holds the button until the take arrives', async () => {
    const panel = await openGenerate()
    await panel.findByRole('radio', { name: 'Female · Obse' })
    let answer: () => void = () => {}
    const fakeFetch = globalThis.fetch
    vi.stubGlobal('fetch', (input: RequestInfo | URL, init?: RequestInit) => {
      if (new URL(String(input)).pathname !== GENERATE) return fakeFetch(input, init)
      return new Promise<Response>((resolve) => {
        answer = () => resolve(new Response(new Blob(['mp3']), { status: 200, headers: { 'X-Voice-Name': 'Obse' } }))
      })
    })

    await userEvent.click(panel.getByRole('button', { name: 'Generate' }))
    expect(await panel.findByRole('button', { name: 'Generating…' })).toBeDisabled()
    answer()

    expect(await panel.findByRole('button', { name: 'Generate again' })).toBeEnabled()
  })

  it('keeps the last take when another fails, and discards it on request', async () => {
    const panel = await openGenerate()
    await userEvent.click(await panel.findByRole('button', { name: 'Generate' }))
    await panel.findByLabelText('Play the generated clip')
    server.on('POST', GENERATE, {
      status: 429,
      body: { error_code: 'voice_rate_limited', message: 'Too many requests. Try again in a minute.' },
    })

    await userEvent.click(panel.getByRole('button', { name: 'Generate again' }))

    expect(await panel.findByText('Too many requests. Try again in a minute.')).toBeInTheDocument()
    expect(panel.getByLabelText('Play the generated clip')).toBeInTheDocument()
    await userEvent.click(panel.getByRole('button', { name: 'Discard' }))
    expect(panel.queryByLabelText('Play the generated clip')).not.toBeInTheDocument()
  })

  it('says so when the server has no Addis key', async () => {
    settings.configured = false
    const panel = await openGenerate()

    expect(await panel.findByText(/Generated voices aren’t set up on this server\. Record or upload instead\./)).toBeInTheDocument()
    expect(panel.queryByRole('button', { name: 'Generate' })).not.toBeInTheDocument()
  })

  it('says so for a language without voices', async () => {
    const panel = await openGenerate({ language: 'en', text: 'A' })

    expect(await panel.findByText('Generated voices are not available for en.')).toBeInTheDocument()
    expect(panel.queryByLabelText('Words to say')).not.toBeInTheDocument()
  })

  it('reads the settings once for every field on the page', async () => {
    renderField({ language: 'om', text: 'ሀ' }, { language: 'om', text: 'ሀገር' })
    for (const tab of screen.getAllByRole('tab', { name: 'Generate' })) await userEvent.click(tab)

    await waitFor(() => expect(screen.getAllByRole('radio', { name: 'Female · Obse' })).toHaveLength(2))
    expect(server.callsTo('GET', SETTINGS)).toHaveLength(1)
    expect(server.callsTo('GET', VOICES)).toHaveLength(1)
  })
})

describe('trimming and keeping a take (bolt 097)', () => {
  beforeEach(() => {
    vi.mocked(prepareClip).mockImplementation(async () => prepared())
  })

  /** A field whose store is recorded: what it was handed, and the address it gave. */
  function renderStoring() {
    const stored: { clip: Blob; type: string }[] = []
    let fail = false
    function Storing() {
      const [url, setUrl] = useState('')
      return (
        <AudioField
          upload={async (clip, type) => {
            if (fail) throw new Error('The upload link expired. Try again.')
            stored.push({ clip, type })
            return `https://pub.example/om/gen-${stored.length}.mp3`
          }}
          url={url}
          savedUrl={null}
          onChange={setUrl}
          voice={{ language: 'om', text: 'Maqaan koo Saaraa dha.' }}
        />
      )
    }
    render(
      <MemoryRouter>
        <SessionProvider>
          <Storing />
        </SessionProvider>
      </MemoryRouter>,
    )
    return { stored, failNext: () => (fail = true) }
  }

  async function generated() {
    await userEvent.click(screen.getByRole('tab', { name: 'Generate' }))
    const panel = within(screen.getByRole('tabpanel', { name: 'Generate' }))
    await userEvent.click(await panel.findByRole('button', { name: 'Generate' }))
    await panel.findByText('Obse · 2.0 s · not stored yet')
    return panel
  }

  it('opens the take in the clip editor with its silence cut', async () => {
    renderStoring()
    const panel = await generated()

    expect(await panel.findByRole('radio', { name: /Cleaned.*0\.73 s/ })).toBeChecked()
    expect(panel.getByRole('radio', { name: /As generated/ })).toBeInTheDocument()
    expect(panel.queryByRole('radio', { name: /As recorded/ })).not.toBeInTheDocument()
    expect(panel.getByText(/Silence trimmed and the volume evened: 2\.00 s → 0\.73 s/)).toBeInTheDocument()
    expect(panel.getByRole('group', { name: 'Improve the sound' })).toBeInTheDocument()
  })

  it('moves the cut by hand', async () => {
    renderStoring()
    const panel = await generated()
    await panel.findByRole('radio', { name: /Cleaned/ })

    fireEvent.change(panel.getByRole('slider', { name: /End/ }), { target: { value: '1.5' } })

    expect(panel.getByText(/2\.00 s → 1\.08 s/)).toBeInTheDocument()
  })

  it('keeps the cleaned take as the clip, like an uploaded file', async () => {
    const { stored } = renderStoring()
    const panel = await generated()
    await panel.findByRole('radio', { name: /Cleaned/ })

    await userEvent.click(panel.getByRole('button', { name: 'Use this clip' }))

    await waitFor(() => expect(stored).toHaveLength(1))
    expect(stored[0]!.type).toBe('audio/mpeg')
    // The cleaned version: the cut, made into a fresh mp3.
    expect(stored[0]!.clip.size).toBeGreaterThan(3)
    expect(screen.getByText('https://pub.example/om/gen-1.mp3')).toBeInTheDocument()
    expect(screen.getByText('Not saved yet')).toBeInTheDocument()
    expect(panel.queryByText(/not stored yet/)).not.toBeInTheDocument()
  })

  it('keeps the take as generated when asked', async () => {
    const { stored } = renderStoring()
    const panel = await generated()
    await userEvent.click(await panel.findByRole('radio', { name: /As generated/ }))

    await userEvent.click(panel.getByRole('button', { name: 'Use this clip' }))

    await waitFor(() => expect(stored).toHaveLength(1))
    // The mp3 Addis sent, byte for byte: 'mp3'.
    expect(stored[0]!.clip.size).toBe(3)
    expect(stored[0]!.type).toBe('audio/mpeg')
  })

  it('keeps the take when storing it fails', async () => {
    const { failNext } = renderStoring()
    const panel = await generated()
    await panel.findByRole('radio', { name: /Cleaned/ })
    failNext()

    await userEvent.click(panel.getByRole('button', { name: 'Use this clip' }))

    expect(await panel.findByText('The upload link expired. Try again.')).toBeInTheDocument()
    expect(panel.getByText('Obse · 2.0 s · not stored yet')).toBeInTheDocument()
    expect(panel.getByRole('button', { name: 'Use this clip' })).toBeEnabled()
  })

  it('gives a new take its own cut, and keeps the effects chosen', async () => {
    renderStoring()
    const panel = await generated()
    await panel.findByRole('radio', { name: /Cleaned/ })
    fireEvent.change(panel.getByRole('slider', { name: /End/ }), { target: { value: '1.5' } })
    await userEvent.click(panel.getByRole('button', { name: 'Warmer' }))

    await userEvent.click(panel.getByRole('button', { name: 'Generate again' }))

    await waitFor(() => expect(panel.getByText(/warmer: 2\.00 s → 0\.73 s/)).toBeInTheDocument())
    expect(server.callsTo('POST', GENERATE)).toHaveLength(2)
  })

  it('discards the take', async () => {
    const { stored } = renderStoring()
    const panel = await generated()

    await userEvent.click(panel.getByRole('button', { name: 'Discard' }))

    expect(panel.queryByText(/not stored yet/)).not.toBeInTheDocument()
    expect(panel.queryByRole('button', { name: 'Use this clip' })).not.toBeInTheDocument()
    expect(stored).toHaveLength(0)
  })
})

describe('the generated label (bolt 099)', () => {
  it('tags a kept take with its voice, so the stored name says who spoke it', async () => {
    const sources: (string | undefined)[] = []
    function Tagging() {
      const [url, setUrl] = useState('')
      return (
        <AudioField
          upload={async (_clip, _type, source) => {
            sources.push(source)
            return 'https://pub.example/om/lesson-1/gen-om-obse-0123456789ab.mp3'
          }}
          url={url}
          savedUrl={null}
          onChange={setUrl}
          voice={{ language: 'om', text: 'Akkam' }}
        />
      )
    }
    render(
      <MemoryRouter>
        <SessionProvider>
          <Tagging />
        </SessionProvider>
      </MemoryRouter>,
    )
    await userEvent.click(screen.getByRole('tab', { name: 'Generate' }))
    const panel = within(screen.getByRole('tabpanel', { name: 'Generate' }))
    await userEvent.click(await panel.findByRole('button', { name: 'Generate' }))
    await userEvent.click(await panel.findByRole('button', { name: 'Use this clip' }))

    await waitFor(() => expect(sources).toEqual(['gen-om-obse']))
    expect(await screen.findByText('Generated · Obse')).toHaveAttribute('title', 'Made with Addis AI')
  })

  it.each([
    ['https://pub.example/om/lesson-1/gen-om-obse-0123456789ab.mp3', 'Obse'],
    ['https://pub.example/am/sounds/gen-am-yohanes-calm-abcdefabcdef.mp3', 'Yohanes'],
    ['/media/audio/am/curriculum/W001/gen-am-loza-0123456789ab.mp3?v=2', 'Loza'],
    ['https://pub.example/om/lesson-1/0123456789ab.mp3', null],
    ['https://example.com/gen-om-obse.mp3', null],
  ])('reads the voice from %s', (url, voice) => {
    expect(generatedVoiceOf(url)).toBe(voice)
  })

  it('shows no label on a clip that was not generated', () => {
    render(
      <MemoryRouter>
        <SessionProvider>
          <AudioField upload={async () => ''} url="https://pub.example/om/lesson-1/0123456789ab.m4a" savedUrl={null} onChange={() => {}} />
        </SessionProvider>
      </MemoryRouter>,
    )

    expect(screen.getByText('Hosted')).toBeInTheDocument()
    expect(screen.queryByText(/^Generated/)).not.toBeInTheDocument()
  })
})
