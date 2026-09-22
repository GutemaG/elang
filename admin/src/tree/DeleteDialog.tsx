import type { DeleteDetails } from '../types'
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

function plural(n: number, word: string): string {
  return `${n} ${word}${n === 1 ? '' : 's'}`
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
  return (
    <div className="overlay">
      <div className="card dialog" role="dialog" aria-modal="true" aria-labelledby="delete-title">
        {prompt.kind === 'confirm' ? (
          <>
            <h2 id="delete-title">
              Delete {name} “{node.title}”?
            </h2>
            <p>{describeContents(details)}</p>
            <p className="muted">Learners will stop seeing it straight away. This cannot be undone.</p>
            <div className="dialog-actions">
              <button type="button" onClick={onClose} disabled={busy}>
                Cancel
              </button>
              <button type="button" className="danger primary" onClick={onConfirm} disabled={busy}>
                Delete
              </button>
            </div>
          </>
        ) : (
          <>
            <h2 id="delete-title">
              “{node.title}” can’t be deleted
            </h2>
            <p>
              {plural(details.learners ?? 0, 'learner')} {details.learners === 1 ? 'has' : 'have'} progress in this{' '}
              {name}, so deleting it would erase their history.
            </p>
            <div className="dialog-actions">
              <button type="button" className="primary" onClick={onClose} autoFocus>
                Close
              </button>
            </div>
          </>
        )}
      </div>
    </div>
  )
}
