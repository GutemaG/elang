import { Button } from '../ui/Button'
import { Icon } from '../ui/Icon'
import { AuthCard } from './AuthCard'
import { useSession } from './SessionContext'

export function NotAuthorisedScreen({ email }: { email: string | null }) {
  const { signOut } = useSession()
  return (
    <AuthCard>
      <span className="grid size-11 place-items-center rounded-full bg-terracotta-tint text-terracotta">
        <Icon name="lock" className="text-2xl" />
      </span>
      <h1 className="mt-4 text-[1.75rem] leading-9 font-bold tracking-[-0.02em] text-coffee">Not authorised</h1>
      <p className="mt-2 text-sm leading-6 text-coffee-soft">
        {email ? (
          <>
            <strong className="font-semibold break-all text-coffee">{email}</strong> is signed in, but is not an admin.
          </>
        ) : (
          'This account is signed in, but is not an admin.'
        )}
      </p>
      <p className="mt-3 rounded bg-inset px-3 py-2.5 text-sm leading-6 text-stone">
        Ask an existing admin to add your address to <code className="font-mono text-coffee">ADMIN_EMAILS</code>.
      </p>
      <Button className="mt-6 w-full justify-center" onClick={signOut}>
        <Icon name="logout" className="text-lg" />
        Sign out
      </Button>
    </AuthCard>
  )
}
