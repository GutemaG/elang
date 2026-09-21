/// The device's current auth session, as read from secure storage at splash
/// time. A missing token, or a token past [expiresAt], both count as "no
/// session" — callers should never need to special-case "expired" versus
/// "absent".
class SessionState {
  const SessionState({
    this.token,
    this.expiresAt,
    this.authProvider,
    this.displayName,
    this.email,
    this.photoUrl,
  });

  /// No session at all — the common "first launch" / "signed out" case.
  const SessionState.none()
    : token = null,
      expiresAt = null,
      authProvider = null,
      displayName = null,
      email = null,
      photoUrl = null;

  final String? token;
  final DateTime? expiresAt;

  /// Which provider (`'google'`/`'apple'`) this session was created with.
  /// Populated purely client-side by `SignInController` at save time — the
  /// backend response never carried this (bolt `014-profile-and-settings-ui`'s
  /// Plan-stage finding). `null` for any session saved before this field
  /// existed; callers should show a generic fallback rather than error.
  final String? authProvider;

  /// Who is signed in, as the provider reported it: read from the claims of
  /// the provider's ID token at sign-in (see `ProviderProfile`) and kept on
  /// this device only -- the backend never stores it. Any of them may be
  /// `null`: Apple shares no name or photo, and a session saved before these
  /// existed has none until the next sign-in.
  final String? displayName;
  final String? email;
  final String? photoUrl;

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
    'displayName': displayName,
    'email': email,
    'photoUrl': photoUrl,
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
      displayName: _string(json['displayName']),
      email: _string(json['email']),
      photoUrl: _string(json['photoUrl']),
    );
  }

  static String? _string(Object? raw) {
    if (raw is! String) return null;
    final trimmed = raw.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  // Intentionally no toString() override that includes the token — never
  // log session tokens (see coding-standards.md's logging constraint).
}
