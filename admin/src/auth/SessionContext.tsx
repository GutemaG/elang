import { createContext, useCallback, useContext, useEffect, useState, type ReactNode } from 'react'

import { ApiClient, ApiError } from '../api'
import { API_BASE_URL } from '../config'
import type { AdminMe, AuthResponse } from '../types'
import { clearSession, emailFromIdToken, loadSession, saveSession } from './session'

export type SessionState =
  | { status: 'signed_out'; message: string | null }
  | { status: 'checking' }
  | { status: 'admin'; email: string }
  | { status: 'not_admin'; email: string | null }

interface SessionValue {
  state: SessionState
  api: ApiClient
  signInWithGoogle: (idToken: string) => Promise<void>
  signOut: () => void
}

const SessionContext = createContext<SessionValue | null>(null)

export function SessionProvider({ children }: { children: ReactNode }) {
  const [state, setState] = useState<SessionState>(() =>
    loadSession() ? { status: 'checking' } : { status: 'signed_out', message: null },
  )

  // One client for the provider's lifetime; it reads the token fresh from
  // storage on every request.
  const [api] = useState(
    () =>
      new ApiClient({
        baseUrl: API_BASE_URL,
        getToken: () => loadSession()?.token ?? null,
        onUnauthorized: () => {
          clearSession()
          setState({ status: 'signed_out', message: 'Your session has ended. Sign in again.' })
        },
      }),
  )

  // Asks the server whether the stored session belongs to an admin, and
  // returns the state that follows -- or null after a 401, which
  // onUnauthorized has already handled.
  const resolveAdmin = useCallback(async (): Promise<SessionState | null> => {
    try {
      const me = await api.get<AdminMe>('/api/v1/admin/me')
      return { status: 'admin', email: me.email }
    } catch (e) {
      if (e instanceof ApiError && e.status === 403) return { status: 'not_admin', email: loadSession()?.email ?? null }
      if (e instanceof ApiError && e.status === 401) return null
      clearSession()
      return { status: 'signed_out', message: messageOf(e) }
    }
  }, [api])

  useEffect(() => {
    // A session kept from before a reload: check it once on start.
    if (!loadSession()) return
    let live = true
    void resolveAdmin().then((next) => {
      if (live && next) setState(next)
    })
    return () => {
      live = false
    }
  }, [resolveAdmin])

  const signInWithGoogle = useCallback(
    async (idToken: string) => {
      setState({ status: 'checking' })
      try {
        const auth = await api.post<AuthResponse>('/api/v1/auth/google', { id_token: idToken })
        saveSession({ token: auth.session_token, email: emailFromIdToken(idToken) })
      } catch (e) {
        clearSession()
        setState({ status: 'signed_out', message: messageOf(e) })
        return
      }
      const next = await resolveAdmin()
      if (next) setState(next)
    },
    [api, resolveAdmin],
  )

  const signOut = useCallback(() => {
    clearSession()
    window.google?.accounts.id.disableAutoSelect()
    setState({ status: 'signed_out', message: null })
  }, [])

  return (
    <SessionContext.Provider value={{ state, api, signInWithGoogle, signOut }}>{children}</SessionContext.Provider>
  )
}

export function useSession(): SessionValue {
  const value = useContext(SessionContext)
  if (!value) throw new Error('useSession must be used inside <SessionProvider>')
  return value
}

export function messageOf(e: unknown): string {
  return e instanceof Error ? e.message : 'Something went wrong.'
}
