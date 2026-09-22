import { GoogleButton } from './GoogleButton'
import { useSession } from './SessionContext'

export function SignInScreen({ message }: { message: string | null }) {
  const { signInWithGoogle } = useSession()
  return (
    <main className="centered">
      <div className="card narrow">
        <h1>Buna Admin</h1>
        <p className="muted">Sign in with the Google account you were made an admin with.</p>
        {message && (
          <p className="error" role="alert">
            {message}
          </p>
        )}
        <GoogleButton onCredential={(token) => void signInWithGoogle(token)} />
      </div>
    </main>
  )
}
