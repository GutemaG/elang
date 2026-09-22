import { screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import { FakeServer } from './test/fakeServer'
import { COURSE, idTokenFor } from './test/fixtures'
import { renderApp, withStoredSession } from './test/renderApp'

// Google's button, replaced: clicking it hands the site an ID token.
vi.mock('./auth/GoogleButton', () => ({
  GoogleButton: ({ onCredential }: { onCredential: (token: string) => void }) => (
    <button type="button" onClick={() => onCredential(idTokenFor('admin@example.com'))}>
      Sign in with Google
    </button>
  ),
}))

const ME = '/api/v1/admin/me'
const GOOGLE = '/api/v1/auth/google'
const COURSES = '/api/v1/admin/courses'

let server: FakeServer

beforeEach(() => {
  server = new FakeServer().install()
})

function signInSucceeds(): void {
  server
    .on('POST', GOOGLE, { body: { session_token: 'session-abc', expires_at: '2026-10-01T00:00:00Z' } })
    .on('GET', ME, { body: { email: 'admin@example.com' } })
    .on('GET', COURSES, { body: { courses: [COURSE] } })
}

describe('signed out', () => {
  it('shows only the Google button', () => {
    renderApp()

    expect(screen.getByRole('button', { name: 'Sign in with Google' })).toBeInTheDocument()
    expect(screen.queryByRole('heading', { name: 'Courses' })).not.toBeInTheDocument()
    expect(server.calls).toHaveLength(0)
  })
})

describe('signing in', () => {
  it('exchanges the Google token, keeps the session for the tab, and opens the content', async () => {
    signInSucceeds()
    renderApp()

    await userEvent.click(screen.getByRole('button', { name: 'Sign in with Google' }))

    expect(await screen.findByRole('heading', { name: 'Courses' })).toBeInTheDocument()
    expect(server.callsTo('POST', GOOGLE)[0]!.body).toEqual({ id_token: idTokenFor('admin@example.com') })
    expect(sessionStorage.getItem('buna_admin.session_token')).toBe('session-abc')
    expect(localStorage.length).toBe(0)
    // Every later request carries the session.
    expect(server.callsTo('GET', ME)[0]!.token).toBe('session-abc')
    expect(screen.getByText('admin@example.com')).toBeInTheDocument()
  })

  it('checks a session left from before a reload, without signing in again', async () => {
    withStoredSession()
    server.on('GET', ME, { body: { email: 'admin@example.com' } }).on('GET', COURSES, { body: { courses: [COURSE] } })

    renderApp()

    expect(await screen.findByRole('heading', { name: 'Courses' })).toBeInTheDocument()
    expect(server.callsTo('POST', GOOGLE)).toHaveLength(0)
  })

  it('shows the server-s message and stays signed out when the token is refused', async () => {
    server.on('POST', GOOGLE, {
      status: 401,
      body: { error_code: 'invalid_token', message: 'Google token could not be verified' },
    })
    renderApp()

    await userEvent.click(screen.getByRole('button', { name: 'Sign in with Google' }))

    expect(await screen.findByRole('alert')).toHaveTextContent('Google token could not be verified')
    expect(sessionStorage.getItem('buna_admin.session_token')).toBeNull()
    expect(screen.getByRole('button', { name: 'Sign in with Google' })).toBeInTheDocument()
  })

  it('keeps the session but reports a backend that cannot be reached', async () => {
    server.on('POST', GOOGLE, { status: 503, body: { error_code: 'unavailable', message: 'Service unavailable' } })
    renderApp()

    await userEvent.click(screen.getByRole('button', { name: 'Sign in with Google' }))

    expect(await screen.findByRole('alert')).toHaveTextContent('Service unavailable')
  })
})

describe('a signed-in account that is not an admin', () => {
  it('is told so, with the account and a way out', async () => {
    server
      .on('POST', GOOGLE, { body: { session_token: 'session-abc', expires_at: '2026-10-01T00:00:00Z' } })
      .on('GET', ME, { status: 403, body: { error_code: 'not_admin', message: 'Admins only' } })
    renderApp()

    await userEvent.click(screen.getByRole('button', { name: 'Sign in with Google' }))

    expect(await screen.findByRole('heading', { name: 'Not authorised' })).toBeInTheDocument()
    expect(screen.getByText('admin@example.com')).toBeInTheDocument()
    expect(screen.queryByRole('heading', { name: 'Courses' })).not.toBeInTheDocument()
    // The session is kept, so it is not retried silently; signing out ends it.
    await userEvent.click(screen.getByRole('button', { name: 'Sign out' }))

    expect(sessionStorage.getItem('buna_admin.session_token')).toBeNull()
    expect(screen.getByRole('button', { name: 'Sign in with Google' })).toBeInTheDocument()
  })
})

describe('a session the server refuses', () => {
  it('returns to sign-in and forgets the token', async () => {
    withStoredSession()
    server.on('GET', ME, {
      status: 401,
      body: { error_code: 'invalid_session', message: 'Session token is unknown or expired' },
    })

    renderApp()

    expect(await screen.findByRole('alert')).toHaveTextContent('Your session has ended')
    expect(screen.getByRole('button', { name: 'Sign in with Google' })).toBeInTheDocument()
    expect(sessionStorage.getItem('buna_admin.session_token')).toBeNull()
  })

  it('ends the session when a later request is refused', async () => {
    withStoredSession()
    server.on('GET', ME, { body: { email: 'admin@example.com' } }).on('GET', COURSES, {
      status: 401,
      body: { error_code: 'invalid_session', message: 'Session token is unknown or expired' },
    })

    renderApp()

    await waitFor(() => expect(screen.getByRole('button', { name: 'Sign in with Google' })).toBeInTheDocument())
    expect(sessionStorage.getItem('buna_admin.session_token')).toBeNull()
  })
})

describe('signing out', () => {
  it('forgets the session and tells Google not to sign in automatically', async () => {
    const disableAutoSelect = vi.fn()
    vi.stubGlobal('google', { accounts: { id: { disableAutoSelect } } })
    signInSucceeds()
    renderApp()

    await userEvent.click(screen.getByRole('button', { name: 'Sign in with Google' }))
    await screen.findByRole('heading', { name: 'Courses' })
    await userEvent.click(screen.getByRole('button', { name: 'Sign out' }))

    expect(disableAutoSelect).toHaveBeenCalledOnce()
    expect(sessionStorage.getItem('buna_admin.session_token')).toBeNull()
    expect(screen.getByRole('button', { name: 'Sign in with Google' })).toBeInTheDocument()
  })
})
