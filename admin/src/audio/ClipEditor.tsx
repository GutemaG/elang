import { useEffect, useId, useMemo, useRef, useState, type PointerEvent, type ReactNode } from 'react'

import { Button } from '../ui/Button'
import { cx } from '../ui/cx'
import { Icon } from '../ui/Icon'
import { MIN_SECONDS, cleanUp, durationOf, formatSeconds, peaksOf, widen, type Span } from './clean'
import { mp3SizeOf, playPcm, prepareClip, type Prepared } from './codec'
import { EFFECTS, applyEffects, ordered, type Effect } from './effects'
import { formatSize } from './formats'

/** Which version of a clip is stored. */
export type ClipUse = 'cleaned' | 'original'

export type PrepareState = { kind: 'working' } | { kind: 'failed' } | { kind: 'ready'; prepared: Prepared }

/** Reads `clip` into samples for cleaning, again whenever it changes. */
export function usePrepared(clip: Blob | null): PrepareState {
  const [done, setDone] = useState<{ clip: Blob; prepared: Prepared | null } | null>(null)
  useEffect(() => {
    if (!clip) return
    let live = true
    void prepareClip(clip).then((prepared) => {
      if (live) setDone({ clip, prepared })
    })
    return () => {
      live = false
    }
  }, [clip])
  if (!clip || done?.clip !== clip) return { kind: 'working' }
  return done.prepared ? { kind: 'ready', prepared: done.prepared } : { kind: 'failed' }
}

/** The effects picked, in words: "noise reduced, warmer". */
export function effectsInWords(effects: readonly Effect[]): string {
  const words: Record<Effect, string> = {
    denoise: 'noise reduced',
    rumble: 'rumble removed',
    warmer: 'warmer',
    clearer: 'clearer',
  }
  return ordered(effects)
    .map((e) => words[e])
    .join(', ')
}

/** The effects as buttons that stay pressed, any number at once. */
export function EffectButtons({
  effects,
  onEffects,
  disabled,
  label = 'Improve',
}: {
  effects: readonly Effect[]
  onEffects: (effects: Effect[]) => void
  disabled?: boolean
  label?: string
}) {
  return (
    <div role="group" aria-label="Improve the sound" className="flex flex-wrap items-center gap-1.5">
      <span aria-hidden="true" className="mr-0.5 text-xs font-semibold text-stone">
        {label}
      </span>
      {EFFECTS.map((e) => {
        const on = effects.includes(e.id)
        return (
          <button
            key={e.id}
            type="button"
            aria-pressed={on}
            title={e.hint}
            disabled={disabled}
            onClick={() => onEffects(on ? effects.filter((x) => x !== e.id) : ordered([...effects, e.id]))}
            className={cx(
              'inline-flex h-8 items-center gap-1 rounded-full border px-3 text-[0.8125rem] font-semibold transition-colors',
              'focus-visible:outline-2 focus-visible:outline-forest disabled:opacity-45',
              on ? 'border-forest bg-forest-tint text-forest' : 'border-line bg-surface text-coffee-soft hover:bg-inset',
            )}
          >
            {on && <Icon name="check" className="-ml-0.5 text-base" />}
            {e.label}
          </button>
        )
      })}
    </div>
  )
}

/** "≈ 6 KB": the cleaned mp3's size, known before it is made. */
export const cleanedSize = (seconds: number): string => `≈ ${formatSize(mp3SizeOf(seconds))}`

const BARS = 120
const WIDTH = 480
const HEIGHT = 64

/** A recording or file before it is stored: the cleaned version (silence
 * cut, volume evened, faded) with handles to move the cut, or the clip as
 * it came. `original` is the player for the clip as it came. */
export function ClipEditor({
  state,
  use,
  onUse,
  span,
  onSpan,
  effects,
  onEffects,
  original,
  originalSize,
  autoPlay = false,
}: {
  state: PrepareState
  use: ClipUse
  onUse: (use: ClipUse) => void
  /** Where the admin moved the cut to, or null for where it was found. */
  span: Span | null
  onSpan: (span: Span | null) => void
  effects: readonly Effect[]
  onEffects: (effects: Effect[]) => void
  original: ReactNode
  /** The clip as it came, in bytes. */
  originalSize: number
  /** Plays the cleaned version as soon as it is ready. */
  autoPlay?: boolean
}) {
  const name = useId()
  const prepared = state.kind === 'ready' ? state.prepared : null
  const length = prepared ? durationOf(prepared.pcm) : 0
  const cut = prepared ? (span ?? prepared.auto) : null
  const chosen: ClipUse = state.kind === 'failed' ? 'original' : use

  const choices: { id: ClipUse; label: string; detail: string }[] = [
    {
      id: 'cleaned',
      label: 'Cleaned',
      detail: cut ? `${formatSeconds(cut.end - cut.start)} · ${cleanedSize(cut.end - cut.start)}` : '',
    },
    {
      id: 'original',
      label: 'As recorded',
      detail: [prepared ? formatSeconds(length) : '', formatSize(originalSize)].filter(Boolean).join(' · '),
    },
  ]

  return (
    <div className="space-y-3">
      <fieldset className="flex flex-wrap items-center gap-2">
        <legend className="sr-only">What to upload</legend>
        <span aria-hidden="true" className="text-xs font-semibold text-stone">
          Upload
        </span>
        <div className="inline-flex rounded border border-line bg-inset p-0.5">
          {choices.map((c) => (
            <label
              key={c.id}
              className={cx(
                'cursor-pointer rounded px-3 py-1 text-[0.8125rem] font-semibold has-[:focus-visible]:outline-2 has-[:focus-visible]:outline-forest',
                chosen === c.id ? 'bg-surface text-coffee shadow-e1' : 'text-stone hover:text-coffee',
                state.kind === 'failed' && c.id === 'cleaned' && 'cursor-not-allowed opacity-45',
              )}
            >
              <input
                type="radio"
                name={name}
                value={c.id}
                checked={chosen === c.id}
                disabled={state.kind === 'failed' && c.id === 'cleaned'}
                onChange={() => onUse(c.id)}
                className="sr-only"
              />
              {c.label}
              {c.detail && <span className="tnum ml-1.5 font-normal text-stone">{c.detail}</span>}
            </label>
          ))}
        </div>
      </fieldset>

      {use === 'cleaned' && state.kind === 'working' && <p className="text-xs text-stone">Cleaning up…</p>}
      {state.kind === 'failed' && (
        <p className="flex items-start gap-1.5 text-xs text-stone">
          <Icon name="info" className="text-base" />
          This browser can’t read the clip to clean it, so it uploads as recorded.
        </p>
      )}
      {chosen === 'cleaned' && prepared && cut ? (
        <>
          <EffectButtons effects={effects} onEffects={onEffects} />
          <Trimmer
            prepared={prepared}
            cut={cut}
            moved={span !== null}
            onSpan={onSpan}
            effects={effects}
            autoPlay={autoPlay}
          />
        </>
      ) : (
        original
      )}
    </div>
  )
}

function Trimmer({
  prepared,
  cut,
  moved,
  onSpan,
  effects,
  autoPlay,
}: {
  prepared: Prepared
  cut: Span
  moved: boolean
  onSpan: (span: Span | null) => void
  effects: readonly Effect[]
  autoPlay: boolean
}) {
  // The waveform and the sound are of the clip with its effects.
  const pcm = useMemo(() => applyEffects(prepared.pcm, effects), [prepared.pcm, effects])
  const length = durationOf(pcm)
  const peaks = useMemo(() => peaksOf(pcm, BARS), [pcm])
  const [playing, setPlaying] = useState(autoPlay)
  const stop = useRef<(() => void) | null>(null)
  const dragging = useRef<'start' | 'end' | null>(null)
  const first = useRef({ pcm, cut, autoPlay })

  // A new effect is a new sound: the old one stops.
  const shown = useRef(pcm)
  useEffect(() => {
    if (shown.current !== pcm) stop.current?.()
    shown.current = pcm
  }, [pcm])

  // The take plays once on its own when asked; leaving stops the sound.
  useEffect(() => {
    const { pcm, cut, autoPlay } = first.current
    if (autoPlay) {
      stop.current = playPcm(cleanUp(pcm, cut), () => {
        stop.current = null
        setPlaying(false)
      })
    }
    return () => stop.current?.()
  }, [])

  const set = (next: Span) => {
    stop.current?.()
    onSpan(widen(next, length))
  }

  function toggle() {
    if (playing) {
      stop.current?.()
      return
    }
    setPlaying(true)
    stop.current = playPcm(cleanUp(pcm, cut), () => {
      stop.current = null
      setPlaying(false)
    })
  }

  const timeAt = (e: PointerEvent<SVGSVGElement>) => {
    const box = e.currentTarget.getBoundingClientRect()
    return Math.min(length, Math.max(0, ((e.clientX - box.left) / Math.max(1, box.width)) * length))
  }

  const x = (t: number) => (t / Math.max(length, 1e-6)) * WIDTH
  const bar = WIDTH / Math.max(1, peaks.length)

  return (
    <div className="space-y-2">
      <svg
        viewBox={`0 0 ${WIDTH} ${HEIGHT}`}
        preserveAspectRatio="none"
        role="img"
        aria-label={`Waveform: kept from ${formatSeconds(cut.start)} to ${formatSeconds(cut.end)} of ${formatSeconds(length)}`}
        className="h-16 w-full cursor-ew-resize touch-none rounded bg-inset text-forest select-none"
        onPointerDown={(e) => {
          const t = timeAt(e)
          dragging.current = Math.abs(t - cut.start) <= Math.abs(t - cut.end) ? 'start' : 'end'
          e.currentTarget.setPointerCapture(e.pointerId)
          set(dragging.current === 'start' ? { ...cut, start: Math.min(t, cut.end - MIN_SECONDS) } : { ...cut, end: Math.max(t, cut.start + MIN_SECONDS) })
        }}
        onPointerMove={(e) => {
          if (!dragging.current) return
          const t = timeAt(e)
          set(dragging.current === 'start' ? { ...cut, start: Math.min(t, cut.end - MIN_SECONDS) } : { ...cut, end: Math.max(t, cut.start + MIN_SECONDS) })
        }}
        onPointerUp={() => {
          dragging.current = null
        }}
      >
        {peaks.map((p, i) => {
          const h = Math.max(1, p * (HEIGHT - 6))
          return <rect key={i} x={i * bar + bar * 0.15} y={(HEIGHT - h) / 2} width={bar * 0.7} height={h} fill="currentColor" />
        })}
        <rect x={0} y={0} width={x(cut.start)} height={HEIGHT} className="fill-surface/75" />
        <rect x={x(cut.end)} y={0} width={WIDTH - x(cut.end)} height={HEIGHT} className="fill-surface/75" />
        {[cut.start, cut.end].map((t, i) => (
          <g key={i}>
            <rect x={x(t) - 1} y={0} width={2} height={HEIGHT} className="fill-coffee" />
            <rect x={x(t) - 4} y={HEIGHT / 2 - 8} width={8} height={16} rx={2} className="fill-coffee" />
          </g>
        ))}
      </svg>

      <div className="flex flex-wrap items-center gap-x-4 gap-y-2">
        <Button size="sm" variant={playing ? 'coffee' : 'primary'} onClick={toggle}>
          <Icon name={playing ? 'stop' : 'play_arrow'} filled className="text-lg" />
          {playing ? 'Stop' : 'Play cleaned'}
        </Button>
        <Edge label="Start" value={cut.start} max={length} onChange={(start) => set({ ...cut, start: Math.min(start, cut.end - MIN_SECONDS) })} />
        <Edge label="End" value={cut.end} max={length} onChange={(end) => set({ ...cut, end: Math.max(end, cut.start + MIN_SECONDS) })} />
        {moved && (
          <Button
            size="sm"
            variant="ghost"
            onClick={() => {
              stop.current?.()
              onSpan(null)
            }}
          >
            <Icon name="auto_fix_high" className="text-lg" />
            Find the speech again
          </Button>
        )}
      </div>
      <p className="tnum text-xs text-stone">
        Silence trimmed and the volume evened{effects.length > 0 && `, ${effectsInWords(effects)}`}: {formatSeconds(length)} →{' '}
        {formatSeconds(cut.end - cut.start)}. Drag the handles or use the sliders if a sound is cut short.
      </p>
    </div>
  )
}

function Edge({ label, value, max, onChange }: { label: string; value: number; max: number; onChange: (t: number) => void }) {
  return (
    <label className="flex items-center gap-2 text-xs font-semibold text-coffee">
      {label}
      <input
        type="range"
        min={0}
        max={max}
        step={0.01}
        value={value}
        aria-valuetext={formatSeconds(value)}
        onChange={(e) => onChange(Number(e.target.value))}
        className="w-28 accent-forest"
      />
      <span className="tnum w-12 font-normal text-stone">{formatSeconds(value)}</span>
    </label>
  )
}
