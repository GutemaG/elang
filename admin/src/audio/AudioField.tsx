import { useEffect, useRef, useState, type ReactNode } from 'react'

import { messageOf, useSession } from '../auth/SessionContext'
import { FieldError, Section } from '../exercises/fields'
import { playableUrl, plainMessage } from '../exercises/model'
import { Button } from '../ui/Button'
import { cx } from '../ui/cx'
import { Icon } from '../ui/Icon'
import { Input } from '../ui/Input'
import {
  IPHONE_SAFE_RECORDING,
  MAX_AUDIO_BYTES,
  MAX_RECORDING_SECONDS,
  audioTypeOf,
  canRecord,
  checkClip,
  formatDuration,
  formatSize,
  recordingType,
} from './formats'
import { checkLink, uploadClip } from './upload'
import { useRecorder, type MicProblem } from './useRecorder'

// The clip every seeded listening exercise started with
// (PLACEHOLDER_AUDIO_URL in backend/app/infrastructure/db/seed_category_content.py).
const PLACEHOLDER_URL = 'https://www.kozco.com/tech/piano2-CoolEdit.mp3'

type Tab = 'record' | 'upload' | 'link'

const TABS: { id: Tab; label: string; icon: string }[] = [
  { id: 'record', label: 'Record', icon: 'mic' },
  { id: 'upload', label: 'Upload', icon: 'upload_file' },
  { id: 'link', label: 'Link', icon: 'link' },
]

interface Props {
  lessonId: string
  /** The draft's `audio_url`. */
  url: string
  /** The stored `audio_url`, or null for an exercise not created yet. */
  savedUrl: string | null
  onChange: (url: string) => void
}

/** A listening exercise's clip: the current one, and three ways to replace
 * it (story 004). Recordings and files are uploaded when the admin chooses
 * "Use this…"; the exercise's own Save then stores the new address. All
 * three panels stay mounted, so switching tabs never loses a take. */
export function AudioField({ lessonId, url, savedUrl, onChange }: Props) {
  const [tab, setTab] = useState<Tab>('record')
  const current = url.trim()
  const unsaved = current !== '' && current !== (savedUrl ?? '').trim()

  return (
    <Section title="Audio" hint="The clip the learner hears. Record it here, upload a file, or paste a link.">
      <CurrentClip url={current} unsaved={unsaved} />
      <FieldError slot="audio_url" />

      <div role="tablist" aria-label="Replace the clip" className="mt-4 flex gap-1 border-b border-line">
        {TABS.map((t) => (
          <button
            key={t.id}
            type="button"
            role="tab"
            id={`audio-tab-${t.id}`}
            aria-selected={tab === t.id}
            aria-controls={`audio-panel-${t.id}`}
            onClick={() => setTab(t.id)}
            className={cx(
              '-mb-px inline-flex h-11 items-center gap-1.5 border-b-2 px-3 text-sm font-semibold transition-colors sm:h-10',
              tab === t.id
                ? 'border-forest text-forest'
                : 'border-transparent text-coffee-soft hover:border-line-strong hover:text-coffee',
            )}
          >
            <Icon name={t.icon} className="text-lg" />
            {t.label}
          </button>
        ))}
      </div>

      {TABS.map((t) => (
        <div
          key={t.id}
          role="tabpanel"
          id={`audio-panel-${t.id}`}
          aria-labelledby={`audio-tab-${t.id}`}
          hidden={tab !== t.id}
          className="pt-4"
        >
          {t.id === 'record' && <RecordPanel lessonId={lessonId} onUploaded={onChange} />}
          {t.id === 'upload' && <UploadPanel lessonId={lessonId} onUploaded={onChange} />}
          {t.id === 'link' && <LinkPanel onChecked={onChange} />}
        </div>
      ))}
    </Section>
  )
}

function CurrentClip({ url, unsaved }: { url: string; unsaved: boolean }) {
  if (!url) {
    return (
      <p className="flex items-center gap-2 rounded-lg bg-terracotta-tint p-3 text-sm text-terracotta">
        <Icon name="music_off" className="text-lg" />
        No audio yet. Add a clip below.
      </p>
    )
  }
  const source =
    url === PLACEHOLDER_URL
      ? { label: 'Placeholder clip', title: 'The piano clip the course was seeded with', tone: 'draft' as const }
      : url.startsWith('/')
        ? {
            label: 'Local backend only',
            title: 'Plays from this computer’s backend, not on a phone over the internet',
            tone: 'neutral' as const,
          }
        : { label: 'Hosted', title: 'Plays from its https address', tone: 'published' as const }

  return (
    <div className="rounded-lg bg-inset p-3">
      <div className="flex flex-wrap items-center gap-2">
        <span className="text-sm font-semibold text-coffee">Current clip</span>
        <Pill tone={source.tone} title={source.title}>
          {source.label}
        </Pill>
        {unsaved && (
          <Pill tone="draft" title="Press Save to keep this clip">
            Not saved yet
          </Pill>
        )}
      </div>
      <audio controls preload="none" src={playableUrl(url)} aria-label="Play the clip" className="mt-2 w-full" />
      <p className="mt-1 text-xs break-all text-stone">{url}</p>
    </div>
  )
}

const PILL_TONES = {
  published: 'border-forest-line bg-forest-tint text-forest',
  draft: 'border-terracotta-line bg-terracotta-tint text-terracotta',
  neutral: 'border-line bg-slate-100 text-slate-500',
}

function Pill({ tone, title, children }: { tone: keyof typeof PILL_TONES; title: string; children: ReactNode }) {
  return (
    <span
      title={title}
      className={cx('rounded-full border px-2 py-0.5 text-[0.6875rem] font-bold', PILL_TONES[tone])}
    >
      {children}
    </span>
  )
}

function Problem({ children }: { children: ReactNode }) {
  return (
    <p role="alert" className="mt-3 flex items-start gap-1.5 text-sm text-danger">
      <Icon name="error" className="mt-px text-base" />
      <span>{children}</span>
    </p>
  )
}

function Note({ icon, children }: { icon: string; children: ReactNode }) {
  return (
    <p className="mb-3 flex items-start gap-1.5 rounded bg-terracotta-tint px-3 py-2 text-sm leading-6 text-terracotta">
      <Icon name={icon} className="mt-1 text-base" />
      <span>{children}</span>
    </p>
  )
}

/** Sends one clip to the store. `send` answers false when it failed, and
 * `problem` then says why. */
function useClipUpload(lessonId: string, onUploaded: (url: string) => void) {
  const { api } = useSession()
  const [busy, setBusy] = useState(false)
  const [problem, setProblem] = useState<string | null>(null)

  async function send(clip: Blob, type: string): Promise<boolean> {
    setBusy(true)
    setProblem(null)
    try {
      onUploaded(await uploadClip(api, lessonId, clip, type))
      return true
    } catch (e) {
      setProblem(plainMessage(messageOf(e)))
      return false
    } finally {
      setBusy(false)
    }
  }

  return { busy, problem, setProblem, send }
}

const MIC_PROBLEMS: Record<MicProblem, string> = {
  denied:
    'The microphone is blocked for this site. Allow it from the icon in the address bar, then try again. Upload and Link still work.',
  'no-mic': 'No microphone was found. Connect one and try again, or use Upload or Link.',
  failed: 'The microphone could not be started. Try again, or use Upload or Link.',
}

function RecordPanel({ lessonId, onUploaded }: { lessonId: string; onUploaded: (url: string) => void }) {
  const recorder = useRecorder()
  const upload = useClipUpload(lessonId, onUploaded)
  const { state } = recorder

  if (!canRecord()) {
    return <Note icon="mic_off">This browser can’t record audio. Use Upload or Link instead.</Note>
  }

  async function use(clip: Blob) {
    const type = audioTypeOf({ type: clip.type })
    if (!type) {
      upload.setProblem('This browser recorded in a format that can’t be stored. Upload a file instead.')
      return
    }
    if (clip.size > MAX_AUDIO_BYTES) {
      upload.setProblem(`The recording is ${formatSize(clip.size)}; clips can be 5 MB at most. Record a shorter one.`)
      return
    }
    if (await upload.send(clip, type)) recorder.discard()
  }

  const again = () => {
    upload.setProblem(null)
    void recorder.start()
  }

  return (
    <div>
      {recordingType() !== IPHONE_SAFE_RECORDING && (
        <Note icon="warning">
          This browser records {recordingType().startsWith('audio/mp4') ? 'mp4 without AAC' : 'WebM'}. Computers and
          Android phones play it, but iPhones may not. For iPhone learners, record in Chrome, Edge or Safari, or upload
          an m4a or mp3.
        </Note>
      )}

      {(state.kind === 'idle' || state.kind === 'asking') && (
        <Button variant="primary" disabled={state.kind === 'asking'} onClick={again}>
          <Icon name="mic" className="text-lg" />
          {state.kind === 'asking' ? 'Waiting for the microphone…' : 'Start recording'}
        </Button>
      )}

      {state.kind === 'recording' && (
        <div className="flex flex-wrap items-center gap-3">
          <span className="inline-flex items-center gap-2 text-sm font-semibold text-danger">
            <span className="size-2.5 animate-pulse rounded-full bg-danger" aria-hidden="true" />
            Recording
          </span>
          <span role="timer" aria-label="Recording time" className="tnum text-sm text-coffee">
            {formatDuration(recorder.seconds)} / {formatDuration(MAX_RECORDING_SECONDS)}
          </span>
          <Button variant="coffee" onClick={recorder.stop}>
            <Icon name="stop" className="text-lg" filled />
            Stop
          </Button>
        </div>
      )}

      {state.kind === 'recorded' && (
        <div className="space-y-3">
          <audio controls src={state.url} aria-label="Play the recording" className="w-full" />
          <p className="text-xs text-stone">
            {formatDuration(state.seconds)} · {formatSize(state.clip.size)} · not uploaded yet
          </p>
          <div className="flex flex-wrap gap-2">
            <Button variant="primary" disabled={upload.busy} onClick={() => void use(state.clip)}>
              <Icon name="cloud_upload" className="text-lg" />
              {upload.busy ? 'Uploading…' : 'Use this recording'}
            </Button>
            <Button disabled={upload.busy} onClick={again}>
              <Icon name="replay" className="text-lg" />
              Record again
            </Button>
            <Button
              variant="danger-ghost"
              disabled={upload.busy}
              onClick={() => {
                upload.setProblem(null)
                recorder.discard()
              }}
            >
              <Icon name="delete" className="text-lg" />
              Discard
            </Button>
          </div>
        </div>
      )}

      {state.kind === 'blocked' && (
        <div>
          <Problem>{MIC_PROBLEMS[state.problem]}</Problem>
          <Button className="mt-3" onClick={again}>
            <Icon name="mic" className="text-lg" />
            Try again
          </Button>
        </div>
      )}

      {upload.problem && <Problem>{upload.problem}</Problem>}
    </div>
  )
}

interface Chosen {
  file: File
  type: string
  url: string
}

function UploadPanel({ lessonId, onUploaded }: { lessonId: string; onUploaded: (url: string) => void }) {
  const upload = useClipUpload(lessonId, onUploaded)
  const [chosen, setChosen] = useState<Chosen | null>(null)
  const input = useRef<HTMLInputElement>(null)

  // Each chosen file is played from a URL of its own, freed when replaced.
  const chosenUrl = chosen?.url
  useEffect(() => {
    if (!chosenUrl) return
    return () => URL.revokeObjectURL(chosenUrl)
  }, [chosenUrl])

  function choose(file: File | undefined) {
    setChosen(null)
    upload.setProblem(null)
    if (!file) return
    const check = checkClip(file)
    if (!check.ok) {
      upload.setProblem(check.problem)
      if (input.current) input.current.value = ''
      return
    }
    setChosen({ file, type: check.type, url: URL.createObjectURL(file) })
  }

  async function use(c: Chosen) {
    if (await upload.send(c.file, c.type)) {
      setChosen(null)
      if (input.current) input.current.value = ''
    }
  }

  return (
    <div>
      <input
        ref={input}
        type="file"
        aria-label="Audio file"
        accept="audio/*,.m4a,.mp3,.webm,.ogg"
        disabled={upload.busy}
        onChange={(e) => choose(e.target.files?.[0])}
        className={cx(
          'block w-full text-sm text-coffee-soft',
          'file:mr-3 file:h-11 file:cursor-pointer file:rounded file:border file:border-line file:bg-surface',
          'file:px-4 file:text-sm file:font-semibold file:text-coffee hover:file:bg-inset sm:file:h-10',
        )}
      />
      <p className="mt-1.5 text-xs text-stone">m4a, mp3, webm or ogg, up to 5 MB. m4a and mp3 play on every phone.</p>

      {chosen && (
        <div className="mt-3 space-y-3">
          <audio controls src={chosen.url} aria-label="Play the chosen file" className="w-full" />
          <p className="text-xs break-all text-stone">
            {chosen.file.name} · {formatSize(chosen.file.size)} · not uploaded yet
          </p>
          <Button variant="primary" disabled={upload.busy} onClick={() => void use(chosen)}>
            <Icon name="cloud_upload" className="text-lg" />
            {upload.busy ? 'Uploading…' : 'Use this file'}
          </Button>
        </div>
      )}

      {upload.problem && <Problem>{upload.problem}</Problem>}
    </div>
  )
}

function LinkPanel({ onChecked }: { onChecked: (url: string) => void }) {
  const { api } = useSession()
  const [link, setLink] = useState('')
  const [busy, setBusy] = useState(false)
  const [problem, setProblem] = useState<string | null>(null)
  const [accepted, setAccepted] = useState<string | null>(null)

  async function check() {
    if (!link.trim() || busy) return
    setBusy(true)
    setProblem(null)
    setAccepted(null)
    try {
      const result = await checkLink(api, link)
      onChecked(result.url)
      setAccepted(result.content_type)
      setLink('')
    } catch (e) {
      setProblem(plainMessage(messageOf(e)))
    } finally {
      setBusy(false)
    }
  }

  return (
    <div>
      <div className="flex flex-wrap gap-2">
        <Input
          aria-label="Audio link"
          type="url"
          inputMode="url"
          placeholder="https://…"
          value={link}
          className="min-w-[12rem] flex-1"
          onChange={(e) => {
            setLink(e.target.value)
            setProblem(null)
            setAccepted(null)
          }}
          onKeyDown={(e) => {
            if (e.key === 'Enter') {
              e.preventDefault()
              void check()
            }
          }}
        />
        <Button variant="primary" disabled={busy || !link.trim()} onClick={() => void check()}>
          <Icon name="fact_check" className="text-lg" />
          {busy ? 'Checking…' : 'Check link'}
        </Button>
      </div>
      <p className="mt-1.5 text-xs text-stone">
        A full https:// address. The server checks it answers with audio before it is used.
      </p>
      {accepted && (
        <p aria-live="polite" className="mt-3 flex items-center gap-1.5 text-sm text-forest">
          <Icon name="check_circle" className="text-base" filled />
          The link plays {accepted}. It is now the current clip; press Save to keep it.
        </p>
      )}
      {problem && <Problem>{problem}</Problem>}
    </div>
  )
}
