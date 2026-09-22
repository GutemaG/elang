import { describe, expect, it } from 'vitest'

import { moved, routes } from './levels'

describe('routes', () => {
  it('match the admin API', () => {
    expect(routes.courses).toBe('/api/v1/admin/courses')
    expect(routes.course('c1')).toBe('/api/v1/admin/courses/c1')
    expect(routes.tree('c1')).toBe('/api/v1/admin/courses/c1/tree')

    expect(routes.create('section', 'c1')).toBe('/api/v1/admin/courses/c1/sections')
    expect(routes.create('skill', 'sec1')).toBe('/api/v1/admin/sections/sec1/skills')
    expect(routes.create('lesson', 'sk1')).toBe('/api/v1/admin/skills/sk1/lessons')

    expect(routes.order('section', 'c1')).toBe('/api/v1/admin/courses/c1/sections/order')
    expect(routes.order('skill', 'sec1')).toBe('/api/v1/admin/sections/sec1/skills/order')
    expect(routes.order('lesson', 'sk1')).toBe('/api/v1/admin/skills/sk1/lessons/order')

    expect(routes.node('lesson', 'l1')).toBe('/api/v1/admin/lessons/l1')
  })
})

describe('moving an item', () => {
  const ids = ['a', 'b', 'c']

  it('swaps with the neighbour above', () => {
    expect(moved(ids, 2, -1)).toEqual(['a', 'c', 'b'])
  })

  it('swaps with the neighbour below', () => {
    expect(moved(ids, 0, 1)).toEqual(['b', 'a', 'c'])
  })

  it('refuses to move past either end', () => {
    expect(moved(ids, 0, -1)).toBeNull()
    expect(moved(ids, 2, 1)).toBeNull()
  })

  it('refuses an item that is not there', () => {
    expect(moved(ids, -1, 1)).toBeNull()
  })

  it('leaves the original list alone', () => {
    moved(ids, 0, 1)

    expect(ids).toEqual(['a', 'b', 'c'])
  })
})
