import { describe, expect, it } from 'vitest'

import { courseTree } from '../test/fixtures'
import { pathTo, readOpen, readScroll, writeOpen, writeScroll } from './treeMemory'

describe('what a course page had open', () => {
  it('is kept per course', () => {
    writeOpen('course-1', new Set(['sec-1', 'lesson-1']))
    writeOpen('course-2', new Set(['sec-9']))

    expect(readOpen('course-1')).toEqual(new Set(['sec-1', 'lesson-1']))
    expect(readOpen('course-2')).toEqual(new Set(['sec-9']))
    expect(readOpen('course-3')).toEqual(new Set())
  })

  it('is in sessionStorage, which goes with the tab', () => {
    writeOpen('course-1', new Set(['sec-1']))

    expect(sessionStorage.getItem('buna_admin.tree_open.course-1')).toBe('["sec-1"]')
    expect(localStorage.length).toBe(0)
  })

  it('starts empty from anything it did not write', () => {
    for (const stored of ['not json', '{"a":1}', '[1, null]']) {
      sessionStorage.setItem('buna_admin.tree_open.course-1', stored)
      expect(readOpen('course-1')).toEqual(new Set())
    }
  })
})

describe('where a course page was scrolled', () => {
  it('is kept per course, to the pixel', () => {
    writeScroll('course-1', 812.6)
    expect(readScroll('course-1')).toBe(813)
    expect(readScroll('course-2')).toBeNull()
  })

  it('the top, or anything unreadable, is nothing to restore', () => {
    writeScroll('course-1', 0)
    expect(readScroll('course-1')).toBeNull()
    sessionStorage.setItem('buna_admin.tree_scroll.course-1', 'far down')
    expect(readScroll('course-1')).toBeNull()
  })
})

describe('the path to a lesson', () => {
  it('is its section, skill and itself', () => {
    expect(pathTo(courseTree(), 'lesson-2')).toEqual(['sec-1', 'skill-1', 'lesson-2'])
  })

  it('is nothing for a lesson not in the course', () => {
    expect(pathTo(courseTree(), 'lesson-99')).toEqual([])
  })
})
