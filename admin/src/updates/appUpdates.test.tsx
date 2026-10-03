import { screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import { FakeServer } from '../test/fakeServer'
import { idTokenFor } from '../test/fixtures'
import { renderApp, withStoredSession } from '../test/renderApp'
import type { AdminAppConfig } from '../types'

vi.mock('../auth/GoogleButton', () => ({
  GoogleButton: ({ onCredential }: { onCredential: (token: string) => void }) => (
    <button type="button" onClick={() => onCredential(idTokenFor('admin@example.com'))}>
      Sign in with Google
    </button>
  ),
}))

const ME = '/api/v1/admin/me'
const CONFIG = '/api/v1/admin/app-config'

let server: FakeServer
let config: AdminAppConfig

beforeEach(() => {
  withStoredSession()
  config = { min_build_android: 3, min_build_ios: 0, latest_build_ios: 0, ios_store_url: '' }
  server = new FakeServer()
    .install()
    .on('GET', ME, { body: { email: 'admin@example.com' } })
    .on('GET', CONFIG, () => ({ body: { config } }))
    .on('PATCH', CONFIG, (call) => {
      config = { ...config, ...(call.body as Partial<AdminAppConfig>) }
      return { body: { config } }
    })
})

const android = () => within(screen.getByRole('heading', { name: 'Android · Google Play' }).closest('section')!)
const ios = () => within(screen.getByRole('heading', { name: 'iOS · App Store' }).closest('section')!)

async function openPage() {
  renderApp('/')
  await userEvent.click(await screen.findByRole('link', { name: 'App updates' }))
  await screen.findByRole('heading', { name: 'App updates' })
}

async function type(field: HTMLElement, text: string) {
  await userEvent.clear(field)
  if (text) await userEvent.type(field, text)
}

describe('the app updates page', () => {
  it('is in the menu and shows the saved builds', async () => {
    await openPage()

    expect(android().getByLabelText('Minimum build')).toHaveValue('3')
    expect(ios().getByLabelText('Minimum build')).toHaveValue('0')
    expect(ios().getByLabelText('Latest build')).toHaveValue('0')
    expect(screen.getByRole('button', { name: 'Save' })).toBeDisabled()
  })

  it('asks before raising a minimum, then saves only what changed', async () => {
    await openPage()

    await type(android().getByLabelText('Minimum build'), '5')
    await userEvent.click(screen.getByRole('button', { name: 'Save' }))

    const dialog = within(screen.getByRole('dialog', { name: 'Require an update?' }))
    expect(dialog.getByText(/Android builds below 5/)).toBeInTheDocument()
    expect(server.callsTo('PATCH', CONFIG)).toHaveLength(0)

    await userEvent.click(dialog.getByRole('button', { name: 'Require update' }))

    expect(await screen.findByRole('status')).toHaveTextContent('Saved')
    expect(server.callsTo('PATCH', CONFIG).map((c) => c.body)).toEqual([{ min_build_android: 5 }])
    expect(android().getByLabelText('Minimum build')).toHaveValue('5')
  })

  it('cancelling the question saves nothing', async () => {
    await openPage()

    await type(android().getByLabelText('Minimum build'), '9')
    await userEvent.click(screen.getByRole('button', { name: 'Save' }))
    await userEvent.click(within(screen.getByRole('dialog')).getByRole('button', { name: 'Cancel' }))

    expect(screen.queryByRole('dialog')).not.toBeInTheDocument()
    expect(server.callsTo('PATCH', CONFIG)).toHaveLength(0)
  })

  it('saves the iOS build and store link without asking, as neither blocks anyone', async () => {
    await openPage()

    await type(ios().getByLabelText('Latest build'), '12')
    await type(ios().getByLabelText('App Store link'), 'https://apps.apple.com/app/id1')
    await userEvent.click(screen.getByRole('button', { name: 'Save' }))

    await waitFor(() => expect(server.callsTo('PATCH', CONFIG)).toHaveLength(1))
    expect(screen.queryByRole('dialog')).not.toBeInTheDocument()
    expect(server.callsTo('PATCH', CONFIG)[0]!.body).toEqual({
      latest_build_ios: 12,
      ios_store_url: 'https://apps.apple.com/app/id1',
    })
  })

  it('lowering a minimum needs no question', async () => {
    await openPage()

    await type(android().getByLabelText('Minimum build'), '0')
    await userEvent.click(screen.getByRole('button', { name: 'Save' }))

    await waitFor(() => expect(server.callsTo('PATCH', CONFIG)).toHaveLength(1))
    expect(screen.queryByRole('dialog')).not.toBeInTheDocument()
  })

  it('will not save a build that is not a whole number, or a link that is not https', async () => {
    await openPage()

    await type(android().getByLabelText('Minimum build'), '-1')
    expect(android().getByText('A whole number, 0 or more.')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Save' })).toBeDisabled()

    await userEvent.click(screen.getByRole('button', { name: 'Undo changes' }))
    expect(android().getByLabelText('Minimum build')).toHaveValue('3')

    await type(ios().getByLabelText('App Store link'), 'http://apps.apple.com')
    expect(ios().getByText('An https:// address, or empty.')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Save' })).toBeDisabled()
  })

  it('shows what the server refused', async () => {
    server.on('PATCH', CONFIG, {
      status: 422,
      body: { error_code: 'invalid_setting', message: 'min_build_ios: expected a whole number from 0' },
    })
    await openPage()

    await type(ios().getByLabelText('Latest build'), '4')
    await userEvent.click(screen.getByRole('button', { name: 'Save' }))

    expect(await screen.findByRole('alert')).toHaveTextContent('expected a whole number from 0')
  })
})
