// The Team page (intent 028): who can sign in to Buna Studio, and which
// courses each course admin works on.

import type { AdminRole } from '../types'

export const TEAM = '/api/v1/admin/team'
export const teamMember = (id: string) => `${TEAM}/${id}`

export interface TeamMember {
  /** Null for an owner, who is set in the server's ADMIN_EMAILS. */
  id: string | null
  email: string
  role: AdminRole
  is_owner: boolean
  courses: { id: string; title: string }[]
  last_signed_in_at: string | null
  created_by: string | null
  created_at: string | null
  updated_by: string | null
  updated_at: string | null
}

export interface Team {
  members: TeamMember[]
}

export const ROLE_LABEL: Record<AdminRole, string> = {
  super_admin: 'Super admin',
  course_admin: 'Course admin',
}
