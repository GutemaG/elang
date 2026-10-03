import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'features/auth/auth_dependencies.dart';
import 'features/auth/auth_routes.dart';
import 'features/lesson/lesson_dependencies.dart';
import 'features/league/league_dependencies.dart';
import 'features/lesson/screens/skill_tree_dashboard_screen.dart';
import 'features/settings/settings_dependencies.dart';
import 'features/updates/app_update_gate.dart';
import 'shared/l10n/app_language.dart';
import 'shared/licences/picture_credits.dart';
import 'shared/services/reminders/reminder_scheduler.dart';
import 'shared/services/reminders/reminder_service.dart';
import 'shared/services/app_config_api.dart';
import 'shared/services/app_updater.dart';
import 'shared/services/app_language_repository.dart';
import 'shared/services/appearance_repository.dart';
import 'shared/services/secure_storage_service.dart';
import 'shared/services/sound_preference_repository.dart';
import 'shared/settings/account_settings_api.dart';
import 'shared/settings/known_settings.dart';
import 'shared/settings/remote_settings_controller.dart';
import 'shared/settings/remote_settings_store.dart';
import 'shared/theme/app_theme.dart';
import 'shared/theme/app_theme_context.dart';
import 'shared/theme/appearance.dart';
import 'l10n/app_localizations.dart';

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
  // The app language (024-app-localization), read before the first frame
  // so the splash is already in it. It is sent to the account once the
  // dependencies below exist.
  final appLanguage = await AppLanguageController.load(
    AppLanguageRepository(storage: storage),
  );
  // The reminder speaks the app language, and is rewritten when it changes.
  reminders.words = () => lookupAppLocalizations(appLanguage.language.locale);
  appLanguage.addListener(() => unawaited(reminders.reschedule()));
  final authDependencies = AuthDependencies(
    storage: storage,
    // Each launch's session check (and the one right after sign-in) brings
    // the Notifications switch as the server has it, so a switch turned off
    // on another phone applies here, and the account's settings, among
    // them its app language.
    onSessionChecked: (user) => unawaited(() async {
      unawaited(reminders.setEnabled(user.notificationEnabled));
      await remoteSettings.applySession(user);
      await appLanguage.syncWithAccount(
        RemoteSettings(user.settings).get(AccountSettings.appLanguage),
      );
    }()),
  );
  final accountSettingsApi = HttpAccountSettingsApi(
    sessionRepository: authDependencies.sessionRepository,
  );
  appLanguage.send = (code) async {
    try {
      await remoteSettings.updateAccount({
        AccountSettings.appLanguage.key: code,
      }, accountSettingsApi);
      return true;
    } on AccountSettingsException {
      return false;
    }
  };
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
        appLanguage: appLanguage,
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
        // The weekly league (023-weekly-leagues).
        leagueDependencies: LeagueDependencies(
          storage: storage,
          sessionRepository: authDependencies.sessionRepository,
        ),
        // Required and offered app updates, checked against the
        // configuration above.
        updates: AppUpdates(
          updater: StoreAppUpdater(),
          settings: remoteSettings,
          storage: storage,
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
    required this.appLanguage,
    this.leagueDependencies,
    this.updates,
  });

  final AuthDependencies authDependencies;
  final LessonDependencies lessonDependencies;
  final SettingsDependencies settingsDependencies;

  /// The weekly league; `null` (tests) hides it.
  final LeagueDependencies? leagueDependencies;

  /// Required and offered app updates; `null` (tests) checks none.
  final AppUpdates? updates;

  /// System, Light or Dark: the learner's choice in Settings.
  final AppearanceController appearance;

  /// The language of the app's own words: the learner's choice in Settings
  /// or at sign-up (024-app-localization).
  final AppLanguageController appLanguage;

  @override
  Widget build(BuildContext context) {
    return AppearanceScope(
      controller: appearance,
      child: AppLanguageScope(
        controller: appLanguage,
        child: ListenableBuilder(
          listenable: Listenable.merge([appearance, appLanguage]),
          builder: (context, _) => _app(appearance.value, appLanguage.language),
        ),
      ),
    );
  }

  Widget _app(ThemeMode mode, AppLanguage language) {
    return MaterialApp(
      title: 'Buna',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: mode,
      locale: language.locale,
      localizationsDelegates: AppLanguage.delegates,
      supportedLocales: AppLanguage.locales,
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: AppTheme.systemBarsFor(
          context.colors,
          brightness: Theme.of(context).brightness,
        ),
        child: switch (updates) {
          final updates? => AppUpdateGate(
            updater: updates.updater,
            settings: updates.settings,
            storage: updates.storage,
            child: child!,
          ),
          null => child!,
        },
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
          league: leagueDependencies,
        ),
      ),
    );
  }
}
