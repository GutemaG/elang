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

  final List<void Function()> _accountChangedListeners = [];

  /// Calls [listener] whenever the signed-in account may have changed: a
  /// sign-out, or a sign-in with a new token. A renewal of the same session
  /// doesn't count. Account-owned copies on the phone (the account settings,
  /// 022-light-and-dark-themes) forget themselves on it.
  void addAccountChangedListener(void Function() listener) =>
      _accountChangedListeners.add(listener);

  void _notifyAccountChanged() {
    for (final listener in List.of(_accountChangedListeners)) {
      listener();
    }
  }

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
    final previous = await getSessionState();
    await _storage.write(_storageKey, jsonEncode(state.toJson()));
    if (previous.token != state.token) _notifyAccountChanged();
  }

  Future<void> clearSession() async {
    await _storage.delete(_storageKey);
    _notifyAccountChanged();
  }
}
