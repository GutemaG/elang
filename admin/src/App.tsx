import { Navigate, Route, Routes } from 'react-router-dom'

import { NotAuthorisedScreen } from './auth/NotAuthorisedScreen'
import { useSession } from './auth/SessionContext'
import { SignInScreen } from './auth/SignInScreen'
import { AppShell } from './shell/AppShell'
import { CourseList } from './tree/CourseList'
import { CourseTree } from './tree/CourseTree'

/** The session decides the screen; only an admin reaches the routes. */
export function App() {
  const { state, signOut } = useSession()

  switch (state.status) {
    case 'signed_out':
      return <SignInScreen message={state.message} />
    case 'checking':
      return (
        <main className="grid min-h-screen place-items-center p-4">
          <p className="flex items-center gap-3 text-sm text-stone">
            <span className="size-4 animate-spin rounded-full border-2 border-forest/25 border-t-forest" aria-hidden="true" />
            Signing in…
          </p>
        </main>
      )
    case 'not_admin':
      return <NotAuthorisedScreen email={state.email} />
    case 'admin':
      return (
        <AppShell email={state.email} onSignOut={signOut}>
          <Routes>
            <Route path="/" element={<CourseList />} />
            <Route path="/courses/:courseId" element={<CourseTree />} />
            <Route path="*" element={<Navigate to="/" replace />} />
          </Routes>
        </AppShell>
      )
  }
}
