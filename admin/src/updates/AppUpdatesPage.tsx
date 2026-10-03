import { useEffect, useId, useState, type FormEvent, type ReactNode } from 'react'

import { messageOf, useSession } from '../auth/SessionContext'
import { PageHeader } from '../shell/Page'
import { routes } from '../tree/levels'
import type { AdminAppConfig, AdminAppConfigResponse } from '../types'
import { Button } from '../ui/Button'
import { Icon } from '../ui/Icon'
import { Input } from '../ui/Input'
import { Modal } from '../ui/Modal'

type Key = keyof AdminAppConfig
type Draft = Record<Key, string>

const BUILD_KEYS = ['min_build_android', 'min_build_ios', 'latest_build_ios'] as const
const MINIMUMS = [
  { key: 'min_build_android', store: 'Android' },
  { key: 'min_build_ios', store: 'iOS' },
] as const

const isBuild = (text: string) => /^\d{1,9}$/.test(text.trim())
const isStoreUrl = (text: string) => text.trim() === '' || /^https:\/\/\S+$/.test(text.trim())

function draftOf(config: AdminAppConfig): Draft {
  return {
    min_build_android: String(config.min_build_android),
    min_build_ios: String(config.min_build_ios),
    latest_build_ios: String(config.latest_build_ios),
    ios_store_url: config.ios_store_url,
  }
}

/** Only what changed, typed as the backend stores it. */
function changesOf(saved: AdminAppConfig, draft: Draft): Partial<AdminAppConfig> {
  const changes: Partial<AdminAppConfig> = {}
  for (const key of BUILD_KEYS) {
    const value = Number(draft[key].trim())
    if (value !== saved[key]) changes[key] = value
  }
  if (draft.ios_store_url.trim() !== saved.ios_store_url) changes.ios_store_url = draft.ios_store_url.trim()
  return changes
}

/** The builds the phone app checks itself against when it opens: an older
 * build than a store's minimum shows only "Update needed" until it is
 * updated. Optional updates on Android come from Google Play itself. */
export function AppUpdatesPage() {
  const { api } = useSession()
  const [saved, setSaved] = useState<AdminAppConfig | null>(null)
  const [draft, setDraft] = useState<Draft | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [notice, setNotice] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)
  const [confirming, setConfirming] = useState(false)

  useEffect(() => {
    let live = true
    api.get<AdminAppConfigResponse>(routes.appConfig).then(
      ({ config }) => {
        if (!live) return
        setSaved(config)
        setDraft(draftOf(config))
      },
      (e: unknown) => live && setError(messageOf(e)),
    )
    return () => {
      live = false
    }
  }, [api])

  const valid = !!draft && BUILD_KEYS.every((key) => isBuild(draft[key])) && isStoreUrl(draft.ios_store_url)
  const changes = saved && draft && valid ? changesOf(saved, draft) : {}
  const changed = Object.keys(changes).length > 0
  // Anything typed, valid or not, so a mistake can be undone too.
  const dirty =
    !!saved && !!draft && (Object.keys(draft) as Key[]).some((key) => draft[key] !== draftOf(saved)[key])
  const raised = saved ? MINIMUMS.filter(({ key }) => (changes[key] ?? saved[key]) > saved[key]) : []

  function edit(key: Key, value: string) {
    setDraft((d) => (d ? { ...d, [key]: value } : d))
    setNotice(null)
  }

  async function save() {
    setConfirming(false)
    setBusy(true)
    setError(null)
    try {
      const { config } = await api.patch<AdminAppConfigResponse>(routes.appConfig, changes)
      setSaved(config)
      setDraft(draftOf(config))
      setNotice('Saved. Phones pick it up the next time the app opens.')
    } catch (e) {
      setError(messageOf(e))
    } finally {
      setBusy(false)
    }
  }

  function submit(e: FormEvent) {
    e.preventDefault()
    if (!changed || busy) return
    if (raised.length > 0) setConfirming(true)
    else void save()
  }

  return (
    <main className="mx-auto max-w-4xl px-4 py-6 sm:px-6 lg:px-8 lg:py-8">
      <PageHeader
        eyebrow="App"
        title="App updates"
        description="Which builds of the phone app may still run. A phone with an older build than its store's minimum shows only “Update needed” until it is updated. The build is the number after the + in pubspec.yaml (Android's versionCode)."
      />

      {error && (
        <div
          role="alert"
          className="mt-6 flex items-center gap-3 rounded-md border border-danger-line bg-danger-tint px-4 py-3 text-sm text-danger"
        >
          <Icon name="error" className="text-lg" />
          <span className="flex-1">{error}</span>
        </div>
      )}

      {!draft && !error && <p className="mt-6 text-sm text-stone">Loading…</p>}

      {draft && (
        <form className="mt-6 space-y-6" onSubmit={submit}>
          <StoreCard
            icon="android"
            title="Android · Google Play"
            note="Google Play offers newer builds itself: the app downloads them in the background and asks to restart. Nothing to set here for that."
          >
            <BuildField
              label="Minimum build"
              value={draft.min_build_android}
              onChange={(v) => edit('min_build_android', v)}
              hint="0 lets every build run. Raise it only once the new build has reached everyone on Google Play, or some phones are stuck until Play offers it."
            />
          </StoreCard>

          <StoreCard
            icon="phone_iphone"
            title="iOS · App Store"
            note="iOS has no update prompt of its own, so the latest build is offered to older ones, at most every three days."
          >
            <div className="grid gap-4 sm:grid-cols-2">
              <BuildField
                label="Minimum build"
                value={draft.min_build_ios}
                onChange={(v) => edit('min_build_ios', v)}
                hint="0 lets every build run."
              />
              <BuildField
                label="Latest build"
                value={draft.latest_build_ios}
                onChange={(v) => edit('latest_build_ios', v)}
                hint="Older builds are offered an update."
              />
            </div>
            <TextField
              label="App Store link"
              value={draft.ios_store_url}
              placeholder="https://apps.apple.com/app/id1234567890"
              invalid={!isStoreUrl(draft.ios_store_url)}
              onChange={(v) => edit('ios_store_url', v)}
              hint={
                isStoreUrl(draft.ios_store_url)
                  ? 'Where “Update” opens on iPhone. Nothing is offered until it is set.'
                  : 'An https:// address, or empty.'
              }
            />
          </StoreCard>

          <div className="flex flex-wrap items-center justify-end gap-3">
            {notice && (
              <p role="status" className="flex-1 text-sm text-forest">
                {notice}
              </p>
            )}
            <Button
              disabled={busy || !dirty}
              onClick={() => {
                if (saved) setDraft(draftOf(saved))
              }}
            >
              Undo changes
            </Button>
            <Button type="submit" variant="primary" disabled={busy || !changed}>
              Save
            </Button>
          </div>
        </form>
      )}

      {confirming && saved && (
        <Modal title="Require an update?" onClose={() => setConfirming(false)}>
          <ul className="mt-2 space-y-1 text-sm leading-6 text-coffee-soft">
            {raised.map(({ key, store }) => (
              <li key={key}>
                {store} builds below {changes[key]} will show only “Update needed” the next time they open.
              </li>
            ))}
          </ul>
          <p className="mt-3 text-sm leading-6 text-coffee-soft">
            Make sure that build is already out to everyone in the store.
          </p>
          <div className="mt-6 flex flex-col-reverse gap-2 sm:flex-row sm:justify-end">
            <Button className="justify-center" onClick={() => setConfirming(false)}>
              Cancel
            </Button>
            <Button variant="primary" className="justify-center" onClick={() => void save()}>
              Require update
            </Button>
          </div>
        </Modal>
      )}
    </main>
  )
}

function StoreCard({
  icon,
  title,
  note,
  children,
}: {
  icon: string
  title: string
  note: string
  children: ReactNode
}) {
  return (
    <section className="overflow-hidden rounded-lg border border-line bg-surface shadow-e1">
      <div className="flex items-start gap-3 border-b border-line px-4 py-4 sm:px-6">
        <span className="grid size-9 shrink-0 place-items-center rounded bg-forest-tint text-forest">
          <Icon name={icon} className="text-xl" />
        </span>
        <div className="min-w-0">
          <h2 className="text-lg leading-6 font-semibold text-coffee">{title}</h2>
          <p className="mt-0.5 text-xs leading-5 text-stone">{note}</p>
        </div>
      </div>
      <div className="space-y-4 px-4 py-4 sm:px-6">{children}</div>
    </section>
  )
}

function BuildField({
  label,
  value,
  hint,
  onChange,
}: {
  label: string
  value: string
  hint: string
  onChange: (value: string) => void
}) {
  return (
    <TextField
      label={label}
      value={value}
      inputMode="numeric"
      invalid={!isBuild(value)}
      onChange={onChange}
      hint={isBuild(value) ? hint : 'A whole number, 0 or more.'}
    />
  )
}

function TextField({
  label,
  value,
  hint,
  invalid,
  placeholder,
  inputMode,
  onChange,
}: {
  label: string
  value: string
  hint: string
  invalid: boolean
  placeholder?: string
  inputMode?: 'numeric'
  onChange: (value: string) => void
}) {
  const id = useId()
  const hintId = useId()
  return (
    <div>
      <label htmlFor={id} className="mb-1.5 block text-sm font-semibold text-coffee">
        {label}
      </label>
      <Input
        id={id}
        value={value}
        inputMode={inputMode}
        placeholder={placeholder}
        autoComplete="off"
        aria-invalid={invalid || undefined}
        aria-describedby={hintId}
        onChange={(e) => onChange(e.target.value)}
      />
      <p id={hintId} className={invalid ? 'mt-1 text-xs text-danger' : 'mt-1 text-xs text-stone'}>
        {hint}
      </p>
    </div>
  )
}
