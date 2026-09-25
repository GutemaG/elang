import '@testing-library/jest-dom/vitest'
import { cleanup, configure } from '@testing-library/react'
import { afterEach, vi } from 'vitest'

// `findBy…` and `waitFor` give up after 1 s by default, which a busy
// machine running the whole suite can pass (bolt 052).
configure({ asyncUtilTimeout: 3_000 })

afterEach(() => {
  cleanup()
  sessionStorage.clear()
  vi.unstubAllGlobals()
  vi.restoreAllMocks()
})
