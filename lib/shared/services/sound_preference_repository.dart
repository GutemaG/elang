import 'secure_storage_service.dart';

/// Reads/writes the device-local sound-on/off preference.
///
/// Unlike language/daily-goal/notification (server-side, via
/// `013-user-preferences-service`), sound has no cross-device need and
/// gates purely local playback (`AnswerFeedbackPlayer`), so it's stored
/// client-side only. Reuses [SecureStorageService] -- this project's one
/// local key-value abstraction -- rather than adding a new `shared_preferences`
/// dependency for a single boolean; that same storage already holds a
/// non-secret value (the onboarding pending selection).
class SoundPreferenceRepository {
  SoundPreferenceRepository({required this._storage});

  static const String _storageKey = 'sound_enabled';

  final SecureStorageService _storage;

  /// Defaults to `true` (sound on) when never set -- matches this
  /// feature's product default.
  Future<bool> getSoundEnabled() async {
    final raw = await _storage.read(_storageKey);
    if (raw == null) return true;
    return raw == 'true';
  }

  Future<void> setSoundEnabled(bool enabled) async {
    await _storage.write(_storageKey, enabled ? 'true' : 'false');
  }
}
