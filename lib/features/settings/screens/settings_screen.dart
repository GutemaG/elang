import 'package:flutter/material.dart';

import '../../../shared/models/language_names.dart';
import '../../../shared/services/course_api.dart';
import '../../../shared/services/session_api.dart';
import '../../../shared/services/session_repository.dart';
import '../../../shared/services/sound_preference_repository.dart';
import '../../../shared/services/user_preferences_api.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/selectable_option_card.dart';
import '../../../shared/widgets/tactile_button.dart';
import '../../auth/auth_routes.dart';
import '../../courses/course_picker.dart';
import '../state/settings_controller.dart';

/// A single daily-goal preset -- same 4 presets/labels as
/// `DailyGoalSelectionScreen`'s `GoalOption`, duplicated here rather than
/// shared/extracted, matching this codebase's existing convention of each
/// screen keeping its own private option list.
class _GoalOption {
  const _GoalOption({required this.minutes, required this.title, required this.icon});

  final int minutes;
  final String title;
  final IconData icon;
}

const List<_GoalOption> _goalOptions = [
  _GoalOption(minutes: 5, title: 'Casual', icon: Icons.eco),
  _GoalOption(minutes: 10, title: 'Regular', icon: Icons.local_cafe),
  _GoalOption(minutes: 15, title: 'Serious', icon: Icons.coffee),
  _GoalOption(minutes: 20, title: 'Intense', icon: Icons.local_fire_department),
];

/// Story 001 (`005-profile-and-settings`): view/edit language, daily goal,
/// and notification preference (real, via `013-user-preferences-service`),
/// toggle sound (local, gates `AnswerFeedbackPlayer`), and log out.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.sessionApi,
    required this.courseApi,
    required this.userPreferencesApi,
    required this.soundPreferenceRepository,
    required this.sessionRepository,
  });

  final SessionApi sessionApi;
  final CourseApi courseApi;
  final UserPreferencesApi userPreferencesApi;
  final SoundPreferenceRepository soundPreferenceRepository;
  final SessionRepository sessionRepository;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final SettingsController _controller;

  @override
  void initState() {
    super.initState();
    _controller = SettingsController(
      sessionApi: widget.sessionApi,
      courseApi: widget.courseApi,
      userPreferencesApi: widget.userPreferencesApi,
      soundPreferenceRepository: widget.soundPreferenceRepository,
      sessionRepository: widget.sessionRepository,
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickGoal() async {
    final minutes = await showModalBottomSheet<int>(
      context: context,
      builder: (context) => _OptionSheet(
        title: 'Daily goal',
        children: [
          for (final option in _goalOptions)
            SelectableOptionCard(
              leading: Icon(option.icon, color: AppColors.primaryContainer),
              title: '${option.title} · ${option.minutes} min/day',
              subtitle: '',
              selected: _controller.dailyGoalMinutes == option.minutes,
              onTap: () => Navigator.of(context).pop(option.minutes),
            ),
        ],
      ),
    );
    if (minutes != null) {
      await _controller.updateDailyGoalMinutes(minutes);
    }
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text("You'll need to sign in again to continue learning."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _controller.logout();
    if (!mounted) return;
    // Clears the *entire* stack, not just a replace -- Settings sits on
    // top of the `home` route via `Navigator.push`, unlike every onboarding
    // screen (which only ever needed `pushReplacementNamed`).
    Navigator.of(context).pushNamedAndRemoveUntil(AuthRoutes.signIn, (route) => false);
  }

  String _goalLabel(int? minutes) {
    final option = _goalOptions.where((o) => o.minutes == minutes).firstOrNull;
    return option == null ? 'Unknown' : '${option.title} · ${option.minutes} min/day';
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    switch (_controller.loadStatus) {
      case SettingsLoadStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case SettingsLoadStatus.error:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.spaceLg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Couldn't load your settings",
                  style: AppTypography.headlineSm.copyWith(color: AppColors.onSurface),
                ),
                const SizedBox(height: AppSpacing.spaceMd),
                TactileButton(label: 'Retry', onPressed: _controller.load),
              ],
            ),
          ),
        );
      case SettingsLoadStatus.loaded:
        return ListView(
          padding: const EdgeInsets.all(AppSpacing.marginMobile),
          children: [
            _ProfileHeader(
              name: _controller.displayName,
              email: _controller.email,
              photoUrl: _controller.photoUrl,
              providerLabel: _providerLabel(_controller.authProvider),
            ),
            const SizedBox(height: AppSpacing.spaceLg),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Daily goal'),
              subtitle: Text(_goalLabel(_controller.dailyGoalMinutes)),
              trailing: const Icon(Icons.chevron_right),
              onTap: _pickGoal,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Course'),
              subtitle: Text(_courseLabel()),
              trailing: const Icon(Icons.chevron_right),
              onTap: _pickCourse,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Notifications'),
              value: _controller.notificationEnabled,
              onChanged: _controller.updateNotificationEnabled,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Sound'),
              value: _controller.soundEnabled,
              onChanged: _controller.updateSoundEnabled,
            ),
            // Flutter's licence page: every package's licence, and the
            // credits of the pictures the app ships (intent 019, story 005).
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Licences'),
              subtitle: const Text('Open-source software and picture credits'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => showLicensePage(context: context, applicationName: 'Buna'),
            ),
            const SizedBox(height: AppSpacing.spaceLg),
            TactileButton(label: 'Log out', onPressed: _confirmLogout),
          ],
        );
    }
  }
}

class _OptionSheet extends StatelessWidget {
  const _OptionSheet({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.marginMobile),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTypography.headlineSm.copyWith(color: AppColors.onSurface)),
            const SizedBox(height: AppSpacing.spaceMd),
            for (final child in children)
              Padding(padding: const EdgeInsets.only(bottom: AppSpacing.spaceSm), child: child),
          ],
        ),
      ),
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
          backgroundColor: AppColors.primaryContainer,
          foregroundImage: url == null ? null : NetworkImage(url),
          // A photo that fails to load falls back to the initials below.
          onForegroundImageError: url == null ? null : (_, _) {},
          child: Text(
            _initials,
            style: AppTypography.headlineSm.copyWith(color: AppColors.onPrimary),
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
                  style: AppTypography.headlineSm.copyWith(color: AppColors.onSurface),
                ),
              if (name != null && email != null)
                Text(
                  email!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant),
                ),
              Text(
                providerLabel,
                style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
