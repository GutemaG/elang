import { useEffect, useRef, useState, type DragEvent } from 'react'
import { Link, useParams } from 'react-router-dom'

import { durationOf, formatSeconds, type Pcm, type Span } from '../audio/clean'
import { ClipEditor, EffectButtons, cleanedSize, effectsInWords, type ClipUse, type PrepareState } from '../audio/ClipEditor'
import { cleanedPcm, finalClip, playPcm, prepareClip, type Prepared } from '../audio/codec'
import type { Effect } from '../audio/effects'
import { checkClip, MAX_AUDIO_BYTES, formatSize } from '../audio/formats'
import { messageOf, useSession } from '../auth/SessionContext'
import { plainMessage, playableUrl } from '../exercises/model'
import { plural } from '../format'
import type { AdminSoundChart, AdminSoundLetter, SoundLetterChange } from '../types'
import { Button } from '../ui/Button'
import { cx } from '../ui/cx'
import { Icon } from '../ui/Icon'
import { Modal } from '../ui/Modal'
import { LetterPicker } from './LetterPicker'
import { englishOf, matchFiles, uploadSound } from './model'
import { useSoundChart } from './useSoundChart'

interface Row {
  /** Stays with the file as rows above it are removed. */
  id: number
  file: File
  letterId: string
  ambiguous: boolean
  /** Why the file can't be stored, before anything is sent. */
  problem: string | null
  state: 'waiting' | 'uploading' | 'done' | 'failed'
  error?: string
  /** The file read for cleaning; null when this browser can't read it. */
  prep: Prepared | null | 'working'
  /** This file's own choice, over the page's "clean up every file". */
  use: ClipUse | null
  /** Where the admin moved this file's cut to; null for where it was found. */
  span: Span | null
  /** This file's own effects, over the page's. */
  effects: Effect[] | null
}

const prepState = (prep: Row['prep']): PrepareState =>
  prep === 'working' ? { kind: 'working' } : prep ? { kind: 'ready', prepared: prep } : { kind: 'failed' }

/** The stretch of a row's file that is kept: cleaned only when it could be
 * read, otherwise null and the file goes as it is. */
function cutOf(row: Row, cleanAll: boolean): Span | null {
  const use = row.use ?? (cleanAll ? 'cleaned' : 'original')
  if (use !== 'cleaned' || !row.prep || row.prep === 'working') return null
  return row.span ?? row.prep.auto
}

/** Many recordings at once: each file is matched to a letter by its name,
 * checked by the admin, then uploaded and saved together. */
export function UploadFilesPage() {
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
      <h1 className="text-[1.75rem] leading-9 font-bold text-coffee">Upload files</h1>
      <p className="mt-1 max-w-2xl text-sm text-stone">
        Drop a folder’s worth of recordings. Name each file by its romanization (hu.mp3) or by the letter itself
        (ሁ.mp3), and the page finds its letter.
      </p>
      {error && (
        <p role="alert" className="mt-4 text-sm text-danger">
          {error}
        </p>
      )}
      {!chart && !error && <p className="mt-6 text-sm text-stone">Loading…</p>}
      {chart && <Uploader chart={chart} saveLetters={saveLetters} />}
    </main>
  )
}

function Uploader({
  chart,
  saveLetters,
}: {
  chart: AdminSoundChart
  saveLetters: (changes: SoundLetterChange[]) => Promise<AdminSoundChart>
}) {
  const { api } = useSession()
  const [rows, setRows] = useState<Row[]>([])
  const [over, setOver] = useState(false)
  const [busy, setBusy] = useState(false)
  const [result, setResult] = useState<string | null>(null)
  const [problem, setProblem] = useState<string | null>(null)
  const [cleanAll, setCleanAll] = useState(true)
  const [pageEffects, setPageEffects] = useState<Effect[]>([])
  const effectsOf = (row: Row) => row.effects ?? pageEffects
  const [trimming, setTrimming] = useState<number | null>(null)
  const nextId = useRef(0)
  const player = useListener()
  const recordable = chart.letters.filter((x) => !x.same_as_id)
  const byId = new Map(chart.letters.map((x) => [x.id, x]))

  function add(files: File[]) {
    setResult(null)
    setProblem(null)
    const matches = matchFiles(files, chart.letters)
    const added: Row[] = matches.map((m) => {
      const check = checkClip(m.file)
      return {
        id: nextId.current++,
        file: m.file,
        letterId: m.letter?.id ?? '',
        ambiguous: m.ambiguous,
        problem: check.ok ? null : check.problem,
        state: 'waiting' as const,
        prep: check.ok ? ('working' as const) : null,
        use: null,
        span: null,
        effects: null,
      }
    })
    setRows((old) => [...old, ...added])
    // Each file is read for cleaning in the background.
    for (const row of added) {
      if (row.prep !== 'working') continue
      void prepareClip(row.file).then((prep) => edit(row.id, { prep }))
    }
  }

  const edit = (id: number, change: Partial<Row>) => setRows((rs) => rs.map((r) => (r.id === id ? { ...r, ...change } : r)))

  function onDrop(e: DragEvent) {
    e.preventDefault()
    setOver(false)
    add([...e.dataTransfer.files])
  }

  const ready = rows.filter((r) => r.state !== 'done' && r.letterId && !r.problem)
  const chosen = new Map<string, number>()
  for (const r of ready) chosen.set(r.letterId, (chosen.get(r.letterId) ?? 0) + 1)
  const twice = new Set([...chosen].filter(([, n]) => n > 1).map(([id]) => id))
  const replacing = ready.filter((r) => byId.get(r.letterId)?.audio_url).length
  const reading = ready.some((r) => r.prep === 'working' && (r.use ?? (cleanAll ? 'cleaned' : 'original')) === 'cleaned')
  const trimmed = rows.find((r) => r.id === trimming)

  async function upload() {
    if (busy || ready.length === 0 || twice.size > 0 || reading) return
    if (player.playing) player.stop()
    setBusy(true)
    setProblem(null)
    const changes: SoundLetterChange[] = []
    const next = [...rows]
    for (let i = 0; i < next.length; i++) {
      const row = next[i]!
      if (row.state === 'done' || !row.letterId || row.problem) continue
      next[i] = { ...row, state: 'uploading' }
      setRows([...next])
      try {
        const type = checkClip(row.file)
        const prep = row.prep === 'working' ? null : row.prep
        const final = await finalClip({ clip: row.file, type: type.ok ? type.type : row.file.type }, prep, {
          use: row.use ?? (cleanAll ? 'cleaned' : 'original'),
          span: row.span,
          effects: effectsOf(row),
        })
        if (final.clip.size > MAX_AUDIO_BYTES) throw new Error(`The file is ${formatSize(final.clip.size)}; 5 MB at most.`)
        const url = await uploadSound(api, chart.language, final.clip, final.type)
        changes.push({ id: row.letterId, audio_url: url, status: 'needs_review' })
        next[i] = { ...row, state: 'done' }
      } catch (e) {
        next[i] = { ...row, state: 'failed', error: plainMessage(messageOf(e)) }
      }
      setRows([...next])
    }
    try {
      if (changes.length) await saveLetters(changes)
      setResult(`${plural(changes.length, 'recording')} saved and marked Needs review.`)
    } catch (e) {
      setProblem(messageOf(e))
    } finally {
      setBusy(false)
    }
  }

  return (
    <div className="mt-6 space-y-4">
      <label
        onDragOver={(e) => {
          e.preventDefault()
          setOver(true)
        }}
        onDragLeave={() => setOver(false)}
        onDrop={onDrop}
        className={cx(
          'flex cursor-pointer items-center gap-4 rounded-lg border-2 border-dashed bg-surface p-5',
          over ? 'border-forest bg-forest-tint' : 'border-line-strong',
        )}
      >
        <Icon name="upload" className="text-3xl text-forest" />
        <span>
          <span className="block text-sm font-semibold text-coffee">Drop files here, or choose them</span>
          <span className="block text-xs text-stone">m4a, mp3, webm or ogg, up to 5 MB each.</span>
        </span>
        <input
          type="file"
          multiple
          aria-label="Recordings"
          accept="audio/*,.m4a,.mp3,.webm,.ogg"
          className="sr-only"
          onChange={(e) => {
            add([...(e.target.files ?? [])])
            e.target.value = ''
          }}
        />
      </label>

      {player.element}
      {player.problem && (
        <p role="alert" className="text-sm text-danger">
          {player.problem}
        </p>
      )}

      {rows.length > 0 && (
        <label className="flex items-start gap-3 rounded-lg border border-line bg-surface px-4 py-3">
          <input
            type="checkbox"
            checked={cleanAll}
            disabled={busy}
            onChange={(e) => setCleanAll(e.target.checked)}
            className="mt-0.5 size-4 accent-forest"
          />
          <span>
            <span className="block text-sm font-semibold text-coffee">Clean up every file</span>
            <span className="block text-xs text-stone">
              Trims the silence around each sound and evens the volume, then uploads it as a small mp3. Turn it off to
              upload the files exactly as they are. A file’s scissors move its cut, change its effects, or keep that
              one as recorded.
            </span>
          </span>
        </label>
      )}
      {rows.length > 0 && cleanAll && (
        <div className="-mt-2 rounded-b-lg px-4">
          <EffectButtons
            effects={pageEffects}
            disabled={busy}
            label="Every file"
            onEffects={(effects) => {
              player.stop()
              setPageEffects(effects)
            }}
          />
        </div>
      )}

      {rows.length > 0 && (
        <div className="overflow-x-auto rounded-lg border border-line bg-surface">
          <table className="w-full min-w-[34rem] text-sm">
            <thead>
              <tr className="border-b border-line text-left text-xs tracking-[0.06em] text-stone uppercase">
                <th className="px-4 py-2">File</th>
                <th className="px-4 py-2">Letter</th>
                <th className="px-4 py-2">What happens</th>
                <th className="px-2 py-2">
                  <span className="sr-only">Remove</span>
                </th>
              </tr>
            </thead>
            <tbody>
              {rows.map((row, i) => (
                <FileRow
                  key={row.id}
                  row={row}
                  letters={recordable}
                  letter={byId.get(row.letterId)}
                  twice={twice.has(row.letterId)}
                  disabled={busy || row.state === 'done'}
                  onPick={(letterId) => setRows((rs) => rs.map((r, j) => (j === i ? { ...r, letterId, ambiguous: false } : r)))}
                  onRemove={() => {
                    player.forget(row.id, row.file)
                    setRows((rs) => rs.filter((_, j) => j !== i))
                  }}
                  playing={player.playing}
                  onPlayFile={() => {
                    const cut = cutOf(row, cleanAll)
                    if (cut && row.prep && row.prep !== 'working')
                      player.togglePcm(`file-${row.id}`, cleanedPcm(row.prep, { span: cut, effects: effectsOf(row) }))
                    else player.toggleFile(row.id, row.file)
                  }}
                  onPlayCurrent={player.toggleUrl}
                  cut={cutOf(row, cleanAll)}
                  effects={effectsOf(row)}
                  onTrim={() => {
                    player.stop()
                    setTrimming(row.id)
                  }}
                />
              ))}
            </tbody>
          </table>
        </div>
      )}

      {rows.length > 0 && (
        <div className="flex flex-wrap items-center gap-3">
          <p className="flex-1 text-sm text-stone" aria-live="polite">
            {result ??
              (twice.size > 0
                ? 'Two files are going to the same letter. Pick another letter for one of them.'
                : `${plural(ready.length, 'file')} will upload${replacing ? `, ${replacing} replacing a recording` : ''}.`)}
          </p>
          {problem && (
            <p role="alert" className="text-sm text-danger">
              {problem}
            </p>
          )}
          <Button
            disabled={busy}
            onClick={() => {
              player.forgetAll()
              setRows([])
            }}
          >
            Clear
          </Button>
          <Button
            variant="primary"
            disabled={busy || ready.length === 0 || twice.size > 0 || reading}
            onClick={() => void upload()}
          >
            <Icon name="cloud_upload" className="text-lg" />
            {busy ? 'Uploading…' : reading ? 'Reading files…' : `Upload ${plural(ready.length, 'file')}`}
          </Button>
        </div>
      )}

      {trimmed && (
        <Modal title={`Clean up ${trimmed.file.name}`} onClose={() => setTrimming(null)} className="sm:max-w-xl">
          <div className="mt-4">
            <ClipEditor
              state={prepState(trimmed.prep)}
              use={trimmed.use ?? (cleanAll ? 'cleaned' : 'original')}
              onUse={(use) => edit(trimmed.id, { use })}
              span={trimmed.span}
              onSpan={(span) => edit(trimmed.id, { span })}
              effects={effectsOf(trimmed)}
              onEffects={(effects) => edit(trimmed.id, { effects })}
              originalSize={trimmed.file.size}
              original={
                <div className="flex items-center gap-2 text-sm text-coffee-soft">
                  <PlayButton
                    playing={player.playing === `file-${trimmed.id}`}
                    label={trimmed.file.name}
                    onClick={() => player.toggleFile(trimmed.id, trimmed.file)}
                  />
                  The file as recorded{trimmed.prep && trimmed.prep !== 'working' ? `, ${formatSeconds(durationOf(trimmed.prep.pcm))}` : ''}.
                </div>
              }
            />
          </div>
          <div className="mt-6 flex justify-end">
            <Button
              variant="primary"
              onClick={() => {
                player.stop()
                setTrimming(null)
              }}
            >
              Done
            </Button>
          </div>
        </Modal>
      )}
    </div>
  )
}

function FileRow({
  row,
  letters,
  letter,
  twice,
  disabled,
  onPick,
  onRemove,
  playing,
  onPlayFile,
  onPlayCurrent,
  cut,
  effects,
  onTrim,
}: {
  row: Row
  letters: AdminSoundLetter[]
  letter: AdminSoundLetter | undefined
  twice: boolean
  disabled: boolean
  onPick: (letterId: string) => void
  onRemove: () => void
  /** What the page is playing: `file-{row id}`, or a recording's address. */
  playing: string | null
  onPlayFile: () => void
  onPlayCurrent: (url: string) => void
  /** The stretch kept when the row is cleaned, or null when it goes as it is. */
  cut: Span | null
  effects: readonly Effect[]
  onTrim: () => void
}) {
  let what: { text: string; tone: string }
  if (row.state === 'done') what = { text: 'Uploaded', tone: 'bg-forest-tint text-forest' }
  else if (row.state === 'uploading') what = { text: 'Uploading…', tone: 'bg-inset text-coffee-soft' }
  else if (row.state === 'failed') what = { text: row.error ?? 'Failed', tone: 'bg-danger-tint text-danger' }
  else if (row.problem) what = { text: row.problem, tone: 'bg-danger-tint text-danger' }
  else if (!letter) what = { text: row.ambiguous ? 'Several letters fit; pick one' : 'No match; pick a letter', tone: 'bg-terracotta-tint text-terracotta' }
  else if (twice) what = { text: 'Same letter as another file', tone: 'bg-danger-tint text-danger' }
  else if (letter.audio_url) what = { text: 'Replaces a recording', tone: 'bg-sky-50 text-sky-700' }
  else what = { text: 'Will upload', tone: 'bg-forest-tint text-forest' }

  return (
    <tr className="border-b border-line last:border-0">
      <td className="px-2 py-2">
        <div className="flex max-w-[16rem] items-center gap-1">
          <PlayButton
            playing={playing === `file-${row.id}`}
            label={row.file.name}
            disabled={!!row.problem}
            onClick={onPlayFile}
          />
          <span className="min-w-0">
            <span className="block truncate font-mono text-xs" title={row.file.name}>
              {row.file.name}
            </span>
            <span className="tnum block text-[0.6875rem] text-stone">
              {row.prep === 'working'
                ? 'Reading…'
                : row.prep && cut
                  ? `Cleaned: ${formatSeconds(durationOf(row.prep.pcm))} → ${formatSeconds(cut.end - cut.start)} · ${formatSize(row.file.size)} → ${cleanedSize(cut.end - cut.start)}${effects.length ? `, ${effectsInWords(effects)}` : ''}`
                  : row.prep
                    ? `As recorded: ${formatSeconds(durationOf(row.prep.pcm))} · ${formatSize(row.file.size)}`
                    : formatSize(row.file.size)}
            </span>
          </span>
          {row.prep && row.prep !== 'working' && (
            <Button
              size="icon"
              variant="ghost"
              aria-label={`Clean up ${row.file.name}`}
              title="Move the cut, or keep this file as recorded"
              disabled={disabled}
              onClick={onTrim}
            >
              <Icon name="content_cut" className="text-lg text-coffee-soft" />
            </Button>
          )}
        </div>
      </td>
      <td className="px-4 py-2">
        <LetterPicker
          label={`Letter for ${row.file.name}`}
          letters={letters}
          value={row.letterId}
          disabled={disabled}
          onPick={onPick}
        />
      </td>
      <td className="px-4 py-2">
        <div className="flex items-center gap-1">
          <span className={cx('rounded-full px-2.5 py-0.5 text-xs font-bold', what.tone)}>{what.text}</span>
          {letter?.audio_url && row.state !== 'done' && (
            <PlayButton
              playing={playing === letter.audio_url}
              label={`${letter.glyph}’s current recording`}
              onClick={() => onPlayCurrent(letter.audio_url!)}
            />
          )}
        </div>
      </td>
      <td className="px-2 py-2">
        <Button size="icon" variant="ghost" aria-label={`Remove ${row.file.name}`} disabled={disabled} onClick={onRemove}>
          <Icon name="close" className="text-lg" />
        </Button>
      </td>
    </tr>
  )
}

function PlayButton({
  playing,
  label,
  disabled,
  onClick,
}: {
  playing: boolean
  label: string
  disabled?: boolean
  onClick: () => void
}) {
  return (
    <Button
      size="icon"
      variant="ghost"
      aria-label={`${playing ? 'Stop' : 'Play'} ${label}`}
      aria-pressed={playing}
      title={playing ? 'Stop' : `Play ${label}`}
      disabled={disabled}
      onClick={onClick}
    >
      <Icon name={playing ? 'stop' : 'play_arrow'} filled className="text-lg text-forest" />
    </Button>
  )
}

/** One hidden audio element for the whole table, so starting one sound stops
 * the last. A file plays from this computer: nothing is sent to hear it. */
function useListener() {
  const ref = useRef<HTMLAudioElement>(null)
  const urls = useRef(new Map<File, string>())
  const pcmStop = useRef<(() => void) | null>(null)
  const [playing, setPlaying] = useState<string | null>(null)
  const [problem, setProblem] = useState<string | null>(null)

  useEffect(() => {
    const made = urls.current
    const sound = pcmStop
    return () => {
      sound.current?.()
      for (const url of made.values()) URL.revokeObjectURL(url)
    }
  }, [])

  function urlOf(file: File) {
    let url = urls.current.get(file)
    if (!url) {
      url = URL.createObjectURL(file)
      urls.current.set(file, url)
    }
    return url
  }

  function stop() {
    ref.current?.pause()
    pcmStop.current?.()
    setPlaying(null)
  }

  /** A cleaned version, played from its samples. */
  function togglePcm(key: string, pcm: Pcm) {
    setProblem(null)
    if (playing === key) return stop()
    ref.current?.pause()
    pcmStop.current = playPcm(pcm, () => {
      pcmStop.current = null
      setPlaying((now) => (now === key ? null : now))
    })
    setPlaying(key)
  }

  function toggle(key: string, src: string) {
    const audio = ref.current
    if (!audio) return
    setProblem(null)
    if (playing === key) return stop()
    pcmStop.current?.()
    audio.src = src
    audio.currentTime = 0
    setPlaying(key)
    void Promise.resolve(audio.play()).catch(cannotPlay)
  }

  /** The audio element's error event: only a sound being played matters, not
   * the empty element at rest. */
  function failed() {
    if (playing) cannotPlay()
  }

  function cannotPlay() {
    setPlaying(null)
    setProblem('This browser can’t play that recording. Check it opens in a music player, or export it again as mp3 or m4a.')
  }

  function forget(id: number, file: File) {
    if (playing === `file-${id}`) stop()
    const url = urls.current.get(file)
    if (!url) return
    URL.revokeObjectURL(url)
    urls.current.delete(file)
  }

  return {
    element: <audio ref={ref} onEnded={stop} onError={failed} className="hidden" />,
    playing,
    problem,
    stop,
    togglePcm,
    toggleFile: (id: number, file: File) => toggle(`file-${id}`, urlOf(file)),
    toggleUrl: (url: string) => toggle(url, playableUrl(url)),
    forget,
    forgetAll: () => {
      stop()
      for (const url of urls.current.values()) URL.revokeObjectURL(url)
      urls.current.clear()
    },
  }
}
