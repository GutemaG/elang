import { Icon } from '../ui/Icon'
import { Input } from '../ui/Input'
import { AddRowButton, FieldError, RowTools, Section } from './fields'
import { addPair, pairRows, removePair, setPairText, type PairsBody } from './model'

/** Match pairs as rows of left ↔ right. A row adds or removes a tile on
 * both sides at once, so the columns always stay the same length. */
export function PairsEditor({ body, onChange }: { body: PairsBody; onChange: (next: PairsBody) => void }) {
  const rows = pairRows(body)

  return (
    <Section title="Pairs" hint="Each row is one correct match. The learner sees the right column shuffled.">
      <ol className="space-y-2">
        {rows.map((row, i) => (
          <li key={`${row.left?.id}-${row.right?.id}`}>
            <div className="flex items-center gap-2 rounded-md border border-line bg-canvas px-2 py-1.5">
              <span className="tnum w-5 shrink-0 pl-1 text-xs font-bold text-stone">{i + 1}</span>
              <div className="flex min-w-0 flex-1 flex-wrap items-center gap-2 sm:flex-nowrap">
                <Input
                  aria-label={`Pair ${i + 1} left`}
                  placeholder="Word"
                  value={row.left?.text ?? ''}
                  className="min-w-[8rem] flex-1"
                  onChange={(e) => onChange(setPairText(body, i, 'left', e.target.value))}
                />
                <Icon name="sync_alt" className="shrink-0 text-lg text-forest" />
                <Input
                  aria-label={`Pair ${i + 1} right`}
                  placeholder="Its match"
                  value={row.right?.text ?? ''}
                  className="min-w-[8rem] flex-1"
                  onChange={(e) => onChange(setPairText(body, i, 'right', e.target.value))}
                />
              </div>
              <RowTools
                what={`pair ${i + 1}`}
                index={i}
                count={rows.length}
                onRemove={() => onChange(removePair(body, i))}
              />
            </div>
            <FieldError slot={`pair:${i}`} className="pl-8" />
          </li>
        ))}
      </ol>
      <FieldError slot="pairs" />
      <AddRowButton label="Add pair" onClick={() => onChange(addPair(body))} />
    </Section>
  )
}
