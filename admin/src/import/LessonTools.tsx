import { Link } from 'react-router-dom'

import { useSession } from '../auth/SessionContext'
import { routes } from '../tree/levels'
import { SAVE_ORDER_FIRST, useTreeActions } from '../tree/TreeActions'
import type { AdminExerciseList } from '../types'
import { Button } from '../ui/Button'
import { Icon } from '../ui/Icon'
import { CSV_TYPE, JSON_TYPE, fileName, saveFile } from './download'
import { exercisesToJson } from './json'
import { exercisesToCsv } from './toCsv'

/** Import and export for an open lesson (bolt 056). Export reads the
 * lesson's exercises fresh and downloads at once; a failure shows in the
 * tree's banner. Import is its own page, so it waits while a new order is
 * unsaved, as the editor links do. */
export function LessonTools({
  courseId,
  lessonId,
  lessonTitle,
  exerciseCount,
}: {
  courseId: string
  lessonId: string
  lessonTitle: string
  exerciseCount: number
}) {
  const { api } = useSession()
  const { busy, ordering, run } = useTreeActions()

  const exportAs = (format: 'json' | 'csv') =>
    void run(async () => {
      const { exercises } = await api.get<AdminExerciseList>(routes.exercises(lessonId))
      if (format === 'json')
        saveFile(fileName(lessonTitle, '-exercises.json'), exercisesToJson(lessonTitle, exercises), JSON_TYPE)
      else saveFile(fileName(lessonTitle, '-exercises.csv'), exercisesToCsv(exercises), CSV_TYPE)
    })

  const importLink =
    'inline-flex h-11 items-center gap-1.5 rounded border border-line bg-surface px-3 text-[0.8125rem] font-semibold text-coffee hover:bg-inset sm:h-8'
  const empty = exerciseCount === 0

  return (
    <div role="group" aria-label="Import and export" className="mb-2 flex flex-wrap items-center gap-2">
      {ordering ? (
        <Button size="sm" disabled title={SAVE_ORDER_FIRST}>
          <Icon name="upload_file" className="text-base" />
          Import
        </Button>
      ) : (
        <Link to={`/courses/${courseId}/lessons/${lessonId}/import`} className={importLink}>
          <Icon name="upload_file" className="text-base" />
          {empty ? 'Import from a file' : 'Import'}
        </Link>
      )}
      <Button
        size="sm"
        variant="ghost"
        disabled={busy || empty}
        title={empty ? 'No exercises to export yet' : undefined}
        onClick={() => exportAs('csv')}
      >
        <Icon name="download" className="text-base" />
        Export CSV
      </Button>
      <Button
        size="sm"
        variant="ghost"
        disabled={busy || empty}
        title={empty ? 'No exercises to export yet' : undefined}
        onClick={() => exportAs('json')}
      >
        <Icon name="download" className="text-base" />
        Export JSON
      </Button>
    </div>
  )
}
