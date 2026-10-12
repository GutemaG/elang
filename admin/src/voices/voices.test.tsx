import { fireEvent, screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

import { FakeServer, type Call } from '../test/fakeServer'
import { idTokenFor } from '../test/fixtures'
import { renderApp, withStoredSession } from '../test/renderApp'
import type { VoiceLanguage, VoiceOption, VoiceSettingsList } from './api'

vi.mock('../auth/GoogleButton', () => ({
  GoogleButton: ({ onCredential }: { onCredential: (token: string) => void }) => (
    <button type="button" onClick={() => onCredential(idTokenFor('admin@example.com'))}>
      Sign in with Google
    </button>
  ),
}))

const ME = '/api/v1/admin/me'
const SETTINGS = '/api/v1/admin/voice/settings'
const VOICES = '/api/v1/admin/voice/voices'

const voice = (id: string, gender: string, style: string, descriptor = `${id} voice`): VoiceOption => ({
  id,
  name: id.split('-')[1]!.replace(/^./, (c) => c.toUpperCase()),
  descriptor,
  gender,
  style,
  preview_audio_url: null,
})

const CATALOG: Record<string, VoiceOption[]> = {
  am: [
    voice('am-yohanes-calm', 'male', 'Narration', 'Low-key reflective tone'),
    voice('am-simon', 'male', 'Commercial'),
    voice('am-loza', 'female', 'Narration'),
  ],
  om: [
    voice('om-hawi', 'female', 'Educational'),
    voice('om-diriba', 'male', 'Narration'),
    voice('om-obse', 'female', 'Narration', 'Clear and steady'),
  ],
}

const lang = (language: string, name: string, male: string, female: string): VoiceLanguage => ({
  language,
  language_name: name,
  male_voice_id: male,
  female_voice_id: female,
  speed: 50,
  updated_by: null,
  updated_at: null,
})

let server: FakeServer
let settings: VoiceSettingsList

beforeEach(() => {
  withStoredSession()
  settings = {
    configured: true,
    languages: [
      lang('am', 'Amharic', 'am-yohanes-calm', 'am-loza'),
      lang('om', 'Afaan Oromo', 'om-diriba', 'om-obse'),
    ],
  }
  server = new FakeServer()
    .install()
    .on('GET', ME, { body: { email: 'admin@example.com' } })
    .on('GET', SETTINGS, () => ({ body: settings }))
    .on('GET', VOICES, (call) => {
      const code = new URLSearchParams(call.query).get('language') ?? ''
      return { body: { language: code, voices: CATALOG[code] ?? [] } }
    })
})

const card = async (title: string) => within(await screen.findByRole('region', { name: title }))

/** Saves a language: echoes the body back as stored by the admin. */
function acceptSaves() {
  server.on('PUT', `${SETTINGS}/om`, (call: Call) => ({
    body: {
      ...settings.languages[1],
      ...(call.body as object),
      updated_by: 'admin@example.com',
      updated_at: '2026-10-12T14:05:00Z',
    },
  }))
  server.on('PUT', `${SETTINGS}/am`, (call: Call) => ({
    body: {
      ...settings.languages[0],
      ...(call.body as object),
      updated_by: 'admin@example.com',
      updated_at: '2026-10-12T14:05:00Z',
    },
  }))
}

describe('the voices page', () => {
  it('is in the menu and shows each language with its default voices', async () => {
    renderApp('/')
    await userEvent.click(await screen.findByRole('link', { name: 'Voices' }))

    expect(await screen.findByRole('heading', { name: 'Voices' })).toBeInTheDocument()
    const om = await card('Afaan Oromo · om')
    await waitFor(() => expect(om.getByLabelText('Male voice')).toHaveValue('om-diriba'))
    expect(om.getByLabelText('Female voice')).toHaveValue('om-obse')
    expect(om.getByText('Clear and steady')).toBeInTheDocument()
    expect(om.getByLabelText('Speed')).toHaveValue('50')
    expect(om.getByText('Default voices')).toBeInTheDocument()
    expect(await card('Amharic · am')).toBeTruthy()
  })

  it('lists only each gender’s voices, by name and style, in Addis’s order', async () => {
    renderApp('/voices')
    const om = await card('Afaan Oromo · om')

    await waitFor(() => expect(om.getByLabelText('Female voice')).toHaveValue('om-obse'))
    const female = within(om.getByLabelText('Female voice')).getAllByRole('option')
    expect(female.map((o) => o.textContent)).toEqual(['Hawi · Educational', 'Obse · Narration'])
    const male = within(om.getByLabelText('Male voice')).getAllByRole('option')
    expect(male.map((o) => o.textContent)).toEqual(['Diriba · Narration'])
  })

  it('saves a language only once something changed, and shows who changed it', async () => {
    acceptSaves()
    renderApp('/voices')
    const om = await card('Afaan Oromo · om')
    await waitFor(() => expect(om.getByLabelText('Female voice')).toHaveValue('om-obse'))
    const save = om.getByRole('button', { name: 'Save Afaan Oromo' })
    expect(save).toBeDisabled()

    await userEvent.selectOptions(om.getByLabelText('Female voice'), 'om-hawi')
    fireEvent.change(om.getByLabelText('Speed'), { target: { value: '40' } })
    expect(om.getByLabelText('Speed')).toHaveValue('40')
    await userEvent.click(save)

    expect(await om.findByText('Saved')).toBeInTheDocument()
    expect(server.callsTo('PUT', `${SETTINGS}/om`)[0]!.body).toEqual({
      male_voice_id: 'om-diriba',
      female_voice_id: 'om-hawi',
      speed: 40,
    })
    expect(om.getByText(/^Last changed by admin@example\.com, 12 Oct/)).toBeInTheDocument()
    expect(save).toBeDisabled()
  })

  it('discards unsaved changes and resets the speed to 50', async () => {
    renderApp('/voices')
    const am = await card('Amharic · am')
    await waitFor(() => expect(am.getByLabelText('Male voice')).toHaveValue('am-yohanes-calm'))

    await userEvent.selectOptions(am.getByLabelText('Male voice'), 'am-simon')
    fireEvent.change(am.getByLabelText('Speed'), { target: { value: '55' } })
    expect(am.getByLabelText('Speed')).toHaveValue('55')
    await userEvent.click(am.getByRole('button', { name: 'Reset to 50' }))
    expect(am.getByLabelText('Speed')).toHaveValue('50')
    await userEvent.click(am.getByRole('button', { name: 'Discard' }))

    expect(am.getByLabelText('Male voice')).toHaveValue('am-yohanes-calm')
    expect(am.getByRole('button', { name: 'Save Amharic' })).toBeDisabled()
  })

  it('shows the server’s refusal under the field it is about', async () => {
    server.on('PUT', `${SETTINGS}/om`, {
      status: 422,
      body: {
        error_code: 'invalid_content',
        message: 'No available female voice om-hawi',
        details: { field: 'female_voice_id' },
      },
    })
    renderApp('/voices')
    const om = await card('Afaan Oromo · om')
    await waitFor(() => expect(om.getByLabelText('Female voice')).toHaveValue('om-obse'))

    await userEvent.selectOptions(om.getByLabelText('Female voice'), 'om-hawi')
    await userEvent.click(om.getByRole('button', { name: 'Save Afaan Oromo' }))

    expect(await om.findByText('No available female voice om-hawi')).toBeInTheDocument()
    expect(om.queryByText('Saved')).not.toBeInTheDocument()
  })

  it('saving one language keeps the other’s unsaved edit', async () => {
    acceptSaves()
    renderApp('/voices')
    const am = await card('Amharic · am')
    const om = await card('Afaan Oromo · om')
    await waitFor(() => expect(om.getByLabelText('Female voice')).toHaveValue('om-obse'))

    await userEvent.selectOptions(om.getByLabelText('Female voice'), 'om-hawi')
    await userEvent.selectOptions(am.getByLabelText('Male voice'), 'am-simon')
    await userEvent.click(am.getByRole('button', { name: 'Save Amharic' }))

    expect(await am.findByText('Saved')).toBeInTheDocument()
    expect(om.getByLabelText('Female voice')).toHaveValue('om-hawi')
    expect(om.getByRole('button', { name: 'Save Afaan Oromo' })).toBeEnabled()
  })

  it('keeps a saved voice the list no longer has, rather than changing it', async () => {
    settings.languages[1] = lang('om', 'Afaan Oromo', 'om-retired', 'om-obse')
    renderApp('/voices')
    const om = await card('Afaan Oromo · om')

    await waitFor(() => expect(om.getByLabelText('Male voice')).toHaveValue('om-retired'))
    expect(om.getByRole('button', { name: 'Save Afaan Oromo' })).toBeDisabled()
  })

  it('is read-only and asks Addis nothing when the server has no key', async () => {
    settings.configured = false
    renderApp('/voices')

    expect(await screen.findByText(/Generated voices aren’t set up on this server/)).toBeInTheDocument()
    const om = await card('Afaan Oromo · om')
    expect(om.getByText('om-diriba')).toBeInTheDocument()
    expect(om.queryByRole('button', { name: 'Save Afaan Oromo' })).not.toBeInTheDocument()
    expect(server.callsTo('GET', VOICES)).toHaveLength(0)
  })

  it('a voice list that fails to load says so on its card, with Retry', async () => {
    let failing = true
    server.on('GET', VOICES, (call) => {
      const code = new URLSearchParams(call.query).get('language') ?? ''
      if (code === 'om' && failing) {
        return { status: 502, body: { error_code: 'voice_service_failed', message: 'The voice service failed. Try again.' } }
      }
      return { body: { language: code, voices: CATALOG[code] ?? [] } }
    })
    renderApp('/voices')
    const om = await card('Afaan Oromo · om')

    expect(await om.findByText(/The voice list couldn’t be loaded/)).toBeInTheDocument()
    const am = await card('Amharic · am')
    await waitFor(() => expect(am.getByText('Low-key reflective tone')).toBeInTheDocument())

    failing = false
    await userEvent.click(om.getByRole('button', { name: 'Retry' }))
    await waitFor(() => expect(om.queryByText(/The voice list couldn’t be loaded/)).not.toBeInTheDocument())
    expect(om.getByText('Clear and steady')).toBeInTheDocument()
  })

  it('offers to try again when the settings can’t be loaded', async () => {
    let failing = true
    server.on('GET', SETTINGS, () =>
      failing ? { status: 500, body: { error_code: 'server_error', message: 'The server failed.' } } : { body: settings },
    )
    renderApp('/voices')

    expect(await screen.findByText('The server failed.')).toBeInTheDocument()
    failing = false
    await userEvent.click(screen.getByRole('button', { name: 'Try again' }))

    expect(await card('Afaan Oromo · om')).toBeTruthy()
  })
})

describe('hearing the voices', () => {
  const GENERATE = '/api/v1/admin/voice/generate'
  const USAGE = '/api/v1/admin/voice/usage'
  const take = () => ({
    body: new Blob(['mp3'], { type: 'audio/mpeg' }),
    headers: { 'Content-Type': 'audio/mpeg', 'X-Voice-Id': 'om-hawi', 'X-Voice-Name': 'Hawi' },
  })

  let play: ReturnType<typeof vi.spyOn>
  let balance: string
  const previews = CATALOG.om!

  beforeEach(() => {
    balance = 'Br 997.53'
    CATALOG.om = previews.map((v) => ({ ...v, preview_audio_url: `https://cdn.example/${v.id}.mp3` }))
    play = vi.spyOn(HTMLMediaElement.prototype, 'play').mockResolvedValue(undefined)
    vi.spyOn(HTMLMediaElement.prototype, 'pause').mockImplementation(() => {})
    URL.createObjectURL = vi.fn(() => 'blob:take-1')
    URL.revokeObjectURL = vi.fn()
    server
      .on('GET', USAGE, () => ({
        body: {
          balance: 997.53,
          currency: 'ETB',
          formatted_balance: balance,
          price_per_minute: 2.5,
          max_characters: 5000,
        },
      }))
      .on('POST', GENERATE, take)
  })

  afterEach(() => {
    CATALOG.om = previews
  })

  const ready = async () => {
    renderApp('/voices')
    const om = await card('Afaan Oromo · om')
    await waitFor(() => expect(om.getByLabelText('Female voice')).toHaveValue('om-obse'))
    return om
  }
  const playedSrc = () => (play.mock.contexts.at(-1) as HTMLAudioElement | undefined)?.src

  it('plays a voice’s preview, and one sound at a time', async () => {
    const om = await ready()

    await userEvent.click(om.getByRole('button', { name: 'Play Obse preview' }))
    expect(playedSrc()).toBe('https://cdn.example/om-obse.mp3')
    expect(om.getByRole('button', { name: 'Stop' })).toBeInTheDocument()

    await userEvent.click(om.getByRole('button', { name: 'Play Diriba preview' }))
    expect(playedSrc()).toBe('https://cdn.example/om-diriba.mp3')
    // Only the one now playing offers Stop.
    expect(om.getAllByRole('button', { name: 'Stop' })).toHaveLength(1)
    expect(om.getByRole('button', { name: 'Play Obse preview' })).toBeInTheDocument()
  })

  it('a voice without a preview can’t be played', async () => {
    renderApp('/voices')
    const am = await card('Amharic · am')
    await waitFor(() => expect(am.getByLabelText('Male voice')).toHaveValue('am-yohanes-calm'))

    expect(am.getByRole('button', { name: 'Play Yohanes preview' })).toBeDisabled()
  })

  it('tries the unsaved choices, plays the take, and saves nothing', async () => {
    const om = await ready()
    expect(await screen.findByText('Br 997.53')).toBeInTheDocument()
    expect(om.getByLabelText('Sample')).toHaveValue('Akkam! Maqaan koo Saaraa dha. Baga nagaan dhufte.')

    await userEvent.selectOptions(om.getByLabelText('Female voice'), 'om-hawi')
    fireEvent.change(om.getByLabelText('Speed'), { target: { value: '35' } })
    balance = 'Br 997.40'
    await userEvent.click(om.getByRole('button', { name: 'Try female' }))

    await waitFor(() => expect(playedSrc()).toBe('blob:take-1'))
    expect(server.callsTo('POST', GENERATE)[0]!.body).toEqual({
      language: 'om',
      text: 'Akkam! Maqaan koo Saaraa dha. Baga nagaan dhufte.',
      gender: 'female',
      voice_id: 'om-hawi',
      speed: 35,
    })
    expect(await screen.findByText('Br 997.40')).toBeInTheDocument()
    expect(server.callsTo('PUT', `${SETTINGS}/om`)).toHaveLength(0)
    // The edit is still unsaved.
    expect(om.getByRole('button', { name: 'Save Afaan Oromo' })).toBeEnabled()
  })

  it('says “Generating…” and holds both tries while one runs', async () => {
    const om = await ready()
    let answer: () => void = () => {}
    const fakeFetch = globalThis.fetch
    vi.stubGlobal('fetch', (input: RequestInfo | URL, init?: RequestInit) => {
      if (new URL(String(input)).pathname !== GENERATE) return fakeFetch(input, init)
      return new Promise<Response>((resolve) => {
        answer = () => resolve(new Response(new Blob(['mp3']), { status: 200, headers: { 'Content-Type': 'audio/mpeg' } }))
      })
    })

    await userEvent.click(om.getByRole('button', { name: 'Try male' }))

    expect(await om.findByRole('button', { name: 'Generating…' })).toBeDisabled()
    expect(om.getByRole('button', { name: 'Try female' })).toBeDisabled()
    answer()
    expect(await om.findByRole('button', { name: 'Try male' })).toBeEnabled()
  })

  it('shows why a try failed', async () => {
    server.on('POST', GENERATE, {
      status: 402,
      body: { error_code: 'voice_credit_exhausted', message: 'The Addis AI credit has run out.' },
    })
    const om = await ready()

    await userEvent.click(om.getByRole('button', { name: 'Try female' }))

    expect(await om.findByText('The Addis AI credit has run out.')).toBeInTheDocument()
    expect(play).not.toHaveBeenCalled()
  })

  it('an empty or overlong sample can’t be tried', async () => {
    const om = await ready()

    await userEvent.clear(om.getByLabelText('Sample'))
    expect(om.getByRole('button', { name: 'Try male' })).toBeDisabled()
    expect(om.getByText('0 / 500')).toBeInTheDocument()

    fireEvent.change(om.getByLabelText('Sample'), { target: { value: 'a'.repeat(501) } })
    expect(om.getByRole('button', { name: 'Try female' })).toBeDisabled()
    expect(om.getByText('501 / 500')).toBeInTheDocument()
  })

  it('warns when Addis no longer offers a saved voice', async () => {
    settings.languages[1] = lang('om', 'Afaan Oromo', 'om-retired', 'om-obse')
    renderApp('/voices')
    const om = await card('Afaan Oromo · om')

    expect(await om.findByText('Addis AI no longer offers this voice. Choose another and save.')).toBeInTheDocument()
    expect(om.getByRole('option', { name: 'om-retired (no longer offered)' })).toBeInTheDocument()
  })

  it('shows the credit left and the price', async () => {
    renderApp('/voices')

    expect(await screen.findByText('Br 997.53')).toBeInTheDocument()
    expect(screen.getByText(/· 2\.5 ETB per minute of audio/)).toBeInTheDocument()
  })

  it('a credit that can’t be read is left out, and the page still works', async () => {
    server.on('GET', USAGE, {
      status: 502,
      body: { error_code: 'voice_service_failed', message: 'The voice service failed.' },
    })
    const om = await ready()

    expect(screen.queryByText(/^Credit:/)).not.toBeInTheDocument()
    expect(screen.queryByText('The voice service failed.')).not.toBeInTheDocument()
    expect(om.getByRole('button', { name: 'Try female' })).toBeEnabled()
  })
})
