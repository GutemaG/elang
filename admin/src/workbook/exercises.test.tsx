import { screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import { FakeServer } from '../test/fakeServer'
import { renderApp, withStoredSession } from '../test/renderApp'
import { COURSE_ID, exercisesPath, publishPath, serveCurriculum, smallCurriculum } from '../test/workbook'
import type { Curriculum, DraftExercise } from '../types'

vi.mock('../auth/GoogleButton', () => ({ GoogleButton: () => null }))

const L1 = `/courses/${COURSE_ID}/workbook/lessons/S1-U01-L1`
const L2 = `/courses/${COURSE_ID}/workbook/lessons/S1-U01-L2`

let server: FakeServer
let state: { curriculum: Curriculum; exercises?: Record<string, DraftExercise[]> }

beforeEach(() => {
  withStoredSession()
  state = { curriculum: smallCurriculum() }
  server = new FakeServer().install()
  serveCurriculum(server, state)
})

const panel = () => within(screen.getByRole('region', { name: 'Exercises' }))
const saves = () => server.callsTo('PUT', exercisesPath('S1-U01-L1')).map((c) => (c.body as { exercises: DraftExercise[] }).exercises)

async function generated() {
  renderApp(L1)
  await userEvent.click(await screen.findByRole('button', { name: 'Generate exercises' }))
  await panel().findByText('Generated 4 exercises.')
}

describe('a lesson’s exercises', () => {
  it('wait until every row is reviewed and recorded', async () => {
    renderApp(L2)

    await screen.findByRole('heading', { name: 'How are you?' })
    expect(await panel().findByText(/must be reviewed and recorded before its exercises are made/)).toHaveTextContent(
      '0/2 reviewed, 0/2 recorded',
    )
    expect(panel().queryByRole('button', { name: /Generate/ })).not.toBeInTheDocument()
    expect(panel().getByRole('button', { name: 'Publish lesson' })).toBeDisabled()
    expect(panel().getByText('Review and record every row first.')).toBeInTheDocument()
  })

  it('are generated from the rows, saved, and shown as the learner sees them', async () => {
    await generated()

    const [sent] = saves()
    expect(sent!.map((d) => d.generated?.key)).toEqual(['mc:W001', 'listen:W001', 'build:S001', 'gap:S001'])
    expect(sent![0]).toMatchObject({ type: 'multiple_choice', prompt: 'How do you say “english W001”?', vocab_ref: 'W001', edited: false })
    expect(panel().getAllByRole('listitem')).toHaveLength(4)

    await userEvent.click(panel().getAllByRole('button', { name: 'Preview' })[0]!)
    expect(panel().getByRole('region', { name: 'Learner preview' })).toBeInTheDocument()
  })

  it('keep an edit when generated again, until reset', async () => {
    await generated()

    await userEvent.click(panel().getAllByRole('button', { name: 'Edit' })[0]!)
    const dialog = within(await screen.findByRole('dialog', { name: 'Edit exercise 1' }))
    const prompt = dialog.getByLabelText('Prompt')
    await userEvent.clear(prompt)
    await userEvent.type(prompt, 'Which one is it?')
    await userEvent.click(dialog.getByRole('button', { name: 'Save exercise' }))

    await waitFor(() => expect(screen.queryByRole('dialog')).not.toBeInTheDocument())
    expect(saves()[1]![0]).toMatchObject({ prompt: 'Which one is it?', edited: true })
    expect(panel().getByText('Edited')).toBeInTheDocument()

    await userEvent.click(panel().getByRole('button', { name: 'Generate again' }))
    expect(await panel().findByText('Generated 4 exercises. Your 1 edited exercise kept.')).toBeInTheDocument()
    expect(saves()[2]![0]).toMatchObject({ prompt: 'Which one is it?', edited: true })

    await userEvent.click(panel().getByRole('button', { name: 'Reset to generated' }))
    await panel().findByText('Exercise 1 reset to the generated one.')
    expect(saves()[3]![0]).toMatchObject({ prompt: 'How do you say “english W001”?', edited: false })
    expect(panel().queryByText('Edited')).not.toBeInTheDocument()
  })

  it('publish the lesson, then say it is published', async () => {
    await generated()
    expect(panel().getByText('Not published')).toBeInTheDocument()

    await userEvent.click(panel().getByRole('button', { name: 'Publish lesson' }))

    expect(await panel().findByText(/Published 4 exercises to the app\. New in the course: section, skill, lesson\./)).toBeInTheDocument()
    expect(panel().getByRole('link', { name: 'See it in the course' })).toHaveAttribute('href', `/courses/${COURSE_ID}`)
    expect(server.callsTo('POST', publishPath('S1-U01-L1'))).toHaveLength(1)
    await waitFor(() => expect(panel().getByRole('button', { name: 'Publish again' })).toBeDisabled())
    expect(panel().getByText('Published; nothing has changed since.')).toBeInTheDocument()
  })

  it('show on the overview whether each lesson is published', async () => {
    state.curriculum = {
      ...state.curriculum,
      entries: state.curriculum.entries.map((e) =>
        e.ref === 'S1-U01-L1' ? { ...e, publish_state: 'published' } : e.ref === 'S1-U01-L2' ? { ...e, publish_state: 'changed' } : e,
      ),
    }
    renderApp(`/courses/${COURSE_ID}/workbook`)

    expect(await screen.findByRole('link', { name: /Hello & goodbye/ })).toHaveTextContent('Published')
    expect(screen.getByRole('link', { name: /How are you\?/ })).toHaveTextContent('Changed since publish')
  })
})
