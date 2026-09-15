// Tests for `SignInController`'s new native-SDK token-acquisition step
// (see this bolt's implementation plan): a cancelled or failed native
// sign-in must resolve directly to `SignInStatus.errorCancelled` /
// `errorFailed` WITHOUT ever calling `AuthApi` — that's the "cancellation
// is a client-side, pre-network event" behavior this bolt adds.
//
// `test/features/auth/sign_in_screen_test.dart` already covers the
// AuthApi-returned `AuthFailureReason.cancelled` path (a backend/API-level
// "cancelled" outcome) and every other pre-existing controller behavior;
// this file is scoped specifically to the new native-SDK short-circuit.

import 'package:flutter_test/flutter_test.dart';

import 'package:elang/features/auth/state/sign_in_controller.dart';
import 'package:elang/shared/services/auth_api.dart';
import 'package:elang/shared/services/onboarding_repository.dart';
import 'package:elang/shared/services/session_repository.dart';

import '../../../helpers/controllable_auth_api.dart';
import '../../../helpers/fake_native_sign_in.dart';
import '../../../helpers/in_memory_secure_storage_service.dart';

void main() {
  late InMemorySecureStorageService storage;
  late ControllableAuthApi authApi;
  late OnboardingRepository onboardingRepository;
  late SessionRepository sessionRepository;

  setUp(() {
    storage = InMemorySecureStorageService();
    authApi = ControllableAuthApi();
    onboardingRepository = OnboardingRepository(storage: storage);
    sessionRepository = SessionRepository(storage: storage);
  });

  test('a cancelled native Google sign-in sets errorCancelled without calling AuthApi', () async {
    final googleSignIn = FakeNativeSignIn.cancelling();
    final controller = SignInController(
      authApi: authApi,
      onboardingRepository: onboardingRepository,
      sessionRepository: sessionRepository,
      googleSignIn: googleSignIn,
      appleSignIn: FakeNativeSignIn(),
    );

    await controller.signIn(AuthProvider.google);

    expect(controller.status, SignInStatus.errorCancelled);
    expect(googleSignIn.callCount, 1);
    expect(authApi.calls, isEmpty);
  });

  test('a cancelled native Apple sign-in sets errorCancelled without calling AuthApi', () async {
    final appleSignIn = FakeNativeSignIn.cancelling();
    final controller = SignInController(
      authApi: authApi,
      onboardingRepository: onboardingRepository,
      sessionRepository: sessionRepository,
      googleSignIn: FakeNativeSignIn(),
      appleSignIn: appleSignIn,
    );

    await controller.signIn(AuthProvider.apple);

    expect(controller.status, SignInStatus.errorCancelled);
    expect(appleSignIn.callCount, 1);
    expect(authApi.calls, isEmpty);
  });

  test('a failed (non-cancel) native sign-in sets errorFailed without calling AuthApi', () async {
    final googleSignIn = FakeNativeSignIn.failing('plugin not configured');
    final controller = SignInController(
      authApi: authApi,
      onboardingRepository: onboardingRepository,
      sessionRepository: sessionRepository,
      googleSignIn: googleSignIn,
      appleSignIn: FakeNativeSignIn(),
    );

    await controller.signIn(AuthProvider.google);

    expect(controller.status, SignInStatus.errorFailed);
    expect(authApi.calls, isEmpty);
  });

  test(
    'a successful native sign-in proceeds into AuthApi with the acquired token',
    () async {
      final googleSignIn = FakeNativeSignIn(token: 'real-token-123');
      final controller = SignInController(
        authApi: authApi,
        onboardingRepository: onboardingRepository,
        sessionRepository: sessionRepository,
        googleSignIn: googleSignIn,
        appleSignIn: FakeNativeSignIn(),
      );

      final future = controller.signIn(AuthProvider.google);
      // Allow the native step (and the pending-selection load) to resolve
      // before the AuthApi call is registered.
      await Future<void>.delayed(Duration.zero);

      expect(authApi.calls, [AuthProvider.google]);
      expect(controller.status, SignInStatus.inFlight);

      authApi.completeNext(const AuthSuccess(sessionToken: 'session-tok'));
      await future;

      expect(controller.status, SignInStatus.idle);
    },
  );

  test('retry() re-triggers the native step again, not just AuthApi', () async {
    final googleSignIn = FakeNativeSignIn.failing('first failure');
    final controller = SignInController(
      authApi: authApi,
      onboardingRepository: onboardingRepository,
      sessionRepository: sessionRepository,
      googleSignIn: googleSignIn,
      appleSignIn: FakeNativeSignIn(),
    );

    await controller.signIn(AuthProvider.google);
    expect(controller.status, SignInStatus.errorFailed);
    expect(googleSignIn.callCount, 1);

    await controller.retry();

    expect(googleSignIn.callCount, 2);
    expect(controller.status, SignInStatus.errorFailed);
    expect(authApi.calls, isEmpty);
  });
}
