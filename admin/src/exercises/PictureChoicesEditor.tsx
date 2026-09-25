import { useEffect, useRef, useState } from 'react'

import { messageOf, useSession } from '../auth/SessionContext'
import { PictureImage } from '../pictures/PictureImage'
import { shrinkAndUpload } from '../pictures/upload'
import { Button } from '../ui/Button'
import { cx } from '../ui/cx'
import { Icon } from '../ui/Icon'
import { Input } from '../ui/Input'
import { AddRowButton, FieldError, Hint, Section } from './fields'
import {
  MAX_ALT_TEXT,
  MAX_PICTURES,
  MIN_PICTURES,
  addPicture,
  markPictureCorrect,
  pictureProblems,
  plainMessage,
  removePicture,
  setAltText,
  setPictureUrl,
  type PictureBody,
} from './model'

/** The 2 to 4 pictures of an image choice or audio image choice question
 * (story 002). Each slot has its picture, its alt text and a "correct"
 * marker. A chosen file is shrunk and uploaded straight away; the
 * question's own Save then stores its address. `onBusy` reports whether
 * any picture is still on its way, so Save can wait for it. */
export function PictureChoicesEditor<B extends PictureBody>({
  body,
  lessonId,
  onChange,
  onBusy,
}: {
  body: B
  lessonId: string
  onChange: (next: B) => void
  onBusy?: (busy: boolean) => void
}) {
  const { api } = useSession()
  const { choices } = body.content
  const correct = body.answer_key.correct_choice_id
  const problems = pictureProblems(body)

  // Uploads finish after a wait, by which time the admin may have edited
  // the question: each is applied to the latest body, not the one it
  // started from.
  const latest = useRef(body)
  useEffect(() => {
    latest.current = body
  }, [body])

  const [busy, setBusy] = useState<ReadonlySet<string>>(new Set())
  const [failed, setFailed] = useState<Readonly<Record<string, string>>>({})
  useEffect(() => {
    onBusy?.(busy.size > 0)
  }, [busy, onBusy])

  async function choose(id: string, file: File | undefined) {
    if (!file) return
    setBusy((b) => new Set(b).add(id))
    setFailed((f) => {
      const next = { ...f }
      delete next[id]
      return next
    })
    try {
      const url = await shrinkAndUpload(api, lessonId, file)
      onChange(setPictureUrl(latest.current, id, url))
    } catch (e) {
      // The slot keeps whatever picture it had.
      setFailed((f) => ({ ...f, [id]: plainMessage(messageOf(e)) }))
    } finally {
      setBusy((b) => {
        const next = new Set(b)
        next.delete(id)
        return next
      })
    }
  }

  return (
    <Section
      title="Pictures"
      hint="2 to 4 pictures. Choose each one, describe it, then mark the one that is correct. Pictures are shrunk to 512 px before they are uploaded."
    >
      <div role="radiogroup" aria-label="Correct picture" className="space-y-2">
        {choices.map((picture, i) => (
          <Slot
            key={picture.id}
            index={i}
            url={picture.image_url}
            alt={picture.alt_text}
            isCorrect={picture.id === correct}
            uploading={busy.has(picture.id)}
            failed={failed[picture.id]}
            needs={problems.slots[i] ?? null}
            canRemove={choices.length > MIN_PICTURES}
            onMark={() => onChange(markPictureCorrect(body, picture.id))}
            onAlt={(text) => onChange(setAltText(body, picture.id, text))}
            onFile={(file) => void choose(picture.id, file)}
            onRemove={() => onChange(removePicture(body, picture.id))}
          />
        ))}
      </div>
      <FieldError slot="choices" />
      {problems.answer && <Hint>{problems.answer}</Hint>}
      {choices.length < MAX_PICTURES ? (
        <AddRowButton label="Add picture" onClick={() => onChange(addPicture(body))} />
      ) : (
        <p className="mt-3 text-xs text-stone">A question can have 4 pictures at most.</p>
      )}
    </Section>
  )
}

function Slot({
  index,
  url,
  alt,
  isCorrect,
  uploading,
  failed,
  needs,
  canRemove,
  onMark,
  onAlt,
  onFile,
  onRemove,
}: {
  index: number
  url: string
  alt: string
  isCorrect: boolean
  uploading: boolean
  failed: string | undefined
  needs: string | null
  canRemove: boolean
  onMark: () => void
  onAlt: (text: string) => void
  onFile: (file: File | undefined) => void
  onRemove: () => void
}) {
  const n = index + 1
  const input = useRef<HTMLInputElement>(null)

  return (
    <div>
      <div
        className={cx(
          'flex flex-wrap items-start gap-3 rounded-md border p-2 transition-colors sm:flex-nowrap',
          isCorrect ? 'border-forest-line bg-forest-tint' : 'border-line bg-canvas',
        )}
      >
        <label className="flex shrink-0 cursor-pointer items-center gap-2 pt-2 pl-1">
          <input
            type="radio"
            name="correct-picture"
            className="size-4 accent-forest"
            checked={isCorrect}
            aria-label={`Picture ${n} is correct`}
            onChange={onMark}
          />
          <span className="tnum w-4 text-xs font-bold text-stone">{n}</span>
        </label>

        <div className="relative size-24 shrink-0">
          <PictureImage url={url} alt={alt} className="size-24" />
          {uploading && (
            <span
              role="status"
              className="absolute inset-0 grid place-items-center rounded-md bg-surface/80 text-forest"
            >
              <Icon name="progress_activity" className="animate-spin text-2xl" />
              <span className="sr-only">Uploading picture {n}…</span>
            </span>
          )}
        </div>

        <div className="min-w-[12rem] flex-1 space-y-2">
          <input
            ref={input}
            type="file"
            accept="image/jpeg,image/png,image/webp"
            aria-label={`Picture ${n} file`}
            className="sr-only"
            tabIndex={-1}
            disabled={uploading}
            onChange={(e) => {
              onFile(e.target.files?.[0])
              // Choosing the same file again still counts as a choice.
              e.target.value = ''
            }}
          />
          <Button size="sm" variant="outline" disabled={uploading} onClick={() => input.current?.click()}>
            <Icon name={url ? 'swap_horiz' : 'add_photo_alternate'} className="text-base" />
            {uploading ? 'Uploading…' : url ? `Replace picture ${n}` : `Choose picture ${n}`}
          </Button>
          <Input
            aria-label={`Picture ${n} description`}
            placeholder="What it shows, e.g. A cup of coffee"
            value={alt}
            maxLength={MAX_ALT_TEXT}
            onChange={(e) => onAlt(e.target.value)}
          />
          <p className="text-xs text-stone">
            Read aloud to learners who can’t see it. Up to {MAX_ALT_TEXT} characters.
          </p>
        </div>

        {isCorrect && (
          <span className="hidden shrink-0 pt-2 text-xs font-bold tracking-wide text-forest uppercase sm:inline">
            Correct
          </span>
        )}
        <Button
          size="icon"
          variant="danger-ghost"
          aria-label={`Remove picture ${n}`}
          title={canRemove ? 'Remove' : 'A question needs at least 2 pictures'}
          disabled={!canRemove}
          onClick={onRemove}
        >
          <Icon name="close" className="text-lg" />
        </Button>
      </div>
      {failed && (
        <p role="alert" className="mt-1.5 flex items-start gap-1.5 pl-9 text-sm text-danger">
          <Icon name="error" className="mt-px text-base" />
          <span>{failed}</span>
        </p>
      )}
      {needs && !failed && (
        <div className="pl-9">
          <Hint>{needs}</Hint>
        </div>
      )}
      <FieldError slot={`choice:${index}`} className="pl-9" />
    </div>
  )
}
