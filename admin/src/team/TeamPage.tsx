import { useCallback, useEffect, useState } from 'react'

import { messageOf, useSession } from '../auth/SessionContext'
import { PageHeader } from '../shell/Page'
import { Badge } from '../ui/Badge'
import { Button } from '../ui/Button'
import { Icon } from '../ui/Icon'
import { Modal } from '../ui/Modal'
import { ROLE_LABEL, TEAM, teamMember, type Team, type TeamMember } from './api'
import { MemberDialog } from './MemberDialog'

const when = (iso: string) =>
  new Date(iso).toLocaleString('en-GB', { day: 'numeric', month: 'short', year: 'numeric' })

type Editing = { kind: 'new' } | { kind: 'edit'; member: TeamMember }

/** Who can sign in to Buna Studio, and which courses they work on (intent
 * 028). Owners come from the server's ADMIN_EMAILS and can't be changed
 * here, and nobody changes their own access. */
export function TeamPage() {
  const { api, state } = useSession()
  const me = state.status === 'admin' ? state.email : null
  const [members, setMembers] = useState<TeamMember[] | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [editing, setEditing] = useState<Editing | null>(null)
  const [removing, setRemoving] = useState<TeamMember | null>(null)
  const [busy, setBusy] = useState(false)
  const [removeError, setRemoveError] = useState<string | null>(null)

  const load = useCallback(async () => {
    try {
      setMembers((await api.get<Team>(TEAM)).members)
      setError(null)
    } catch (e) {
      setError(messageOf(e))
    }
  }, [api])

  useEffect(() => {
    let live = true
    api.get<Team>(TEAM).then(
      (team) => live && setMembers(team.members),
      (e: unknown) => live && setError(messageOf(e)),
    )
    return () => {
      live = false
    }
  }, [api])

  async function remove(member: TeamMember) {
    if (!member.id) return
    setBusy(true)
    setRemoveError(null)
    try {
      await api.delete(teamMember(member.id))
      setRemoving(null)
      await load()
    } catch (e) {
      setRemoveError(messageOf(e))
    } finally {
      setBusy(false)
    }
  }

  return (
    <main className="mx-auto max-w-6xl px-4 py-6 sm:px-6 lg:px-8 lg:py-8">
      <PageHeader
        eyebrow="Configuration"
        title="Team"
        description="Who can sign in to Buna Studio, and which courses they work on."
        actions={
          <Button variant="primary" onClick={() => setEditing({ kind: 'new' })}>
            <Icon name="person_add" className="text-lg" />
            Add admin
          </Button>
        }
      />

      {error && (
        <div
          role="alert"
          className="mt-6 flex flex-wrap items-center gap-3 rounded-md border border-danger-line bg-danger-tint px-4 py-3 text-sm text-danger"
        >
          <Icon name="error" className="text-lg" />
          <span className="flex-1">{error}</span>
          <Button size="sm" onClick={() => void load()}>
            Try again
          </Button>
        </div>
      )}

      <section className="mt-6 overflow-hidden rounded-lg border border-line bg-surface shadow-e1">
        <div className="border-b border-line px-4 py-4 sm:px-6">
          <h2 className="text-lg leading-6 font-semibold text-coffee">Admins</h2>
          <p className="text-xs text-stone">
            {members ? `${members.length} ${members.length === 1 ? 'person' : 'people'}` : 'Loading…'}. A course
            admin works only on the courses chosen for them.
          </p>
        </div>
        <ul className="divide-y divide-line">
          {members?.map((member) => (
            <MemberRow
              key={member.email}
              member={member}
              isMe={member.email === me}
              onEdit={() => setEditing({ kind: 'edit', member })}
              onRemove={() => {
                setRemoveError(null)
                setRemoving(member)
              }}
            />
          ))}
        </ul>
      </section>

      {editing && (
        <MemberDialog
          member={editing.kind === 'edit' ? editing.member : null}
          onClose={() => setEditing(null)}
          onSaved={() => {
            setEditing(null)
            void load()
          }}
        />
      )}

      {removing && (
        <Modal title={`Remove ${removing.email}?`} onClose={() => !busy && setRemoving(null)}>
          <p className="mt-2 text-sm leading-6 text-coffee-soft">They lose access on their next click.</p>
          {removeError && (
            <p role="alert" className="mt-3 text-sm text-danger">
              {removeError}
            </p>
          )}
          <div className="mt-6 flex flex-col-reverse gap-2 sm:flex-row sm:justify-end">
            <Button className="justify-center" disabled={busy} onClick={() => setRemoving(null)}>
              Cancel
            </Button>
            <Button variant="danger" className="justify-center" disabled={busy} onClick={() => void remove(removing)}>
              Remove
            </Button>
          </div>
        </Modal>
      )}
    </main>
  )
}

function MemberRow({
  member,
  isMe,
  onEdit,
  onRemove,
}: {
  member: TeamMember
  isMe: boolean
  onEdit: () => void
  onRemove: () => void
}) {
  const role = member.is_owner ? 'Owner' : ROLE_LABEL[member.role]
  const courses =
    member.role === 'super_admin'
      ? 'All courses'
      : member.courses.length === 0
        ? 'No courses yet'
        : member.courses.map((c) => c.title).join(', ')
  const editable = !member.is_owner && !isMe && member.id !== null

  return (
    <li className="flex flex-wrap items-center gap-x-4 gap-y-2 px-4 py-3 sm:px-6">
      <span className="min-w-0 flex-1 basis-64">
        <span className="flex flex-wrap items-center gap-2">
          <span className="text-base font-semibold break-all text-coffee">{member.email}</span>
          <Badge tone={member.role === 'super_admin' ? 'forest' : 'neutral'}>{role}</Badge>
          {isMe && <Badge tone="neutral">You</Badge>}
        </span>
        <span className="mt-0.5 block text-sm text-coffee-soft">{courses}</span>
        <span className="mt-0.5 block text-xs text-stone">
          {member.last_signed_in_at ? `Last signed in ${when(member.last_signed_in_at)}` : 'Not signed in yet'}
        </span>
      </span>
      {member.is_owner ? (
        <span className="flex items-center gap-1.5 text-xs text-stone">
          <Icon name="lock" className="text-base" />
          Set in the server’s ADMIN_EMAILS
        </span>
      ) : (
        editable && (
          <span className="flex gap-1">
            <Button size="icon" variant="ghost" aria-label={`Edit ${member.email}`} onClick={onEdit}>
              <Icon name="edit" className="text-lg" />
            </Button>
            <Button size="icon" variant="danger-ghost" aria-label={`Remove ${member.email}`} onClick={onRemove}>
              <Icon name="person_remove" className="text-lg" />
            </Button>
          </span>
        )
      )}
    </li>
  )
}
