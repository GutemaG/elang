import { describe, expect, it } from 'vitest'

import { orderRoute, routes } from './levels'

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

describe('where a new order is sent', () => {
  it('each level to its parent, and exercises to their lesson', () => {
    expect(orderRoute('section', 'c1')).toBe('/api/v1/admin/courses/c1/sections/order')
    expect(orderRoute('skill', 'sec1')).toBe('/api/v1/admin/sections/sec1/skills/order')
    expect(orderRoute('lesson', 'sk1')).toBe('/api/v1/admin/skills/sk1/lessons/order')
    expect(orderRoute('exercise', 'l1')).toBe('/api/v1/admin/lessons/l1/exercises/order')
  })
})
