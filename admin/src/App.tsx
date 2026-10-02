import { Navigate, Route, Routes } from 'react-router-dom'

import { NotAuthorisedScreen } from './auth/NotAuthorisedScreen'
import { useSession } from './auth/SessionContext'
import { SignInScreen } from './auth/SignInScreen'
import { ExerciseEditorRoute } from './exercises/ExerciseEditorPage'
import { GuidePage } from './guide/GuidePage'
import { ImportPage } from './import/ImportPage'
import { LanguagesPage } from './languages/LanguagesPage'
import { DashboardPage } from './learners/DashboardPage'
import { LearnerPage } from './learners/LearnerPage'
import { LearnersPage } from './learners/LearnersPage'
import { AppShell } from './shell/AppShell'
import { CourseList } from './tree/CourseList'
import { CourseTree } from './tree/CourseTree'
import { VocabularyPage } from './vocab/VocabularyPage'

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
            <Route path="/vocabulary" element={<CourseList key="vocabulary" purpose="vocabulary" />} />
            <Route path="/courses/:courseId/vocabulary" element={<VocabularyPage />} />
            <Route path="/languages" element={<LanguagesPage />} />
            <Route path="/guide" element={<GuidePage />} />
            <Route path="/dashboard" element={<DashboardPage />} />
            <Route path="/learners" element={<LearnersPage />} />
            <Route path="/learners/:learnerId" element={<LearnerPage />} />
            <Route
              path="/courses/:courseId/lessons/:lessonId/exercises/new/:type"
              element={<ExerciseEditorRoute />}
            />
            <Route
              path="/courses/:courseId/lessons/:lessonId/exercises/:exerciseId"
              element={<ExerciseEditorRoute />}
            />
            <Route path="/courses/:courseId/lessons/:lessonId/import" element={<ImportPage />} />
            <Route path="*" element={<Navigate to="/" replace />} />
          </Routes>
        </AppShell>
      )
  }
}
