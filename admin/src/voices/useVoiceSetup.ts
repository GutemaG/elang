import { useEffect, useState } from 'react'

import type { ApiClient } from '../api'
import { voiceRoutes, type VoiceCatalog, type VoiceLanguage, type VoiceOption, type VoiceSettingsList } from './api'

// Read once per page load and shared by every clip field on the page (FR-16):
// a letter's page has two fields, and neither should ask twice.
interface Cache {
  generation: number
  settings?: Promise<VoiceSettingsList>
  catalogs: Map<string, Promise<VoiceOption[]>>
}
const caches = new WeakMap<ApiClient, Cache>()
let generation = 0

/** Drops what was read, so the next field reads it again: the Voices page
 * calls this after a save. */
export function forgetVoiceSetup(): void {
  generation += 1
}

function cacheOf(api: ApiClient): Cache {
  let cache = caches.get(api)
  if (!cache || cache.generation !== generation) {
    cache = { generation, catalogs: new Map() }
    caches.set(api, cache)
  }
  return cache
}

function settingsOf(api: ApiClient): Promise<VoiceSettingsList> {
  const cache = cacheOf(api)
  if (!cache.settings) {
    const read = api.get<VoiceSettingsList>(voiceRoutes.settings)
    // A failure is not kept, so the next field tries again.
    read.catch(() => {
      if (cache.settings === read) cache.settings = undefined
    })
    cache.settings = read
  }
  return cache.settings
}

function catalogOf(api: ApiClient, language: string): Promise<VoiceOption[]> {
  const { catalogs } = cacheOf(api)
  let read = catalogs.get(language)
  if (!read) {
    read = api.get<VoiceCatalog>(voiceRoutes.voices(language)).then((c) => c.voices)
    read.catch(() => catalogs.delete(language))
    catalogs.set(language, read)
  }
  return read
}

export type VoiceSetup =
  | { kind: 'loading' }
  | { kind: 'failed'; message: string }
  | {
      kind: 'ready'
      configured: boolean
      /** The field's language's settings; null when it has none (no voices,
       * or only a lesson is known). */
      language: VoiceLanguage | null
      /** Every language with voices, for naming one that has none. */
      languages: VoiceLanguage[]
      /** Voice id -> name, when the catalog could be read. */
      names: Record<string, string>
    }

/** What a Generate tab needs to know before it can offer anything. */
export function useVoiceSetup(api: ApiClient, language: string | undefined): VoiceSetup {
  // Each answer is kept with what it answers, so a new language reads as
  // loading until its own answer arrives.
  const key = language ?? ''
  const [answer, setAnswer] = useState<{ api: ApiClient; key: string; setup: VoiceSetup } | null>(null)

  useEffect(() => {
    let live = true
    const setSetup = (setup: VoiceSetup) => setAnswer({ api, key, setup })
    void (async () => {
      try {
        const list = await settingsOf(api)
        const mine = language ? (list.languages.find((l) => l.language === language) ?? null) : null
        let names: Record<string, string> = {}
        if (list.configured && mine) {
          try {
            names = Object.fromEntries((await catalogOf(api, mine.language)).map((v) => [v.id, v.name]))
          } catch {
            // Without the catalog the buttons say the voice ids instead.
          }
        }
        if (live) setSetup({ kind: 'ready', configured: list.configured, language: mine, languages: list.languages, names })
      } catch (e) {
        if (live) setSetup({ kind: 'failed', message: e instanceof Error ? e.message : 'Something went wrong.' })
      }
    })()
    return () => {
      live = false
    }
  }, [api, key, language])

  return answer && answer.api === api && answer.key === key ? answer.setup : { kind: 'loading' }
}
