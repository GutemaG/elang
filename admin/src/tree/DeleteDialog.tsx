import { plural } from '../format'
import type { DeleteDetails } from '../types'
import { Button } from '../ui/Button'
import { Icon } from '../ui/Icon'
import { LEVELS } from './levels'
import type { NodeRef } from './TreeActions'

export type DeletePrompt =
  | { kind: 'confirm'; node: NodeRef; details: DeleteDetails }
  | { kind: 'in_use'; node: NodeRef; details: DeleteDetails }

interface Props {
  prompt: DeletePrompt
  busy: boolean
  onConfirm: () => void
  onClose: () => void
}

/** What a delete would take with it, from the server's counts. */
export function describeContents(details: DeleteDetails): string {
  const parts = [
    details.skills ? plural(details.skills, 'skill') : null,
    details.lessons ? plural(details.lessons, 'lesson') : null,
    details.exercises ? plural(details.exercises, 'exercise') : null,
  ].filter((p): p is string => p !== null)
  if (parts.length === 0) return 'Nothing else is inside it.'
  const list = parts.length === 1 ? parts[0] : `${parts.slice(0, -1).join(', ')} and ${parts[parts.length - 1]}`
  return `This also deletes ${list}.`
}

/** Driven entirely by the server's 409: `confirmation_required` can go
 * ahead with confirm=true; `content_in_use` cannot be forced. */
export function DeleteDialog({ prompt, busy, onConfirm, onClose }: Props) {
  const { node, details } = prompt
  const name = LEVELS[node.level].name
  const confirm = prompt.kind === 'confirm'

  return (
    <div className="fixed inset-0 z-50 grid place-items-end bg-[rgb(30_20_18_/_0.45)] sm:place-items-center sm:p-4">
      <div
        role="dialog"
        aria-modal="true"
        aria-labelledby="delete-title"
        onKeyDown={(e) => e.key === 'Escape' && !busy && onClose()}
        className="w-full rounded-t-lg border border-line bg-surface p-6 shadow-e3 sm:max-w-md sm:rounded-lg"
      >
        <div className="flex items-start gap-4">
          <span
            className={
              confirm
                ? 'grid size-10 shrink-0 place-items-center rounded-full bg-danger-tint text-danger'
                : 'grid size-10 shrink-0 place-items-center rounded-full bg-terracotta-tint text-terracotta'
            }
          >
            <Icon name={confirm ? 'delete' : 'lock'} className="text-xl" />
          </span>
          <div className="min-w-0">
            {confirm ? (
              <>
                <h2 id="delete-title" className="text-lg leading-6 font-semibold break-words text-coffee">
                  Delete {name} “{node.title}”?
                </h2>
                <p className="mt-2 text-sm leading-6 text-coffee-soft">{describeContents(details)}</p>
                <p className="mt-1 text-sm leading-6 text-stone">
                  Learners will stop seeing it straight away. This cannot be undone.
                </p>
              </>
            ) : (
              <>
                <h2 id="delete-title" className="text-lg leading-6 font-semibold break-words text-coffee">
                  “{node.title}” can’t be deleted
                </h2>
                <p className="mt-2 text-sm leading-6 text-coffee-soft">
                  {plural(details.learners ?? 0, 'learner')} {details.learners === 1 ? 'has' : 'have'} progress in
                  this {name}, so deleting it would erase their history.
                </p>
              </>
            )}
          </div>
        </div>

        <div className="mt-6 flex flex-col-reverse gap-2 sm:flex-row sm:justify-end">
          {confirm ? (
            <>
              <Button onClick={onClose} disabled={busy} className="justify-center">
                Cancel
              </Button>
              <Button variant="danger" onClick={onConfirm} disabled={busy} className="justify-center">
                Delete
              </Button>
            </>
          ) : (
            <Button variant="primary" onClick={onClose} autoFocus className="justify-center">
              Close
            </Button>
          )}
        </div>
      </div>
    </div>
  )
}
