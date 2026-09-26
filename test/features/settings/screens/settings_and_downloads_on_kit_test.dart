// Settings and downloads on the library (018-mobile-design-system, bolt
// 049, story 004): each is an AppPage with a titled top bar and a back
// arrow; settings groups its rows under section headings with green
// switches and a full-width Log out; the daily goal is a library sheet and
// log-out a library dialog; each download is a row with a delete button,
// deleting asks in the library dialog with a destructive primary, and an
// empty list is an EmptyState. Also the switch and snack-bar themes.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:elang/features/auth/auth_routes.dart';
import 'package:elang/features/lesson/screens/download_management_screen.dart';
import 'package:elang/features/settings/screens/settings_screen.dart';
import 'package:elang/shared/models/lesson_content.dart';
import 'package:elang/shared/models/session_state.dart';
import 'package:elang/shared/services/fake_course_api.dart';
import 'package:elang/shared/services/session_api.dart';
import 'package:elang/shared/services/session_repository.dart';
import 'package:elang/shared/services/sound_preference_repository.dart';
import 'package:elang/shared/services/sync_engine.dart';
import 'package:elang/shared/services/user_preferences_api.dart';
import 'package:elang/shared/services/user_preferences_api_exception.dart';
import 'package:elang/shared/theme/app_colors.dart';
import 'package:elang/shared/theme/app_theme.dart';
import 'package:elang/shared/theme/app_tone.dart';
import 'package:elang/shared/widgets/app_button.dart';
import 'package:elang/shared/widgets/app_card.dart';
import 'package:elang/shared/widgets/app_icon_button.dart';
import 'package:elang/shared/widgets/app_page.dart';
import 'package:elang/shared/widgets/app_sheet.dart';
import 'package:elang/shared/widgets/app_status.dart';
import 'package:elang/shared/widgets/selectable_option_card.dart';

import '../../../helpers/controllable_lesson_api.dart';
import '../../../helpers/fake_connectivity_monitor.dart';
import '../../../helpers/fake_lesson_pack_store.dart';
import '../../../helpers/fake_pending_sync_queue_store.dart';
import '../../../helpers/fake_user_preferences_api.dart';
import '../../../helpers/in_memory_secure_storage_service.dart';

/// [home] as the app's first page, or, with [pushed], opened on top of a
/// first page by tapping 'OPEN', as the dashboard opens settings.
Widget _app(Widget home, {bool pushed = false}) => MaterialApp(
  theme: AppTheme.light,
  home: pushed
      ? Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: GestureDetector(
                onTap: () =>
                    Navigator.of(context)
                        .push(MaterialPageRoute<void>(builder: (_) => home)),
                child: const Text('OPEN'),
              ),
            ),
          ),
        )
      : home,
  routes: {AuthRoutes.signIn: (_) => const Scaffold(body: Text('SIGN IN'))},
);

SessionApi _sessionApi({List<int> statuses = const []}) {
  var call = 0;
  return SessionApi(
    client: MockClient((request) async {
      final status = call < statuses.length ? statuses[call] : 200;
      call++;
      if (status != 200) return http.Response('', status);
      return http.Response(
        jsonEncode({
          'valid': true,
          'user': {
            'id': 'user-1',
            'selected_language': 'am',
            'daily_xp_target': 40, // Regular, 10 minutes
            'notification_enabled': true,
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }),
  );
}

class _SettingsRig {
  final preferences = FakeUserPreferencesApi()
    ..nextResult = const UpdatedPreferences(
      selectedLanguage: 'am',
      dailyXpTarget: 80, // Intense, 20 minutes
      notificationEnabled: true,
    );
  final sessions = SessionRepository(storage: InMemorySecureStorageService());

  Future<Widget> screen({List<int> statuses = const []}) async {
    await sessions.saveSession(
      SessionState(
        token: 'session-token',
        expiresAt: DateTime.now().add(const Duration(days: 1)),
        authProvider: 'google',
        displayName: 'Abebe Bikila',
        email: 'abebe@example.com',
      ),
    );
    return SettingsScreen(
      sessionApi: _sessionApi(statuses: statuses),
      courseApi: FakeCourseApi(),
      userPreferencesApi: preferences,
      soundPreferenceRepository: SoundPreferenceRepository(
        storage: InMemorySecureStorageService(),
      ),
      sessionRepository: sessions,
    );
  }
}

Future<_SettingsRig> _pumpSettings(
  WidgetTester tester, {
  bool pushed = false,
}) async {
  final rig = _SettingsRig();
  await tester.pumpWidget(_app(await rig.screen(), pushed: pushed));
  if (pushed) {
    await tester.tap(find.text('OPEN'));
  }
  await tester.pumpAndSettle();
  return rig;
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// The titles of the rows in each settings group, top to bottom.
List<List<String>> _groups(WidgetTester tester) => [
  for (final group in tester.widgetList<ListRowGroup>(
    find.byType(ListRowGroup),
  ))
    [
      for (final row in group.children)
        switch (row) {
          ListRow r => r.title,
          SwitchRow r => r.title,
          _ => '?',
        },
    ],
];

// ---------------------------------------------------------------------------
// Downloads.

const _pack = LessonContent(
  lessonId: 'lesson-a',
  skillId: 'skill-a',
  title: 'Alphabet & Fidel',
  beansAtStart: 5,
  beansMax: 5,
  exercises: [],
);

Future<FakeLessonPackStore> _pumpDownloads(
  WidgetTester tester, {
  bool empty = false,
  bool pushed = false,
}) async {
  final store = FakeLessonPackStore()..fakeSizeBytes = 2048;
  if (!empty) {
    await store.save(
      _pack,
      courseId: 'c-en-am',
      courseTitle: 'English to Amharic',
    );
  }
  await tester.pumpWidget(
    _app(
      DownloadManagementScreen(
        lessonPackStore: store,
        syncEngine: SyncEngine(
          lessonApi: ControllableLessonApi(),
          connectivityMonitor: FakeConnectivityMonitor(),
          queueStore: FakePendingSyncQueueStore(),
        ),
      ),
      pushed: pushed,
    ),
  );
  if (pushed) await tester.tap(find.text('OPEN'));
  await tester.pumpAndSettle();
  return store;
}

void main() {
  group('settings', () {
    testWidgets('is an AppPage titled Settings, whose back arrow pops it', (
      tester,
    ) async {
      await _pumpSettings(tester, pushed: true);

      expect(find.byType(AppPage), findsOneWidget);
      expect(
        tester.widget<AppTopBar>(find.byType(AppTopBar)).title,
        'Settings',
      );
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('OPEN'), findsOneWidget);
      expect(find.byType(SettingsScreen), findsNothing);
    });

    testWidgets('has no back arrow when it is the first page', (tester) async {
      await _pumpSettings(tester);
      expect(find.byTooltip('Back'), findsNothing);
    });

    testWidgets('loading is LoadingState; a failure is an ErrorState whose '
        'Retry button loads again', (tester) async {
      final rig = _SettingsRig();
      await tester.pumpWidget(_app(await rig.screen(statuses: [500])));
      expect(find.byType(LoadingState), findsOneWidget);
      await tester.pumpAndSettle();

      final error = tester.widget<ErrorState>(find.byType(ErrorState));
      expect(error.title, "Couldn't load your settings");
      expect(error.retryLabel, 'Retry');
      expect(tester.widget<AppPage>(find.byType(AppPage)).scrollable, isFalse);
      await tester.tap(find.widgetWithText(AppButton, 'Retry'));
      await tester.pumpAndSettle();
      expect(find.byType(ErrorState), findsNothing);
      expect(find.text('Abebe Bikila'), findsOneWidget);
      expect(tester.widget<AppPage>(find.byType(AppPage)).scrollable, isTrue);
    });

    testWidgets('the profile sits on a card at the top', (tester) async {
      await _pumpSettings(tester);
      final card = find.ancestor(
        of: find.text('Abebe Bikila'),
        matching: find.byType(AppCard),
      );
      expect(card, findsOneWidget);
      expect(
        tester.getTopLeft(card).dy,
        lessThan(tester.getTopLeft(find.text('Learning')).dy),
      );
    });

    testWidgets('rows are grouped on cards under Learning, Preferences and '
        'About, in that order', (tester) async {
      await _pumpSettings(tester);

      final headers = tester
          .widgetList<SectionHeader>(find.byType(SectionHeader))
          .map((h) => h.title)
          .toList();
      expect(headers, ['Learning', 'Preferences', 'About']);
      expect(_groups(tester), [
        ['Daily goal', 'Course'],
        ['Notifications', 'Sound'],
        ['Licences'],
      ]);
      for (final title in headers) {
        final header = tester.getTopLeft(find.text(title)).dy;
        expect(header, greaterThan(0), reason: title);
      }
    });

    testWidgets('the rows show their values and icons', (tester) async {
      await _pumpSettings(tester);

      final goal = tester.widget<ListRow>(
        find.widgetWithText(ListRow, 'Daily goal'),
      );
      expect(goal.subtitle, 'Regular · 10 min/day');
      expect(goal.icon, Icons.flag);
      expect(goal.tone, AppTone.secondary);
      final course = tester.widget<ListRow>(
        find.widgetWithText(ListRow, 'Course'),
      );
      expect(course.icon, Icons.translate);
      expect(course.tone, AppTone.primary);
      expect(course.onTap, isNotNull);
      expect(
        tester.widget<SwitchRow>(find.widgetWithText(SwitchRow, 'Sound')).icon,
        Icons.volume_up,
      );
    });

    testWidgets('tapping the switch itself flips it, as tapping the row '
        'does', (tester) async {
      final rig = await _pumpSettings(tester);
      final row = find.widgetWithText(SwitchRow, 'Notifications');
      // The fake answers with whatever the backend would keep.
      void backendKeeps(bool on) =>
          rig.preferences.nextResult = UpdatedPreferences(
            selectedLanguage: 'am',
            dailyXpTarget: 40,
            notificationEnabled: on,
          );

      backendKeeps(false);
      await _tap(
        tester,
        find.descendant(of: row, matching: find.byType(Switch)),
      );
      expect(rig.preferences.calls.single.notificationEnabled, isFalse);
      expect(tester.widget<SwitchRow>(row).value, isFalse);

      backendKeeps(true);
      await _tap(tester, find.text('Notifications'));
      expect(rig.preferences.calls.last.notificationEnabled, isTrue);
    });

    testWidgets('a screen reader hears one node per switch: its name and '
        'whether it is on, not a button', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pumpSettings(tester);

      expect(
        tester.getSemantics(
          find.ancestor(of: find.text('Sound'), matching: find.byType(ListRow)),
        ),
        isSemantics(
          label: 'Sound',
          hasToggledState: true,
          isToggled: true,
          isButton: false,
          hasTapAction: true,
        ),
      );
      semantics.dispose();
    });

    testWidgets('Log out is a full-width secondary button at the very end, '
        'and asks in the library dialog with a plain primary', (tester) async {
      await _pumpSettings(tester);

      final logOut = find.widgetWithText(AppButton, 'Log out');
      expect(
        tester.widget<AppButton>(logOut).variant,
        AppButtonVariant.secondary,
      );
      expect(tester.widget<AppButton>(logOut).expand, isTrue);
      await tester.ensureVisible(logOut);
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(logOut).dy,
        greaterThan(tester.getTopLeft(find.text('Licences')).dy),
      );

      await _tap(tester, logOut);
      expect(find.byType(AppDialogFrame), findsOneWidget);
      expect(find.text('Log out?'), findsOneWidget);
      final confirm = find.descendant(
        of: find.byType(AppDialogFrame),
        matching: find.widgetWithText(AppButton, 'Log out'),
      );
      expect(
        tester.widget<AppButton>(confirm).variant,
        AppButtonVariant.primary,
      );
    });

    testWidgets('a tap outside the log-out dialog keeps you signed in', (
      tester,
    ) async {
      final rig = await _pumpSettings(tester);
      await _tap(tester, find.widgetWithText(AppButton, 'Log out'));

      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.byType(AppDialogFrame), findsNothing);
      expect(find.text('SIGN IN'), findsNothing);
      expect((await rig.sessions.getSessionState()).token, isNotNull);
    });

    testWidgets('the daily goal opens the library sheet with the four goal '
        'cards, the current one chosen', (tester) async {
      await _pumpSettings(tester);
      await _tap(tester, find.text('Daily goal'));

      expect(find.byType(AppSheetFrame), findsOneWidget);
      final cards = tester
          .widgetList<SelectableOptionCard>(find.byType(SelectableOptionCard))
          .toList();
      expect(cards.map((c) => c.title), [
        'Casual · 5 min/day',
        'Regular · 10 min/day',
        'Serious · 15 min/day',
        'Intense · 20 min/day',
      ]);
      expect(cards.map((c) => c.selected), [false, true, false, false]);
      expect(cards[0].subtitle, 'Gentle warm up · +10 XP/day');
    });

    testWidgets('picking a goal saves it and closes the sheet', (tester) async {
      final rig = await _pumpSettings(tester);
      await _tap(tester, find.text('Daily goal'));
      await _tap(tester, find.text('Intense · 20 min/day'));

      expect(find.byType(AppSheetFrame), findsNothing);
      expect(rig.preferences.calls.single.dailyGoalMinutes, 20);
      expect(
        tester
            .widget<ListRow>(find.widgetWithText(ListRow, 'Daily goal'))
            .subtitle,
        'Intense · 20 min/day',
      );
    });

    testWidgets('closing the goal sheet changes nothing', (tester) async {
      final rig = await _pumpSettings(tester);
      await _tap(tester, find.text('Daily goal'));
      await _tap(tester, find.byTooltip('Close'));

      expect(find.byType(AppSheetFrame), findsNothing);
      expect(rig.preferences.calls, isEmpty);
    });

    testWidgets('a failed change shows its message on the themed dark '
        'card', (tester) async {
      final rig = await _pumpSettings(tester);
      rig.preferences.nextException = const UserPreferencesApiException(
        'offline',
      );
      await _tap(tester, find.text('Notifications'));

      final message = find.text("Couldn't save your change. Please try again.");
      expect(message, findsOneWidget);
      final card = tester.widget<Material>(
        find.ancestor(of: message, matching: find.byType(Material)).first,
      );
      expect(card.color, AppColors.inverseSurface);
    });
  });

  group('downloads', () {
    testWidgets('is an AppPage titled Manage Downloads, whose back arrow '
        'pops it', (tester) async {
      await _pumpDownloads(tester, pushed: true);

      expect(
        tester.widget<AppTopBar>(find.byType(AppTopBar)).title,
        'Manage Downloads',
      );
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(DownloadManagementScreen), findsNothing);
    });

    testWidgets('each pack is a row on one card: title, then course and '
        'size, then a delete button', (tester) async {
      await _pumpDownloads(tester);

      final group = find.byType(ListRowGroup);
      expect(group, findsOneWidget);
      final row = tester.widget<ListRow>(
        find.descendant(of: group, matching: find.byType(ListRow)),
      );
      expect(row.title, 'Alphabet & Fidel');
      expect(row.subtitle, 'English to Amharic · 2.0 KB');
      expect(row.icon, Icons.download_done_rounded);
      expect(row.tone, AppTone.primary);
      final delete = tester.widget<AppIconButton>(
        find.descendant(of: group, matching: find.byType(AppIconButton)),
      );
      expect(delete.tooltip, 'Delete "Alphabet & Fidel"');
      expect(delete.icon, Icons.delete_outline_rounded);
    });

    testWidgets('loading is LoadingState', (tester) async {
      final store = FakeLessonPackStore();
      await tester.pumpWidget(
        _app(
          DownloadManagementScreen(
            lessonPackStore: store,
            syncEngine: SyncEngine(
              lessonApi: ControllableLessonApi(),
              connectivityMonitor: FakeConnectivityMonitor(),
              queueStore: FakePendingSyncQueueStore(),
            ),
          ),
        ),
      );
      expect(find.byType(LoadingState), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('an empty list is an EmptyState that says how it fills', (
      tester,
    ) async {
      await _pumpDownloads(tester, empty: true);

      final empty = tester.widget<EmptyState>(find.byType(EmptyState));
      expect(empty.title, 'No downloaded lessons yet.');
      expect(empty.message, contains('download from the path'));
      expect(empty.action, isNull);
      expect(find.byType(ListRowGroup), findsNothing);
    });

    testWidgets('deleting asks in the library dialog with a destructive '
        'Delete, and a tap outside keeps the pack', (tester) async {
      final store = await _pumpDownloads(tester);
      await _tap(tester, find.byTooltip('Delete "Alphabet & Fidel"'));

      expect(find.byType(AppDialogFrame), findsOneWidget);
      final delete = tester.widget<AppButton>(
        find.widgetWithText(AppButton, 'Delete'),
      );
      expect(delete.variant, AppButtonVariant.destructive);

      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.byType(AppDialogFrame), findsNothing);
      expect(await store.isDownloaded('lesson-a'), isTrue);
    });
  });

  group('the theme', () {
    Set<WidgetState> states(List<WidgetState> s) => s.toSet();

    testWidgets('a switch is a green track with a white thumb when on, a '
        'grey outlined track when off, and faded when disabled', (
      tester,
    ) async {
      final theme = AppTheme.light.switchTheme;
      final on = states([WidgetState.selected]);
      final off = states([]);
      expect(theme.trackColor!.resolve(on), AppColors.primaryContainer);
      expect(theme.thumbColor!.resolve(on), AppColors.onPrimary);
      expect(theme.trackOutlineColor!.resolve(on), AppColors.primaryContainer);
      expect(theme.trackColor!.resolve(off), AppColors.surfaceContainerHighest);
      expect(theme.thumbColor!.resolve(off), AppColors.outline);
      expect(theme.trackOutlineColor!.resolve(off), AppColors.outline);
      expect(
        theme.trackColor!.resolve({WidgetState.selected, WidgetState.disabled}),
        AppColors.primaryContainer.withValues(alpha: 0.4),
      );
    });

    testWidgets('a message is a floating dark card with the base radius', (
      tester,
    ) async {
      final theme = AppTheme.light.snackBarTheme;
      expect(theme.behavior, SnackBarBehavior.floating);
      expect(theme.backgroundColor, AppColors.inverseSurface);
      expect(theme.contentTextStyle!.color, AppColors.inverseOnSurface);
    });
  });

  group('SwitchRow', () {
    Widget host(Widget row) => MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: ListRowGroup(children: [row])),
    );

    testWidgets('disabled, it cannot be flipped and reads as a disabled '
        'switch', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        host(const SwitchRow(title: 'Sound', value: true, onChanged: null)),
      );
      await tester.tap(find.text('Sound'));
      await tester.pump();
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
      expect(
        tester.getSemantics(find.byType(ListRow)),
        isSemantics(
          label: 'Sound',
          hasToggledState: true,
          isToggled: true,
          hasEnabledState: true,
          isEnabled: false,
        ),
      );
      semantics.dispose();
    });

    testWidgets('each tap passes the flipped value', (tester) async {
      final values = <bool>[];
      await tester.pumpWidget(
        host(SwitchRow(title: 'Sound', value: false, onChanged: values.add)),
      );
      await tester.tap(find.text('Sound'));
      await tester.tap(find.byType(Switch));
      await tester.pump();
      expect(values, [true, true]);
    });

    testWidgets('it holds the tap target of a one-line row', (tester) async {
      await tester.pumpWidget(
        host(SwitchRow(title: 'Sound', value: false, onChanged: (_) {})),
      );
      expect(
        tester.getSize(find.byType(ListRow)).height,
        greaterThanOrEqualTo(ListRow.oneLineHeight),
      );
      expect(
        tester.renderObject<RenderBox>(find.byType(ListRow)).size.height,
        greaterThanOrEqualTo(48),
      );
    });
  });
}
