import 'dart:convert';

/// The name, email and photo a sign-in provider put in its ID token.
///
/// Read straight from the token's claims, for display only. The token's
/// signature is not checked here and does not need to be: the backend
/// verifies the same token before it issues a session, and nothing read
/// here is ever trusted for anything but showing the learner who they are.
class ProviderProfile {
  const ProviderProfile({this.name, this.email, this.photoUrl});

  static const ProviderProfile empty = ProviderProfile();

  final String? name;
  final String? email;
  final String? photoUrl;

  /// The profile in [idToken], a JWT from Google or Apple. Anything that is
  /// not a readable JWT yields [empty] rather than an error: a missing
  /// profile only means Settings shows less.
  static ProviderProfile fromIdToken(String idToken) {
    final parts = idToken.split('.');
    if (parts.length != 3) return empty;
    try {
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final claims = jsonDecode(payload);
      if (claims is! Map<String, dynamic>) return empty;
      return ProviderProfile(
        name: _claim(claims, 'name'),
        email: _claim(claims, 'email'),
        photoUrl: _claim(claims, 'picture'),
      );
    } on Object {
      return empty;
    }
  }

  static String? _claim(Map<String, dynamic> claims, String key) {
    final value = claims[key];
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
