// Shared in-memory fake for [SecureStorageService], used across widget
// tests so the auth/onboarding flow can be exercised without depending on
// `flutter_secure_storage`'s platform channel (which has no test-environment
// implementation).
//
// Mocking here is at the storage boundary only, per `coding-standards.md`'s
// "mock at the network/DB boundary only" testing convention — domain logic
// (OnboardingRepository, SessionRepository, SignInController, etc.) always
// runs for real against this fake.

import 'package:elang/shared/services/secure_storage_service.dart';

class InMemorySecureStorageService implements SecureStorageService {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}
