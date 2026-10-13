import { useRef, useState } from 'react'

import { messageOf, useSession } from '../auth/SessionContext'
import { Button } from '../ui/Button'
import { cx } from '../ui/cx'
import { FIELD_CLASS } from '../ui/Input'
import { Modal } from '../ui/Modal'
import { formatBytes, LIBRARY_EXPORT, type AudioExport } from './api'
import { buildBackup, saveBlob, type Progress } from './backup'

type Stage =
  | { kind: 'choose' }
  | { kind: 'working'; progress: Progress }
  | { kind: 'done'; files: number; bytes: number; failed: number; name: string }

/** Builds the backup ZIP in this browser (intent 029, FR-8): asks the
 * server what goes in it, downloads each file, and saves the ZIP. */
export function ExportDialog({
  courses,
  onClose,
}: {
  courses: { id: string; title: string }[]
  onClose: () => void
}) {
  const { api } = useSession()
  const [courseId, setCourseId] = useState('')
  const [includeUnused, setIncludeUnused] = useState(false)
  const [stage, setStage] = useState<Stage>({ kind: 'choose' })
  const [error, setError] = useState<string | null>(null)
  const abort = useRef<AbortController | null>(null)

  async function start() {
    setError(null)
    const controller = new AbortController()
    abort.current = controller
    try {
      const query = new URLSearchParams()
      if (courseId) query.set('course_id', courseId)
      if (includeUnused) query.set('include_unused', 'true')
      const plan = await api.get<AudioExport>(`${LIBRARY_EXPORT}${query.size ? `?${query}` : ''}`)
      setStage({ kind: 'working', progress: { done: 0, total: plan.files.length } })
      const backup = await buildBackup(plan, {
        origin: window.location.origin,
        signal: controller.signal,
        onProgress: (progress) => setStage({ kind: 'working', progress }),
      })
      const blob = new Blob(backup.parts as BlobPart[], { type: 'application/zip' })
      saveBlob(`${plan.name}.zip`, blob)
      setStage({
        kind: 'done',
        files: plan.files.length - backup.failed.length,
        bytes: blob.size,
        failed: backup.failed.length,
        name: `${plan.name}.zip`,
      })
    } catch (e) {
      if (controller.signal.aborted) {
        setStage({ kind: 'choose' })
        return
      }
      setError(messageOf(e))
      setStage({ kind: 'choose' })
    }
  }

  const working = stage.kind === 'working'

  return (
    <Modal title="Export audio backup" onClose={() => !working && onClose()}>
      {stage.kind === 'choose' && (
        <>
          <p className="mt-2 text-sm leading-6 text-coffee-soft">
            A ZIP of the audio files, in folders by course, section and lesson, with a{' '}
            <span className="font-mono">manifest.csv</span> that says which exercise, Workbook row or letter each file
            belongs to. It is built in this browser and saved to your computer; keep it wherever you like, such as
            Google Drive.
          </p>
          <label className="mt-4 block text-sm font-semibold text-coffee">
            What to export
            <select
              className={cx(FIELD_CLASS, 'mt-1.5')}
              value={courseId}
              onChange={(e) => setCourseId(e.target.value)}
            >
              <option value="">Everything</option>
              {courses.map((c) => (
                <option key={c.id} value={c.id}>
                  {c.title} (with its Sounds)
                </option>
              ))}
            </select>
          </label>
          <label className="mt-3 flex cursor-pointer items-center gap-2.5 text-sm text-coffee">
            <input
              type="checkbox"
              checked={includeUnused}
              onChange={(e) => setIncludeUnused(e.target.checked)}
              className="size-4 accent-forest"
            />
            Include files nothing uses
          </label>
          {error && (
            <p role="alert" className="mt-3 text-sm text-danger">
              {error}
            </p>
          )}
          <div className="mt-6 flex flex-col-reverse gap-2 sm:flex-row sm:justify-end">
            <Button className="justify-center" onClick={onClose}>
              Cancel
            </Button>
            <Button variant="primary" className="justify-center" onClick={() => void start()}>
              Export
            </Button>
          </div>
        </>
      )}

      {stage.kind === 'working' && (
        <>
          <p className="mt-2 text-sm text-coffee-soft" aria-live="polite">
            Downloading {stage.progress.done} of {stage.progress.total} files…
          </p>
          <progress
            className="mt-3 h-2 w-full accent-forest"
            max={Math.max(stage.progress.total, 1)}
            value={stage.progress.done}
          />
          <div className="mt-6 flex justify-end">
            <Button className="justify-center" onClick={() => abort.current?.abort()}>
              Cancel
            </Button>
          </div>
        </>
      )}

      {stage.kind === 'done' && (
        <>
          <p className="mt-2 text-sm leading-6 text-coffee-soft" role="status">
            Saved {stage.name}: {stage.files} {stage.files === 1 ? 'file' : 'files'}, {formatBytes(stage.bytes)}.
          </p>
          {stage.failed > 0 && (
            <p role="alert" className="mt-2 text-sm text-danger">
              {stage.failed} {stage.failed === 1 ? 'file' : 'files'} could not be downloaded; the manifest marks them
              download_failed.
            </p>
          )}
          <div className="mt-6 flex justify-end">
            <Button variant="primary" className="justify-center" onClick={onClose}>
              Done
            </Button>
          </div>
        </>
      )}
    </Modal>
  )
}
