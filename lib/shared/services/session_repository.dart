import 'dart:convert';

import '../models/session_state.dart';
import 'secure_storage_service.dart';

/// Reads/writes the device's [SessionState] to secure storage.
///
/// This is the storage half of the "session-check / routing" concern from
/// the implementation plan; the actual routing *decision* (home vs.
/// onboarding) lives in `AuthFlowController` so this class stays a plain
/// persistence boundary that's easy to mock in Stage 3.
class SessionRepository {
  SessionRepository({required this._storage});

  static const String _storageKey = 'session_state';

  final SecureStorageService _storage;

  /// Returns the stored session, or [SessionState.none] if nothing is
  /// stored / the stored payload can't be parsed. Callers should treat an
  /// expired token the same as no token — see [SessionState.isValid].
  Future<SessionState> getSessionState() async {
    final raw = await _storage.read(_storageKey);
    if (raw == null) return const SessionState.none();
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return SessionState.fromJson(decoded);
    } catch (_) {
      return const SessionState.none();
    }
  }

  /// Persists a newly-issued session (called after a successful sign-in).
  Future<void> saveSession(SessionState state) async {
    await _storage.write(_storageKey, jsonEncode(state.toJson()));
  }

  Future<void> clearSession() async {
    await _storage.delete(_storageKey);
  }
}
