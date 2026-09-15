// Smoke test for the app's entry point.
//
// Verifies BunaApp boots into the splash screen without crashing. Uses an
// in-memory fake for secure storage so the test doesn't depend on platform
// channels (flutter_secure_storage has no test-environment implementation).

import 'package:flutter_test/flutter_test.dart';

import 'package:elang/features/auth/auth_dependencies.dart';
import 'package:elang/main.dart';

import 'helpers/in_memory_secure_storage_service.dart';

void main() {
  testWidgets('BunaApp boots into the splash screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      BunaApp(
        authDependencies: AuthDependencies(
          storage: InMemorySecureStorageService(),
        ),
      ),
    );

    // First frame, before the session-check/animation resolves.
    await tester.pump();

    expect(find.text('Buna'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
  });
}
