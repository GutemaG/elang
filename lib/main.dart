import 'package:flutter/material.dart';

import 'features/auth/auth_dependencies.dart';
import 'features/auth/auth_routes.dart';
import 'features/lesson/lesson_dependencies.dart';
import 'features/lesson/screens/skill_tree_dashboard_screen.dart';
import 'shared/theme/app_theme.dart';

void main() {
  final authDependencies = AuthDependencies();
  runApp(
    BunaApp(
      authDependencies: authDependencies,
      lessonDependencies: LessonDependencies(
        sessionRepository: authDependencies.sessionRepository,
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
  });

  final AuthDependencies authDependencies;
  final LessonDependencies lessonDependencies;

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
        ),
      ),
    );
  }
}
