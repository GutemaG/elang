import type { AdminTreeExercise } from '../types'
import { Icon } from '../ui/Icon'

// ExerciseType in backend/app/domain/lesson/value_objects.py.
const TYPES: Record<string, { name: string; icon: string }> = {
  multiple_choice: { name: 'Multiple choice', icon: 'checklist' },
  listening: { name: 'Listening', icon: 'headphones' },
  sentence_construction: { name: 'Sentence', icon: 'segment' },
  match_pairs: { name: 'Match pairs', icon: 'join' },
  gap_fill: { name: 'Gap fill', icon: 'space_bar' },
  spell_tiles: { name: 'Spell tiles', icon: 'abc' },
}

/** A lesson's exercises, read-only here; editing them is bolt 038. */
export function ExerciseList({ exercises }: { exercises: AdminTreeExercise[] }) {
  if (exercises.length === 0) {
    return (
      <p className="flex items-center gap-2 rounded border border-dashed border-line-strong px-3 py-3 text-sm text-stone">
        <Icon name="inbox" className="text-lg" />
        No exercises yet.
      </p>
    )
  }
  return (
    <ol className="divide-y divide-line overflow-hidden rounded border border-line bg-surface">
      {[...exercises]
        .sort((a, b) => a.order_index - b.order_index)
        .map((ex, i) => {
          const type = TYPES[ex.type]
          return (
            <li key={ex.id} className="flex flex-wrap items-center gap-x-3 gap-y-1.5 px-3 py-2.5 text-sm">
              <span className="tnum w-5 shrink-0 text-xs font-semibold text-stone">{i + 1}</span>
              <span className="inline-flex shrink-0 items-center gap-1.5 rounded-sm bg-inset px-2 py-0.5 text-xs font-semibold text-coffee-soft">
                <Icon name={type?.icon ?? 'help'} className="text-sm" />
                <span>{type?.name ?? ex.type}</span>
              </span>
              {/* Its own line on a phone, beside the type from sm up. */}
              <span className="order-last w-full pl-8 text-coffee sm:order-none sm:w-auto sm:min-w-0 sm:flex-1 sm:pl-0">
                {ex.prompt}
              </span>
              {ex.audio === 'placeholder' && (
                <span
                  title="Still plays the piano placeholder clip"
                  className="inline-flex items-center gap-1 rounded-full border border-terracotta-line bg-terracotta-tint px-2 py-0.5 text-[0.6875rem] font-bold text-terracotta"
                >
                  <Icon name="music_note" className="text-sm" />
                  <span>placeholder audio</span>
                </span>
              )}
              {ex.audio === 'local' && (
                <span
                  title="Plays from the local backend only, not on a real phone"
                  className="inline-flex items-center gap-1 rounded-full border border-line bg-slate-100 px-2 py-0.5 text-[0.6875rem] font-bold text-slate-500"
                >
                  <Icon name="computer" className="text-sm" />
                  <span>local audio</span>
                </span>
              )}
              {ex.audio === 'hosted' && (
                <span
                  title="Plays from the audio store"
                  className="inline-flex items-center gap-1 rounded-full border border-forest-line bg-forest-tint px-2 py-0.5 text-[0.6875rem] font-bold text-forest"
                >
                  <Icon name="graphic_eq" className="text-sm" />
                  <span>audio ready</span>
                </span>
              )}
            </li>
          )
        })}
    </ol>
  )
}
