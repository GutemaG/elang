import { screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import { FakeServer } from '../test/fakeServer'
import { idTokenFor } from '../test/fixtures'
import { renderApp, withStoredSession } from '../test/renderApp'
import type { LeagueGroup, LeagueMember, LeagueWeek } from './api'
import { timeLeft, weekLabel, zoneOf } from './api'

vi.mock('../auth/GoogleButton', () => ({
  GoogleButton: ({ onCredential }: { onCredential: (token: string) => void }) => (
    <button type="button" onClick={() => onCredential(idTokenFor('admin@example.com'))}>
      Sign in with Google
    </button>
  ),
}))

const ME = '/api/v1/admin/me'
const LEAGUES = '/api/v1/admin/leagues'
const SUPER = { email: 'admin@example.com', role: 'super_admin', is_owner: true, course_ids: null }
const HELPER = { email: 'admin@example.com', role: 'course_admin', is_owner: false, course_ids: ['course-1'] }

function member(n: number, extra: Partial<LeagueMember> = {}): LeagueMember {
  return {
    member_id: `m${n}`,
    user_id: `u${n}`,
    first_name: `Learner${n}`,
    shown_name: `Learner${n}`,
    email: `l${n}@example.com`,
    rank: n,
    xp: 100 - n * 10,
    earned_xp: 100 - n * 10,
    xp_adjustment: 0,
    xp_adjustment_reason: null,
    last_xp_at: new Date().toISOString(),
    joined_at: '2026-10-12T08:00:00Z',
    hidden: false,
    removed: false,
    removed_at: null,
    removed_reason: null,
    tier_after: null,
    movement: null,
    reward_amole: null,
    ...extra,
  }
}

function group(extra: Partial<LeagueGroup> = {}): LeagueGroup {
  return {
    group_id: 'g1',
    tier: 'light_roast',
    status: 'open',
    promote_count: 1,
    demote_count: 1,
    members: [1, 2, 3, 4, 5].map((n) => member(n)),
    ...extra,
  }
}

let server: FakeServer
let week: LeagueWeek

beforeEach(() => {
  withStoredSession()
  week = {
    week_start: '2026-10-12',
    week_end: new Date(Date.now() + 2 * 86_400_000 + 3 * 3_600_000 + 60_000).toISOString(),
    is_current: true,
    weeks: ['2026-10-12', '2026-10-05'],
    totals: { groups: 1, members: 5, removed: 0, xp: 250 },
    groups: [group()],
  }
  server = new FakeServer()
    .install()
    .on('GET', ME, { body: SUPER })
    .on('GET', LEAGUES, () => ({ body: week }))
})

const main = () => within(screen.getByRole('main'))
const opened = () => screen.findByRole('heading', { name: 'Leagues' })
const row = (name: string) => within(main().getByRole('row', { name }))

describe('league helpers', () => {
  it('marks the promote and demote zones among ranked members', () => {
    const g = group({ members: [member(1), member(2), member(3), member(4, { rank: null, removed: true })] })
    expect(g.members.map((m) => zoneOf(g, m))).toEqual(['up', null, 'down', null])
  })

  it('labels weeks and time left', () => {
    expect(weekLabel('2026-10-12')).toBe('12 Oct – 18 Oct 2026')
    expect(timeLeft('2026-10-15T12:00:00Z', new Date('2026-10-13T09:00:00Z'))).toBe('2 days 3 hours')
    expect(timeLeft('2026-10-13T09:30:00Z', new Date('2026-10-13T09:00:00Z'))).toBe('under an hour')
  })
})

describe('the leagues page', () => {
  it('is under Learners for a super admin only', async () => {
    renderApp('/')
    expect(await screen.findByRole('link', { name: 'Leagues' })).toBeInTheDocument()
  })

  it('sends a course admin back to the workspace', async () => {
    server.on('GET', ME, { body: HELPER }).on('GET', '/api/v1/admin/courses', { body: { courses: [] } })
    renderApp('/leagues')

    expect(await screen.findByRole('heading', { name: 'Courses' })).toBeInTheDocument()
    expect(screen.queryByRole('link', { name: 'Leagues' })).not.toBeInTheDocument()
  })

  it('shows this week ranked, with the zones, totals and time left', async () => {
    renderApp('/leagues')

    expect(await screen.findByRole('region', { name: 'Light Roast · group 1' })).toBeInTheDocument()
    expect(main().getByText('Ends in 2 days 3 hours')).toBeInTheDocument()
    expect(main().getByText('top 1 up, bottom 1 down', { exact: false })).toBeInTheDocument()
    expect(row('Learner1').getByText('l1@example.com')).toBeInTheDocument()
    expect(row('Learner1').getByText('90')).toBeInTheDocument()
    expect(row('Learner1').getByRole('button', { name: 'Remove Learner1' })).toBeInTheDocument()
    expect(main().getByLabelText('Week')).toHaveDisplayValue('This week · 12 Oct – 18 Oct 2026')
  })

  it('opens a past week from the picker, read only, with stored results', async () => {
    server.on('GET', LEAGUES, (call) =>
      call.query.includes('week=2026-10-05')
        ? {
            body: {
              ...week,
              week_start: '2026-10-05',
              is_current: false,
              groups: [
                group({
                  status: 'closed',
                  members: [
                    member(1, { movement: 'up', tier_after: 'medium_roast', reward_amole: 100 }),
                    member(2, { movement: 'stayed', tier_after: 'light_roast', reward_amole: 60 }),
                  ],
                }),
              ],
            },
          }
        : { body: week },
    )
    renderApp('/leagues')

    await userEvent.selectOptions(await screen.findByLabelText('Week'), '5 Oct – 11 Oct 2026')

    expect(await main().findByText('Moved up')).toBeInTheDocument()
    expect(row('Learner1').getByText('to Medium Roast')).toBeInTheDocument()
    expect(row('Learner1').getByText('100')).toBeInTheDocument()
    expect(main().queryByRole('button', { name: /^Remove/ })).not.toBeInTheDocument()
    expect(server.callsTo('GET', LEAGUES).at(-1)!.query).toBe('?week=2026-10-05')
  })

  it('shows removed and adjusted members as such', async () => {
    week.groups = [
      group({
        members: [
          member(1, { xp: 120, earned_xp: 80, xp_adjustment: 40, xp_adjustment_reason: 'Offline lessons' }),
          member(2, { rank: null, removed: true, removed_reason: 'Bot XP' }),
        ],
      }),
    ]
    renderApp('/leagues')
    await opened()

    expect(await main().findByText('80 earned +40')).toBeInTheDocument()
    expect(row('Learner2').getByText('Removed')).toBeInTheDocument()
    expect(row('Learner2').getByText('Reason: Bot XP')).toBeInTheDocument()
    expect(row('Learner2').getByRole('button', { name: 'Restore Learner2' })).toBeInTheDocument()
  })

  it('removes a member with a reason', async () => {
    server.on('POST', `${LEAGUES}/members/m1/remove`, () => {
      week = { ...week, groups: [group({ members: [member(1, { rank: null, removed: true }), member(2, { rank: 1 })] })] }
      return { body: member(1, { removed: true }) }
    })
    renderApp('/leagues')

    await userEvent.click(await screen.findByRole('button', { name: 'Remove Learner1' }))
    const dialog = within(screen.getByRole('dialog', { name: 'Remove Learner1 from this week’s league?' }))
    const confirm = dialog.getByRole('button', { name: 'Remove from this week' })
    expect(confirm).toBeDisabled()
    await userEvent.type(dialog.getByLabelText('Reason'), 'Bot XP')
    await userEvent.click(confirm)

    expect(server.callsTo('POST', `${LEAGUES}/members/m1/remove`)[0]!.body).toEqual({ reason: 'Bot XP' })
    await waitFor(() => expect(screen.queryByRole('dialog')).not.toBeInTheDocument())
    expect(await row('Learner1').findByText('Removed')).toBeInTheDocument()
  })

  it('previews and saves an XP adjustment, keeping a refusal in the dialog', async () => {
    let refuse = true
    server.on('PUT', `${LEAGUES}/members/m3/xp`, () =>
      refuse
        ? { status: 422, body: { error_code: 'invalid_content', message: 'Write a reason', details: { field: 'reason' } } }
        : { body: member(3) },
    )
    renderApp('/leagues')

    await userEvent.click(await screen.findByRole('button', { name: 'Adjust XP for Learner3' }))
    const dialog = within(screen.getByRole('dialog', { name: 'Adjust Learner3’s XP this week' }))
    await userEvent.type(dialog.getByLabelText('Adjustment'), '50')
    expect(dialog.getByText('120')).toBeInTheDocument()
    expect(dialog.getByText('3 → 1')).toBeInTheDocument()

    await userEvent.click(dialog.getByRole('button', { name: 'Save adjustment' }))
    expect(await dialog.findByRole('alert')).toHaveTextContent('Write a reason')

    refuse = false
    await userEvent.type(dialog.getByLabelText('Reason'), 'Lost lessons')
    await userEvent.click(dialog.getByRole('button', { name: 'Save adjustment' }))

    expect(server.callsTo('PUT', `${LEAGUES}/members/m3/xp`).at(-1)!.body).toEqual({
      adjustment: 50,
      reason: 'Lost lessons',
    })
    await waitFor(() => expect(screen.queryByRole('dialog')).not.toBeInTheDocument())
  })

  it('filters by tier and searches by name or email', async () => {
    // The server sends groups highest tier first.
    week.groups = [group({ group_id: 'g2', tier: 'golden_cup', members: [member(9, { first_name: 'Sara' })] }), group()]
    renderApp('/leagues')
    await opened()

    const regions = await main().findAllByRole('region')
    expect(regions.map((r) => r.getAttribute('aria-label'))).toEqual(['Golden Cup · group 1', 'Light Roast · group 1'])

    await userEvent.selectOptions(main().getByLabelText('Tier'), 'Golden Cup (1)')
    expect(main().queryByRole('region', { name: 'Light Roast · group 1' })).not.toBeInTheDocument()

    await userEvent.click(main().getByRole('button', { name: 'Clear filters' }))
    await userEvent.type(main().getByRole('searchbox'), 'l2@')
    await waitFor(() => expect(main().queryByRole('region', { name: 'Golden Cup · group 1' })).not.toBeInTheDocument())
    expect(main().getByRole('row', { name: 'Learner2' })).toBeInTheDocument()
    expect(main().queryByRole('row', { name: 'Learner1' })).not.toBeInTheDocument()
  })
})
