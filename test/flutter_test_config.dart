import 'dart:async';

import 'package:elang/shared/theme/app_motion.dart';

/// Runs before every test file. Looping decoration (the current skill's
/// bobbing "Start" bubble) never settles, so `pumpAndSettle` would time
/// out; tests that check the loop turn it back on themselves.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  AppMotion.loopsEnabled = false;
  await testMain();
}
