import { Button } from '../ui/Button'
import { Input } from '../ui/Input'
import { cx } from '../ui/cx'
import { Icon } from '../ui/Icon'
import { AddRowButton, FieldError, Hint, RowTools, Section } from './fields'
import {
  addTile,
  appendToAnswer,
  missingAnswer,
  moveInAnswer,
  removeFromAnswer,
  removeTile,
  setTileText,
  tilesOf,
  type SequenceBody,
} from './model'

/** The tiles of a sentence or spelling exercise, and the correct answer
 * built from them by clicking, in order. Tiles are told apart by id, never
 * by text: "ላ" twice is two tiles, and each can be placed. */
export function SequenceEditor<B extends SequenceBody>({
  body,
  onChange,
}: {
  body: B
  onChange: (next: B) => void
}) {
  const tiles = tilesOf(body)
  const sequence = body.answer_key.correct_sequence
  const byId = new Map(tiles.map((t, i) => [t.id, { tile: t, index: i }]))
  const unit = body.type === 'sentence_construction' ? 'Word' : 'Letter'
  const missing = missingAnswer(body)

  return (
    <>
      <Section
        title={body.type === 'sentence_construction' ? 'Word bank' : 'Letter tiles'}
        hint={
          body.type === 'sentence_construction'
            ? 'Every word the learner can pick from. Words left out of the answer act as distractors.'
            : 'Every letter the learner can pick from. The same letter twice is two tiles.'
        }
      >
        <ol className="space-y-2">
          {tiles.map((tile, i) => {
            const used = sequence.includes(tile.id)
            return (
              <li key={tile.id}>
                <div className="flex items-center gap-2 rounded-md border border-line bg-canvas px-2 py-1.5">
                  <span className="tnum w-5 shrink-0 pl-1 text-xs font-bold text-stone">{i + 1}</span>
                  <Input
                    aria-label={`${unit} ${i + 1}`}
                    placeholder={`${unit} ${i + 1}`}
                    value={tile.text}
                    className="flex-1"
                    onChange={(e) => onChange(setTileText(body, i, e.target.value))}
                  />
                  <span
                    className={cx(
                      'hidden shrink-0 rounded-full px-2 py-0.5 text-[0.6875rem] font-bold sm:inline',
                      used ? 'bg-forest-tint text-forest' : 'bg-inset text-stone',
                    )}
                  >
                    {used ? 'In answer' : 'Distractor'}
                  </span>
                  <RowTools
                    what={`${unit.toLowerCase()} ${i + 1}`}
                    index={i}
                    count={tiles.length}
                    onRemove={() => onChange(removeTile(body, i))}
                  />
                </div>
                <FieldError slot={`tile:${i}`} className="pl-8" />
              </li>
            )
          })}
        </ol>
        <FieldError slot="tiles" />
        <AddRowButton label={`Add ${unit.toLowerCase()}`} onClick={() => onChange(addTile(body))} />
      </Section>

      <Section title="Correct answer" hint="Click tiles in the order the learner must place them.">
        <ol
          aria-label="Correct answer"
          className="flex min-h-14 flex-wrap items-center gap-2 rounded-md border-2 border-dashed border-forest/30 bg-forest-tint/40 p-2"
        >
          {sequence.length === 0 && <li className="px-1 text-sm text-stone">No tiles placed yet.</li>}
          {sequence.map((id, position) => {
            const text = byId.get(id)?.tile.text || '(empty)'
            return (
              <li
                key={id}
                className="flex items-center gap-0.5 rounded border border-forest-line bg-surface py-0.5 pr-0.5 pl-2.5 shadow-e1"
              >
                <span className="tnum mr-1 text-[0.625rem] font-bold text-stone">{position + 1}</span>
                <span className="text-base font-semibold text-coffee">{text}</span>
                <Button
                  size="icon"
                  variant="ghost"
                  aria-label={`Move answer ${position + 1} earlier`}
                  title="Earlier"
                  disabled={position === 0}
                  onClick={() => onChange(moveInAnswer(body, position, -1))}
                >
                  <Icon name="chevron_left" className="text-lg" />
                </Button>
                <Button
                  size="icon"
                  variant="ghost"
                  aria-label={`Move answer ${position + 1} later`}
                  title="Later"
                  disabled={position === sequence.length - 1}
                  onClick={() => onChange(moveInAnswer(body, position, 1))}
                >
                  <Icon name="chevron_right" className="text-lg" />
                </Button>
                <Button
                  size="icon"
                  variant="danger-ghost"
                  aria-label={`Remove answer ${position + 1}`}
                  title="Take out of the answer"
                  onClick={() => onChange(removeFromAnswer(body, position))}
                >
                  <Icon name="close" className="text-lg" />
                </Button>
              </li>
            )
          })}
        </ol>
        <FieldError slot="answer" />
        {missing && <Hint>{missing}</Hint>}

        <p className="mt-4 mb-2 text-xs font-bold tracking-[0.06em] text-stone uppercase">Tiles to place</p>
        <div className="flex flex-wrap gap-2">
          {tiles.map((tile, i) =>
            sequence.includes(tile.id) ? null : (
              <button
                key={tile.id}
                type="button"
                aria-label={`Add ${unit.toLowerCase()} ${i + 1} to the answer`}
                onClick={() => onChange(appendToAnswer(body, tile.id))}
                className="inline-flex h-11 items-center gap-1.5 rounded border border-line bg-surface px-3 text-base font-semibold text-coffee shadow-e1 transition-colors hover:border-forest hover:bg-forest-tint sm:h-9"
              >
                <Icon name="add" className="text-sm text-forest" />
                {tile.text || <span className="text-sm font-normal text-stone">(empty)</span>}
              </button>
            ),
          )}
          {tiles.every((t) => sequence.includes(t.id)) && (
            <p className="text-sm text-stone">Every tile is in the answer.</p>
          )}
        </div>
      </Section>
    </>
  )
}
