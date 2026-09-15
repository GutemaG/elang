/// The device's current auth session, as read from secure storage at splash
/// time. A missing token, or a token past [expiresAt], both count as "no
/// session" — callers should never need to special-case "expired" versus
/// "absent".
class SessionState {
  const SessionState({this.token, this.expiresAt});

  /// No session at all — the common "first launch" / "signed out" case.
  const SessionState.none() : token = null, expiresAt = null;

  final String? token;
  final DateTime? expiresAt;

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
  };

  static SessionState fromJson(Map<String, dynamic> json) {
    final token = json['token'];
    final expiresAtRaw = json['expiresAt'];
    return SessionState(
      token: token is String ? token : null,
      expiresAt: expiresAtRaw is String
          ? DateTime.tryParse(expiresAtRaw)
          : null,
    );
  }

  // Intentionally no toString() override that includes the token — never
  // log session tokens (see coding-standards.md's logging constraint).
}
