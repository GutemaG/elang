import { useCallback, useEffect, useState } from 'react'

import { messageOf, useSession } from '../auth/SessionContext'
import { PageHeader } from '../shell/Page'
import { Button } from '../ui/Button'
import { Icon } from '../ui/Icon'
import {
  voiceRoutes,
  type VoiceCatalog,
  type VoiceLanguage,
  type VoiceSettingsList,
  type VoiceUsage,
} from './api'
import { usePlayer } from './usePlayer'
import { VoiceCard, type CatalogState } from './VoiceCard'

/** Which Addis AI voice speaks each language, and how fast (intent 027).
 * The Generate tab of every clip field uses what is saved here. */
export function VoicesPage() {
  const { api } = useSession()
  const [settings, setSettings] = useState<VoiceSettingsList | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [catalogs, setCatalogs] = useState<Record<string, CatalogState>>({})
  const [usage, setUsage] = useState<VoiceUsage | null>(null)
  const player = usePlayer()

  /** The credit line (FR-15). Hidden, not an error, when it can't load. */
  const loadUsage = useCallback(async () => {
    try {
      setUsage(await api.get<VoiceUsage>(voiceRoutes.usage))
    } catch {
      setUsage(null)
    }
  }, [api])

  const loadCatalog = useCallback(
    async (code: string) => {
      setCatalogs((c) => ({ ...c, [code]: { kind: 'loading' } }))
      try {
        const catalog = await api.get<VoiceCatalog>(voiceRoutes.voices(code))
        setCatalogs((c) => ({ ...c, [code]: { kind: 'ready', voices: catalog.voices } }))
      } catch (e) {
        setCatalogs((c) => ({ ...c, [code]: { kind: 'failed', message: messageOf(e) } }))
      }
    },
    [api],
  )

  const load = useCallback(async () => {
    setError(null)
    try {
      const list = await api.get<VoiceSettingsList>(voiceRoutes.settings)
      setSettings(list)
      if (list.configured) {
        await Promise.all([...list.languages.map((l) => loadCatalog(l.language)), loadUsage()])
      }
    } catch (e) {
      setError(messageOf(e))
    }
  }, [api, loadCatalog, loadUsage])

  useEffect(() => {
    void load()
  }, [load])

  function replace(saved: VoiceLanguage) {
    setSettings((s) =>
      s && { ...s, languages: s.languages.map((l) => (l.language === saved.language ? saved : l)) },
    )
  }

  return (
    <main className="mx-auto max-w-6xl px-4 py-6 sm:px-6 lg:px-8 lg:py-8">
      <PageHeader
        eyebrow="Workspace"
        title="Voices"
        description="The generated voices for each language, and how fast they speak."
      />

      {error && (
        <div
          role="alert"
          className="mt-6 flex flex-wrap items-center gap-3 rounded-md border border-danger-line bg-danger-tint px-4 py-3 text-sm text-danger"
        >
          <Icon name="error" className="text-lg" />
          <span className="flex-1">{error}</span>
          <Button size="sm" onClick={() => void load()}>
            Try again
          </Button>
        </div>
      )}

      {usage && (
        <p className="mt-4 flex items-center gap-2 text-sm text-coffee-soft">
          <Icon name="account_balance_wallet" className="text-base" />
          <span>
            Credit: <span className="font-semibold text-coffee">{usage.formatted_balance}</span>
            {usage.price_per_minute !== null && ` · ${usage.price_per_minute} ${usage.currency} per minute of audio`}
          </span>
        </p>
      )}

      {settings && !settings.configured && (
        <p
          role="note"
          className="mt-6 flex items-start gap-2 rounded-md bg-terracotta-tint px-4 py-3 text-sm leading-6 text-terracotta"
        >
          <Icon name="info" className="mt-1 text-base" />
          <span>
            Generated voices aren’t set up on this server. Add <code className="font-semibold">ADDIS_API_KEY</code> to
            the backend’s environment.
          </span>
        </p>
      )}

      {!settings && !error && <p className="mt-6 text-sm text-stone">Loading…</p>}

      <div className="mt-6 grid gap-6">
        {settings?.languages.map((language) => (
          <VoiceCard
            key={language.language}
            settings={language}
            catalog={settings.configured ? (catalogs[language.language] ?? { kind: 'loading' }) : null}
            onRetryCatalog={() => void loadCatalog(language.language)}
            onSaved={replace}
            player={player}
            onTried={() => void loadUsage()}
          />
        ))}
      </div>
    </main>
  )
}
