// A deterministic [NativeSignIn] test double.
//
// Real `GoogleNativeSignIn`/`AppleNativeSignIn` invoke actual platform
// plugins, which have no test-environment implementation and would throw
// (see `native_sign_in.dart`'s catch-all). Widget/controller tests that
// exercise `SignInController.signIn()` beyond the native-SDK step (the
// concurrency guard, retry, AuthApi error mapping, successful routing) need
// a token-acquisition stand-in that never touches a real plugin — this is
// that stand-in.

import 'package:elang/features/auth/state/native_sign_in.dart';

class FakeNativeSignIn implements NativeSignIn {
  /// Always resolves to [token].
  FakeNativeSignIn({this.token = 'fake-native-token'})
    : _cancelled = false,
      _failureMessage = null;

  /// Always throws [NativeSignInCancelledException], simulating the user
  /// dismissing the native OAuth sheet.
  FakeNativeSignIn.cancelling()
    : token = '',
      _cancelled = true,
      _failureMessage = null;

  /// Always throws [NativeSignInFailedException] with [message], simulating
  /// any other native-SDK failure.
  FakeNativeSignIn.failing(String message)
    : token = '',
      _cancelled = false,
      _failureMessage = message;

  /// The token [signIn] resolves to on success.
  final String token;
  final bool _cancelled;
  final String? _failureMessage;

  /// Number of times [signIn] has been called, so tests can assert the
  /// native step was (or wasn't) reached.
  int callCount = 0;

  @override
  Future<String> signIn() async {
    callCount++;
    if (_cancelled) throw const NativeSignInCancelledException();
    final failureMessage = _failureMessage;
    if (failureMessage != null) {
      throw NativeSignInFailedException(failureMessage);
    }
    return token;
  }
}
