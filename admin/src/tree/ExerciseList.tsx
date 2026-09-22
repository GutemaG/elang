import type { AdminTreeExercise } from '../types'

const TYPE_NAMES: Record<string, string> = {
  multiple_choice: 'Multiple choice',
  listening: 'Listening',
  sentence_construction: 'Sentence',
  match_pairs: 'Match pairs',
  gap_fill: 'Gap fill',
  spell_tiles: 'Spell tiles',
}

/** A lesson's exercises, read-only here; editing them is bolt 038. */
export function ExerciseList({ exercises }: { exercises: AdminTreeExercise[] }) {
  if (exercises.length === 0) return <p className="muted empty">No exercises yet.</p>
  return (
    <ol className="exercises">
      {[...exercises]
        .sort((a, b) => a.order_index - b.order_index)
        .map((ex) => (
          <li key={ex.id}>
            <span className="type">{TYPE_NAMES[ex.type] ?? ex.type}</span>
            <span className="prompt">{ex.prompt}</span>
            {ex.audio === 'placeholder' && (
              <span className="badge warn" title="Still plays the piano placeholder clip">
                placeholder audio
              </span>
            )}
            {ex.audio === 'local' && (
              <span className="badge" title="Plays from the local backend only, not on a real phone">
                local audio
              </span>
            )}
          </li>
        ))}
    </ol>
  )
}
