import 'package:flutter/material.dart';

import 'features/auth/auth_dependencies.dart';
import 'features/auth/auth_routes.dart';
import 'features/lesson/lesson_dependencies.dart';
import 'features/lesson/screens/skill_tree_dashboard_screen.dart';
import 'features/settings/settings_dependencies.dart';
import 'shared/licences/picture_credits.dart';
import 'shared/services/sound_preference_repository.dart';
import 'shared/theme/app_theme.dart';

void main() {
  // The dependencies below reach platform plugins as soon as they are
  // built (the sync engine asks connectivity_plus whether it is online), so
  // the binding has to exist before `runApp` would create it.
  WidgetsFlutterBinding.ensureInitialized();
  // The bundled sample pictures' credits, on the licence page settings
  // opens (019-image-choice-exercise-types, story 005).
  registerPictureCredits();
  final authDependencies = AuthDependencies();
  // Shared with both LessonDependencies (gates AnswerFeedbackPlayer) and
  // SettingsDependencies (the toggle UI) -- same instance, so a flip is
  // visible on the very next graded answer, no restart needed.
  final soundPreferenceRepository = SoundPreferenceRepository(
    storage: authDependencies.storage,
  );
  runApp(
    BunaApp(
      authDependencies: authDependencies,
      lessonDependencies: LessonDependencies(
        sessionRepository: authDependencies.sessionRepository,
        soundPreferenceRepository: soundPreferenceRepository,
      ),
      settingsDependencies: SettingsDependencies(
        sessionRepository: authDependencies.sessionRepository,
        soundPreferenceRepository: soundPreferenceRepository,
      ),
    ),
  );
}

/// App root: wires the auth/onboarding route table (see
/// `lib/features/auth/auth_routes.dart`) with a single [AuthDependencies]
/// bag shared by every screen in that flow, and supplies the skill-tree
/// dashboard (see [LessonDependencies]) as the `home` route's destination —
/// the post-sign-in landing screen as of `006-core-lesson-loop-ui`.
class BunaApp extends StatelessWidget {
  const BunaApp({
    super.key,
    required this.authDependencies,
    required this.lessonDependencies,
    required this.settingsDependencies,
  });

  final AuthDependencies authDependencies;
  final LessonDependencies lessonDependencies;
  final SettingsDependencies settingsDependencies;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Buna',
      theme: AppTheme.light,
      initialRoute: AuthRoutes.splash,
      routes: AuthRoutes.build(
        authDependencies,
        homeBuilder: (context) => SkillTreeDashboardScreen(
          lessonApi: lessonDependencies.lessonApi,
          audioPlayer: lessonDependencies.audioPlayer,
          feedbackPlayer: lessonDependencies.feedbackPlayer,
          connectivityMonitor: lessonDependencies.connectivityMonitor,
          lessonPackStore: lessonDependencies.lessonPackStore,
          lessonPackDownloader: lessonDependencies.lessonPackDownloader,
          syncEngine: lessonDependencies.syncEngine,
          courseApi: authDependencies.courseApi,
          courseCache: authDependencies.courseCache,
          sessionRepository: settingsDependencies.sessionRepository,
          userPreferencesApi: settingsDependencies.userPreferencesApi,
          soundPreferenceRepository:
              settingsDependencies.soundPreferenceRepository,
        ),
      ),
    );
  }
}
