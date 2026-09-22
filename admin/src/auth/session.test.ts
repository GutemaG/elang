import { describe, expect, it } from 'vitest'

import { idTokenFor } from '../test/fixtures'
import { clearSession, emailFromIdToken, loadSession, saveSession } from './session'

describe('the stored session', () => {
  it('round-trips the token and email through sessionStorage', () => {
    saveSession({ token: 'abc', email: 'admin@example.com' })

    expect(loadSession()).toEqual({ token: 'abc', email: 'admin@example.com' })
    // sessionStorage, never localStorage: the session dies with the tab.
    expect(localStorage.length).toBe(0)
  })

  it('is empty before a sign-in and after a sign-out', () => {
    expect(loadSession()).toBeNull()

    saveSession({ token: 'abc', email: null })
    clearSession()

    expect(loadSession()).toBeNull()
  })

  it('keeps the token when no email could be read', () => {
    saveSession({ token: 'abc', email: null })

    expect(loadSession()).toEqual({ token: 'abc', email: null })
  })
})

describe('the email in a Google ID token', () => {
  it('is read from the payload', () => {
    expect(emailFromIdToken(idTokenFor('admin@example.com'))).toBe('admin@example.com')
  })

  it('is null for anything unreadable', () => {
    expect(emailFromIdToken('not-a-token')).toBeNull()
    expect(emailFromIdToken('a.!!!.c')).toBeNull()
    expect(emailFromIdToken(`a.${btoa('{"sub":"123"}')}.c`)).toBeNull()
  })
})
