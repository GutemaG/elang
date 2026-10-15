// The Leagues page (intent 030): one week's groups, ranked as the app
// ranks them, and the two corrections for the current week. Super admins
// only.

export const LEAGUES = '/api/v1/admin/leagues'
export const leagueMember = (id: string) => `${LEAGUES}/members/${id}`

export type Tier = 'green_bean' | 'light_roast' | 'medium_roast' | 'dark_roast' | 'golden_cup'

/** The app's tier names, highest first. */
export const TIERS: { key: Tier; name: string }[] = [
  { key: 'golden_cup', name: 'Golden Cup' },
  { key: 'dark_roast', name: 'Dark Roast' },
  { key: 'medium_roast', name: 'Medium Roast' },
  { key: 'light_roast', name: 'Light Roast' },
  { key: 'green_bean', name: 'Green Bean' },
]

export const tierName = (tier: Tier) => TIERS.find((t) => t.key === tier)?.name ?? tier

export interface LeagueMember {
  member_id: string
  user_id: string
  first_name: string | null
  /** The name other learners see: the first name, or "Learner 1234". */
  shown_name: string
  email: string | null
  /** Place in the group; null when removed or hidden. */
  rank: number | null
  /** What ranks: earned plus the adjustment (the stored XP once closed). */
  xp: number
  earned_xp: number
  xp_adjustment: number
  xp_adjustment_reason: string | null
  last_xp_at: string | null
  joined_at: string
  /** Switched "Show me in leagues" off. */
  hidden: boolean
  removed: boolean
  removed_at: string | null
  removed_reason: string | null
  tier_after: Tier | null
  movement: 'up' | 'down' | 'stayed' | null
  reward_amole: number | null
}

export interface LeagueGroup {
  group_id: string
  tier: Tier
  /** `ended`: the week is over, waiting for a member to open the app. */
  status: 'open' | 'ended' | 'closed'
  promote_count: number
  demote_count: number
  members: LeagueMember[]
}

export interface LeagueWeek {
  week_start: string
  week_end: string
  is_current: boolean
  weeks: string[]
  totals: { groups: number; members: number; removed: number; xp: number }
  groups: LeagueGroup[]
}

/** Where a ranked member sits: moving up, down, or neither. */
export function zoneOf(group: LeagueGroup, member: LeagueMember): 'up' | 'down' | null {
  if (member.rank === null) return null
  const ranked = group.members.filter((m) => m.rank !== null).length
  if (member.rank <= group.promote_count) return 'up'
  if (member.rank > ranked - group.demote_count) return 'down'
  return null
}

const DAY_MONTH = new Intl.DateTimeFormat('en-GB', { day: 'numeric', month: 'short', timeZone: 'UTC' })
const DAY_MONTH_YEAR = new Intl.DateTimeFormat('en-GB', {
  day: 'numeric',
  month: 'short',
  year: 'numeric',
  timeZone: 'UTC',
})

const day = (iso: string) => new Date(`${iso.slice(0, 10)}T00:00:00Z`)

/** "12 – 18 Oct 2026": Monday to Sunday. */
export function weekLabel(weekStart: string): string {
  const start = day(weekStart)
  const end = new Date(start.getTime() + 6 * 86_400_000)
  return `${DAY_MONTH.format(start)} – ${DAY_MONTH_YEAR.format(end)}`
}

/** "3 days 4 hours", "5 hours", "under an hour". */
export function timeLeft(endIso: string, now = new Date()): string {
  const hours = Math.floor((new Date(endIso).getTime() - now.getTime()) / 3_600_000)
  if (hours < 1) return 'under an hour'
  const days = Math.floor(hours / 24)
  const rest = hours % 24
  const parts = []
  if (days) parts.push(`${days} ${days === 1 ? 'day' : 'days'}`)
  if (rest) parts.push(`${rest} ${rest === 1 ? 'hour' : 'hours'}`)
  return parts.join(' ')
}

/** "+40", "−25" for an adjustment. */
export const signed = (n: number) => (n > 0 ? `+${n}` : n < 0 ? `−${Math.abs(n)}` : '0')
