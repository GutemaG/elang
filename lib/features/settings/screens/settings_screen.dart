import 'package:flutter/material.dart';

import '../../../shared/l10n/app_language.dart';
import '../../../shared/models/course.dart';
import '../../../shared/models/language_names.dart';
import '../../../shared/services/course_api.dart';
import '../../../shared/services/reminders/reminder_service.dart';
import '../../../shared/services/session_api.dart';
import '../../../shared/services/session_repository.dart';
import '../../../shared/services/sound_preference_repository.dart';
import '../../../shared/services/user_preferences_api.dart';
import '../../../shared/settings/account_settings_api.dart';
import '../../../shared/settings/known_settings.dart';
import '../../../shared/settings/remote_settings_controller.dart';
import '../../../shared/theme/app_theme_context.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_tone.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/theme/appearance.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_icon_button.dart';
import '../../../shared/widgets/app_page.dart';
import '../../../shared/widgets/app_sheet.dart';
import '../../../shared/widgets/app_status.dart';
import '../../../shared/widgets/course_glyph.dart';
import '../../../shared/widgets/selectable_option_card.dart';
import '../../auth/auth_routes.dart';
import '../../feedback/feedback_api.dart';
import '../../feedback/feedback_screen.dart';
import '../../courses/course_picker.dart';
import '../state/settings_controller.dart';
import '../../../l10n/app_localizations.dart';

/// A single daily-goal preset -- same 4 presets/labels as
/// `DailyGoalSelectionScreen`'s `GoalOption`, duplicated here rather than
/// shared/extracted, matching this codebase's existing convention of each
/// screen keeping its own private option list.
class _GoalOption {
  const _GoalOption({
    required this.minutes,
    required this.title,
    required this.description,
    required this.xpPerDay,
    required this.icon,
  });

  final int minutes;
  final String title;
  final String description;
  final int xpPerDay;
  final IconData icon;
}

/// The four presets, in the app language [l].
List<_GoalOption> _goalOptions(AppLocalizations l) => [
  _GoalOption(
    minutes: 5,
    title: l.goalCasual,
    description: l.goalCasualDescription,
    xpPerDay: 10,
    icon: Icons.eco,
  ),
  _GoalOption(
    minutes: 10,
    title: l.goalRegular,
    description: l.goalRegularDescription,
    xpPerDay: 20,
    icon: Icons.local_cafe,
  ),
  _GoalOption(
    minutes: 15,
    title: l.goalSerious,
    description: l.goalSeriousDescription,
    xpPerDay: 30,
    icon: Icons.coffee,
  ),
  _GoalOption(
    minutes: 20,
    title: l.goalIntense,
    description: l.goalIntenseDescription,
    xpPerDay: 50,
    icon: Icons.local_fire_department,
  ),
];

/// Story 001 (`005-profile-and-settings`): view/edit language, daily goal,
/// and notification preference (real, via `013-user-preferences-service`),
/// toggle sound (local, gates `AnswerFeedbackPlayer`), and log out.
///
/// Drawn on the design library (018-mobile-design-system, bolt 049): grouped
/// rows under section headings, green switches and a full-width "Log out"
/// at the end, after Material 3 lists and Duolingo's settings.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.sessionApi,
    required this.courseApi,
    required this.userPreferencesApi,
    required this.soundPreferenceRepository,
    required this.sessionRepository,
    this.reminders,
    this.accountSettingsApi,
    this.feedbackApi,
    this.onCourseChanged,
  });

  final SessionApi sessionApi;
  final CourseApi courseApi;
  final UserPreferencesApi userPreferencesApi;
  final SoundPreferenceRepository soundPreferenceRepository;
  final SessionRepository sessionRepository;

  /// The 8 pm reminder the Notifications switch controls
  /// (021-daily-reminder); `null` keeps the switch a saved preference only.
  final ReminderService? reminders;

  /// Saves account settings ("Show me in leagues", 023-weekly-leagues);
  /// `null` leaves the League section out.
  final AccountSettingsApi? accountSettingsApi;

  /// Sends feedback (027-learner-feedback); `null` leaves the "Send
  /// feedback" row out.
  final FeedbackApi? feedbackApi;

  /// Told when the learner switches course here, so the learning path,
  /// open beside it in the bottom bar, follows.
  final ValueChanged<Course>? onCourseChanged;

  /// The "Send feedback" row.
  static const sendFeedbackKey = ValueKey('settings-send-feedback');

  /// The "Show me in leagues" switch.
  static const showInLeaguesKey = ValueKey('settings-show-in-leagues');

  /// The Appearance row (System, Light or Dark).
  static const appearanceRowKey = ValueKey('settings-appearance');

  /// The App language row (024-app-localization).
  static const appLanguageRowKey = ValueKey('settings-app-language');

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  late final SettingsController _controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = SettingsController(
      sessionApi: widget.sessionApi,
      courseApi: widget.courseApi,
      userPreferencesApi: widget.userPreferencesApi,
      soundPreferenceRepository: widget.soundPreferenceRepository,
      sessionRepository: widget.sessionRepository,
      reminders: widget.reminders,
    );
    _controller.addListener(_onControllerChanged);
    _controller.load();
  }

  String? _lastShownError;

  void _onControllerChanged() {
    setState(() {});
    final error = _controller.errorMessage;
    if (error != null && error != _lastShownError) {
      _lastShownError = error;
      // The controller says what failed; the words are the app's.
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.saveChangeFailed)));
    }
  }

  /// Back from the phone's settings: notifications may be allowed now.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _controller.recheckNotificationPermission();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickGoal() async {
    final minutes = await showAppSheet<int>(
      context: context,
      builder: (context) => _GoalSheet(selected: _controller.dailyGoalMinutes),
    );
    if (minutes != null) {
      await _controller.updateDailyGoalMinutes(minutes);
    }
  }

  Future<void> _pickAppearance(AppearanceController appearance) async {
    final mode = await showAppSheet<ThemeMode>(
      context: context,
      builder: (context) => _AppearanceSheet(selected: appearance.value),
    );
    if (mode != null) await appearance.choose(mode);
  }

  Future<void> _pickAppLanguage(AppLanguageController appLanguage) async {
    final code = await showAppSheet<String>(
      context: context,
      builder: (context) =>
          _AppLanguageSheet(selected: appLanguage.language.code),
    );
    if (code != null && code != appLanguage.language.code) {
      await appLanguage.choose(code);
    }
  }

  Future<void> _setShowInLeagues(
    RemoteSettingsController settings,
    AccountSettingsApi api,
    bool show,
  ) async {
    try {
      await settings.updateAccount({
        AccountSettings.showInLeagues.key: show,
      }, api);
    } on AccountSettingsException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.saveFailedCheckConnection)),
      );
    }
  }

  Future<void> _pickCourse() async {
    final switched = await pickAndSwitchCourse(
      context,
      courseApi: widget.courseApi,
    );
    if (switched != null) {
      _controller.applySwitchedCourse(switched);
      widget.onCourseChanged?.call(switched);
    }
  }

  Future<void> _confirmLogout() async {
    // Signing out deletes nothing, so the confirm is a plain primary.
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: context.l10n.logOutQuestion,
      message: context.l10n.logOutMessage,
      confirmLabel: context.l10n.logOut,
      icon: Icons.logout,
    );
    if (confirmed != true) return;

    await _controller.logout();
    if (!mounted) return;
    // Clears the *entire* stack, not just a replace -- Settings sits on
    // top of the `home` route via `Navigator.push`, unlike every onboarding
    // screen (which only ever needed `pushReplacementNamed`).
    Navigator.of(context)
        .pushNamedAndRemoveUntil(AuthRoutes.signIn, (route) => false);
  }

  String _goalLabel(int? minutes) {
    final l = context.l10n;
    final option = _goalOptions(l)
        .where((o) => o.minutes == minutes)
        .firstOrNull;
    return option == null
        ? l.unknown
        : '${option.title} · ${l.minutesPerDay(option.minutes)}';
  }

  String _courseLabel() {
    final course = _controller.activeCourse;
    if (course != null) return course.title;
    final language = _controller.selectedLanguage;
    return language == null ? context.l10n.unknown : languageName(language);
  }

  String _providerLabel(String? provider) {
    switch (provider) {
      case 'google':
        return context.l10n.signedInWithGoogle;
      case 'apple':
        return context.l10n.signedInWithApple;
      default:
        return context.l10n.signedIn;
    }
  }

  @override
  Widget build(BuildContext context) {
    final loaded = _controller.loadStatus == SettingsLoadStatus.loaded;
    return AppPage(
      topBar: AppTopBar(
        leading: Navigator.of(context).canPop()
            ? AppIconButton(
                icon: Icons.arrow_back,
                tooltip: context.l10n.back,
                onPressed: () => Navigator.of(context).maybePop(),
              )
            : null,
        title: context.l10n.settingsTitle,
      ),
      // Loading and errors sit in the middle of the page; the list scrolls.
      scrollable: loaded,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    switch (_controller.loadStatus) {
      case SettingsLoadStatus.loading:
        return const Center(child: LoadingState());
      case SettingsLoadStatus.error:
        return Center(
          child: SingleChildScrollView(
            child: ErrorState(
              title: context.l10n.settingsLoadFailed,
              onRetry: _controller.load,
              retryLabel: context.l10n.retry,
            ),
          ),
        );
      case SettingsLoadStatus.loaded:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppCard(
              child: _ProfileHeader(
                name: _controller.displayName,
                email: _controller.email,
                photoUrl: _controller.photoUrl,
                providerLabel: _providerLabel(_controller.authProvider),
              ),
            ),
            SectionHeader(title: context.l10n.sectionLearning),
            ListRowGroup(
              children: [
                ListRow(
                  icon: Icons.flag,
                  tone: AppTone.secondary,
                  title: context.l10n.dailyGoal,
                  subtitle: _goalLabel(_controller.dailyGoalMinutes),
                  onTap: _pickGoal,
                ),
                ListRow(
                  icon: Icons.translate,
                  tone: AppTone.primary,
                  title: context.l10n.course,
                  subtitle: _courseLabel(),
                  onTap: _pickCourse,
                ),
              ],
            ),
            SectionHeader(title: context.l10n.sectionPreferences),
            ListRowGroup(
              children: [
                SwitchRow(
                  icon: Icons.notifications,
                  title: context.l10n.notifications,
                  subtitle: context.l10n.notificationsSubtitle,
                  value: _controller.notificationEnabled,
                  onChanged: _controller.updateNotificationEnabled,
                ),
                // Wanted on, but the phone blocks it (021-daily-reminder).
                if (_controller.notificationsBlocked)
                  ListRow(
                    key: const ValueKey('notifications-blocked'),
                    icon: Icons.notifications_off,
                    title: context.l10n.notificationsBlocked,
                    subtitle: context.l10n.notificationsAllow,
                    onTap: _controller.openNotificationSettings,
                  ),
                SwitchRow(
                  icon: Icons.volume_up,
                  title: context.l10n.sound,
                  value: _controller.soundEnabled,
                  onChanged: _controller.updateSoundEnabled,
                ),
                // System, Light or Dark (022-light-and-dark-themes), kept
                // on the phone. The app always provides it; a screen
                // pumped on its own may not.
                if (AppearanceScope.maybeOf(context) case final appearance?)
                  ListRow(
                    key: SettingsScreen.appearanceRowKey,
                    icon: Icons.contrast,
                    title: context.l10n.appearance,
                    subtitle: _appearanceOptions(context.l10n)
                        .firstWhere((o) => o.mode == appearance.value)
                        .title,
                    onTap: () => _pickAppearance(appearance),
                  ),
                // English, Amharic or Afaan Oromo (024-app-localization),
                // kept on the phone and the account.
                if (AppLanguageScope.maybeOf(context) case final appLanguage?)
                  ListRow(
                    key: SettingsScreen.appLanguageRowKey,
                    icon: Icons.translate,
                    title: context.l10n.appLanguageTitle,
                    subtitle: appLanguage.language.nativeName,
                    onTap: () => _pickAppLanguage(appLanguage),
                  ),
              ],
            ),
            // 023-weekly-leagues, story 007. The app always provides the
            // settings scope; a screen pumped on its own may not.
            if ((
                  RemoteSettingsScope.maybeOf(context),
                  widget.accountSettingsApi,
                )
                case (final settings?, final api?)) ...[
              SectionHeader(title: context.l10n.sectionLeague),
              ListRowGroup(
                children: [
                  SwitchRow(
                    key: SettingsScreen.showInLeaguesKey,
                    icon: Icons.emoji_events,
                    title: context.l10n.showInLeagues,
                    subtitle: context.l10n.showInLeaguesSubtitle,
                    value: settings.account.get(AccountSettings.showInLeagues),
                    onChanged: (show) => _setShowInLeagues(settings, api, show),
                  ),
                ],
              ),
            ],
            SectionHeader(title: context.l10n.sectionAbout),
            ListRowGroup(
              children: [
                if (widget.feedbackApi case final api?)
                  ListRow(
                    key: SettingsScreen.sendFeedbackKey,
                    icon: Icons.feedback,
                    tone: AppTone.primary,
                    title: context.l10n.sendFeedback,
                    subtitle: context.l10n.sendFeedbackSubtitle,
                    onTap: () => Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) => FeedbackScreen(api: api),
                      ),
                    ),
                  ),
                // Flutter's licence page: every package's licence, and the
                // credits of the pictures the app ships (intent 019, story
                // 005).
                ListRow(
                  icon: Icons.info_outline,
                  title: context.l10n.licences,
                  subtitle: context.l10n.licencesSubtitle,
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: 'Buna',
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.spaceLg),
            AppButton.exit(
              label: context.l10n.logOut,
              leading: const Icon(Icons.logout),
              onPressed: _confirmLogout,
            ),
          ],
        );
    }
  }
}

class _AppearanceOption {
  const _AppearanceOption(this.mode, this.icon, this.title, this.description);

  final ThemeMode mode;
  final IconData icon;
  final String title;
  final String description;
}

/// System, Light and Dark, in the app language [l].
List<_AppearanceOption> _appearanceOptions(AppLocalizations l) => [
  _AppearanceOption(
    ThemeMode.system,
    Icons.brightness_auto,
    l.appearanceSystem,
    l.appearanceSystemDescription,
  ),
  _AppearanceOption(
    ThemeMode.light,
    Icons.light_mode,
    l.appearanceLight,
    l.appearanceLightDescription,
  ),
  _AppearanceOption(
    ThemeMode.dark,
    Icons.dark_mode,
    l.appearanceDark,
    l.appearanceDarkDescription,
  ),
];

/// The Appearance picker: System, Light and Dark as option cards, the
/// current one selected. Pops with the chosen mode; a dismiss pops `null`.
class _AppearanceSheet extends StatelessWidget {
  const _AppearanceSheet({required this.selected});

  final ThemeMode selected;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                context.l10n.appearance,
                style: AppTypography.headlineSm.copyWith(
                  color: context.colors.onSurface,
                ),
              ),
            ),
            AppIconButton(
              icon: Icons.close,
              tooltip: context.l10n.close,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.spaceXs),
        for (final option in _appearanceOptions(context.l10n))
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.spaceSm),
            child: SelectableOptionCard(
              leading: IconBadge(
                icon: option.icon,
                tone: selected == option.mode
                    ? AppTone.primary
                    : AppTone.neutral,
                size: 48,
                square: true,
              ),
              title: option.title,
              subtitle: option.description,
              selected: selected == option.mode,
              onTap: () => Navigator.of(context).pop(option.mode),
            ),
          ),
      ],
    );
  }
}

/// The App language picker: each language by its own name, with its
/// English name under it, the current one selected. Pops with the chosen
/// code; a dismiss pops `null`.
class _AppLanguageSheet extends StatelessWidget {
  const _AppLanguageSheet({required this.selected});

  final String selected;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                context.l10n.appLanguageTitle,
                style: AppTypography.forText(
                  AppTypography.headlineSm.copyWith(
                    color: context.colors.onSurface,
                  ),
                  context.l10n.appLanguageTitle,
                ),
              ),
            ),
            AppIconButton(
              icon: Icons.close,
              tooltip: context.l10n.close,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.spaceXs),
        for (final language in AppLanguage.all)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.spaceSm),
            child: SelectableOptionCard(
              key: ValueKey('app-language-${language.code}'),
              leading: CourseGlyph(languageCode: language.code, size: 48),
              title: language.nativeName,
              subtitle: language.englishName,
              selected: selected == language.code,
              onTap: () => Navigator.of(context).pop(language.code),
            ),
          ),
      ],
    );
  }
}

/// The daily-goal picker: the onboarding screen's four goal cards in the
/// library sheet. Pops with the chosen minutes; a dismiss pops `null`.
class _GoalSheet extends StatelessWidget {
  const _GoalSheet({required this.selected});

  final int? selected;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                context.l10n.dailyGoal,
                style: AppTypography.headlineSm.copyWith(
                  color: context.colors.onSurface,
                ),
              ),
            ),
            AppIconButton(
              icon: Icons.close,
              tooltip: context.l10n.close,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.spaceXs),
        for (final option in _goalOptions(context.l10n))
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.spaceSm),
            child: SelectableOptionCard(
              leading: IconBadge(
                icon: option.icon,
                tone: selected == option.minutes
                    ? AppTone.primary
                    : AppTone.secondary,
                size: 48,
                square: true,
              ),
              title:
                  '${option.title} · ${context.l10n.minutesPerDay(option.minutes)}',
              subtitle:
                  '${option.description} · ${context.l10n.xpPerDay(option.xpPerDay)}',
              selected: selected == option.minutes,
              onTap: () => Navigator.of(context).pop(option.minutes),
            ),
          ),
      ],
    );
  }
}

/// Who is signed in: the provider's photo (initials when there is none, or
/// it cannot load -- offline, say), name and email, and which provider.
/// Whatever is missing is simply left out; with nothing at all it is just
/// the provider line, which is what a session from before this showed.
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.name,
    required this.email,
    required this.photoUrl,
    required this.providerLabel,
  });

  final String? name;
  final String? email;
  final String? photoUrl;
  final String providerLabel;

  String get _initials {
    final source = name ?? email;
    if (source == null) return '?';
    final words = source.split(RegExp(r'[\s@.]+')).where((w) => w.isNotEmpty);
    return words.take(2).map((w) => w.characters.first.toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    final url = photoUrl;
    final title = name ?? email;
    return Row(
      children: [
        CircleAvatar(
          radius: 32,
          backgroundColor: context.colors.primaryContainer,
          foregroundImage: url == null ? null : NetworkImage(url),
          // A photo that fails to load falls back to the initials below.
          onForegroundImageError: url == null ? null : (_, _) {},
          child: Text(
            _initials,
            style: AppTypography.headlineSm.copyWith(
              color: context.colors.onPrimary,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.spaceMd),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title != null)
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.headlineSm.copyWith(
                    color: context.colors.onSurface,
                  ),
                ),
              if (name != null && email != null)
                Text(
                  email!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySm.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              Text(
                providerLabel,
                style: AppTypography.bodySm.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
