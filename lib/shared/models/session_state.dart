/// The device's current auth session, as read from secure storage at splash
/// time. A missing token, or a token past [expiresAt], both count as "no
/// session" — callers should never need to special-case "expired" versus
/// "absent".
class SessionState {
  const SessionState({this.token, this.expiresAt, this.authProvider});

  /// No session at all — the common "first launch" / "signed out" case.
  const SessionState.none() : token = null, expiresAt = null, authProvider = null;

  final String? token;
  final DateTime? expiresAt;

  /// Which provider (`'google'`/`'apple'`) this session was created with.
  /// Populated purely client-side by `SignInController` at save time — the
  /// backend response never carried this (bolt `014-profile-and-settings-ui`'s
  /// Plan-stage finding). `null` for any session saved before this field
  /// existed; callers should show a generic fallback rather than error.
  final String? authProvider;

  /// True only when a token exists and either has no expiry or hasn't
  /// expired yet. An expired-but-present token is treated as invalid, not
  /// as a special third state.
  bool get isValid {
    if (token == null || token!.isEmpty) return false;
    if (expiresAt == null) return true;
    return expiresAt!.isAfter(DateTime.now());
  }

  Map<String, dynamic> toJson() => {
    'token': token,
    'expiresAt': expiresAt?.toIso8601String(),
    'authProvider': authProvider,
  };

  static SessionState fromJson(Map<String, dynamic> json) {
    final token = json['token'];
    final expiresAtRaw = json['expiresAt'];
    final authProviderRaw = json['authProvider'];
    return SessionState(
      token: token is String ? token : null,
      expiresAt: expiresAtRaw is String
          ? DateTime.tryParse(expiresAtRaw)
          : null,
      authProvider: authProviderRaw is String ? authProviderRaw : null,
    );
  }

  // Intentionally no toString() override that includes the token — never
  // log session tokens (see coding-standards.md's logging constraint).
}
