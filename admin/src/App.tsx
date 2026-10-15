import type { ReactNode } from 'react'
import { Navigate, Route, Routes } from 'react-router-dom'

import { ActivityPage } from './activity/ActivityPage'
import { NotAuthorisedScreen } from './auth/NotAuthorisedScreen'
import { useAccess } from './auth/access'
import { useSession } from './auth/SessionContext'
import { SignInScreen } from './auth/SignInScreen'
import { ExerciseEditorRoute } from './exercises/ExerciseEditorPage'
import { FeedbackPage } from './feedback/FeedbackPage'
import { GuidePage } from './guide/GuidePage'
import { ImportPage } from './import/ImportPage'
import { LanguagesPage } from './languages/LanguagesPage'
import { LeaguesPage } from './leagues/LeaguesPage'
import { AudioLibraryPage } from './library/AudioLibraryPage'
import { DashboardPage } from './learners/DashboardPage'
import { LearnerPage } from './learners/LearnerPage'
import { LearnersPage } from './learners/LearnersPage'
import { AppShell } from './shell/AppShell'
import { LetterPage } from './sounds/LetterPage'
import { RecordSessionPage } from './sounds/RecordSessionPage'
import { SoundChartPage } from './sounds/SoundChartPage'
import { SoundsPage } from './sounds/SoundsPage'
import { UploadFilesPage } from './sounds/UploadFilesPage'
import { TeamPage } from './team/TeamPage'
import { AppUpdatesPage } from './updates/AppUpdatesPage'
import { CourseList } from './tree/CourseList'
import { CourseTree } from './tree/CourseTree'
import { VocabularyPage } from './vocab/VocabularyPage'
import { VoicesPage } from './voices/VoicesPage'
import { LessonPage } from './workbook/LessonPage'
import { WorkbookPage } from './workbook/WorkbookPage'

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
            <Route path="/workbook" element={<CourseList key="workbook" purpose="workbook" />} />
            <Route path="/courses/:courseId/workbook" element={<WorkbookPage />} />
            <Route path="/courses/:courseId/workbook/lessons/:lessonRef" element={<LessonPage />} />
            <Route path="/languages" element={<SuperOnly><LanguagesPage /></SuperOnly>} />
            <Route path="/sounds" element={<SoundsPage />} />
            <Route path="/sounds/:language" element={<SoundChartPage />} />
            <Route path="/sounds/:language/letters/:letterId" element={<LetterPage />} />
            <Route path="/sounds/:language/record" element={<RecordSessionPage />} />
            <Route path="/sounds/:language/upload" element={<UploadFilesPage />} />
            <Route path="/voices" element={<SuperOnly><VoicesPage /></SuperOnly>} />
            <Route path="/audio-library" element={<SuperOnly><AudioLibraryPage /></SuperOnly>} />
            <Route path="/guide" element={<GuidePage />} />
            <Route path="/team" element={<SuperOnly><TeamPage /></SuperOnly>} />
            <Route path="/dashboard" element={<SuperOnly><DashboardPage /></SuperOnly>} />
            <Route path="/learners" element={<SuperOnly><LearnersPage /></SuperOnly>} />
            <Route path="/learners/:learnerId" element={<SuperOnly><LearnerPage /></SuperOnly>} />
            <Route path="/feedback" element={<SuperOnly><FeedbackPage /></SuperOnly>} />
            <Route path="/leagues" element={<SuperOnly><LeaguesPage /></SuperOnly>} />
            <Route path="/activity" element={<SuperOnly><ActivityPage /></SuperOnly>} />
            <Route path="/app-updates" element={<SuperOnly><AppUpdatesPage /></SuperOnly>} />
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

/** A configuration or learners page: a course admin who opens its address
 * is sent to the workspace instead (intent 028). */
function SuperOnly({ children }: { children: ReactNode }) {
  return useAccess().isSuper ? children : <Navigate to="/" replace />
}
