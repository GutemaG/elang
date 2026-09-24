import type { ExerciseBody } from '../types'
import { cx } from '../ui/cx'
import { FIELD_CLASS, Input } from '../ui/Input'
import { ChoicesEditor } from './ChoicesEditor'
import { FieldError, Section } from './fields'
import { PairsEditor } from './PairsEditor'
import { SequenceEditor } from './SequenceEditor'
import { playableUrl, setAudioUrl, setPrompt, setSentence } from './model'

/** The whole form for one exercise: the prompt, then whatever its type
 * needs. One branch per type, so each type's shape is checked by
 * TypeScript against the backend's. */
export function ExerciseForm({ body, onChange }: { body: ExerciseBody; onChange: (next: ExerciseBody) => void }) {
  return (
    <div className="space-y-4">
      <Section title="Prompt" hint="The instruction or question the learner reads first.">
        <textarea
          aria-label="Prompt"
          rows={2}
          value={body.prompt}
          placeholder="e.g. How do you say ‘Hello’ in Amharic?"
          onChange={(e) => onChange(setPrompt(body, e.target.value))}
          className={cx(FIELD_CLASS, 'h-auto min-h-20 resize-y py-2 leading-6')}
        />
        <FieldError slot="prompt" />
      </Section>

      {body.type === 'listening' && (
        <Section
          title="Audio"
          hint="A full https:// address, or a /media/… path from a local upload. Recording and uploading here come next."
        >
          <Input
            aria-label="Audio address"
            placeholder="https://… or /media/audio/…"
            value={body.content.audio_url}
            onChange={(e) => onChange(setAudioUrl(body, e.target.value))}
          />
          <FieldError slot="audio_url" />
          {body.content.audio_url.trim() && (
            <audio
              controls
              preload="none"
              src={playableUrl(body.content.audio_url.trim())}
              aria-label="Play the clip"
              className="mt-3 w-full"
            />
          )}
        </Section>
      )}

      {body.type === 'gap_fill' && (
        <Section title="Sentence" hint="The words either side of the gap. One side may be empty.">
          <div className="flex flex-wrap items-center gap-2">
            <Input
              aria-label="Text before the gap"
              placeholder="Text before"
              value={body.content.sentence_before}
              className="min-w-[10rem] flex-1"
              onChange={(e) => onChange(setSentence(body, 'sentence_before', e.target.value))}
            />
            <span
              aria-hidden="true"
              className="inline-flex h-10 w-20 shrink-0 items-center justify-center rounded border-2 border-dashed border-terracotta/50 bg-terracotta-tint text-xs font-bold text-terracotta"
            >
              gap
            </span>
            <Input
              aria-label="Text after the gap"
              placeholder="Text after"
              value={body.content.sentence_after}
              className="min-w-[10rem] flex-1"
              onChange={(e) => onChange(setSentence(body, 'sentence_after', e.target.value))}
            />
          </div>
          <FieldError slot="sentence" />
        </Section>
      )}

      {(body.type === 'multiple_choice' || body.type === 'listening' || body.type === 'gap_fill') && (
        <ChoicesEditor body={body} onChange={onChange} />
      )}
      {(body.type === 'sentence_construction' || body.type === 'spell_tiles') && (
        <SequenceEditor body={body} onChange={onChange} />
      )}
      {body.type === 'match_pairs' && <PairsEditor body={body} onChange={onChange} />}
    </div>
  )
}
