import { screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import { FakeServer } from '../test/fakeServer'
import { renderApp, withStoredSession } from '../test/renderApp'
import { COURSE_ID, PUBLIC_URL, rowPath, serveCurriculum, smallCurriculum, STORE_PATH, UPLOADS } from '../test/workbook'
import type { Curriculum } from '../types'
import { nextUnrecorded, ordered } from './rows'

vi.mock('../auth/GoogleButton', () => ({ GoogleButton: () => null }))
// Reading a clip needs a browser's audio engine; with none, files upload as
// they are.
vi.mock('../audio/codec', async (original) => ({
  ...(await original<typeof import('../audio/codec')>()),
  prepareClip: vi.fn(async () => null),
}))

const L1 = `/courses/${COURSE_ID}/workbook/lessons/S1-U01-L1`
const L2 = `/courses/${COURSE_ID}/workbook/lessons/S1-U01-L2`

let server: FakeServer
let state: { curriculum: Curriculum }

beforeEach(() => {
  withStoredSession()
  state = { curriculum: smallCurriculum() }
  server = new FakeServer().install()
  serveCurriculum(server, state)
  URL.createObjectURL = vi.fn(() => 'blob:clip')
  URL.revokeObjectURL = vi.fn()
})

const rowList = () => within(screen.getByRole('region', { name: 'Words and sentence' }))
const editor = () => within(screen.getByRole('form'))
const patches = (ref: string) => server.callsTo('PATCH', rowPath(ref)).map((c) => c.body)

describe('a lesson’s page', () => {
  it('lists the rows with the least sure first, or in order', async () => {
    renderApp(L2)

    expect(await screen.findByRole('heading', { name: 'How are you?' })).toBeInTheDocument()
    const refs = () => rowList().getAllByRole('button').filter((b) => /^[WS]\d/.test(b.textContent ?? '')).map((b) => b.textContent!.slice(0, 4))
    expect(refs()).toEqual(['W003', 'W002'])
    expect(rowList().getByText('Low')).toBeInTheDocument()

    await userEvent.click(rowList().getByRole('button', { name: 'In order' }))
    expect(refs()).toEqual(['W002', 'W003'])
  })

  it('saves only what changed, with the row’s version, and says who changed it', async () => {
    renderApp(`${L2}?row=W002`)
    const form = await screen.findByRole('form', { name: 'Row W002' })
    expect(within(form).getByText(/Last changed by admin@example.com/)).toBeInTheDocument()
    expect(within(form).getByLabelText('Reviewer comment')).toHaveValue('Use the polite form')

    const text = within(form).getByLabelText('Amharic')
    await userEvent.clear(text)
    await userEvent.type(text, 'ደህና ሁኑ')
    await userEvent.selectOptions(within(form).getByLabelText('Status'), 'Reviewed')
    await userEvent.click(within(form).getByRole('button', { name: 'Save' }))

    expect(await screen.findByRole('status')).toHaveTextContent('Saved.')
    expect(patches('W002')).toEqual([{ version: 1, text: 'ደህና ሁኑ', status: 'reviewed' }])
    expect(rowList().getByRole('button', { name: /W002/ })).toHaveTextContent('Reviewed')
    expect(screen.getByText(/^S1-U01-L2 · 1\/2 reviewed/)).toBeInTheDocument()
  })

  it('warns before new words go over a recording, then says it is back to Draft', async () => {
    renderApp(`${L1}?row=W001`)
    const form = await screen.findByRole('form', { name: 'Row W001' })

    await userEvent.type(within(form).getByLabelText('Romanization'), 'u')

    expect(within(form).getByRole('note')).toHaveTextContent('Saving new words sends it back to Draft')
    await userEvent.click(within(form).getByRole('button', { name: 'Save' }))
    expect(await screen.findByRole('status')).toHaveTextContent('it is back to Draft: check its recording')
    expect(rowList().getByRole('button', { name: /W001/ })).toHaveTextContent('Draft')
  })

  it('says when someone else saved the row first, and reloads it', async () => {
    renderApp(`${L2}?row=W003`)
    const form = await screen.findByRole('form', { name: 'Row W003' })
    state.curriculum = {
      ...state.curriculum,
      rows: state.curriculum.rows.map((r) => (r.ref === 'W003' ? { ...r, version: 2, comment: 'Theirs' } : r)),
    }

    await userEvent.type(within(form).getByLabelText('Reviewer comment'), 'Mine')
    await userEvent.click(within(form).getByRole('button', { name: 'Save' }))

    const alert = await within(form).findByRole('alert')
    expect(alert).toHaveTextContent('Someone saved this row after you opened it.')
    await userEvent.click(within(alert).getByRole('button', { name: 'Reload' }))
    await waitFor(() => expect(editor().getByLabelText('Reviewer comment')).toHaveValue('Theirs'))
  })

  it('keeps the word to blank in the sentence', async () => {
    renderApp(`${L1}?row=S001`)
    const form = await screen.findByRole('form', { name: 'Row S001' })
    const blank = within(form).getByLabelText('Word to blank')

    await userEvent.clear(blank)
    await userEvent.type(blank, 'ሌሊት')

    expect(within(form).getByRole('alert')).toHaveTextContent('“ሌሊት” is not in the sentence.')
    expect(within(form).getByRole('button', { name: 'Save' })).toBeDisabled()
  })

  it('uploads a recording for the row and saves it', async () => {
    renderApp(`${L2}?row=W003`)
    const form = await screen.findByRole('form', { name: 'Row W003' })

    await userEvent.click(within(form).getByRole('tab', { name: /Upload/ }))
    const clip = new File([new Uint8Array(2048)], 'W003.m4a', { type: 'audio/mp4' })
    await userEvent.setup({ applyAccept: false }).upload(within(form).getByLabelText('Audio file'), clip)
    await userEvent.click(within(form).getByRole('button', { name: 'Use this file' }))
    await waitFor(() => expect(server.callsTo('PUT', STORE_PATH)).toHaveLength(1))
    expect(server.callsTo('POST', UPLOADS)[0]!.body).toEqual({ row_ref: 'W003', content_type: 'audio/mp4', size: 2048 })

    await userEvent.click(within(form).getByRole('button', { name: 'Save' }))

    await waitFor(() => expect(patches('W003')).toEqual([{ version: 1, audio_url: PUBLIC_URL }]))
    expect(await screen.findByText(/^S1-U01-L2 · .* 1\/2 recorded$/)).toBeInTheDocument()
  })

  it('goes on to the next row with no recording, in the next lesson too', async () => {
    renderApp(`${L1}?row=S001`)
    const form = await screen.findByRole('form', { name: 'Row S001' })

    await userEvent.click(within(form).getByRole('button', { name: 'Next unrecorded' }))

    expect(await screen.findByRole('heading', { name: 'How are you?' })).toBeInTheDocument()
    expect(await screen.findByRole('form', { name: 'Row W003' })).toBeInTheDocument()
  })

  it('moves between lessons', async () => {
    renderApp(L1)
    await screen.findByRole('heading', { name: 'Hello & goodbye' })
    expect(screen.getByRole('button', { name: 'Previous lesson' })).toBeDisabled()

    await userEvent.click(screen.getByRole('button', { name: 'Next lesson' }))

    expect(await screen.findByRole('heading', { name: 'How are you?' })).toBeInTheDocument()
    expect(screen.getByRole('link', { name: 'English to Amharic' })).toHaveAttribute('href', `/courses/${COURSE_ID}/workbook`)
  })

  it('says so for a lesson that is not in the workbook', async () => {
    renderApp(`/courses/${COURSE_ID}/workbook/lessons/S9-U01-L1`)

    expect(await screen.findByRole('alert')).toHaveTextContent('This lesson is not in the workbook.')
  })
})

describe('the order to check and record in', () => {
  it('finds the next unrecorded row after this one, then in later lessons, then earlier here', () => {
    const { entries, rows } = smallCurriculum()

    expect(ordered(rows.filter((r) => r.lesson_ref === 'S1-U01-L2'), 'check_first').map((r) => r.ref)).toEqual(['W003', 'W002'])
    expect(nextUnrecorded(entries, rows, 'S1-U01-L1', 'W001', 'check_first')).toEqual({ lesson: 'S1-U01-L2', row: 'W003' })
    expect(nextUnrecorded(entries, rows, 'S1-U01-L2', 'W003', 'check_first')).toEqual({ lesson: 'S1-U01-L2', row: 'W002' })
    expect(nextUnrecorded(entries, rows, 'S1-U01-L2', 'W002', 'check_first')).toEqual({ lesson: 'S1-U01-L2', row: 'W003' })
    const allRecorded = rows.map((r) => ({ ...r, audio_url: 'https://pub.example/x.m4a' }))
    expect(nextUnrecorded(entries, allRecorded, 'S1-U01-L1', 'W001', 'in_order')).toBeNull()
  })
})
