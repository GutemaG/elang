// A deterministic [AuthApi] test double for the sign-in screen's tests.
//
// Unlike `FakeAuthApi` (which resolves after a fixed real-world `Duration`),
// this fake never resolves on its own — each call returns a `Future` backed
// by a `Completer` that the test completes explicitly via [completeNext].
// That makes "tap Google, assert in-flight, then resolve" and "tap Google
// then immediately tap Apple before the first resolves" deterministic:
// no timers, no `pump(duration)` guessing.
//
// It also records every call in [calls], which is what lets tests verify
// the concurrency guard (a blocked second tap never reaches the AuthApi
// boundary at all) and that "Retry" re-invokes the *same* provider.

import 'package:elang/shared/models/pending_onboarding_selection.dart';
import 'package:elang/shared/services/auth_api.dart';
import 'dart:async';

class ControllableAuthApi implements AuthApi {
  final List<AuthProvider> calls = [];
  final List<Completer<AuthResult>> _pending = [];

  /// Onboarding selections passed in on each call, in call order — lets a
  /// test assert what pending selection was actually attached to a given
  /// sign-in attempt.
  final List<PendingOnboardingSelection?> pendingSelectionsSeen = [];

  Future<AuthResult> _register(
    AuthProvider provider,
    PendingOnboardingSelection? pendingSelection,
  ) {
    calls.add(provider);
    pendingSelectionsSeen.add(pendingSelection);
    final completer = Completer<AuthResult>();
    _pending.add(completer);
    return completer.future;
  }

  @override
  Future<AuthResult> signInWithGoogle({
    required String idToken,
    PendingOnboardingSelection? pendingSelection,
  }) => _register(AuthProvider.google, pendingSelection);

  @override
  Future<AuthResult> signInWithApple({
    required String identityToken,
    PendingOnboardingSelection? pendingSelection,
  }) => _register(AuthProvider.apple, pendingSelection);

  /// Number of calls still awaiting a [completeNext].
  int get pendingCount => _pending.length;

  /// Completes the oldest not-yet-completed call with [result].
  void completeNext(AuthResult result) {
    final completer = _pending.removeAt(0);
    completer.complete(result);
  }
}
