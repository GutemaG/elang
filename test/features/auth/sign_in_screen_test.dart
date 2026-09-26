// Sign-in screen tests.
//
// Covers stories 003 (equal-prominence Google/Apple buttons, the
// concurrency guard) and 004 (inline error/retry, pending selections
// untouched on failure).
//
// Uses `ControllableAuthApi` (test/helpers/controllable_auth_api.dart)
// instead of the real `FakeAuthApi` for these tests specifically because
// the concurrency-guard and "Retry re-triggers the same provider" checks
// need to assert exactly which/how many calls reached the `AuthApi`
// boundary and control exactly when each one resolves — a fixed
// real-world `Duration` (as `FakeAuthApi` uses) would make that timing
// non-deterministic under `pump()`.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:elang/features/auth/auth_routes.dart';
import 'package:elang/features/auth/screens/sign_in_screen.dart';
import 'package:elang/shared/services/auth_api.dart';
import 'package:elang/shared/services/onboarding_repository.dart';
import 'package:elang/shared/services/session_repository.dart';
import 'package:elang/shared/widgets/app_button.dart';

import '../../helpers/controllable_auth_api.dart';
import '../../helpers/fake_native_sign_in.dart';
import '../../helpers/in_memory_secure_storage_service.dart';

const _pendingSelectionStorageKey = 'pending_onboarding_selection';

class _Deps {
  _Deps()
    : storage = InMemorySecureStorageService(),
      authApi = ControllableAuthApi() {
    onboardingRepository = OnboardingRepository(storage: storage);
    sessionRepository = SessionRepository(storage: storage);
  }

  final InMemorySecureStorageService storage;
  final ControllableAuthApi authApi;
  late final OnboardingRepository onboardingRepository;
  late final SessionRepository sessionRepository;
}

Widget _wrapped(_Deps deps) {
  return MaterialApp(
    initialRoute: AuthRoutes.signIn,
    routes: {
      AuthRoutes.signIn: (_) => SignInScreen(
        authApi: deps.authApi,
        onboardingRepository: deps.onboardingRepository,
        sessionRepository: deps.sessionRepository,
        // Real Google/Apple SDKs have no test-environment implementation
        // (see `native_sign_in.dart`) — these tests exercise the AuthApi
        // boundary and screen behavior, not the native SDK itself, so a
        // fake that always "succeeds" stands in for an already-authenticated
        // native step, matching this suite's pre-SDK behavior.
        googleSignIn: FakeNativeSignIn(),
        appleSignIn: FakeNativeSignIn(),
      ),
      AuthRoutes.home: (_) => const Scaffold(body: Text('HOME_STUB')),
    },
  );
}

void main() {
  testWidgets('Google and Apple buttons render at identical size', (
    tester,
  ) async {
    final deps = _Deps();
    await tester.pumpWidget(_wrapped(deps));

    final googleSize = tester.getSize(
      find.widgetWithText(AppButton, 'Continue with Google'),
    );
    final appleSize = tester.getSize(
      find.widgetWithText(AppButton, 'Continue with Apple'),
    );

    expect(googleSize, appleSize);
  });

  testWidgets('tapping Google disables both buttons while in-flight', (
    tester,
  ) async {
    final deps = _Deps();
    await tester.pumpWidget(_wrapped(deps));

    await tester.tap(find.text('Continue with Google'));
    await tester.pump();

    final googleButton = tester.widget<AppButton>(
      find.widgetWithText(AppButton, 'Continue with Google'),
    );
    final appleButton = tester.widget<AppButton>(
      find.widgetWithText(AppButton, 'Continue with Apple'),
    );
    expect(googleButton.onPressed, isNull);
    expect(appleButton.onPressed, isNull);

    // Resolve so the test doesn't leave a dangling pending Future.
    deps.authApi.completeNext(const AuthSuccess(sessionToken: 'tok'));
    await tester.pumpAndSettle();
  });

  testWidgets(
    'tapping Apple immediately after Google does not start a second in-flight sign-in',
    (tester) async {
      final deps = _Deps();
      await tester.pumpWidget(_wrapped(deps));

      await tester.tap(find.text('Continue with Google'));
      await tester.pump();
      expect(deps.authApi.calls, [AuthProvider.google]);
      expect(deps.authApi.pendingCount, 1);

      // Second tap before the first resolves — the concurrency guard
      // should make this a no-op: no second call reaches the AuthApi.
      await tester.tap(find.text('Continue with Apple'), warnIfMissed: false);
      await tester.pump();

      expect(deps.authApi.calls, [AuthProvider.google]);
      expect(deps.authApi.pendingCount, 1);

      deps.authApi.completeNext(const AuthSuccess(sessionToken: 'tok'));
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'a forced failure shows the inline error banner with retry, and pending selections are untouched',
    (tester) async {
      final deps = _Deps();
      // A pending selection already exists, as if onboarding finished
      // before the user reached sign-in.
      await deps.onboardingRepository.selectLanguage('am');
      await deps.onboardingRepository.selectDailyGoal(10);
      final before = deps.storage.values[_pendingSelectionStorageKey];
      expect(before, isNotNull);

      await tester.pumpWidget(_wrapped(deps));

      await tester.tap(find.text('Continue with Google'));
      await tester.pump();
      deps.authApi.completeNext(
        const AuthFailure(AuthFailureReason.networkError),
      );
      await tester.pumpAndSettle();

      expect(find.text('Something went wrong — try again'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      // Untouched, byte-for-byte, through the failure.
      expect(deps.storage.values[_pendingSelectionStorageKey], before);

      // Buttons are re-enabled again after the failure (not stuck disabled).
      final googleButton = tester.widget<AppButton>(
        find.widgetWithText(AppButton, 'Continue with Google'),
      );
      expect(googleButton.onPressed, isNotNull);
    },
  );

  testWidgets(
    'a cancelled attempt shows the neutral cancel-tone message, not the failure-tone one',
    (tester) async {
      final deps = _Deps();
      await tester.pumpWidget(_wrapped(deps));

      await tester.tap(find.text('Continue with Apple'));
      await tester.pump();
      deps.authApi.completeNext(const AuthFailure(AuthFailureReason.cancelled));
      await tester.pumpAndSettle();

      expect(find.text('Sign-in was cancelled'), findsOneWidget);
      expect(find.text('Something went wrong — try again'), findsNothing);
    },
  );

  testWidgets('tapping Retry re-triggers the same provider', (tester) async {
    final deps = _Deps();
    await tester.pumpWidget(_wrapped(deps));

    await tester.tap(find.text('Continue with Apple'));
    await tester.pump();
    expect(deps.authApi.calls, [AuthProvider.apple]);

    deps.authApi.completeNext(
      const AuthFailure(AuthFailureReason.providerError),
    );
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pump();

    expect(deps.authApi.calls, [AuthProvider.apple, AuthProvider.apple]);

    deps.authApi.completeNext(const AuthSuccess(sessionToken: 'tok'));
    await tester.pumpAndSettle();

    expect(find.text('HOME_STUB'), findsOneWidget);
  });

  testWidgets('a successful sign-in routes to home', (tester) async {
    final deps = _Deps();
    await tester.pumpWidget(_wrapped(deps));

    await tester.tap(find.text('Continue with Google'));
    await tester.pump();
    deps.authApi.completeNext(const AuthSuccess(sessionToken: 'tok'));
    await tester.pumpAndSettle();

    expect(find.text('HOME_STUB'), findsOneWidget);
  });
}
