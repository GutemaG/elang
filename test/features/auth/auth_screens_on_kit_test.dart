// Onboarding and sign-in on the library (018-mobile-design-system, bolt
// 046, story 001): each screen is an AppPage with its actions docked, links
// are text links, the provider buttons are equal, the sign-in error is an
// inline banner with Retry, and nothing overflows on a small phone.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:elang/features/auth/auth_dependencies.dart';
import 'package:elang/features/auth/auth_flow_controller.dart';
import 'package:elang/features/auth/screens/daily_goal_selection_screen.dart';
import 'package:elang/features/auth/screens/language_selection_screen.dart';
import 'package:elang/features/auth/screens/onboarding_carousel_screen.dart';
import 'package:elang/features/auth/screens/sign_in_screen.dart';
import 'package:elang/features/auth/screens/splash_screen.dart';
import 'package:elang/shared/models/course.dart';
import 'package:elang/shared/services/auth_api.dart';
import 'package:elang/shared/services/course_api.dart';
import 'package:elang/shared/services/fake_course_api.dart';
import 'package:elang/shared/services/onboarding_repository.dart';
import 'package:elang/shared/services/session_repository.dart';
import 'package:elang/shared/theme/app_theme.dart';
import 'package:elang/shared/theme/app_tone.dart';
import 'package:elang/shared/widgets/app_button.dart';
import 'package:elang/shared/widgets/app_card.dart';
import 'package:elang/shared/widgets/app_page.dart';
import 'package:elang/shared/widgets/app_status.dart';
import 'package:elang/shared/widgets/selectable_option_card.dart';

import '../../helpers/controllable_auth_api.dart';
import '../../helpers/fake_native_sign_in.dart';
import '../../helpers/in_memory_secure_storage_service.dart';

Widget _app(Widget home, {double textScale = 1}) => MaterialApp(
  theme: AppTheme.light,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context)
        .copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  ),
  home: home,
  // Stand-ins for where the screens navigate, so a tap in these tests does
  // not need the whole app.
  onGenerateRoute: (settings) => MaterialPageRoute<void>(
    builder: (_) => Scaffold(body: Text('ROUTE ${settings.name}')),
  ),
);

void _size(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

OnboardingRepository _onboarding() =>
    OnboardingRepository(storage: InMemorySecureStorageService());

AuthFlowController _authFlow() => AuthFlowController(
  sessionRepository: AuthDependencies(storage: InMemorySecureStorageService())
      .sessionRepository,
);

SignInScreen _signIn(ControllableAuthApi api) {
  final storage = InMemorySecureStorageService();
  return SignInScreen(
    authApi: api,
    onboardingRepository: OnboardingRepository(storage: storage),
    sessionRepository: SessionRepository(storage: storage),
    googleSignIn: FakeNativeSignIn(),
    appleSignIn: FakeNativeSignIn(),
  );
}

/// A catalog that fails once, then loads.
class _FlakyCourseApi extends FakeCourseApi {
  var _failed = false;

  @override
  Future<List<Course>> getCatalog() async {
    if (!_failed) {
      _failed = true;
      throw const CourseApiException('offline');
    }
    return super.getCatalog();
  }
}

/// [label]'s button, whichever variant it is.
AppButton _button(WidgetTester tester, String label) =>
    tester.widget<AppButton>(find.widgetWithText(AppButton, label));

/// Whether [label]'s button sits in the page's bottom dock: below the
/// scrolling content, near the bottom of the screen.
void _expectDocked(WidgetTester tester, String label) {
  final button = tester.getRect(find.widgetWithText(AppButton, label));
  final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
  expect(button.bottom, greaterThan(screen.height - 160), reason: label);
}

void main() {
  group('splash', () {
    testWidgets('a celebration page with Get Started docked as the primary '
        'action', (tester) async {
      await tester.pumpWidget(
        _app(SplashScreen(authFlowController: _authFlow())),
      );
      await tester.pump();

      expect(
        tester.widget<AppPage>(find.byType(AppPage)).background,
        AppPageBackground.celebration,
      );
      expect(_button(tester, 'Get Started').variant, AppButtonVariant.primary);
      _expectDocked(tester, 'Get Started');
      await tester.pumpAndSettle();
    });

    testWidgets('the brewing bar and its percentage follow the animation '
        'frame by frame', (tester) async {
      await tester.pumpWidget(
        _app(SplashScreen(authFlowController: _authFlow())),
      );
      await tester.pump(const Duration(milliseconds: 700));

      final bar = tester.widget<AppProgressBar>(find.byType(AppProgressBar));
      expect(bar.animate, isFalse);
      expect(bar.value, closeTo(0.5, 0.01));
      expect(find.widgetWithText(CountBadge, '50%'), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('the mascot and the brewing card are library cards', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(SplashScreen(authFlowController: _authFlow())),
      );
      await tester.pump();

      expect(find.byType(AppCard), findsNWidgets(2));
      expect(
        find.descendant(
          of: find.byType(AppCard).first,
          matching: find.byIcon(Icons.local_cafe),
        ),
        findsOneWidget,
      );
      await tester.pumpAndSettle();
    });
  });

  group('onboarding carousel', () {
    testWidgets('the brand top bar has Skip as a text link', (tester) async {
      await tester.pumpWidget(_app(const OnboardingCarouselScreen()));

      expect(
        find.descendant(
          of: find.byType(AppTopBar),
          matching: find.text('Skip'),
        ),
        findsOneWidget,
      );
      expect(_button(tester, 'Skip').variant, AppButtonVariant.text);
      expect(find.text('Buna'), findsOneWidget);
    });

    testWidgets('Continue is docked, then "Already have an account?" with Log '
        'In as a text link', (tester) async {
      await tester.pumpWidget(_app(const OnboardingCarouselScreen()));

      expect(_button(tester, 'Continue').variant, AppButtonVariant.primary);
      expect(_button(tester, 'Log In').variant, AppButtonVariant.text);
      _expectDocked(tester, 'Continue');
      expect(
        tester.getRect(find.text('Log In')).top,
        greaterThan(
          tester.getRect(find.widgetWithText(AppButton, 'Continue')).bottom,
        ),
      );
    });

    testWidgets('each slide is a card with the Tibeb stripe, and the dots '
        'follow the slide', (tester) async {
      await tester.pumpWidget(_app(const OnboardingCarouselScreen()));

      final card = tester.widget<AppCard>(
        find.ancestor(
          of: find.text('Bite-Sized Amharic'),
          matching: find.byType(AppCard),
        ),
      );
      expect(card.topStripe, isTrue);
      expect(find.widgetWithText(CountBadge, 'ሀ ha'), findsOneWidget);
      expect(tester.widget<PageDots>(find.byType(PageDots)).index, 0);
      expect(tester.widget<PageDots>(find.byType(PageDots)).count, 3);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(tester.widget<PageDots>(find.byType(PageDots)).index, 1);
    });
  });

  group('language selection', () {
    Widget screen(CourseApi api) => LanguageSelectionScreen(
      onboardingRepository: _onboarding(),
      courseApi: api,
    );

    testWidgets('loading is the library loading state', (tester) async {
      await tester.pumpWidget(_app(screen(FakeCourseApi())));
      expect(find.byType(LoadingState), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.byType(LoadingState), findsNothing);
    });

    testWidgets('a failed catalog is an ErrorState with its sentence and '
        'Retry', (tester) async {
      await tester.pumpWidget(_app(screen(_FlakyCourseApi())));
      await tester.pumpAndSettle();

      final error = tester.widget<ErrorState>(find.byType(ErrorState));
      expect(error.title, "Couldn't load the courses.");
      expect(error.message, isNull);
      expect(error.retryLabel, 'Retry');

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.byType(ErrorState), findsNothing);
      expect(find.text('I speak'), findsOneWidget);
    });

    testWidgets('loading and errors fill the page, centred above the dock', (
      tester,
    ) async {
      await tester.pumpWidget(_app(screen(_FlakyCourseApi())));
      await tester.pumpAndSettle();

      final page = tester.getRect(find.byType(AppPage));
      final dock = tester.getRect(find.widgetWithText(AppButton, 'Continue'));
      final title = tester.getCenter(find.text("Couldn't load the courses."));
      // Nearer the middle of the room above the dock than its top.
      expect(title.dy, greaterThan(page.top + (dock.top - page.top) * 0.3));
      expect(tester.widget<AppPage>(find.byType(AppPage)).scrollable, isFalse);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(tester.widget<AppPage>(find.byType(AppPage)).scrollable, isTrue);
    });

    testWidgets('the flag is a square badge, green when the course is open', (
      tester,
    ) async {
      await tester.pumpWidget(_app(screen(FakeCourseApi())));
      await tester.pumpAndSettle();

      final flags = tester.widgetList<IconBadge>(
        find.descendant(
          of: find.byType(SelectableOptionCard),
          matching: find.byType(IconBadge),
        ),
      );
      expect(flags, isNotEmpty);
      expect(flags.every((f) => f.square), isTrue);
      expect(
        flags
            .where((f) => f.icon == Icons.flag)
            .every((f) => f.tone == AppTone.primary),
        isTrue,
      );
    });

    testWidgets('Continue is docked; "I speak" chips take no style of their '
        'own', (tester) async {
      await tester.pumpWidget(_app(screen(FakeCourseApi())));
      await tester.pumpAndSettle();

      _expectDocked(tester, 'Continue');
      for (final chip in tester.widgetList<ChoiceChip>(
        find.byType(ChoiceChip),
      )) {
        expect(chip.selectedColor, isNull);
        expect(chip.backgroundColor, isNull);
        expect(chip.side, isNull);
        expect(chip.labelStyle, isNull);
      }
    });
  });

  group('daily goal', () {
    testWidgets('the headline is the display token, unchanged', (tester) async {
      await tester.pumpWidget(
        _app(DailyGoalSelectionScreen(onboardingRepository: _onboarding())),
      );
      final headline = tester.widget<Text>(find.text('Choose your daily goal'));
      expect(headline.style!.fontSize, 32);
    });

    testWidgets('the chosen goal has the green badge; the others gold', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(DailyGoalSelectionScreen(onboardingRepository: _onboarding())),
      );

      AppTone toneOf(IconData icon) =>
          tester.widget<IconBadge>(find.widgetWithIcon(IconBadge, icon)).tone;
      expect(toneOf(Icons.local_cafe), AppTone.primary); // Regular, the default
      expect(toneOf(Icons.eco), AppTone.secondary);

      await tester.tap(find.textContaining('Casual'));
      await tester.pumpAndSettle();
      expect(toneOf(Icons.eco), AppTone.primary);
      expect(toneOf(Icons.local_cafe), AppTone.secondary);
    });

    testWidgets('the tip is a banner; Continue and its caption are docked', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(DailyGoalSelectionScreen(onboardingRepository: _onboarding())),
      );

      expect(
        find.widgetWithText(
          InfoBanner,
          'Tip: Studying during your morning Buna ritual boosts long-term recall.',
        ),
        findsOneWidget,
      );
      _expectDocked(tester, 'Continue');
      expect(
        tester
            .getRect(find.text('You can change your goal anytime in Settings.'))
            .top,
        greaterThan(
          tester.getRect(find.widgetWithText(AppButton, 'Continue')).bottom,
        ),
      );
    });
  });

  group('sign-in', () {
    testWidgets('Google and Apple are equal white secondary buttons with '
        'their marks', (tester) async {
      await tester.pumpWidget(_app(_signIn(ControllableAuthApi())));

      final google = _button(tester, 'Continue with Google');
      final apple = _button(tester, 'Continue with Apple');
      expect(google.variant, AppButtonVariant.secondary);
      expect(apple.variant, AppButtonVariant.secondary);
      expect(google.leading, isNotNull);
      expect(apple.leading, isA<Icon>());
      expect((apple.leading! as Icon).icon, Icons.apple);
      expect(
        tester.getSize(find.widgetWithText(AppButton, 'Continue with Google')),
        tester.getSize(find.widgetWithText(AppButton, 'Continue with Apple')),
      );
    });

    testWidgets('a failure shows an inline banner with Retry inside it, and '
        'Retry tries the same provider again', (tester) async {
      final api = ControllableAuthApi();
      await tester.pumpWidget(_app(_signIn(api)));

      await tester.tap(find.text('Continue with Apple'));
      await tester.pump();
      api.completeNext(const AuthFailure(AuthFailureReason.networkError));
      await tester.pumpAndSettle();

      final banner = find.widgetWithText(
        InfoBanner,
        'Something went wrong — try again',
      );
      expect(banner, findsOneWidget);
      expect(tester.widget<InfoBanner>(banner).tone, AppTone.secondary);
      expect(
        find.descendant(
          of: banner,
          matching: find.widgetWithText(AppButton, 'Retry'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(api.calls, [AuthProvider.apple, AuthProvider.apple]);
      api.completeNext(const AuthSuccess(sessionToken: 'tok'));
      await tester.pumpAndSettle();
    });

    testWidgets('it is an AppPage, and the terms line is still there', (
      tester,
    ) async {
      await tester.pumpWidget(_app(_signIn(ControllableAuthApi())));
      expect(find.byType(AppPage), findsOneWidget);
      expect(
        find.text(
          'By continuing you agree to our Terms of Service & Privacy Policy.',
        ),
        findsOneWidget,
      );
    });
  });

  group('small screens', () {
    final screens = <String, Widget Function()>{
      'splash': () => SplashScreen(authFlowController: _authFlow()),
      'carousel': () => const OnboardingCarouselScreen(),
      'language': () => LanguageSelectionScreen(
        onboardingRepository: _onboarding(),
        courseApi: FakeCourseApi(),
      ),
      'daily goal': () =>
          DailyGoalSelectionScreen(onboardingRepository: _onboarding()),
      'sign-in': () => _signIn(ControllableAuthApi()),
    };
    for (final size in const [Size(320, 568), Size(360, 640)]) {
      for (final scale in const [1.0, 1.3]) {
        for (final MapEntry(key: name, value: build) in screens.entries) {
          testWidgets('$name fits ${size.width.toInt()} px at ${scale}x', (
            tester,
          ) async {
            _size(tester, size);
            await tester.pumpWidget(_app(build(), textScale: scale));
            await tester.pump(const Duration(milliseconds: 700));
            expect(tester.takeException(), isNull);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          });
        }
      }
    }

    testWidgets('the sign-in error banner fits 320 px at 1.3x', (tester) async {
      _size(tester, const Size(320, 568));
      final api = ControllableAuthApi();
      await tester.pumpWidget(_app(_signIn(api), textScale: 1.3));
      await tester.tap(find.text('Continue with Google'));
      await tester.pump();
      api.completeNext(const AuthFailure(AuthFailureReason.networkError));
      await tester.pumpAndSettle();

      expect(find.text('Retry'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
