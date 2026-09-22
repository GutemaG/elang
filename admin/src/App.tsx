import { Link, Navigate, Route, Routes } from 'react-router-dom'

import { NotAuthorisedScreen } from './auth/NotAuthorisedScreen'
import { useSession } from './auth/SessionContext'
import { SignInScreen } from './auth/SignInScreen'
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
        <main className="centered">
          <p className="muted">Signing in…</p>
        </main>
      )
    case 'not_admin':
      return <NotAuthorisedScreen email={state.email} />
    case 'admin':
      return (
        <>
          <header className="topbar">
            <Link to="/" className="brand">
              Buna Admin
            </Link>
            <span className="muted">{state.email}</span>
            <button type="button" onClick={signOut}>
              Sign out
            </button>
          </header>
          <Routes>
            <Route path="/" element={<CourseList />} />
            <Route path="/courses/:courseId" element={<CourseTree />} />
            <Route path="*" element={<Navigate to="/" replace />} />
          </Routes>
        </>
      )
  }
}
