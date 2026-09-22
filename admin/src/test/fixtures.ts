import type { AdminCourse, AdminCourseTree } from '../types'

/** A Google ID token shaped like the real thing: header.payload.signature,
 * where only the payload is read (for display). */
export function idTokenFor(email: string): string {
  const payload = btoa(JSON.stringify({ email, sub: '123' }))
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
  return `eyJhbGciOiJSUzI1NiJ9.${payload}.signature`
}

export const COURSE: AdminCourse = {
  id: 'course-1',
  title: 'Amharic',
  learning_language: 'am',
  from_language: 'en',
  status: 'active',
  section_count: 2,
}

/** Two sections; the first holds two skills, the first of which holds two
 * lessons, the first with three exercises (one on placeholder audio). */
export function courseTree(): AdminCourseTree {
  return {
    course: COURSE,
    sections: [
      {
        id: 'sec-1',
        title: 'Basics',
        subtitle: 'First words',
        order_index: 1,
        skill_count: 2,
        skills: [
          {
            id: 'skill-1',
            title: 'Greetings',
            order_index: 1,
            lesson_count: 2,
            lessons: [
              {
                id: 'lesson-1',
                title: 'Hello',
                order_index: 1,
                exercise_count: 3,
                exercises: [
                  { id: 'ex-1', order_index: 1, type: 'multiple_choice', prompt: 'Which means hello?', audio: null },
                  { id: 'ex-2', order_index: 2, type: 'listening', prompt: 'What do you hear?', audio: 'placeholder' },
                  { id: 'ex-3', order_index: 3, type: 'listening', prompt: 'And this one?', audio: 'local' },
                ],
              },
              { id: 'lesson-2', title: 'Goodbye', order_index: 2, exercise_count: 0, exercises: [] },
            ],
          },
          { id: 'skill-2', title: 'Numbers', order_index: 2, lesson_count: 0, lessons: [] },
        ],
      },
      {
        id: 'sec-2',
        title: 'Travel',
        subtitle: 'Getting around',
        order_index: 2,
        skill_count: 0,
        skills: [],
      },
    ],
  }
}
