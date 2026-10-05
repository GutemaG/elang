import { useEffect, useState } from 'react'

import { ApiError } from '../api'
import { messageOf, useSession } from '../auth/SessionContext'
import { plural } from '../format'
import { routes } from '../tree/levels'
import type { CurriculumImportRequest, CurriculumImportResult, CurriculumImportTally } from '../types'
import { Button } from '../ui/Button'
import { Modal } from '../ui/Modal'
import { locate, type ParsedWorkbook, type WorkbookProblem } from './model'

type Preview =
  | { kind: 'checking' }
  | { kind: 'ready'; result: CurriculumImportResult }
  | { kind: 'problems'; problems: WorkbookProblem[] }
  | { kind: 'failed'; message: string }

/** The server's own problems with the file, pointed back at its rows. */
function serverProblems(parsed: ParsedWorkbook, e: unknown): WorkbookProblem[] | null {
  if (!(e instanceof ApiError) || e.errorCode !== 'invalid_import') return null
  const rows = Array.isArray(e.details.rows) ? (e.details.rows as { ref: string; field: string; message: string }[]) : []
  return rows.map((p) => locate(parsed, p))
}

/** What an import of the chosen workbook would do, from the server's dry
 * run; nothing is saved until Import. */
export function ImportDialog({
  courseId,
  fileName,
  parsed,
  onClose,
  onImported,
}: {
  courseId: string
  fileName: string
  parsed: ParsedWorkbook
  onClose: () => void
  onImported: (result: CurriculumImportResult) => void
}) {
  const { api } = useSession()
  const [overwrite, setOverwrite] = useState(false)
  const [preview, setPreview] = useState<Preview>(
    parsed.problems.length > 0 ? { kind: 'problems', problems: parsed.problems } : { kind: 'checking' },
  )
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const readable = parsed.problems.length === 0

  const request = (overwriteReviewed: boolean): CurriculumImportRequest => ({
    entries: parsed.entries,
    rows: parsed.rows,
    overwrite_reviewed: overwriteReviewed,
  })

  useEffect(() => {
    if (!readable) return
    let live = true
    api.put<CurriculumImportResult>(`${routes.curriculum(courseId)}?dry_run=true`, request(overwrite)).then(
      (result) => live && setPreview({ kind: 'ready', result }),
      (e: unknown) => {
        if (!live) return
        const problems = serverProblems(parsed, e)
        setPreview(problems ? { kind: 'problems', problems } : { kind: 'failed', message: messageOf(e) })
      },
    )
    return () => {
      live = false
    }
    // The request is made from `parsed`, which never changes while open.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [api, courseId, overwrite, readable])

  async function confirm() {
    setBusy(true)
    setError(null)
    try {
      onImported(await api.put<CurriculumImportResult>(routes.curriculum(courseId), request(overwrite)))
    } catch (e) {
      const problems = serverProblems(parsed, e)
      if (problems) setPreview({ kind: 'problems', problems })
      else setError(messageOf(e))
      setBusy(false)
    }
  }

  const result = preview.kind === 'ready' ? preview.result : null
  const changes = result ? result.entries.added + result.entries.changed + result.rows.added + result.rows.changed : 0

  return (
    <Modal title="Import workbook" onClose={() => !busy && onClose()} className="sm:max-w-xl">
      <p className="mt-1 truncate text-sm text-stone">{fileName}</p>

      {preview.kind === 'checking' && (
        <p role="status" className="mt-4 text-sm text-stone">
          Checking the file…
        </p>
      )}

      {preview.kind === 'failed' && (
        <p role="alert" className="mt-4 text-sm text-danger">
          {preview.message}
        </p>
      )}

      {preview.kind === 'problems' && (
        <div className="mt-4 rounded bg-danger-tint p-3" role="alert">
          <p className="text-sm font-semibold text-danger">
            {plural(preview.problems.length, 'problem')} to fix in the file first. Nothing was imported.
          </p>
          <ul className="mt-2 max-h-56 list-disc space-y-0.5 overflow-y-auto pl-5 text-xs leading-5 text-danger">
            {preview.problems.map((p, i) => (
              <li key={i}>
                {p.tab}
                {p.row !== null && `, row ${p.row}`}: {p.message}
              </li>
            ))}
          </ul>
        </div>
      )}

      {result && (
        <div className="mt-4 space-y-4">
          <dl className="grid grid-cols-2 gap-3">
            <Tally label="Lessons and skills" tally={result.entries} />
            <Tally label="Words and sentences" tally={result.rows} />
          </dl>
          {parsed.skipped > 0 && (
            <p className="text-xs text-stone">
              {plural(parsed.skipped, 'row')} of Section 0 (sounds and writing) skipped: the Sounds tab covers them.
            </p>
          )}
          {result.kept.length > 0 && (
            <p className="rounded bg-inset p-3 text-xs leading-5 text-coffee-soft">
              <span className="font-semibold text-coffee">{plural(result.kept.length, 'row')} kept as they are</span>{' '}
              because they are reviewed or recorded: {result.kept.join(', ')}.
            </p>
          )}
          {result.missing_rows.length > 0 && (
            <p className="text-xs leading-5 text-stone">
              {plural(result.missing_rows.length, 'row')} in the workbook here {result.missing_rows.length === 1 ? 'is' : 'are'}{' '}
              not in the file and will stay: {result.missing_rows.join(', ')}.
            </p>
          )}
          <label className="flex items-start gap-2 text-sm text-coffee">
            <input
              type="checkbox"
              className="mt-0.5 size-4 accent-forest"
              checked={overwrite}
              disabled={busy}
              onChange={(e) => {
                setOverwrite(e.target.checked)
                setPreview({ kind: 'checking' })
              }}
            />
            <span>
              Overwrite reviewed and recorded rows too
              <span className="block text-xs text-stone">Their recordings stay. Changed text goes back to Draft.</span>
            </span>
          </label>
        </div>
      )}

      {error && (
        <p role="alert" className="mt-3 text-sm text-danger">
          {error}
        </p>
      )}

      <div className="mt-6 flex flex-col-reverse gap-2 sm:flex-row sm:justify-end">
        <Button className="justify-center" disabled={busy} onClick={onClose}>
          {result ? 'Cancel' : 'Close'}
        </Button>
        {result && (
          <Button variant="primary" className="justify-center" disabled={busy || changes === 0} onClick={() => void confirm()}>
            {changes === 0 ? 'Nothing to import' : busy ? 'Importing…' : `Import ${plural(changes, 'change')}`}
          </Button>
        )}
      </div>
    </Modal>
  )
}

function Tally({ label, tally }: { label: string; tally: CurriculumImportTally }) {
  return (
    <div className="rounded-md border border-line p-3">
      <dt className="text-xs font-semibold text-stone">{label}</dt>
      <dd className="tnum mt-1 space-y-0.5 text-sm text-coffee">
        <span className="block">{tally.added} new</span>
        <span className="block">{tally.changed} changed</span>
        {tally.kept > 0 && <span className="block">{tally.kept} kept</span>}
        <span className="block text-stone">{tally.unchanged} unchanged</span>
      </dd>
    </div>
  )
}
