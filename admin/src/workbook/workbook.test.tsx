import { screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import { FakeServer } from '../test/fakeServer'
import { COURSE } from '../test/fixtures'
import { renderApp, withStoredSession } from '../test/renderApp'
import { COURSE_ID, CURRICULUM, curriculumOf, serveCurriculum, smallCurriculum, smallWorkbook } from '../test/workbook'
import type { Curriculum, CurriculumImportRequest } from '../types'
import { readWorkbook, saveWorkbook } from './files'

vi.mock('../auth/GoogleButton', () => ({ GoogleButton: () => null }))
// Reading and saving .xlsx files is the libraries' job (and `model.test.ts`
// reads the real workbook); here the page gets tabs straight away.
vi.mock('./files', () => ({ readWorkbook: vi.fn(), saveWorkbook: vi.fn(async () => undefined) }))

const PAGE = `/courses/${COURSE_ID}/workbook`
const XLSX = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'

let server: FakeServer
let state: { curriculum: Curriculum }

beforeEach(() => {
  withStoredSession()
  state = { curriculum: curriculumOf([], []) }
  server = new FakeServer().install()
  serveCurriculum(server, state)
  vi.mocked(readWorkbook).mockResolvedValue(smallWorkbook())
  vi.mocked(saveWorkbook).mockClear()
})

const chooseFile = async () =>
  userEvent.upload(screen.getByLabelText('Workbook file to import'), new File(['x'], 'a1.xlsx', { type: XLSX }))

const imports = () => server.callsTo('PUT', CURRICULUM)

describe('the Workbook', () => {
  it('is in the menu and opens each course’s workbook', async () => {
    server.on('GET', '/api/v1/admin/courses', { body: { courses: [COURSE] } })
    renderApp('/')

    await userEvent.click(await screen.findByRole('link', { name: 'Workbook' }))

    const course = await screen.findByRole('link', { name: /Amharic/ })
    expect(course).toHaveAttribute('href', `/courses/${COURSE_ID}/workbook`)
    expect(course).toHaveTextContent('Open workbook')
    expect(screen.getByRole('link', { name: 'Workbook' })).toHaveAttribute('aria-current', 'page')
  })

  it('offers the import when nothing is in it yet', async () => {
    renderApp(PAGE)

    expect(await screen.findByRole('heading', { name: 'Nothing imported yet' })).toBeInTheDocument()
    expect(screen.getByRole('heading', { name: 'English to Amharic' })).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Export to Excel' })).toBeDisabled()
  })
})

describe('importing the workbook', () => {
  it('shows what will change, saves nothing until Import, then shows the lessons', async () => {
    renderApp(PAGE)
    await screen.findByRole('heading', { name: 'Nothing imported yet' })

    await chooseFile()

    const dialog = within(await screen.findByRole('dialog', { name: 'Import workbook' }))
    expect(await dialog.findByText('Lessons and skills')).toBeInTheDocument()
    expect(dialog.getAllByText('3 new')).toHaveLength(2)
    expect(dialog.getByText(/1 row of Section 0 \(sounds and writing\) skipped/)).toBeInTheDocument()
    expect(imports()).toHaveLength(1)
    expect(imports()[0]!.query).toBe('?dry_run=true')
    const sent = imports()[0]!.body as CurriculumImportRequest
    expect(sent.overwrite_reviewed).toBe(false)
    expect(sent.entries.map((e) => e.ref)).toEqual(['S1', 'S1-U01', 'S1-U01-L1'])
    expect(sent.rows.map((r) => [r.ref, r.position, r.status])).toEqual([
      ['W001', 1, 'draft'],
      ['W002', 2, 'to_do'],
      ['S001', 3, 'draft'],
    ])

    await userEvent.click(dialog.getByRole('button', { name: 'Import 6 changes' }))

    await waitFor(() => expect(screen.queryByRole('dialog')).not.toBeInTheDocument())
    expect(imports()[1]!.query).toBe('')
    expect(await screen.findByRole('status')).toHaveTextContent('Imported: 3 words and sentences, 3 sections, skills and lessons.')
    const lesson = await screen.findByRole('link', { name: /Hello & goodbye/ })
    expect(lesson).toHaveTextContent('0/3 reviewed')
    expect(lesson).toHaveAttribute('href', `/courses/${COURSE_ID}/workbook/lessons/S1-U01-L1`)
  })

  it('checks again with reviewed and recorded rows overwritten when asked', async () => {
    renderApp(PAGE)
    await screen.findByRole('heading', { name: 'Nothing imported yet' })
    await chooseFile()
    const dialog = within(await screen.findByRole('dialog', { name: 'Import workbook' }))
    await dialog.findByText('Lessons and skills')

    await userEvent.click(dialog.getByRole('checkbox', { name: /Overwrite reviewed and recorded rows/ }))

    await waitFor(() => expect(imports()).toHaveLength(2))
    expect((imports()[1]!.body as CurriculumImportRequest).overwrite_reviewed).toBe(true)
    expect(imports()[1]!.query).toBe('?dry_run=true')
  })

  it('lists the file’s problems by tab and row and sends nothing', async () => {
    const sheets = smallWorkbook()
    const words = sheets[1]!.data
    words[1]![words[0]!.indexOf('Status: Amharic')] = 'Done'
    vi.mocked(readWorkbook).mockResolvedValue(sheets)
    renderApp(PAGE)
    await screen.findByRole('heading', { name: 'Nothing imported yet' })

    await chooseFile()

    const dialog = within(await screen.findByRole('dialog', { name: 'Import workbook' }))
    expect(dialog.getByRole('alert')).toHaveTextContent('1 problem to fix in the file first. Nothing was imported.')
    expect(dialog.getByRole('alert')).toHaveTextContent('Words, row 2: The status must be To do, Draft, Needs change or Reviewed, not “Done”.')
    expect(dialog.queryByRole('button', { name: /Import/ })).not.toBeInTheDocument()
    expect(imports()).toHaveLength(0)
  })

  it('points the server’s problems at their rows', async () => {
    server.on('PUT', CURRICULUM, {
      status: 422,
      body: {
        error_code: 'invalid_import',
        message: '1 problem(s) in the curriculum',
        details: { rows: [{ ref: 'S001', field: 'blank', message: 'The word to blank, “ሰላም”, is not in the sentence' }] },
      },
    })
    renderApp(PAGE)
    await screen.findByRole('heading', { name: 'Nothing imported yet' })

    await chooseFile()

    const dialog = within(await screen.findByRole('dialog', { name: 'Import workbook' }))
    expect(await dialog.findByRole('alert')).toHaveTextContent(
      'Sentences, row 2: S001: The word to blank, “ሰላም”, is not in the sentence',
    )
  })

  it('says so when the file is not a workbook', async () => {
    vi.mocked(readWorkbook).mockRejectedValue(new Error('not a zip'))
    renderApp(PAGE)
    await screen.findByRole('heading', { name: 'Nothing imported yet' })

    await chooseFile()

    expect(await screen.findByRole('alert')).toHaveTextContent('That file could not be read as an Excel workbook (.xlsx).')
  })
})

describe('the overview', () => {
  beforeEach(() => {
    state.curriculum = smallCurriculum()
  })

  it('shows each lesson’s progress, and adds up the skill and course', async () => {
    renderApp(PAGE)

    const ready = await screen.findByRole('link', { name: /Hello & goodbye/ })
    expect(ready).toHaveTextContent('Ready')
    expect(ready).toHaveTextContent('2/2 reviewed')
    expect(ready).toHaveTextContent('2/2 recorded')
    const pending = screen.getByRole('link', { name: /How are you\?/ })
    expect(pending).toHaveTextContent('1 needs change')
    expect(pending).toHaveTextContent('0/2 recorded')
    const section = screen.getByRole('region', { name: 'S1 · First conversations' })
    expect(within(section).getAllByText('2/4 reviewed')).toHaveLength(2)
    expect(screen.getByText('Reviewed').closest('div.rounded-md')).toHaveTextContent('2/4')
  })

  it('filters to lessons ready to publish, or needing change', async () => {
    renderApp(PAGE)
    await screen.findByRole('link', { name: /Hello & goodbye/ })

    await userEvent.click(screen.getByRole('button', { name: 'Ready to publish (1)' }))
    expect(screen.getByRole('link', { name: /Hello & goodbye/ })).toBeInTheDocument()
    expect(screen.queryByRole('link', { name: /How are you\?/ })).not.toBeInTheDocument()

    await userEvent.click(screen.getByRole('button', { name: 'Needs change (1)' }))
    expect(screen.queryByRole('link', { name: /Hello & goodbye/ })).not.toBeInTheDocument()
    expect(screen.getByRole('link', { name: /How are you\?/ })).toBeInTheDocument()
  })

  it('exports the curriculum as the workbook’s tabs', async () => {
    renderApp(PAGE)
    await screen.findByRole('link', { name: /Hello & goodbye/ })

    await userEvent.click(screen.getByRole('button', { name: 'Export to Excel' }))

    expect(saveWorkbook).toHaveBeenCalledTimes(1)
    const [name, tabs] = vi.mocked(saveWorkbook).mock.calls[0]!
    expect(name).toBe('English-to-Amharic-workbook.xlsx')
    expect(tabs.map((t) => [t.sheet, t.data.length])).toEqual([
      ['Plan', 3],
      ['Words', 4],
      ['Sentences', 2],
    ])
  })
})
