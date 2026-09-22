// The admin session lives in sessionStorage: it survives a reload but not
// closing the tab, so an admin token never outlives the tab (story 001).

const TOKEN_KEY = 'buna_admin.session_token'
const EMAIL_KEY = 'buna_admin.email'

export interface StoredSession {
  token: string
  /** Read from the Google ID token for display only; the server decides. */
  email: string | null
}

export function loadSession(): StoredSession | null {
  try {
    const token = sessionStorage.getItem(TOKEN_KEY)
    return token ? { token, email: sessionStorage.getItem(EMAIL_KEY) } : null
  } catch {
    return null
  }
}

export function saveSession(session: StoredSession): void {
  try {
    sessionStorage.setItem(TOKEN_KEY, session.token)
    if (session.email) sessionStorage.setItem(EMAIL_KEY, session.email)
    else sessionStorage.removeItem(EMAIL_KEY)
  } catch {
    // Storage blocked: the session then lasts only until a reload.
  }
}

export function clearSession(): void {
  try {
    sessionStorage.removeItem(TOKEN_KEY)
    sessionStorage.removeItem(EMAIL_KEY)
  } catch {
    // Nothing stored, nothing to clear.
  }
}

/** The `email` claim of a Google ID token, unverified -- for showing who is
 * signed in on the not-authorised screen, never for deciding access. */
export function emailFromIdToken(idToken: string): string | null {
  const payload = idToken.split('.')[1]
  if (!payload) return null
  try {
    const json = atob(payload.replace(/-/g, '+').replace(/_/g, '/'))
    const claims = JSON.parse(json) as { email?: unknown }
    return typeof claims.email === 'string' ? claims.email : null
  } catch {
    return null
  }
}
