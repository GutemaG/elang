import { useEffect, useId, useState } from 'react'
import { Link, useParams } from 'react-router-dom'

import type { Span } from '../audio/clean'
import { ClipEditor, usePrepared, type ClipUse } from '../audio/ClipEditor'
import { finalClip } from '../audio/codec'
import { audioTypeOf, canRecord, formatDuration, MAX_AUDIO_BYTES } from '../audio/formats'
import { useRecorder } from '../audio/useRecorder'
import { messageOf, useSession } from '../auth/SessionContext'
import { plainMessage } from '../exercises/model'
import { plural } from '../format'
import type { AdminSoundChart, AdminSoundLetter, SoundLetterChange } from '../types'
import { Button } from '../ui/Button'
import { Icon } from '../ui/Icon'
import { Input } from '../ui/Input'
import { englishOf, needingRecording, uploadSound } from './model'
import { useSoundChart } from './useSoundChart'

/** Every letter still without a recording, one after another, so a speaker
 * can record a whole chart in one sitting. The keyboard drives it: Space
 * starts and stops, Enter keeps the take and moves on. */
export function RecordSessionPage() {
  const { language = '' } = useParams()
  const { chart, error, saveLetters } = useSoundChart(language)

  return (
    <main className="mx-auto max-w-5xl px-4 py-6 sm:px-6 lg:px-8 lg:py-8">
      <nav aria-label="Breadcrumb" className="mb-3 flex flex-wrap items-center gap-1 text-sm">
        <Link to="/sounds" className="text-forest hover:underline">
          Sounds
        </Link>
        <Icon name="chevron_right" className="text-base text-stone" />
        <Link to={`/sounds/${language}`} className="text-forest hover:underline">
          {chart ? `${chart.language_name} · ${englishOf(chart.title)}` : language}
        </Link>
      </nav>
      <h1 className="text-[1.75rem] leading-9 font-bold text-coffee">Record session</h1>
      <p className="mt-1 text-sm text-stone">The letters without a sound, one after another.</p>

      {error && (
        <p role="alert" className="mt-4 text-sm text-danger">
          {error}
        </p>
      )}
      {!chart && !error && <p className="mt-6 text-sm text-stone">Loading…</p>}
      {chart && <Session chart={chart} saveLetters={saveLetters} />}
    </main>
  )
}

function Session({
  chart,
  saveLetters,
}: {
  chart: AdminSoundChart
  saveLetters: (changes: SoundLetterChange[]) => Promise<AdminSoundChart>
}) {
  const { api } = useSession()
  // The letters to record, fixed when the session starts: keeping a take
  // must not reshuffle what comes next.
  const [queue] = useState<AdminSoundLetter[]>(() => needingRecording(chart))
  const recorder = useRecorder()
  const speakerId = useId()
  const [index, setIndex] = useState(0)
  const [kept, setKept] = useState(0)
  const [speaker, setSpeaker] = useState('')
  const [busy, setBusy] = useState(false)
  const [problem, setProblem] = useState<string | null>(null)
  const { state } = recorder
  const letter = queue[index]
  // Cleaned or as recorded holds for the whole session; the cut is the take's own.
  const prep = usePrepared(state.kind === 'recorded' ? state.clip : null)
  const [use, setUse] = useState<ClipUse>('cleaned')
  const [span, setSpan] = useState<Span | null>(null)
  const prepared = prep.kind === 'ready' ? prep.prepared : null

  const actions = {
    toggle: () => {
      if (busy) return
      if (state.kind === 'recording') recorder.stop()
      else if (state.kind !== 'asking') {
        setProblem(null)
        setSpan(null)
        void recorder.start()
      }
    },
    keep: () => {
      if (state.kind === 'recorded' && !busy && !(use === 'cleaned' && prep.kind === 'working')) void keep(state.clip)
    },
    again: () => {
      if (!busy && state.kind !== 'recording') {
        setProblem(null)
        setSpan(null)
        void recorder.start()
      }
    },
    skip: () => {
      if (busy) return
      setSpan(null)
      recorder.discard()
      setProblem(null)
      setIndex((i) => i + 1)
    },
  }

  // Attached again after every render, so the keys always act on what is
  // on screen now.
  useEffect(() => {
    function onKey(e: KeyboardEvent) {
      const target = e.target as HTMLElement | null
      if (target && (target.tagName === 'INPUT' || target.tagName === 'TEXTAREA' || target.tagName === 'SELECT')) return
      if (e.key === ' ') {
        e.preventDefault()
        actions.toggle()
      } else if (e.key === 'Enter') {
        e.preventDefault()
        actions.keep()
      } else if (e.key.toLowerCase() === 'r') {
        actions.again()
      } else if (e.key.toLowerCase() === 's') {
        actions.skip()
      }
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  })

  async function keep(clip: Blob) {
    if (!letter) return
    const type = audioTypeOf({ type: clip.type })
    if (!type) {
      setProblem('This browser recorded in a format that can’t be stored. Use Upload files instead.')
      return
    }
    setBusy(true)
    setProblem(null)
    try {
      const final = await finalClip({ clip, type }, prepared, { use, span })
      if (final.clip.size > MAX_AUDIO_BYTES) {
        setProblem('That take is too long. Record it again, shorter.')
        return
      }
      const url = await uploadSound(api, chart.language, final.clip, final.type)
      await saveLetters([
        { id: letter.id, audio_url: url, status: 'needs_review', ...(speaker.trim() ? { recorded_by: speaker.trim() } : {}) },
      ])
      setSpan(null)
      recorder.discard()
      setKept((n) => n + 1)
      setIndex((i) => i + 1)
    } catch (e) {
      setProblem(plainMessage(messageOf(e)))
    } finally {
      setBusy(false)
    }
  }

  if (!canRecord()) {
    return (
      <p className="mt-6 rounded bg-terracotta-tint px-4 py-3 text-sm text-terracotta">
        This browser can’t record audio. Use Upload files on the chart instead.
      </p>
    )
  }

  if (!letter) {
    return (
      <section className="mt-6 rounded-lg border border-line bg-surface p-8 text-center shadow-e1">
        <Icon name="task_alt" className="text-5xl text-forest" />
        <h2 className="mt-2 text-xl font-semibold text-coffee">
          {queue.length === 0 ? 'Every sound already has a recording' : 'Session finished'}
        </h2>
        <p className="mt-1 text-sm text-stone">
          {queue.length === 0
            ? 'Nothing is left to record.'
            : `${plural(kept, 'recording')} kept. They are marked Needs review for a native speaker to check.`}
        </p>
        <Link to={`/sounds/${chart.language}`} className="mt-4 inline-block text-sm font-semibold text-forest underline">
          Back to the chart
        </Link>
      </section>
    )
  }

  const upNext = queue.slice(index + 1, index + 7)

  return (
    <div className="mt-6 grid gap-5 md:grid-cols-[minmax(0,1fr)_14rem]">
      <section className="flex flex-col items-center gap-3 rounded-lg border border-line bg-surface p-6 text-center shadow-e1">
        <p className="tnum text-xs font-semibold text-stone">
          {index + 1} of {queue.length} · say it once, clearly
        </p>
        <p className="text-8xl leading-none font-bold text-coffee" aria-label={`Letter ${letter.glyph}`}>
          {letter.glyph}
        </p>
        <p className="font-mono text-lg text-coffee-soft">{letter.romanization}</p>

        {state.kind === 'recording' ? (
          <Button variant="coffee" onClick={() => actions.toggle()}>
            <Icon name="stop" className="text-lg" filled />
            Stop · {formatDuration(recorder.seconds)}
          </Button>
        ) : state.kind === 'recorded' ? (
          <div className="flex w-full flex-col items-center gap-3">
            <div className="w-full max-w-md text-left">
              <ClipEditor
                state={prep}
                use={use}
                onUse={setUse}
                span={span}
                onSpan={setSpan}
                autoPlay
                original={<audio controls autoPlay={use === 'original'} src={state.url} aria-label="Play the take" className="w-full" />}
              />
            </div>
            <div className="flex flex-wrap justify-center gap-2">
              <Button disabled={busy} onClick={() => actions.again()}>
                <Icon name="replay" className="text-lg" />
                Record again
              </Button>
              <Button variant="primary" disabled={busy || (use === 'cleaned' && prep.kind === 'working')} onClick={() => actions.keep()}>
                <Icon name="check" className="text-lg" />
                {busy ? 'Saving…' : 'Keep and next'}
              </Button>
            </div>
          </div>
        ) : (
          <Button variant="primary" disabled={state.kind === 'asking'} onClick={() => actions.toggle()}>
            <Icon name="mic" className="text-lg" />
            {state.kind === 'asking' ? 'Waiting for the microphone…' : 'Record'}
          </Button>
        )}

        {state.kind === 'blocked' && (
          <p role="alert" className="text-sm text-danger">
            The microphone could not be used. Allow it from the address bar, then try again.
          </p>
        )}
        {problem && (
          <p role="alert" className="text-sm text-danger">
            {problem}
          </p>
        )}
        <p className="text-xs text-stone">
          <kbd className="rounded border border-line px-1">Space</kbd> start and stop ·{' '}
          <kbd className="rounded border border-line px-1">Enter</kbd> keep and next ·{' '}
          <kbd className="rounded border border-line px-1">R</kbd> again ·{' '}
          <kbd className="rounded border border-line px-1">S</kbd> skip
        </p>
        <Button size="sm" variant="ghost" disabled={busy} onClick={() => actions.skip()}>
          Skip this letter
        </Button>
      </section>

      <aside className="space-y-3">
        <div>
          <label htmlFor={speakerId} className="mb-1.5 block text-sm font-semibold text-coffee">
            Speaker
          </label>
          <Input id={speakerId} value={speaker} maxLength={120} placeholder="Who is recording" onChange={(e) => setSpeaker(e.target.value)} />
          <p className="mt-1 text-xs text-stone">Saved as “Recorded by” and credited in the app.</p>
        </div>
        <div>
          <h2 className="text-sm font-semibold text-coffee">Up next</h2>
          <ul className="mt-1.5 space-y-1">
            {upNext.map((x) => (
              <li key={x.id} className="flex items-center gap-3 rounded border border-line bg-surface px-3 py-1.5">
                <span className="min-w-8 text-lg font-semibold text-coffee">{x.glyph}</span>
                <span className="font-mono text-xs text-stone">{x.romanization}</span>
              </li>
            ))}
            {upNext.length === 0 && <li className="text-xs text-stone">This is the last one.</li>}
          </ul>
        </div>
        <p className="text-xs text-stone">{plural(kept, 'take')} kept so far. Kept takes are marked Needs review.</p>
      </aside>
    </div>
  )
}
