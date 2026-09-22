import { render } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'

import { App } from '../App'
import { SessionProvider } from '../auth/SessionContext'

/** The whole site, at one address. Tests replace `auth/GoogleButton`, so
 * nothing ever talks to Google. */
export function renderApp(path = '/') {
  return render(
    <MemoryRouter initialEntries={[path]}>
      <SessionProvider>
        <App />
      </SessionProvider>
    </MemoryRouter>,
  )
}

/** A session already stored, as after a reload. */
export function withStoredSession(token = 'session-abc', email = 'admin@example.com'): void {
  sessionStorage.setItem('buna_admin.session_token', token)
  sessionStorage.setItem('buna_admin.email', email)
}
