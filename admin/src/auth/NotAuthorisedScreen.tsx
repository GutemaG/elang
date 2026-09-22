import { useSession } from './SessionContext'

export function NotAuthorisedScreen({ email }: { email: string | null }) {
  const { signOut } = useSession()
  return (
    <main className="centered">
      <div className="card narrow">
        <h1>Not authorised</h1>
        <p>
          {email ? (
            <>
              <strong>{email}</strong> is signed in, but is not an admin.
            </>
          ) : (
            'This account is signed in, but is not an admin.'
          )}
        </p>
        <p className="muted">Ask an existing admin to add your address to ADMIN_EMAILS.</p>
        <button type="button" onClick={signOut}>
          Sign out
        </button>
      </div>
    </main>
  )
}
