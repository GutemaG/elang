import { Input } from '../ui/Input'
import { cx } from '../ui/cx'
import { AddRowButton, FieldError, Hint, RowTools, Section } from './fields'
import {
  addChoice,
  markCorrect,
  missingAnswer,
  moveChoice,
  removeChoice,
  setChoiceText,
  type ChoiceBody,
} from './model'

/** The choices of a multiple-choice, listening or gap-fill exercise. The
 * correct one is marked with a radio button, so no id is ever typed. */
export function ChoicesEditor<B extends ChoiceBody>({
  body,
  onChange,
}: {
  body: B
  onChange: (next: B) => void
}) {
  const { choices } = body.content
  const correct = body.answer_key.correct_choice_id
  const missing = missingAnswer(body)

  return (
    <Section title="Choices" hint="Type each choice, then mark the one that is correct.">
      <div role="radiogroup" aria-label="Correct choice" className="space-y-2">
        {choices.map((choice, i) => {
          const isCorrect = choice.id === correct
          return (
            <div key={choice.id}>
              <div
                className={cx(
                  'flex items-center gap-2 rounded-md border px-2 py-1.5 transition-colors',
                  isCorrect ? 'border-forest-line bg-forest-tint' : 'border-line bg-canvas',
                )}
              >
                <label className="flex shrink-0 cursor-pointer items-center gap-2 pl-1">
                  <input
                    type="radio"
                    name="correct-choice"
                    className="size-4 accent-forest"
                    checked={isCorrect}
                    aria-label={`Choice ${i + 1} is correct`}
                    onChange={() => onChange(markCorrect(body, choice.id))}
                  />
                  <span className="tnum w-4 text-xs font-bold text-stone">{i + 1}</span>
                </label>
                <Input
                  aria-label={`Choice ${i + 1}`}
                  placeholder={`Choice ${i + 1}`}
                  value={choice.text}
                  className="flex-1"
                  onChange={(e) => onChange(setChoiceText(body, i, e.target.value))}
                />
                {isCorrect && (
                  <span className="hidden shrink-0 text-xs font-bold tracking-wide text-forest uppercase sm:inline">
                    Correct
                  </span>
                )}
                <RowTools
                  what={`choice ${i + 1}`}
                  index={i}
                  count={choices.length}
                  onMove={(by) => onChange(moveChoice(body, i, by))}
                  onRemove={() => onChange(removeChoice(body, i))}
                />
              </div>
              <FieldError slot={`choice:${i}`} className="pl-9" />
            </div>
          )
        })}
      </div>
      <FieldError slot="choices" />
      {missing && <Hint>{missing}</Hint>}
      <AddRowButton label="Add choice" onClick={() => onChange(addChoice(body))} />
    </Section>
  )
}
