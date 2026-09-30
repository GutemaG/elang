import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'features/auth/auth_dependencies.dart';
import 'features/auth/auth_routes.dart';
import 'features/lesson/lesson_dependencies.dart';
import 'features/lesson/screens/skill_tree_dashboard_screen.dart';
import 'features/settings/settings_dependencies.dart';
import 'shared/licences/picture_credits.dart';
import 'shared/services/reminders/reminder_scheduler.dart';
import 'shared/services/reminders/reminder_service.dart';
import 'shared/services/app_config_api.dart';
import 'shared/services/appearance_repository.dart';
import 'shared/services/secure_storage_service.dart';
import 'shared/services/sound_preference_repository.dart';
import 'shared/settings/remote_settings_controller.dart';
import 'shared/settings/remote_settings_store.dart';
import 'shared/theme/app_theme.dart';
import 'shared/theme/app_theme_context.dart';
import 'shared/theme/appearance.dart';

Future<void> main() async {
  // The dependencies below reach platform plugins as soon as they are
  // built (the sync engine asks connectivity_plus whether it is online), so
  // the binding has to exist before `runApp` would create it.
  WidgetsFlutterBinding.ensureInitialized();
  // The bundled sample pictures' credits, on the licence page settings
  // opens (019-image-choice-exercise-types, story 005).
  registerPictureCredits();
  // One store for the whole app, built first so the reminders below and
  // sign-in share it.
  final storage = FlutterSecureStorageService();
  // The 8 pm reminder (021-daily-reminder). The web can't schedule one.
  final reminders = ReminderService(
    scheduler: kIsWeb ? const NoReminderScheduler() : LocalReminderScheduler(),
    store: ReminderStore(storage: storage),
  );
  // Account settings and app configuration (022-light-and-dark-themes,
  // FR-10), from the copies saved on the phone, so they work offline.
  final remoteSettings = await RemoteSettingsController.load(
    store: RemoteSettingsStore(storage: storage),
    configApi: AppConfigApi(),
  );
  final authDependencies = AuthDependencies(
    storage: storage,
    // Each launch's session check brings the Notifications switch as the
    // server has it, so a switch turned off on another phone applies here,
    // and the account's settings.
    onSessionChecked: (user) {
      unawaited(reminders.setEnabled(user.notificationEnabled));
      unawaited(remoteSettings.applySession(user));
    },
  );
  // One learner's settings are never read for another.
  authDependencies.sessionRepository.addAccountChangedListener(
    () => unawaited(remoteSettings.forgetAccount()),
  );
  // In the background: opening the app never waits for the network.
  unawaited(remoteSettings.refreshConfig());
  // Shared with both LessonDependencies (gates AnswerFeedbackPlayer) and
  // SettingsDependencies (the toggle UI) -- same instance, so a flip is
  // visible on the very next graded answer, no restart needed.
  final soundPreferenceRepository = SoundPreferenceRepository(
    storage: authDependencies.storage,
  );
  // The Appearance choice (022-light-and-dark-themes), read before the
  // first frame so the splash is already in the chosen theme.
  final appearance = await AppearanceController.load(
    AppearanceRepository(storage: storage),
  );
  runApp(
    RemoteSettingsScope(
      controller: remoteSettings,
      child: BunaApp(
        appearance: appearance,
        authDependencies: authDependencies,
        lessonDependencies: LessonDependencies(
          sessionRepository: authDependencies.sessionRepository,
          soundPreferenceRepository: soundPreferenceRepository,
          reminders: reminders,
        ),
        settingsDependencies: SettingsDependencies(
          sessionRepository: authDependencies.sessionRepository,
          soundPreferenceRepository: soundPreferenceRepository,
        ),
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
    required this.appearance,
  });

  final AuthDependencies authDependencies;
  final LessonDependencies lessonDependencies;
  final SettingsDependencies settingsDependencies;

  /// System, Light or Dark: the learner's choice in Settings.
  final AppearanceController appearance;

  @override
  Widget build(BuildContext context) {
    return AppearanceScope(
      controller: appearance,
      child: ValueListenableBuilder(
        valueListenable: appearance,
        builder: (context, mode, _) => _app(mode),
      ),
    );
  }

  Widget _app(ThemeMode mode) {
    return MaterialApp(
      title: 'Buna',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: mode,
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: AppTheme.systemBarsFor(
          context.colors,
          brightness: Theme.of(context).brightness,
        ),
        child: child!,
      ),
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
          mediaCache: lessonDependencies.mediaCache,
          reminders: lessonDependencies.reminders,
          sessionRepository: settingsDependencies.sessionRepository,
          userPreferencesApi: settingsDependencies.userPreferencesApi,
          soundPreferenceRepository:
              settingsDependencies.soundPreferenceRepository,
        ),
      ),
    );
  }
}
