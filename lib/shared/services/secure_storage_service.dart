import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Thin abstraction over Keychain/Keystore-backed storage.
///
/// Kept as an interface (rather than calling `flutter_secure_storage`
/// directly from repositories) so Stage 3 can substitute an in-memory fake
/// at the storage boundary per `coding-standards.md`'s "mock at the
/// network/DB boundary only" testing convention.
abstract class SecureStorageService {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// Real implementation backed by `flutter_secure_storage` (iOS Keychain /
/// Android Keystore).
class FlutterSecureStorageService implements SecureStorageService {
  FlutterSecureStorageService({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}
