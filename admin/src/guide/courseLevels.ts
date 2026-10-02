// The five levels of a course, shared by the Guide page and the course
// page's info panel.

/** The five levels, outermost first: what each is, its example, and where
 * the learner meets it in the app. */
export const LEVELS = [
  {
    key: 'course',
    name: 'Course',
    icon: 'school',
    is: 'One language taught to speakers of another.',
    app: 'The course badge at the top of the dashboard; learners switch course from it.',
    rule: 'Starts as Coming soon. Make it available once it has an exercise.',
  },
  {
    key: 'section',
    name: 'Section',
    icon: 'view_agenda',
    is: 'A themed group of skills, with a title and a subtitle.',
    app: 'The heading over a stretch of the path, which changes as the learner scrolls.',
    rule: 'Every section is open: a learner can start any of them.',
  },
  {
    key: 'skill',
    name: 'Skill',
    icon: 'account_tree',
    is: 'One topic, such as greetings or numbers.',
    app: 'One round node on the path. Tapping it opens a bubble with Start or Review.',
    rule: 'Within a section, skills unlock in order: finish one to open the next.',
  },
  {
    key: 'lesson',
    name: 'Lesson',
    icon: 'menu_book',
    is: 'One short sitting inside a skill, a few minutes long.',
    app: 'Start plays the skill’s next unfinished lesson. The ring on the node counts them.',
    rule: 'A skill is complete when all its lessons are done; replaying them all earns a crown (up to 5).',
  },
  {
    key: 'exercise',
    name: 'Exercise',
    icon: 'quiz',
    is: 'One question inside a lesson.',
    app: 'One screen of the lesson, played in the order you set.',
    rule: 'Eight types, below. Each can point at a vocabulary word that Practice brings back.',
  },
] as const

export type LevelKey = (typeof LEVELS)[number]['key']
export const level = (key: LevelKey) => LEVELS.find((l) => l.key === key)!

// Each level's colour in the diagram, outermost to innermost.
export const TONES: Record<LevelKey, { box: string; chip: string }> = {
  course: { box: 'border-coffee/25 bg-surface', chip: 'bg-coffee text-white' },
  section: { box: 'border-forest-line bg-forest-tint/40', chip: 'bg-forest text-white' },
  skill: { box: 'border-terracotta-line bg-terracotta-tint/50', chip: 'bg-terracotta text-white' },
  lesson: { box: 'border-line-strong bg-inset/70', chip: 'bg-coffee-soft text-white' },
  exercise: { box: 'border-line bg-surface', chip: 'bg-stone text-white' },
}
