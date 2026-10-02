import { describe, expect, it } from 'vitest'

import type { AdminReport, AdminTotals } from '../types'
import { activity, bucketName, lastSeen, reportCsv, shiftedEnd, trend } from './report'

const zero: AdminTotals = {
  new_learners: 0,
  active_learners: 0,
  lessons: 0,
  practice_sessions: 0,
  xp: 0,
  accuracy: null,
  skills_completed: 0,
}

function report(period: AdminReport['period'], start: string, end: string, buckets: number): AdminReport {
  return {
    period,
    course_id: null,
    start,
    end,
    totals: zero,
    previous: zero,
    buckets: Array.from({ length: buckets }, () => ({ start, end, partial: false, totals: zero })),
    now: { total_learners: 0, active_today: 0, active_7_days: 0, active_30_days: 0 },
    courses: [],
    top_learners: [],
  }
}

describe('trend', () => {
  it('compares counts as a percentage and rates in points', () => {
    expect(trend(30, 40)).toEqual({ text: '−25%', direction: 'down' })
    expect(trend(4, 2)).toEqual({ text: '+100%', direction: 'up' })
    expect(trend(3, 0)).toEqual({ text: 'New', direction: 'up' })
    expect(trend(5, 5)).toEqual({ text: 'No change', direction: 'same' })
    expect(trend(0, 0)).toBeNull()
    expect(trend(0.8, 0.75, 'rate')).toEqual({ text: '+5 pts', direction: 'up' })
    expect(trend(0.8, null, 'rate')).toBeNull()
  })
})

describe('shiftedEnd', () => {
  it('asks for the day before, or the same number of buckets after', () => {
    const weeks = report('week', '2026-07-13', '2026-10-04', 12)
    expect(shiftedEnd(weeks, -1)).toBe('2026-07-12')
    expect(shiftedEnd(weeks, 1)).toBe('2026-12-27')

    const months = report('month', '2025-11-01', '2026-10-31', 12)
    expect(shiftedEnd(months, 1)).toBe('2027-10-31')
    expect(shiftedEnd(report('day', '2026-09-03', '2026-10-02', 30), 1)).toBe('2026-11-01')
  })
})

describe('wording', () => {
  const now = new Date('2026-10-02T12:00:00Z')

  it('says how long ago a learner studied', () => {
    expect(lastSeen(null, now)).toBe('Never')
    expect(lastSeen('2026-10-02T01:00:00Z', now)).toBe('Today')
    expect(lastSeen('2026-10-01T23:00:00Z', now)).toBe('Yesterday')
    expect(lastSeen('2026-09-28T10:00:00Z', now)).toBe('4 days ago')
    expect(lastSeen('2026-09-01T10:00:00Z', now)).toBe('1 Sept 2026')
    expect(activity('2026-09-10T10:00:00Z', now)).toEqual({ label: 'Away 22 days', tone: 'draft' })
  })

  it('names buckets in UTC', () => {
    const bucket = { start: '2026-09-28', end: '2026-10-04', partial: true, totals: zero }
    expect(bucketName(bucket, 'week')).toBe('Week of 28 Sept 2026')
    expect(bucketName({ ...bucket, start: '2026-10-01' }, 'month')).toBe('October 2026')
  })
})

describe('reportCsv', () => {
  it('writes a row a bucket, accuracy as a percentage', () => {
    const r = report('week', '2026-09-28', '2026-10-04', 1)
    r.buckets[0] = { ...r.buckets[0]!, partial: true, totals: { ...zero, lessons: 3, xp: 40, accuracy: 0.8125 } }

    expect(reportCsv(r).split('\n')).toEqual([
      'Start,End,Active learners,New learners,Lessons completed,Practice sessions,XP earned,Skills completed,Accuracy,Partial',
      '2026-09-28,2026-10-04,0,0,3,0,40,0,81.3,yes',
      '',
    ])
  })
})
