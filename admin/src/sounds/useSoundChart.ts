import { useCallback, useEffect, useState } from 'react'

import { messageOf, useSession } from '../auth/SessionContext'
import { routes } from '../tree/levels'
import type { AdminSoundChart, SoundLetterChange } from '../types'

/** One language's chart, loaded once, with the writes every Sounds page
 * makes. Each write returns the whole chart, which replaces the one shown. */
export function useSoundChart(language: string) {
  const { api } = useSession()
  const [chart, setChart] = useState<AdminSoundChart | null>(null)
  const [error, setError] = useState<string | null>(null)

  const reload = useCallback(async () => {
    try {
      setChart(await api.get<AdminSoundChart>(routes.soundChart(language)))
      setError(null)
    } catch (e) {
      setError(messageOf(e))
    }
  }, [api, language])

  useEffect(() => {
    let live = true
    api.get<AdminSoundChart>(routes.soundChart(language)).then(
      (c) => live && setChart(c),
      (e: unknown) => live && setError(messageOf(e)),
    )
    return () => {
      live = false
    }
  }, [api, language])

  /** Saves letter changes, all or nothing. Throws what the server refused. */
  const saveLetters = useCallback(
    async (letters: SoundLetterChange[]) => {
      const next = await api.patch<AdminSoundChart>(routes.soundLetters(language), { letters })
      setChart(next)
      return next
    },
    [api, language],
  )

  const setEnabled = useCallback(
    async (enabled: boolean) => {
      const next = await api.patch<AdminSoundChart>(routes.soundChart(language), { enabled })
      setChart(next)
      return next
    },
    [api, language],
  )

  return { chart, error, setError, reload, saveLetters, setEnabled }
}
