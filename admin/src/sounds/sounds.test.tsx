import { fireEvent, screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import { FakeServer, type Call } from '../test/fakeServer'
import { renderApp, withStoredSession } from '../test/renderApp'
import type { AdminSoundChart, AdminSoundLetter, SoundLetterChange } from '../types'
import { chartToCsv, csvToChanges, matchFiles, searchLetters } from './model'

vi.mock('../auth/GoogleButton', () => ({ GoogleButton: () => null }))

const A = '/api/v1/admin'
const CHARTS = `${A}/sound-charts`
const AM = `${CHARTS}/am`
const LETTERS = `${AM}/letters`
const UPLOADS = `${AM}/audio/uploads`
const STORE_PATH = '/am/sounds/0123456789ab.m4a'
const PUBLIC_URL = `https://pub.example${STORE_PATH}`

function letter(id: string, glyph: string, romanization: string, extra: Partial<AdminSoundLetter> = {}): AdminSoundLetter {
  return {
    id,
    group: 'fidel',
    position: 0,
    glyph,
    romanization,
    hint: {},
    audio_url: null,
    same_as_id: null,
    example_word: null,
    example_romanization: null,
    example_meaning: {},
    example_audio_url: null,
    status: 'draft',
    recorded_by: null,
    updated_at: '2026-10-04T09:00:00Z',
    ...extra,
  }
}

/** Two rows of a small Fidel: ሀ ሁ (ሀ recorded and ready), and ሐ ሑ, which
 * sound like them. */
function smallChart(): AdminSoundChart {
  const letters = [
    letter('ha', 'ሀ', 'he', { position: 0, audio_url: 'https://pub.example/am/sounds/aaaaaaaaaaaa.m4a', status: 'ready' }),
    letter('hu', 'ሁ', 'hu', { position: 1 }),
    letter('hha', 'ሐ', 'he', { position: 2, same_as_id: 'ha' }),
    letter('hhu', 'ሑ', 'hu', { position: 3, same_as_id: 'hu' }),
  ]
  return withCounts({
    language: 'am',
    language_name: 'Amharic',
    title: { en: 'Fidel', am: 'ፊደል' },
    enabled: false,
    version: 3,
    updated_at: '2026-10-04T09:00:00Z',
    groups: [{ key: 'fidel', names: { en: 'Fidel' }, columns: 2, column_labels: ['e', 'u'] }],
    letters,
    counts: { letters: 0, ready: 0, needs_review: 0, draft: 0, needs_recording: 0, same_sound: 0 },
    gaps: { no_letters: false, no_romanization: 0, no_audio: 0 },
  })
}

/** Works the counts out as the server does. */
function withCounts(chart: AdminSoundChart): AdminSoundChart {
  const xs = chart.letters
  const byId = new Map(xs.map((x) => [x.id, x]))
  return {
    ...chart,
    counts: {
      letters: xs.length,
      ready: xs.filter((x) => x.status === 'ready').length,
      needs_review: xs.filter((x) => x.status === 'needs_review').length,
      draft: xs.filter((x) => x.status === 'draft').length,
      needs_recording: xs.filter((x) => !x.same_as_id && !x.audio_url).length,
      same_sound: xs.filter((x) => x.same_as_id).length,
    },
    gaps: {
      no_letters: xs.length === 0,
      no_romanization: xs.filter((x) => !x.romanization).length,
      no_audio: xs.filter((x) => !(x.same_as_id ? byId.get(x.same_as_id)?.audio_url : x.audio_url)).length,
    },
  }
}

let server: FakeServer
let chart: AdminSoundChart

function serve() {
  server
    .on('GET', `${A}/me`, { body: { email: 'admin@example.com' } })
    .on('GET', CHARTS, () => ({ body: { charts: [chart] } }))
    .on('GET', AM, () => ({ body: chart }))
    .on('PATCH', LETTERS, (call: Call) => {
      const { letters } = call.body as { letters: SoundLetterChange[] }
      chart = withCounts({
        ...chart,
        version: chart.version + 1,
        letters: chart.letters.map((x) => {
          const change = letters.find((c) => c.id === x.id)
          return change ? { ...x, ...change } : x
        }),
      })
      return { body: chart }
    })
    .on('PATCH', AM, (call: Call) => {
      chart = withCounts({ ...chart, ...(call.body as Partial<AdminSoundChart>), version: chart.version + 1 })
      return { body: chart }
    })
    .on('POST', UPLOADS, () => ({
      status: 201,
      body: {
        upload_url: `https://store.example${STORE_PATH}?X-Amz-Signature=abc`,
        method: 'PUT',
        headers: { 'Content-Type': 'audio/mpeg' },
        key: STORE_PATH.slice(1),
        public_url: PUBLIC_URL,
        expires_in: 600,
      },
    }))
    .on('PUT', STORE_PATH, { status: 200 })
}

beforeEach(() => {
  withStoredSession()
  chart = smallChart()
  server = new FakeServer().install()
  serve()
})

const patches = () => server.callsTo('PATCH', LETTERS).map((c) => (c.body as { letters: SoundLetterChange[] }).letters)

describe('the Sounds list', () => {
  it('is in the menu and shows each chart with how far it has got', async () => {
    renderApp('/')
    await userEvent.click(await screen.findByRole('link', { name: 'Sounds' }))

    const card = await screen.findByRole('link', { name: /Amharic · Fidel/ })
    expect(card).toHaveTextContent('Not in the app')
    // ሀ is recorded; ሁ is not; ሐ and ሑ share their sounds.
    expect(card).toHaveTextContent('4 letters · 1 of 2 sounds recorded · 1 ready')
  })

  it('starts a chart from a template, choosing it to suit the language', async () => {
    server
      .on('GET', CHARTS, { body: { charts: [] } })
      .on('GET', `${A}/languages`, {
        body: {
          languages: [
            { code: 'en', name: 'English', native_name: 'English', course_count: 2 },
            { code: 'om', name: 'Afaan Oromo', native_name: 'Afaan Oromoo', course_count: 1 },
          ],
        },
      })
      .on('POST', CHARTS, (call: Call) => ({ status: 201, body: { ...chart, language: (call.body as { language: string }).language } }))
      .on('GET', `${CHARTS}/om`, { body: { ...chart, language: 'om', language_name: 'Afaan Oromo' } })
    renderApp('/sounds')

    await userEvent.click(await screen.findByRole('button', { name: 'New chart' }))
    const dialog = within(await screen.findByRole('dialog', { name: 'New sounds chart' }))
    // English is taught from, never learned: it has no chart.
    expect(await dialog.findByRole('option', { name: /Afaan Oromo/ })).toBeInTheDocument()
    expect(dialog.queryByRole('option', { name: /English/ })).not.toBeInTheDocument()
    expect(dialog.getByRole('radio', { name: /Qubee/ })).toBeChecked()

    await userEvent.click(dialog.getByRole('button', { name: 'Create chart' }))

    expect(server.callsTo('POST', CHARTS)[0]!.body).toEqual({ language: 'om', template: 'qubee' })
    expect(await screen.findByRole('heading', { name: 'Afaan Oromo · Fidel' })).toBeInTheDocument()
  })
})

describe('a chart', () => {
  it('shows every letter with where it stands, and filters them', async () => {
    renderApp('/sounds/am')

    expect(await screen.findByRole('heading', { name: 'Amharic · Fidel' })).toBeInTheDocument()
    expect(screen.getByRole('link', { name: 'ሀ, he: Ready' })).toBeInTheDocument()
    expect(screen.getByRole('link', { name: 'ሁ, hu: No audio' })).toBeInTheDocument()
    expect(screen.getByRole('link', { name: 'ሐ, he: Same sound as ሀ' })).toBeInTheDocument()
    expect(screen.getByRole('link', { name: /Record missing \(1\)/ })).toBeInTheDocument()

    await userEvent.click(screen.getByRole('button', { name: 'No audio' }))
    expect(screen.getByRole('link', { name: 'ሁ, hu: No audio' })).not.toHaveClass('opacity-30')
    expect(screen.getByRole('link', { name: 'ሀ, he: Ready' })).toHaveClass('opacity-30')
  })

  it('will not show the chart in the app until every sound has audio', async () => {
    renderApp('/sounds/am')

    await userEvent.click(await screen.findByRole('button', { name: 'Show in the app…' }))
    const dialog = within(screen.getByRole('dialog', { name: 'Show this chart in the app?' }))
    expect(dialog.getByText('1 of 2 still need a recording.')).toBeInTheDocument()
    expect(dialog.getByRole('button', { name: 'Show in the app' })).toBeDisabled()
  })

  it('shows a complete chart in the app', async () => {
    chart = withCounts({ ...chart, letters: chart.letters.map((x) => (x.id === 'hu' ? { ...x, audio_url: PUBLIC_URL } : x)) })
    renderApp('/sounds/am')

    await userEvent.click(await screen.findByRole('button', { name: 'Show in the app…' }))
    await userEvent.click(screen.getByRole('button', { name: 'Show in the app' }))

    expect(server.callsTo('PATCH', AM)[0]!.body).toEqual({ enabled: true })
    expect(await screen.findByRole('status')).toHaveTextContent('Learners see the Sounds tab')
    expect(screen.getByText('In the app')).toBeInTheDocument()
  })

  it('marks many letters ready at once, skipping any that cannot be', async () => {
    chart = withCounts({
      ...chart,
      letters: [
        ...chart.letters.map((x) => (x.id === 'hu' ? { ...x, audio_url: PUBLIC_URL, status: 'needs_review' as const } : x)),
        letter('le', 'ለ', 'le', { position: 4, audio_url: PUBLIC_URL, status: 'needs_review' }),
        letter('lu', 'ሉ', 'lu', { position: 5 }),
      ],
    })
    renderApp('/sounds/am')
    await userEvent.click(await screen.findByRole('button', { name: 'Select letters' }))
    const toolbar = within(screen.getByRole('toolbar', { name: 'Selected letters' }))
    expect(toolbar.getByRole('button', { name: 'Mark ready' })).toBeDisabled()

    // No recording, or another letter's: nothing to mark.
    expect(screen.getByRole('button', { name: 'ሉ, lu: No audio' })).toBeDisabled()
    expect(screen.getByRole('button', { name: 'ሐ, he: Same sound as ሀ' })).toBeDisabled()

    // Only those that need review, from the filter.
    await userEvent.click(screen.getByRole('button', { name: 'Needs review' }))
    await userEvent.click(toolbar.getByRole('button', { name: 'Select all shown (2)' }))
    expect(toolbar.getByText('2 letters selected')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'ሁ, hu: Needs review' })).toHaveAttribute('aria-pressed', 'true')
    // ሀ is ready already, so picking it changes nothing more.
    await userEvent.click(screen.getByRole('button', { name: 'ሀ, he: Ready' }))
    expect(toolbar.getByText('3 letters selected')).toBeInTheDocument()

    await userEvent.click(toolbar.getByRole('button', { name: 'Mark ready' }))
    const dialog = within(screen.getByRole('dialog', { name: 'Mark 2 letters ready?' }))
    await userEvent.click(dialog.getByRole('button', { name: 'Mark ready' }))

    await waitFor(() =>
      expect(patches()).toEqual([
        [
          { id: 'hu', status: 'ready' },
          { id: 'le', status: 'ready' },
        ],
      ]),
    )
    expect(await screen.findByRole('status')).toHaveTextContent('2 letters marked Ready.')
    expect(screen.queryByRole('toolbar')).not.toBeInTheDocument()
    expect(screen.getByRole('link', { name: 'ለ, le: Ready' })).toBeInTheDocument()
  })

  it('can send letters back for review, and leaves select mode untouched on Done', async () => {
    renderApp('/sounds/am')
    await userEvent.click(await screen.findByRole('button', { name: 'Select letters' }))
    await userEvent.click(screen.getByRole('button', { name: 'ሀ, he: Ready' }))
    await userEvent.click(screen.getByRole('button', { name: 'Mark needs review' }))
    await userEvent.click(within(screen.getByRole('dialog', { name: 'Mark 1 letter needs review?' })).getByRole('button', { name: 'Mark needs review' }))
    await waitFor(() => expect(patches()).toEqual([[{ id: 'ha', status: 'needs_review' }]]))

    await userEvent.click(screen.getByRole('button', { name: 'Select letters' }))
    await userEvent.click(screen.getByRole('button', { name: 'Done' }))
    expect(screen.getByRole('link', { name: 'ሀ, he: Needs review' })).toBeInTheDocument()
    expect(patches()).toHaveLength(1)
  })

  it('imports a CSV as changes to only the letters that differ', async () => {
    renderApp('/sounds/am')
    await screen.findByRole('heading', { name: 'Amharic · Fidel' })

    const csv = chartToCsv(chart).replace(',hu,,,,', ',hu,Like the u in put,,,')
    fireEvent.change(screen.getByLabelText('CSV file to import'), {
      target: { files: [new File([csv], 'sounds-am.csv', { type: 'text/csv' })] },
    })

    const dialog = within(await screen.findByRole('dialog', { name: 'Import from CSV' }))
    expect(dialog.getByText(/1 letter will change/)).toBeInTheDocument()
    await userEvent.click(dialog.getByRole('button', { name: 'Import 1 change' }))

    await waitFor(() => expect(patches()).toEqual([[{ id: 'hu', hint: { en: 'Like the u in put' } }]]))
  })
})

describe('a letter', () => {
  it('saves only what changed, then moves to the next letter', async () => {
    renderApp('/sounds/am/letters/hu')

    expect(await screen.findByRole('heading', { name: /Letter ሁ/ })).toBeInTheDocument()
    await userEvent.clear(screen.getByLabelText('Romanization'))
    await userEvent.type(screen.getByLabelText('Romanization'), 'hū')
    await userEvent.click(screen.getByRole('radio', { name: 'Needs review' }))
    await userEvent.type(screen.getByLabelText('Recorded by'), 'Selam')
    await userEvent.click(screen.getByRole('button', { name: 'Save and next' }))

    await waitFor(() =>
      expect(patches()).toEqual([[{ id: 'hu', romanization: 'hū', status: 'needs_review', recorded_by: 'Selam' }]]),
    )
    expect(await screen.findByRole('heading', { name: /Letter ሐ/ })).toBeInTheDocument()
  })

  it('a letter that sounds like another has nothing to record', async () => {
    renderApp('/sounds/am/letters/hha')

    expect(await screen.findByText(/Plays the recording of ሀ \(he\)/)).toBeInTheDocument()
    expect(screen.queryByRole('tab', { name: 'Record' })).not.toBeInTheDocument()
    expect(screen.getByLabelText('Same sound as')).toHaveValue('ha')
  })

  it('a letter others share keeps its own sound and cannot be deleted', async () => {
    renderApp('/sounds/am/letters/ha')

    expect(await screen.findByLabelText('Same sound as')).toBeDisabled()
    expect(screen.getByText(/ሐ share this letter’s sound/)).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Delete' })).toBeDisabled()
  })
})

describe('uploading many files', () => {
  it('matches each file to its letter by name, then uploads and saves them together', async () => {
    renderApp('/sounds/am/upload')
    await screen.findByLabelText('Recordings')

    const files = [
      new File([new Uint8Array(900)], 'hu.mp3', { type: 'audio/mpeg' }),
      new File([new Uint8Array(900)], 'hello.mp3', { type: 'audio/mpeg' }),
    ]
    await userEvent.upload(screen.getByLabelText('Recordings'), files)

    expect(screen.getByRole('combobox', { name: 'Letter for hu.mp3' })).toHaveValue('ሁ · hu')
    expect(screen.getByRole('combobox', { name: 'Letter for hello.mp3' })).toHaveValue('')
    expect(screen.getByText('No match; pick a letter')).toBeInTheDocument()

    await userEvent.click(screen.getByRole('button', { name: 'Upload 1 file' }))

    await waitFor(() => expect(patches()).toEqual([[{ id: 'hu', audio_url: PUBLIC_URL, status: 'needs_review' }]]))
    expect(server.callsTo('POST', UPLOADS)[0]!.body).toEqual({ content_type: 'audio/mpeg', size: 900 })
    expect(server.callsTo('PUT', STORE_PATH)).toHaveLength(1)
    expect(await screen.findByText('1 recording saved and marked Needs review.')).toBeInTheDocument()
  })

  it('finds a letter by typing its romanization, glyph or hint', async () => {
    chart = withCounts({
      ...chart,
      letters: [
        ...chart.letters,
        letter('le', 'ለ', 'le', { position: 4 }),
        letter('lu', 'ሉ', 'lu', { position: 5, hint: { en: 'as in loot' } }),
      ],
    })
    renderApp('/sounds/am/upload')
    await screen.findByLabelText('Recordings')
    await userEvent.upload(screen.getByLabelText('Recordings'), [
      new File([new Uint8Array(900)], 'take-3.mp3', { type: 'audio/mpeg' }),
    ])
    const picker = screen.getByRole('combobox', { name: 'Letter for take-3.mp3' })
    const options = () => screen.getAllByRole('option').map((o) => o.textContent)

    // Every letter with its own sound, and none that borrow one.
    await userEvent.click(picker)
    expect(options()).toEqual(['ሀheRecorded', 'ሁhu', 'ለle', 'ሉlu'])

    // The exact romanization first, then those that start with it.
    await userEvent.type(picker, 'lu')
    expect(options()).toEqual(['ሉlu'])
    await userEvent.clear(picker)
    await userEvent.type(picker, 'l')
    expect(options()).toEqual(['ለle', 'ሉlu'])
    await userEvent.keyboard('{ArrowDown}{Enter}')
    expect(picker).toHaveValue('ሉ · lu')
    expect(screen.queryByRole('listbox')).not.toBeInTheDocument()

    // By the glyph, or by a word of its hint, with a click.
    await userEvent.clear(picker)
    await userEvent.type(picker, 'ለ')
    await userEvent.click(screen.getByRole('option', { name: /ለ/ }))
    expect(picker).toHaveValue('ለ · le')
    await userEvent.clear(picker)
    await userEvent.type(picker, 'loot')
    expect(options()).toEqual(['ሉlu'])

    // Nothing found says so, and Escape keeps the letter it had.
    await userEvent.clear(picker)
    await userEvent.type(picker, 'zz')
    expect(screen.getByText('No letter matches “zz”.')).toBeInTheDocument()
    await userEvent.keyboard('{Escape}')
    expect(picker).toHaveValue('ለ · le')
    expect(screen.getByRole('button', { name: 'Upload 1 file' })).toBeEnabled()
  })

  it('plays a file before it is sent, and the recording it would replace', async () => {
    let made = 0
    URL.createObjectURL = vi.fn(() => `blob:file-${++made}`)
    URL.revokeObjectURL = vi.fn()
    const play = vi.spyOn(HTMLMediaElement.prototype, 'play').mockResolvedValue(undefined)
    const pause = vi.spyOn(HTMLMediaElement.prototype, 'pause').mockImplementation(() => {})
    const { container } = renderApp('/sounds/am/upload')
    await screen.findByLabelText('Recordings')
    await userEvent.upload(screen.getByLabelText('Recordings'), [
      new File([new Uint8Array(900)], 'hu.mp3', { type: 'audio/mpeg' }),
      new File([new Uint8Array(900)], 'he.mp3', { type: 'audio/mpeg' }),
    ])
    const audio = () => container.querySelector('audio')!

    await userEvent.click(screen.getByRole('button', { name: 'Play hu.mp3' }))
    expect(audio().src).toBe('blob:file-1')
    expect(play).toHaveBeenCalledTimes(1)
    expect(screen.getByRole('button', { name: 'Stop hu.mp3' })).toHaveAttribute('aria-pressed', 'true')

    // Another one takes over; ሀ already has a recording to compare with.
    await userEvent.click(screen.getByRole('button', { name: 'Play ሀ’s current recording' }))
    expect(audio().src).toBe('https://pub.example/am/sounds/aaaaaaaaaaaa.m4a')
    expect(screen.getByRole('button', { name: 'Play hu.mp3' })).toBeInTheDocument()

    await userEvent.click(screen.getByRole('button', { name: 'Stop ሀ’s current recording' }))
    expect(pause).toHaveBeenCalled()
    await userEvent.click(screen.getByRole('button', { name: 'Play he.mp3' }))
    fireEvent.ended(audio())
    expect(screen.queryByRole('button', { name: /^Stop/ })).not.toBeInTheDocument()

    // Nothing was sent to hear them, and a removed file is let go.
    expect(server.callsTo('POST', UPLOADS)).toHaveLength(0)
    await userEvent.click(screen.getByRole('button', { name: 'Remove hu.mp3' }))
    expect(URL.revokeObjectURL).toHaveBeenCalledWith('blob:file-1')
    play.mockRestore()
    pause.mockRestore()
  })

  it('says when the browser cannot play a file', async () => {
    URL.createObjectURL = vi.fn(() => 'blob:file')
    URL.revokeObjectURL = vi.fn()
    const play = vi.spyOn(HTMLMediaElement.prototype, 'play').mockRejectedValue(new Error('NotSupportedError'))
    renderApp('/sounds/am/upload')
    await screen.findByLabelText('Recordings')
    await userEvent.upload(screen.getByLabelText('Recordings'), [
      new File([new Uint8Array(900)], 'hu.mp3', { type: 'audio/mpeg' }),
    ])

    await userEvent.click(screen.getByRole('button', { name: 'Play hu.mp3' }))

    expect(await screen.findByText(/can’t play that recording/)).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Play hu.mp3' })).toBeInTheDocument()
    play.mockRestore()
  })
})

describe('the record session', () => {
  it('says when the browser cannot record', async () => {
    renderApp('/sounds/am/record')

    expect(await screen.findByText(/This browser can’t record audio/)).toBeInTheDocument()
  })
})

describe('the rules', () => {
  const file = (name: string) => new File(['x'], name, { type: 'audio/mpeg' })

  it('searches letters best match first, without needing the apostrophe', () => {
    const xs = [
      letter('ta', 'ተ', 'te'),
      letter('tta', 'ጠ', "t'e"),
      letter('dh', 'Dh dh', 'dh'),
      letter('d', 'D d', 'd', { hint: { en: 'as in dog' } }),
    ]
    const ids = (q: string) => searchLetters(xs, q).map((x) => x.id)
    expect(ids('')).toEqual(['ta', 'tta', 'dh', 'd'])
    expect(ids('te')).toEqual(['ta', 'tta'])
    expect(ids("t'e")).toEqual(['tta', 'ta'])
    expect(ids('d')).toEqual(['d', 'dh'])
    expect(ids('Dh')).toEqual(['dh'])
    expect(ids('ጠ')).toEqual(['tta'])
    expect(ids('dog')).toEqual(['d'])
    expect(ids('x')).toEqual([])
  })

  it('names a file by romanization, glyph or either form of a Qubee letter', () => {
    const letters = [
      letter('dh', 'Dh dh', 'dh'),
      letter('x', 'X x', "t'"),
      letter('ha', 'ሀ', 'he'),
      letter('hha', 'ሐ', 'he', { same_as_id: 'ha' }),
      letter('a1', 'a', 'a'),
      letter('a2', 'A a', 'a'),
    ]
    const ids = (name: string) => {
      const m = matchFiles([file(name)], letters)[0]!
      return m.ambiguous ? 'ambiguous' : (m.letter?.id ?? null)
    }

    expect(ids('dh.m4a')).toBe('dh')
    expect(ids('Dh.mp3')).toBe('dh')
    expect(ids('x.mp3')).toBe('x')
    expect(ids('ta.mp3')).toBeNull()
    expect(ids("t'.mp3")).toBe('x')
    // ሐ shares ሀ's sound, so "he" can only mean ሀ.
    expect(ids('he.mp3')).toBe('ha')
    expect(ids('ሀ.mp3')).toBe('ha')
    expect(ids('a.mp3')).toBe('ambiguous')
  })

  it('reads its own export back as no changes, and names rows it cannot use', () => {
    const c = smallChart()
    expect(csvToChanges(chartToCsv(c), c)).toEqual({ changes: [], problems: [] })

    const edited = chartToCsv(c).concat('\r\nnope,fidel,ሂ,hi,,,,,,,,,draft,\r\n,fidel,ሁ,hū,,,,,,,,,done,')
    const result = csvToChanges(edited, c)
    expect(result.problems).toEqual([
      { line: 6, message: 'No letter in this chart has that id.' },
      { line: 7, message: 'The status must be draft, needs_review or ready, not “done”.' },
    ])
  })

  it('leaves a field alone when its column is not in the file', () => {
    const c = smallChart()
    c.letters[1]!.hint = { en: 'Keep me' }
    const csv = 'glyph,romanization,group\r\nሁ,hū,fidel'
    expect(csvToChanges(csv, c).changes).toEqual([{ id: 'hu', romanization: 'hū' }])
  })
})
