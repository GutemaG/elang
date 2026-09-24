import { Icon } from '../ui/Icon'
import { AuthCard } from './AuthCard'
import { GoogleButton } from './GoogleButton'
import { useSession } from './SessionContext'

export function SignInScreen({ message }: { message: string | null }) {
  const { signInWithGoogle } = useSession()
  return (
    <AuthCard>
      <h1 className="text-[1.75rem] leading-9 font-bold tracking-[-0.02em] text-coffee">Sign in</h1>
      <p className="mt-2 text-sm leading-6 text-stone">
        Use the Google account you were made an admin with. Changes you make here reach learners straight away.
      </p>
      {message && (
        <p
          role="alert"
          className="mt-5 flex items-start gap-2 rounded border border-danger-line bg-danger-tint px-3 py-2.5 text-sm text-danger"
        >
          <Icon name="error" className="mt-px text-lg" />
          <span>{message}</span>
        </p>
      )}
      <div className="mt-6 flex justify-center">
        <GoogleButton onCredential={(token) => void signInWithGoogle(token)} />
      </div>
    </AuthCard>
  )
}
