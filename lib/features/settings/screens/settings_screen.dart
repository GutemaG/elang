import 'package:flutter/material.dart';

import '../../../shared/models/language_names.dart';
import '../../../shared/services/course_api.dart';
import '../../../shared/services/reminders/reminder_service.dart';
import '../../../shared/services/session_api.dart';
import '../../../shared/services/session_repository.dart';
import '../../../shared/services/sound_preference_repository.dart';
import '../../../shared/services/user_preferences_api.dart';
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
import '../../../shared/widgets/selectable_option_card.dart';
import '../../auth/auth_routes.dart';
import '../../courses/course_picker.dart';
import '../state/settings_controller.dart';

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

const List<_GoalOption> _goalOptions = [
  _GoalOption(
    minutes: 5,
    title: 'Casual',
    description: 'Gentle warm up',
    xpPerDay: 10,
    icon: Icons.eco,
  ),
  _GoalOption(
    minutes: 10,
    title: 'Regular',
    description: 'Steady progress',
    xpPerDay: 20,
    icon: Icons.local_cafe,
  ),
  _GoalOption(
    minutes: 15,
    title: 'Serious',
    description: 'Fast retention',
    xpPerDay: 30,
    icon: Icons.coffee,
  ),
  _GoalOption(
    minutes: 20,
    title: 'Intense',
    description: 'Speed fluency',
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
  });

  final SessionApi sessionApi;
  final CourseApi courseApi;
  final UserPreferencesApi userPreferencesApi;
  final SoundPreferenceRepository soundPreferenceRepository;
  final SessionRepository sessionRepository;

  /// The 8 pm reminder the Notifications switch controls
  /// (021-daily-reminder); `null` keeps the switch a saved preference only.
  final ReminderService? reminders;

  /// The Appearance row (System, Light or Dark).
  static const appearanceRowKey = ValueKey('settings-appearance');

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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
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

  Future<void> _pickCourse() async {
    final switched = await pickAndSwitchCourse(
      context,
      courseApi: widget.courseApi,
    );
    if (switched != null) {
      _controller.applySwitchedCourse(switched);
    }
  }

  Future<void> _confirmLogout() async {
    // Signing out deletes nothing, so the confirm is a plain primary.
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: 'Log out?',
      message: "You'll need to sign in again to continue learning.",
      confirmLabel: 'Log out',
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
    final option = _goalOptions.where((o) => o.minutes == minutes).firstOrNull;
    return option == null
        ? 'Unknown'
        : '${option.title} · ${option.minutes} min/day';
  }

  String _courseLabel() {
    final course = _controller.activeCourse;
    if (course != null) return course.title;
    final language = _controller.selectedLanguage;
    return language == null ? 'Unknown' : languageName(language);
  }

  String _providerLabel(String? provider) {
    switch (provider) {
      case 'google':
        return 'Signed in with Google';
      case 'apple':
        return 'Signed in with Apple';
      default:
        return 'Signed in';
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
                tooltip: 'Back',
                onPressed: () => Navigator.of(context).maybePop(),
              )
            : null,
        title: 'Settings',
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
              title: "Couldn't load your settings",
              onRetry: _controller.load,
              retryLabel: 'Retry',
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
            const SectionHeader(title: 'Learning'),
            ListRowGroup(
              children: [
                ListRow(
                  icon: Icons.flag,
                  tone: AppTone.secondary,
                  title: 'Daily goal',
                  subtitle: _goalLabel(_controller.dailyGoalMinutes),
                  onTap: _pickGoal,
                ),
                ListRow(
                  icon: Icons.translate,
                  tone: AppTone.primary,
                  title: 'Course',
                  subtitle: _courseLabel(),
                  onTap: _pickCourse,
                ),
              ],
            ),
            const SectionHeader(title: 'Preferences'),
            ListRowGroup(
              children: [
                SwitchRow(
                  icon: Icons.notifications,
                  title: 'Notifications',
                  subtitle: "A reminder at 8 pm if you haven't practised",
                  value: _controller.notificationEnabled,
                  onChanged: _controller.updateNotificationEnabled,
                ),
                // Wanted on, but the phone blocks it (021-daily-reminder).
                if (_controller.notificationsBlocked)
                  ListRow(
                    key: const ValueKey('notifications-blocked'),
                    icon: Icons.notifications_off,
                    title: "Blocked in your phone's settings",
                    subtitle: 'Tap to allow notifications',
                    onTap: _controller.openNotificationSettings,
                  ),
                SwitchRow(
                  icon: Icons.volume_up,
                  title: 'Sound',
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
                    title: 'Appearance',
                    subtitle: _appearanceOptions
                        .firstWhere((o) => o.mode == appearance.value)
                        .title,
                    onTap: () => _pickAppearance(appearance),
                  ),
              ],
            ),
            const SectionHeader(title: 'About'),
            ListRowGroup(
              children: [
                // Flutter's licence page: every package's licence, and the
                // credits of the pictures the app ships (intent 019, story
                // 005).
                ListRow(
                  icon: Icons.info_outline,
                  title: 'Licences',
                  subtitle: 'Open-source software and picture credits',
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: 'Buna',
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.spaceLg),
            AppButton.secondary(label: 'Log out', onPressed: _confirmLogout),
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

const _appearanceOptions = [
  _AppearanceOption(
    ThemeMode.system,
    Icons.brightness_auto,
    'System',
    'Match your phone',
  ),
  _AppearanceOption(ThemeMode.light, Icons.light_mode, 'Light', 'Always light'),
  _AppearanceOption(ThemeMode.dark, Icons.dark_mode, 'Dark', 'Always dark'),
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
                'Appearance',
                style: AppTypography.headlineSm.copyWith(
                  color: context.colors.onSurface,
                ),
              ),
            ),
            AppIconButton(
              icon: Icons.close,
              tooltip: 'Close',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.spaceXs),
        for (final option in _appearanceOptions)
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
                'Daily goal',
                style: AppTypography.headlineSm.copyWith(
                  color: context.colors.onSurface,
                ),
              ),
            ),
            AppIconButton(
              icon: Icons.close,
              tooltip: 'Close',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.spaceXs),
        for (final option in _goalOptions)
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
              title: '${option.title} · ${option.minutes} min/day',
              subtitle: '${option.description} · +${option.xpPerDay} XP/day',
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
