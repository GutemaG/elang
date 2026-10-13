import { useSession } from './SessionContext'

export interface Access {
  /** An owner or a super admin: everything, configuration included. */
  isSuper: boolean
  canOpenCourse: (courseId: string) => boolean
}

/** What the signed-in admin may use (intent 028). The site only hides
 * what a role can't use; the server decides. */
export function useAccess(): Access {
  const { state } = useSession()
  if (state.status !== 'admin') return { isSuper: false, canOpenCourse: () => false }
  const { role, courseIds } = state
  const isSuper = role === 'super_admin'
  return {
    isSuper,
    canOpenCourse: (courseId) => isSuper || (courseIds ?? []).includes(courseId),
  }
}
