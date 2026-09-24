import type { ExerciseBody, Tile } from '../types'
import { cx } from '../ui/cx'
import { Icon } from '../ui/Icon'
import { TYPE_INFO, pairRows, playableUrl, tilesOf } from './model'

// Pair colours: each correct match shares one, on both sides.
const PAIR_TONES = [
  'border-forest-line bg-forest-tint text-forest',
  'border-terracotta-line bg-terracotta-tint text-terracotta',
  'border-sky-200 bg-sky-50 text-sky-800',
  'border-violet-200 bg-violet-50 text-violet-800',
  'border-amber-200 bg-amber-50 text-amber-800',
  'border-rose-200 bg-rose-50 text-rose-800',
]

const shown = (text: string) => text || '…'

/** Roughly what the learner sees, with the correct answer shown. An
 * approximation of the app's screens, not a copy (story 005). Renders
 * whatever it is given, finished or not, so it can follow the form live. */
export function ExercisePreview({ body }: { body: ExerciseBody }) {
  const info = TYPE_INFO[body.type]
  return (
    <section role="region" aria-label="Learner preview" className="mx-auto w-full max-w-[22rem]">
      <p className="mb-2 flex items-center gap-1.5 text-xs font-bold tracking-[0.08em] text-stone uppercase">
        <Icon name="smartphone" className="text-base" />
        Learner preview
      </p>
      <div className="overflow-hidden rounded-[1.75rem] border-[6px] border-coffee bg-canvas shadow-e3">
        <div className="flex items-center gap-2 px-4 pt-4">
          <Icon name="close" className="text-lg text-stone" />
          <div className="h-2.5 flex-1 overflow-hidden rounded-full bg-inset">
            <div className="h-full w-2/5 rounded-full bg-forest" />
          </div>
        </div>
        <div className="space-y-4 px-4 pt-5 pb-6">
          <p className="flex items-center gap-1.5 text-xs font-semibold text-stone">
            <Icon name={info.icon} className="text-sm" />
            {info.name}
          </p>
          <p className="text-lg leading-7 font-bold break-words text-coffee">{shown(body.prompt)}</p>
          <Body body={body} />
        </div>
      </div>
    </section>
  )
}

function Body({ body }: { body: ExerciseBody }) {
  switch (body.type) {
    case 'multiple_choice':
      return <Choices choices={body.content.choices} correct={body.answer_key.correct_choice_id} />
    case 'listening':
      return (
        <>
          {body.content.audio_url.trim() ? (
            <div className="flex items-center gap-3 rounded-lg bg-inset p-3">
              <span className="grid size-11 shrink-0 place-items-center rounded-full bg-forest text-white">
                <Icon name="volume_up" className="text-2xl" filled />
              </span>
              <audio
                controls
                preload="none"
                src={playableUrl(body.content.audio_url.trim())}
                aria-label="Clip the learner hears"
                className="h-9 min-w-0 flex-1"
              />
            </div>
          ) : (
            <p className="rounded-lg bg-terracotta-tint p-3 text-sm text-terracotta">No audio yet.</p>
          )}
          <Choices choices={body.content.choices} correct={body.answer_key.correct_choice_id} />
        </>
      )
    case 'gap_fill': {
      const answer = body.content.choices.find((c) => c.id === body.answer_key.correct_choice_id)
      return (
        <>
          <p className="rounded-lg bg-surface p-3 text-base leading-8 text-coffee shadow-e1">
            {body.content.sentence_before && <span>{body.content.sentence_before} </span>}
            <span className="rounded border-b-2 border-forest bg-forest-tint px-2 py-0.5 font-bold text-forest">
              {answer ? shown(answer.text) : '____'}
            </span>
            {body.content.sentence_after && <span> {body.content.sentence_after}</span>}
          </p>
          <Choices choices={body.content.choices} correct={body.answer_key.correct_choice_id} inline />
        </>
      )
    }
    case 'sentence_construction':
    case 'spell_tiles': {
      const tiles = tilesOf(body)
      const byId = new Map(tiles.map((t) => [t.id, t]))
      const sequence = body.answer_key.correct_sequence
      return (
        <>
          <ol
            aria-label="Correct order"
            className="flex min-h-14 flex-wrap items-center gap-1.5 border-b-2 border-line pb-2"
          >
            {sequence.map((id) => (
              <li
                key={id}
                className="rounded-md border border-forest-line bg-forest-tint px-3 py-1.5 text-base font-bold text-forest"
              >
                {shown(byId.get(id)?.text ?? '')}
              </li>
            ))}
            {sequence.length === 0 && <li className="text-sm text-stone">No answer yet.</li>}
          </ol>
          <ul aria-label="Tiles" className="flex flex-wrap justify-center gap-1.5">
            {tiles.map((t) => {
              const used = sequence.includes(t.id)
              return (
                <li
                  key={t.id}
                  title={used ? undefined : 'Not in the answer'}
                  className={cx(
                    'rounded-md border px-3 py-1.5 text-base font-semibold shadow-e1',
                    used ? 'border-line bg-surface text-coffee' : 'border-dashed border-line-strong bg-inset text-stone',
                  )}
                >
                  {shown(t.text)}
                  {!used && <span className="sr-only"> (distractor)</span>}
                </li>
              )
            })}
          </ul>
        </>
      )
    }
    case 'match_pairs': {
      const tone = new Map<string, number>()
      pairRows(body).forEach((row, i) => {
        if (row.left) tone.set(row.left.id, i)
        if (row.right) tone.set(row.right.id, i)
      })
      const column = (tiles: Tile[], label: string) => (
        <ul aria-label={label} className="space-y-1.5">
          {tiles.map((t) => {
            const i = tone.get(t.id)
            return (
              <li
                key={t.id}
                className={cx(
                  'flex items-center justify-between gap-2 rounded-md border px-2.5 py-2 text-sm font-semibold',
                  i === undefined ? 'border-line bg-surface text-coffee' : PAIR_TONES[i % PAIR_TONES.length],
                )}
              >
                <span className="min-w-0 break-words">{shown(t.text)}</span>
                {i !== undefined && <span className="tnum text-[0.625rem] font-bold opacity-70">{i + 1}</span>}
              </li>
            )
          })}
        </ul>
      )
      return (
        <div className="grid grid-cols-2 gap-2">
          {column(body.content.left_tiles, 'Left column')}
          {column(body.content.right_tiles, 'Right column')}
        </div>
      )
    }
  }
}

function Choices({ choices, correct, inline }: { choices: Tile[]; correct: string; inline?: boolean }) {
  return (
    <ul aria-label="Choices" className={inline ? 'flex flex-wrap gap-2' : 'space-y-2'}>
      {choices.map((c) => {
        const isCorrect = c.id === correct
        return (
          <li
            key={c.id}
            className={cx(
              'flex items-center gap-2 rounded-lg border-2 px-3 py-2.5 text-base font-semibold',
              isCorrect ? 'border-forest bg-forest-tint text-forest' : 'border-line bg-surface text-coffee',
            )}
          >
            <span className="min-w-0 flex-1 break-words">{shown(c.text)}</span>
            {isCorrect && (
              <>
                <Icon name="check_circle" className="text-lg" filled />
                <span className="sr-only">(correct)</span>
              </>
            )}
          </li>
        )
      })}
    </ul>
  )
}
