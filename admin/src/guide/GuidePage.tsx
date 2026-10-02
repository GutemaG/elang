import type { ReactNode } from 'react'
import { Link } from 'react-router-dom'

import { TYPE_INFO } from '../exercises/model'
import { PageHeader } from '../shell/Page'
import type { ExerciseType } from '../types'
import { cx } from '../ui/cx'
import { Icon } from '../ui/Icon'
import { level, LEVELS, TONES, type LevelKey } from './courseLevels'

const STEPS: { title: string; body: string }[] = [
  { title: 'Create the course', body: 'Courses → New course, then pick the language to learn and the language learners speak.' },
  { title: 'Add a section', body: 'On the course page, Add section, e.g. “Basics — your first words”.' },
  { title: 'Add skills', body: 'Open the section and add a skill for each topic, in the order learners should meet them.' },
  { title: 'Add lessons', body: 'Open a skill and add two or three short lessons.' },
  { title: 'Add exercises', body: 'Open a lesson and add exercises one at a time, or many at once with Import.' },
  { title: 'Make it available', body: 'Back at the top of the course page, Make available. Learners can now pick it.' },
]

/** How content is organised, as a diagram with a worked example, for
 * anyone new to the admin site. Static: nothing here talks to the server. */
export function GuidePage() {
  return (
    <main className="mx-auto max-w-6xl px-4 py-6 sm:px-6 lg:px-8 lg:py-8">
      <PageHeader
        eyebrow="Guide"
        title="How a course is built"
        description="Content nests in five levels: a course holds sections, a section holds skills, a skill holds lessons, and a lesson holds exercises. Here is one course, opened all the way down."
      />

      <Card title="The five levels, with an example" icon="account_tree">
        <Diagram />
        <p className="mt-4 text-xs leading-5 text-stone">
          Example: English to Amharic. Faded rows are siblings — a level usually holds several of the next.
        </p>
      </Card>

      <Card title="What each level is, and where learners see it" icon="smartphone">
        <ol className="divide-y divide-line">
          {LEVELS.map((l, i) => (
            <li key={l.key} className="grid gap-3 py-4 first:pt-0 last:pb-0 md:grid-cols-[11rem_1fr_1fr]">
              <div className="flex items-center gap-3">
                <span className={cx('grid size-9 shrink-0 place-items-center rounded-md', TONES[l.key].chip)}>
                  <Icon name={l.icon} className="text-lg" />
                </span>
                <span>
                  <span className="block text-[0.6875rem] font-bold tracking-[0.12em] text-stone uppercase">
                    Level {i + 1}
                  </span>
                  <span className="block font-semibold text-coffee">{l.name}</span>
                </span>
              </div>
              <div className="text-sm leading-6">
                <p className="text-coffee">{l.is}</p>
                <p className="mt-1 text-stone">{l.rule}</p>
              </div>
              <p className="flex gap-2 rounded-md bg-inset px-3 py-2 text-sm leading-6 text-coffee-soft">
                <Icon name="smartphone" className="mt-0.5 text-base text-stone" />
                <span>{l.app}</span>
              </p>
            </li>
          ))}
        </ol>
      </Card>

      <Card title="The eight exercise types" icon="quiz">
        <ul className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
          {(Object.keys(TYPE_INFO) as ExerciseType[]).map((type) => (
            <li key={type} className="rounded-md border border-line p-3">
              <span className="flex items-center gap-2 font-semibold text-coffee">
                <Icon name={TYPE_INFO[type].icon} className="text-lg text-forest" />
                {TYPE_INFO[type].name}
              </span>
              <span className="mt-1 block text-sm leading-5 text-stone">{TYPE_INFO[type].description}</span>
            </li>
          ))}
        </ul>
      </Card>

      <Card title="Build a course in six steps" icon="checklist">
        <ol className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
          {STEPS.map((step, i) => (
            <li key={step.title} className="flex gap-3 rounded-md border border-line p-4">
              <span className="grid size-7 shrink-0 place-items-center rounded-full bg-forest text-sm font-bold text-white">
                {i + 1}
              </span>
              <span>
                <span className="block font-semibold text-coffee">{step.title}</span>
                <span className="mt-1 block text-sm leading-5 text-stone">{step.body}</span>
              </span>
            </li>
          ))}
        </ol>
        <div className="mt-5 flex flex-wrap items-center gap-x-6 gap-y-2 text-sm">
          <Link to="/" className="inline-flex items-center gap-1 font-semibold text-forest hover:underline">
            Go to Courses
            <Icon name="arrow_forward" className="text-base" />
          </Link>
          <span className="flex items-center gap-1.5 text-stone">
            <Icon name="lock" className="text-base" />
            Anything learners have progress in can’t be deleted, so their history is never lost.
          </span>
        </div>
      </Card>
    </main>
  )
}

function Card({ title, icon, children }: { title: string; icon: string; children: ReactNode }) {
  return (
    <section className="mt-6 rounded-lg border border-line bg-surface p-4 shadow-e1 sm:p-6">
      <h2 className="mb-4 flex items-center gap-2 text-lg leading-6 font-semibold text-coffee">
        <Icon name={icon} className="text-xl text-forest" />
        {title}
      </h2>
      {children}
    </section>
  )
}

/** The worked example as nested boxes, each level inside the one above. */
function Diagram() {
  return (
    <figure aria-label="Diagram: a course holds sections, which hold skills, which hold lessons, which hold exercises">
      <Box level="course" example="English to Amharic" note="Amharic for English speakers · Available">
        <Box level="section" example="Basics" note="Your first words">
          <Box level="skill" example="Greetings" note="Node 1 on the path · unlocked first">
            <Box level="lesson" example="Hello" note="Lesson 1 of 2">
              <ul className="space-y-2">
                <ExerciseRow type="multiple_choice" prompt="Which one means “hello”?" answer="ሰላም (selam)" />
                <ExerciseRow type="listening" prompt="What do you hear?" answer="ሰላም" />
                <ExerciseRow type="match_pairs" prompt="Match the words" answer="hello ↔ ሰላም, thanks ↔ አመሰግናለሁ" />
              </ul>
            </Box>
            <Sibling icon="menu_book" label="Lesson 2 · Goodbye" />
          </Box>
          <Sibling icon="account_tree" label="Skill · Numbers — opens when Greetings is done" />
        </Box>
        <Sibling icon="view_agenda" label="Section · Family & People" />
      </Box>
    </figure>
  )
}

function Box({ level: key, example, note, children }: { level: LevelKey; example: string; note: string; children: ReactNode }) {
  const tone = TONES[key]
  return (
    <div className={cx('rounded-lg border p-3 sm:p-4', tone.box)}>
      <div className="mb-3 flex flex-wrap items-center gap-x-2.5 gap-y-1">
        <span
          className={cx(
            'inline-flex items-center gap-1 rounded-full px-2.5 py-0.5 text-[0.6875rem] font-bold tracking-[0.08em] uppercase',
            tone.chip,
          )}
        >
          <Icon name={level(key).icon} className="text-sm" />
          {level(key).name}
        </span>
        <span className="font-semibold text-coffee">{example}</span>
        <span className="text-xs text-stone">{note}</span>
      </div>
      <div className="space-y-2">{children}</div>
    </div>
  )
}

function ExerciseRow({ type, prompt, answer }: { type: ExerciseType; prompt: string; answer: string }) {
  return (
    <li className={cx('flex flex-wrap items-center gap-x-3 gap-y-1 rounded-md border px-3 py-2', TONES.exercise.box)}>
      <span className={cx('inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-[0.6875rem] font-bold uppercase', TONES.exercise.chip)}>
        <Icon name={TYPE_INFO[type].icon} className="text-sm" />
        {TYPE_INFO[type].name}
      </span>
      <span className="text-sm text-coffee">{prompt}</span>
      <span className="text-sm text-forest">→ {answer}</span>
    </li>
  )
}

function Sibling({ icon, label }: { icon: string; label: string }) {
  return (
    <div className="flex items-center gap-2 rounded-md border border-dashed border-line-strong px-3 py-2 text-sm text-stone opacity-80">
      <Icon name={icon} className="text-base" />
      {label}
    </div>
  )
}
