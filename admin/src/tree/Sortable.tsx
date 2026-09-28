import { DndContext, PointerSensor, closestCenter, useSensor, useSensors, type DragEndEvent, type Modifier } from '@dnd-kit/core'
import { SortableContext, arrayMove, useSortable, verticalListSortingStrategy } from '@dnd-kit/sortable'
import { CSS } from '@dnd-kit/utilities'
import {
  createContext,
  useContext,
  useEffect,
  useRef,
  useState,
  type CSSProperties,
  type HTMLAttributes,
  type ReactNode,
} from 'react'

import { cx } from '../ui/cx'
import { Icon } from '../ui/Icon'

// Drag to reorder (bolt 055). Each list -- a course's sections, a section's
// skills, a skill's lessons, a lesson's exercises -- is its own DndContext,
// so a row can only land among its siblings, which is all the API's
// `/order` endpoints allow. A drag only changes the page; the course page
// holds the new order until Save.
//
// The pointer (mouse, pen, touch) drags through dnd-kit. The keyboard is
// handled here instead: the up and down arrows on a row's handle move it one
// place, which is quicker than dnd-kit's pick-up-and-drop and needs no
// layout, so it is testable.

interface ListState {
  ids: readonly string[]
  disabled: boolean
  move: (id: string, by: -1 | 1) => void
}

const ListContext = createContext<ListState | null>(null)

function useList(): ListState {
  const list = useContext(ListContext)
  if (!list) throw new Error('A sortable row must be inside a SortableList')
  return list
}

/** Rows only ever move up and down their list. */
const alongTheList: Modifier = ({ transform }) => ({ ...transform, x: 0 })

const position = (ids: readonly string[], id: unknown) => `position ${ids.indexOf(String(id)) + 1} of ${ids.length}`

interface Props {
  ids: readonly string[]
  /** How a row is named to screen readers: "section Basics". */
  nameOf: (id: string) => string
  onReorder: (ids: string[]) => void
  disabled?: boolean
  children: ReactNode
}

export function SortableList({ ids, nameOf, onReorder, disabled = false, children }: Props) {
  // A few pixels of travel before a drag starts, so a click on the handle
  // is still a click.
  const sensors = useSensors(useSensor(PointerSensor, { activationConstraint: { distance: 4 } }))
  const [said, setSaid] = useState('')
  // The handle to focus again once a keyboard move has re-rendered the list.
  const refocus = useRef<string | null>(null)

  useEffect(() => {
    const id = refocus.current
    if (!id) return
    refocus.current = null
    const handles = document.querySelectorAll<HTMLElement>('[data-drag-handle]')
    Array.from(handles)
      .find((h) => h.dataset.dragHandle === id)
      ?.focus()
  }, [ids])

  const move = (id: string, by: -1 | 1) => {
    const from = ids.indexOf(id)
    const to = from + by
    if (from < 0 || to < 0 || to >= ids.length) return
    refocus.current = id
    onReorder(arrayMove([...ids], from, to))
    setSaid(`${nameOf(id)} moved to position ${to + 1} of ${ids.length}. Not saved yet.`)
  }

  const onDragEnd = ({ active, over }: DragEndEvent) => {
    if (!over || active.id === over.id) return
    const from = ids.indexOf(String(active.id))
    const to = ids.indexOf(String(over.id))
    if (from < 0 || to < 0) return
    onReorder(arrayMove([...ids], from, to))
  }

  return (
    <ListContext.Provider value={{ ids, disabled, move }}>
      <DndContext
        sensors={sensors}
        collisionDetection={closestCenter}
        modifiers={[alongTheList]}
        onDragEnd={onDragEnd}
        accessibility={{
          screenReaderInstructions: {
            draggable: 'Press the up or down arrow to move it, or drag it. Nothing is saved until you choose Save order.',
          },
          announcements: {
            onDragStart: ({ active }) => `Picked up ${nameOf(String(active.id))}.`,
            onDragOver: ({ active, over }) =>
              over ? `${nameOf(String(active.id))} is over ${position(ids, over.id)}.` : undefined,
            onDragEnd: ({ active, over }) =>
              over
                ? `${nameOf(String(active.id))} dropped at ${position(ids, over.id)}. Not saved yet.`
                : `${nameOf(String(active.id))} dropped where it was.`,
            onDragCancel: ({ active }) => `Moving ${nameOf(String(active.id))} was cancelled.`,
          },
        }}
      >
        <SortableContext items={[...ids]} strategy={verticalListSortingStrategy}>
          {children}
        </SortableContext>
      </DndContext>
      <p aria-live="polite" className="sr-only">
        {said}
      </p>
    </ListContext.Provider>
  )
}

type Sortable = ReturnType<typeof useSortable>

interface ItemState {
  id: string
  attachHandle: Sortable['setActivatorNodeRef']
  attributes: Sortable['attributes']
  listeners: Sortable['listeners']
  isDragging: boolean
}

const ItemContext = createContext<ItemState | null>(null)

interface ItemProps extends Omit<HTMLAttributes<HTMLLIElement>, 'style'> {
  id: string
  children: ReactNode
}

/** One row that can be dragged: the `<li>` that moves, lifted above its
 * siblings while it does. Its DragHandle is somewhere inside it. */
export function SortableItem({ id, className, children, ...rest }: ItemProps) {
  const { disabled } = useList()
  const { attributes, listeners, setNodeRef, setActivatorNodeRef, transform, transition, isDragging } = useSortable({
    id,
    disabled,
  })
  const style: CSSProperties = { transform: CSS.Translate.toString(transform), transition }
  return (
    <ItemContext.Provider value={{ id, attachHandle: setActivatorNodeRef, attributes, listeners, isDragging }}>
      <li ref={setNodeRef} style={style} className={cx(className, isDragging && 'relative z-10 shadow-e3')} {...rest}>
        {children}
      </li>
    </ItemContext.Provider>
  )
}

/** The grip a row is dragged by. 44px on a phone, like the row's other
 * buttons; `touch-none` so a drag on a touch screen moves the row rather
 * than scrolling the page. */
export function DragHandle({ name }: { name: string }) {
  const { disabled, move } = useList()
  const item = useContext(ItemContext)
  if (!item) throw new Error('A DragHandle must be inside a SortableItem')
  const { id, attachHandle, attributes, listeners, isDragging } = item
  return (
    <button
      type="button"
      ref={attachHandle}
      {...attributes}
      {...listeners}
      data-drag-handle={id}
      aria-label={`Move ${name}`}
      title="Drag to move, or use the arrow keys"
      disabled={disabled}
      onKeyDown={(e) => {
        if (e.key !== 'ArrowUp' && e.key !== 'ArrowDown') return
        e.preventDefault()
        move(id, e.key === 'ArrowUp' ? -1 : 1)
      }}
      className={cx(
        'grid size-11 shrink-0 cursor-grab touch-none place-items-center rounded text-stone',
        'hover:bg-inset hover:text-coffee active:cursor-grabbing disabled:pointer-events-none disabled:opacity-45 sm:size-8',
        isDragging && 'cursor-grabbing bg-inset text-coffee',
      )}
    >
      <Icon name="drag_indicator" className="text-xl" />
    </button>
  )
}
