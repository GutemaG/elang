import 'secure_storage_service.dart';

/// What [AppLanguageRepository] keeps: the chosen code (`null` until one is
/// chosen), whether the account still has to be told, and whether the code
/// only came from sign-up's "I speak" choice, so sign-up may still change it.
typedef StoredAppLanguage = ({String? code, bool unsent, bool fromSignUp});

/// Reads and writes the app language (024-app-localization, story 003).
///
/// Kept on the phone like Appearance (`AppearanceRepository`): it must
/// apply before sign-in, and it survives sign-out, which clears only the
/// session. The account keeps a copy too (story 006); `unsent` marks a
/// change the account has not taken yet.
class AppLanguageRepository {
  AppLanguageRepository({required this._storage});

  static const String _codeKey = 'app_language';
  static const String _unsentKey = 'app_language_unsent';
  static const String _fromSignUpKey = 'app_language_from_sign_up';

  final SecureStorageService _storage;

  Future<StoredAppLanguage> load() async {
    final code = await _storage.read(_codeKey);
    return (
      code: code == null || code.isEmpty ? null : code,
      unsent: await _storage.read(_unsentKey) == 'true',
      fromSignUp: await _storage.read(_fromSignUpKey) == 'true',
    );
  }

  /// Keeps [code]; `""` forgets the choice.
  Future<void> save(
    String code, {
    required bool unsent,
    bool fromSignUp = false,
  }) async {
    await _storage.write(_codeKey, code);
    await _storage.write(_unsentKey, unsent ? 'true' : 'false');
    await _storage.write(_fromSignUpKey, fromSignUp ? 'true' : 'false');
  }
}
