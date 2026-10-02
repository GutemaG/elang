import { screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import { FakeServer } from '../test/fakeServer'
import { idTokenFor } from '../test/fixtures'
import { renderApp, withStoredSession } from '../test/renderApp'
import type { AdminLanguage } from '../types'

vi.mock('../auth/GoogleButton', () => ({
  GoogleButton: ({ onCredential }: { onCredential: (token: string) => void }) => (
    <button type="button" onClick={() => onCredential(idTokenFor('admin@example.com'))}>
      Sign in with Google
    </button>
  ),
}))

const ME = '/api/v1/admin/me'
const LANGUAGES = '/api/v1/admin/languages'

let server: FakeServer
let languages: AdminLanguage[]

beforeEach(() => {
  withStoredSession()
  languages = [
    { code: 'am', name: 'Amharic', native_name: 'አማርኛ', course_count: 3 },
    { code: 'ti', name: 'Tigrinya', native_name: 'ትግርኛ', course_count: 0 },
  ]
  server = new FakeServer()
    .install()
    .on('GET', ME, { body: { email: 'admin@example.com' } })
    .on('GET', LANGUAGES, () => ({ body: { languages } }))
})

const row = (name: string) => within(screen.getByText(name, { selector: 'span' }).closest('li')!)

describe('the languages page', () => {
  it('is in the menu and lists each language with how many courses use it', async () => {
    renderApp('/')
    await userEvent.click(await screen.findByRole('link', { name: 'Languages' }))

    expect(await screen.findByRole('heading', { name: 'Languages' })).toBeInTheDocument()
    expect(row('Amharic').getByText('Used by 3 courses')).toBeInTheDocument()
    expect(row('Tigrinya').getByText('No courses yet')).toBeInTheDocument()
    expect(row('Tigrinya').getByText('ትግርኛ')).toBeInTheDocument()
    // Only an unused language can be deleted.
    expect(screen.getByRole('button', { name: 'Delete Amharic' })).toBeDisabled()
    expect(screen.getByRole('button', { name: 'Delete Tigrinya' })).toBeEnabled()
  })

  it('adds a language and lists it', async () => {
    server.on('POST', LANGUAGES, (call) => {
      languages = [...languages, { code: 'sid', name: 'Sidama', native_name: 'Sidaamu Afoo', course_count: 0 }]
      return { status: 201, body: call.body }
    })
    renderApp('/languages')

    await userEvent.click(await screen.findByRole('button', { name: 'Add language' }))
    const dialog = within(screen.getByRole('dialog', { name: 'Add language' }))
    const add = dialog.getByRole('button', { name: 'Add language' })
    expect(add).toBeDisabled()
    await userEvent.type(dialog.getByLabelText('Code'), 'SID')
    await userEvent.type(dialog.getByLabelText('Name in English'), ' Sidama ')
    await userEvent.type(dialog.getByLabelText('Its own name'), 'Sidaamu Afoo')
    await userEvent.click(add)

    expect(server.callsTo('POST', LANGUAGES)[0]!.body).toEqual({
      code: 'sid',
      name: 'Sidama',
      native_name: 'Sidaamu Afoo',
    })
    expect(await screen.findByText('Sidama')).toBeInTheDocument()
    expect(screen.queryByRole('dialog')).not.toBeInTheDocument()
  })

  it('keeps the dialog open with the server’s reason when it refuses', async () => {
    server.on('POST', LANGUAGES, {
      status: 409,
      body: { error_code: 'content_exists', message: "A language with code 'ti' already exists" },
    })
    renderApp('/languages')

    await userEvent.click(await screen.findByRole('button', { name: 'Add language' }))
    const dialog = within(screen.getByRole('dialog', { name: 'Add language' }))
    await userEvent.type(dialog.getByLabelText('Code'), 'ti')
    await userEvent.type(dialog.getByLabelText('Name in English'), 'Tigrinya')
    await userEvent.type(dialog.getByLabelText('Its own name'), 'ትግርኛ')
    await userEvent.click(dialog.getByRole('button', { name: 'Add language' }))

    expect(await dialog.findByRole('alert')).toHaveTextContent('already exists')
  })

  it('corrects a name; the code stays', async () => {
    server.on('PATCH', `${LANGUAGES}/am`, (call) => {
      languages = [{ ...languages[0]!, native_name: 'አማርኛ ቋንቋ' }, languages[1]!]
      return { body: { ...languages[0]!, ...(call.body as object) } }
    })
    renderApp('/languages')

    await userEvent.click(await screen.findByRole('button', { name: 'Edit Amharic' }))
    const dialog = within(screen.getByRole('dialog', { name: 'Edit Amharic' }))
    expect(dialog.getByLabelText('Code')).toBeDisabled()
    await userEvent.clear(dialog.getByLabelText('Its own name'))
    await userEvent.type(dialog.getByLabelText('Its own name'), 'አማርኛ ቋንቋ')
    await userEvent.click(dialog.getByRole('button', { name: 'Save' }))

    expect(server.callsTo('PATCH', `${LANGUAGES}/am`)[0]!.body).toEqual({
      name: 'Amharic',
      native_name: 'አማርኛ ቋንቋ',
    })
    expect(await screen.findByText('አማርኛ ቋንቋ')).toBeInTheDocument()
  })

  it('deletes an unused language after asking', async () => {
    server.on('DELETE', `${LANGUAGES}/ti`, () => {
      languages = languages.filter((l) => l.code !== 'ti')
      return { status: 204 }
    })
    renderApp('/languages')

    await userEvent.click(await screen.findByRole('button', { name: 'Delete Tigrinya' }))
    await userEvent.click(within(screen.getByRole('dialog', { name: 'Delete Tigrinya?' })).getByRole('button', { name: 'Delete' }))

    await waitFor(() => expect(screen.queryByText('Tigrinya')).not.toBeInTheDocument())
    expect(server.callsTo('DELETE', `${LANGUAGES}/ti`)).toHaveLength(1)
  })
})
