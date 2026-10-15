// The activity log (intent 030): every successful change made in the
// admin site, who made it and where it opens. Super admins only.

export const ACTIVITY = '/api/v1/admin/activity'

export interface ActivityEntry {
  id: string
  created_at: string
  admin_email: string
  admin_role: 'super_admin' | 'course_admin'
  method: string
  route: string
  area: string
  action: string
  target_kind: string | null
  target_id: string | null
  /** As it was when the change was made. */
  target_name: string | null
  course_id: string | null
  /** Where the target opens in this site; null after a delete. */
  link: string | null
  details: Record<string, unknown>
}

export interface ActivityPage {
  items: ActivityEntry[]
  total: number
  next_cursor: string | null
  admins: string[]
  areas: string[]
  courses: { id: string; title: string }[]
}

export const AREAS: Record<string, { label: string; icon: string }> = {
  curriculum: { label: 'Curriculum', icon: 'menu_book' },
  vocabulary: { label: 'Vocabulary', icon: 'translate' },
  workbook: { label: 'Workbook', icon: 'table_view' },
  sounds: { label: 'Sounds', icon: 'graphic_eq' },
  voices: { label: 'Voices', icon: 'record_voice_over' },
  audio_library: { label: 'Audio library', icon: 'library_music' },
  languages: { label: 'Languages', icon: 'language' },
  team: { label: 'Team', icon: 'group_add' },
  app_updates: { label: 'App updates', icon: 'system_update' },
  feedback: { label: 'Feedback', icon: 'feedback' },
  leagues: { label: 'Leagues', icon: 'emoji_events' },
  other: { label: 'Other', icon: 'more_horiz' },
}

export const areaOf = (area: string) => AREAS[area] ?? { label: area, icon: 'more_horiz' }

const DETAIL_LABELS: Record<string, string> = {
  reason: 'Reason',
  week: 'Week',
  adjustment: 'Adjustment',
  adjustment_before: 'Adjustment before',
  was_removed_for: 'Was removed for',
  files: 'Files',
  role: 'Role',
  courses: 'Courses',
  language: 'Language',
  voice: 'Voice',
  characters: 'Characters',
  fields: 'Settings changed',
}

/** Details as label and value pairs, in a stable order. */
export function detailRows(details: Record<string, unknown>): { label: string; value: string }[] {
  return Object.entries(details).map(([key, value]) => ({
    label: DETAIL_LABELS[key] ?? key.replace(/_/g, ' '),
    value: Array.isArray(value)
      ? value.join(', ')
      : key === 'role'
        ? String(value).replace('_', ' ')
        : String(value),
  }))
}

const EXACT = new Intl.DateTimeFormat('en-GB', {
  day: 'numeric',
  month: 'short',
  year: 'numeric',
  hour: '2-digit',
  minute: '2-digit',
})

export const exactTime = (iso: string) => EXACT.format(new Date(iso))

/** "Just now", "5 min ago", "3 h ago", "Yesterday", then a date. */
export function relativeTime(iso: string, now = new Date()): string {
  const seconds = Math.round((now.getTime() - new Date(iso).getTime()) / 1000)
  if (seconds < 60) return 'Just now'
  const minutes = Math.floor(seconds / 60)
  if (minutes < 60) return `${minutes} min ago`
  const hours = Math.floor(minutes / 60)
  if (hours < 24) return `${hours} h ago`
  if (hours < 48) return 'Yesterday'
  return new Intl.DateTimeFormat('en-GB', { day: 'numeric', month: 'short', year: 'numeric' }).format(new Date(iso))
}
