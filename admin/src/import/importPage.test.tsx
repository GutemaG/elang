import { fireEvent, screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

import { FakeServer } from '../test/fakeServer'
import { COURSE, courseTree, idTokenFor } from '../test/fixtures'
import { MC, lessonExercises } from '../test/exercises'
import { renderApp, withStoredSession } from '../test/renderApp'
import { readText } from './download'

vi.mock('../auth/GoogleButton', () => ({
  GoogleButton: ({ onCredential }: { onCredential: (token: string) => void }) => (
    <button type="button" onClick={() => onCredential(idTokenFor('admin@example.com'))}>
      Sign in with Google
    </button>
  ),
}))

const ME = '/api/v1/admin/me'
const COURSES = '/api/v1/admin/courses'
const TREE = '/api/v1/admin/courses/course-1/tree'
const EXERCISES = '/api/v1/admin/lessons/lesson-1/exercises'
const IMPORT = '/api/v1/admin/lessons/lesson-1/exercises/import'
const PAGE = '/courses/course-1/lessons/lesson-1/import'

const HEADER = 'type,prompt,sentence,answer,wrong,audio_url,descriptions'
const csv = (...lines: string[]) => new File([[HEADER, ...lines].join('\n')], 'hello.csv', { type: 'text/csv' })

let server: FakeServer

beforeEach(() => {
  withStoredSession()
  Object.defineProperty(window, 'scrollY', { configurable: true, value: 0 })
  server = new FakeServer()
    .install()
    .on('GET', ME, { body: { email: 'admin@example.com' } })
    .on('GET', COURSES, { body: { courses: [COURSE] } })
    .on('GET', TREE, { body: courseTree() })
    .on('GET', EXERCISES, { body: { exercises: lessonExercises() } })
    .on('POST', IMPORT, (call) => {
      const { exercises, dry_run } = call.body as { exercises: unknown[]; dry_run?: boolean }
      return dry_run ? { body: { count: exercises.length } } : { status: 201, body: { exercises: [] } }
    })
})

/** The import page, once it knows the lesson. */
async function openImport(): Promise<void> {
  renderApp(PAGE)
  await screen.findByRole('link', { name: 'Hello' })
}

async function choose(file: File): Promise<void> {
  await userEvent.upload(screen.getByLabelText(/Choose a file/), file)
}

const dryRuns = () => server.callsTo('POST', IMPORT).filter((c) => (c.body as { dry_run?: boolean }).dry_run)
const saves = () => server.callsTo('POST', IMPORT).filter((c) => !(c.body as { dry_run?: boolean }).dry_run)
const rowOf = (label: string) => screen.getByRole('cell', { name: label }).closest('tr')!

describe('importing a lesson', () => {
  it('is reached from the open lesson', async () => {
    renderApp('/courses/course-1?open=lesson-1')

    await userEvent.click(await screen.findByRole('link', { name: 'Import' }))

    expect(await screen.findByRole('heading', { name: 'Import exercises' })).toBeInTheDocument()
    expect(screen.getByText('Hello', { selector: 'strong' })).toBeInTheDocument()
  })

  it('checks a CSV without saving, then adds it after the lesson, and says so back in the tree', async () => {
    await openImport()

    await choose(csv('multiple_choice,Say hello,,ሰላም,ቻው,,', 'spell_tiles,Spell coffee,,ቡና,,,'))

    expect(await screen.findByText('Every row can be added')).toBeInTheDocument()
    expect(dryRuns()).toHaveLength(1)
    const checked = dryRuns()[0]!.body as { exercises: { type: string; prompt: string }[] }
    expect(checked.exercises.map((e) => [e.type, e.prompt])).toEqual([
      ['multiple_choice', 'Say hello'],
      ['spell_tiles', 'Spell coffee'],
    ])
    expect(within(rowOf('Row 2')).getByText('OK')).toBeInTheDocument()
    expect(within(rowOf('Row 3')).getByText('ቡ | ና')).toBeInTheDocument()

    await userEvent.click(screen.getByRole('button', { name: 'Add 2 exercises' }))

    expect(await screen.findByText('Added 2 exercises.')).toBeInTheDocument()
    expect(saves()).toHaveLength(1)
    expect(saves()[0]!.body).toEqual({ exercises: checked.exercises, mode: 'append' })
    // Back in the tree with the lesson open.
    expect(screen.getByText('Which means hello?')).toBeInTheDocument()
  })

  it('shows every problem on its row, from the file and from the server, and adds nothing', async () => {
    server.on('POST', IMPORT, {
      status: 422,
      body: {
        error_code: 'invalid_import',
        message: '1 of 2 exercises cannot be saved',
        details: {
          rows: [
            { index: 1, field: 'content.audio_url', message: 'content.audio_url must be a full https:// address' },
          ],
        },
      },
    })
    await openImport()

    await choose(
      csv(
        'multiple_choice,Fine,,ሰላም,ቻው,,',
        'gap_fill,No gap,ቡና እፈልጋለሁ,እባክህ,ውሃ,,',
        'listening,Hear,,ሰላም,ቻው,http://x/a.mp3,',
      ),
    )

    expect(await screen.findByText(/2 rows need fixing/)).toBeInTheDocument()
    expect(within(rowOf('Row 3')).getByText('Mark the gap in "sentence" with ___, once.')).toBeInTheDocument()
    expect(within(rowOf('Row 4')).getByText('Must be a full https:// address')).toBeInTheDocument()
    expect(within(rowOf('Row 2')).getByText('OK')).toBeInTheDocument()
    // Only the rows that became exercises were sent to be checked.
    expect((dryRuns()[0]!.body as { exercises: unknown[] }).exercises).toHaveLength(2)
    expect(screen.getByRole('button', { name: 'Add 3 exercises' })).toBeDisabled()
  })

  it('refuses a file not saved as UTF-8, saying how to save it', async () => {
    await openImport()

    // "café" in Windows-1252, as Excel's plain CSV would save it.
    await choose(new File([new Uint8Array([...new TextEncoder().encode(`${HEADER}\nx,caf`), 0xe9])], 'old.csv'))

    expect(await screen.findByRole('alert')).toHaveTextContent('Save As › CSV UTF-8')
    expect(server.callsTo('POST', IMPORT)).toHaveLength(0)
  })

  it('refuses more than 200 exercises before checking any', async () => {
    await openImport()

    await choose(csv(...Array.from({ length: 201 }, (_, i) => `multiple_choice,Q${i},,a,b,,`)))

    expect(await screen.findByRole('alert')).toHaveTextContent('at most 200 exercises, and this file has 201')
    expect(server.callsTo('POST', IMPORT)).toHaveLength(0)
  })

  it('replaces the lesson only after asking', async () => {
    await openImport()
    await choose(csv('multiple_choice,Say hello,,ሰላም,ቻው,,'))
    await screen.findByText('Every row can be added')

    await userEvent.click(screen.getByRole('radio', { name: 'Replace them with these' }))
    await userEvent.click(screen.getByRole('button', { name: 'Replace with 1' }))
    const dialog = screen.getByRole('dialog', { name: 'Replace the 3 exercises?' })
    expect(saves()).toHaveLength(0)
    await userEvent.click(within(dialog).getByRole('button', { name: 'Replace' }))

    expect(await screen.findByText('Added 1 exercise.')).toBeInTheDocument()
    expect((saves()[0]!.body as { mode: string }).mode).toBe('replace')
  })

  it('takes pasted JSON exactly as written', async () => {
    await openImport()

    await userEvent.click(screen.getByText('Or paste the text'))
    fireEvent.change(screen.getByLabelText('CSV or JSON to import'), {
      target: { value: JSON.stringify([{ ...MC, id: 'x1' }]) },
    })
    await userEvent.click(screen.getByRole('button', { name: 'Check pasted text' }))

    expect(await screen.findByText('Every row can be added')).toBeInTheDocument()
    expect((dryRuns()[0]!.body as { exercises: unknown[] }).exercises).toEqual([MC])
    expect(screen.getByRole('cell', { name: 'Exercise 1' })).toBeInTheDocument()
  })

  it('keeps the page and shows why when adding fails', async () => {
    await openImport()
    await choose(csv('multiple_choice,Say hello,,ሰላም,ቻው,,'))
    await screen.findByText('Every row can be added')
    server.on('POST', IMPORT, { status: 500, body: { error_code: 'oops', message: 'Something broke' } })

    await userEvent.click(screen.getByRole('button', { name: 'Add 1 exercise' }))

    expect(await screen.findByRole('alert')).toHaveTextContent('Something broke')
    expect(screen.getByRole('heading', { name: 'Import exercises' })).toBeInTheDocument()
  })

  it('offers a sample file of each format, without opening the help', async () => {
    const saved = captureDownloads()
    await openImport()

    await userEvent.click(screen.getByRole('button', { name: 'Sample CSV' }))
    await userEvent.click(screen.getByRole('button', { name: 'Sample JSON' }))

    await waitFor(() => expect(saved).toHaveLength(2))
    expect(saved.map((s) => s.name)).toEqual(['exercises-sample.csv', 'exercises-sample.json'])
    expect((await saved[0]!.text).split('\r\n')).toHaveLength(9)
  })

  it('previews a row as the learner will see it, before anything is added', async () => {
    await openImport()
    await choose(csv('multiple_choice,Say hello,,ሰላም,ቻው,,'))
    await screen.findByText('Every row can be added')

    await userEvent.click(screen.getByRole('button', { name: 'Preview Row 2' }))

    const dialog = screen.getByRole('dialog', { name: 'Preview: Row 2' })
    expect(within(dialog).getByText('Say hello')).toBeInTheDocument()
    expect(within(dialog).getByText('ሰላም')).toBeInTheDocument()
    expect(saves()).toHaveLength(0)
  })
})

/** Files the page saves, by name, with their text. */
function captureDownloads(): { name: string; text: Promise<string>; blob: Blob }[] {
  const saved: { name: string; text: Promise<string>; blob: Blob }[] = []
  const blobs = new Map<string, Blob>()
  let n = 0
  vi.stubGlobal(
    'URL',
    Object.assign(URL, {
      createObjectURL: (blob: Blob) => {
        const url = `blob:test/${n++}`
        blobs.set(url, blob)
        return url
      },
      revokeObjectURL: () => {},
    }),
  )
  vi.spyOn(HTMLAnchorElement.prototype, 'click').mockImplementation(function (this: HTMLAnchorElement) {
    const blob = blobs.get(this.href)!
    saved.push({ name: this.download, text: readText(blob), blob })
  })
  return saved
}

function bytesOf(blob: Blob): Promise<ArrayBuffer> {
  return new Promise((resolve) => {
    const reader = new FileReader()
    reader.onload = () => resolve(reader.result as ArrayBuffer)
    reader.readAsArrayBuffer(blob)
  })
}

afterEach(() => {
  vi.restoreAllMocks()
})

describe('exporting a lesson', () => {
  it('downloads its exercises as CSV and as JSON, named after it', async () => {
    const saved = captureDownloads()
    renderApp('/courses/course-1?open=lesson-1')
    await screen.findByRole('link', { name: 'Import' })

    await userEvent.click(screen.getByRole('button', { name: 'Export CSV' }))
    await userEvent.click(screen.getByRole('button', { name: 'Export JSON' }))

    await waitFor(() => expect(saved).toHaveLength(2))
    expect(saved.map((s) => s.name)).toEqual(['Hello-exercises.csv', 'Hello-exercises.json'])
    // A byte-order mark first, so Excel reads it as UTF-8.
    expect([...new Uint8Array(await bytesOf(saved[0]!.blob)).slice(0, 3)]).toEqual([0xef, 0xbb, 0xbf])
    const csvText = await saved[0]!.text
    expect(csvText.startsWith(`type,prompt,pronunciation,sentence,answer,answer_pronunciation,wrong,wrong_pronunciation,audio_url,descriptions\r\n`)).toBe(true)
    expect(csvText.split('\r\n')).toHaveLength(1 + lessonExercises().length)
    const json = JSON.parse(await saved[1]!.text) as { lesson: string; exercises: unknown[] }
    expect(json.lesson).toBe('Hello')
    expect(json.exercises).toHaveLength(lessonExercises().length)
  })

  it('an empty lesson offers only an import', async () => {
    renderApp('/courses/course-1?open=lesson-2')

    expect(await screen.findByRole('link', { name: 'Import from a file' })).toBeInTheDocument()
    const tools = screen.getAllByRole('group', { name: 'Import and export' })
    const empty = tools.find((g) => within(g).queryByRole('link', { name: 'Import from a file' }))!
    expect(within(empty).getByRole('button', { name: 'Export CSV' })).toBeDisabled()
  })

  it('import waits while a new order is unsaved', async () => {
    renderApp('/courses/course-1?open=lesson-1')
    await screen.findByRole('link', { name: 'Import' })

    fireEvent.keyDown(screen.getByRole('button', { name: 'Move exercise 1' }), { key: 'ArrowDown' })

    expect(screen.queryByRole('link', { name: 'Import' })).not.toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Import' })).toBeDisabled()
  })
})
