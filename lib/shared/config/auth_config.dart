// TODO(deploy): Every value below is a placeholder — none of these are real
// secrets and none of them work against a real Google/Apple developer
// console project. Replace them per environment before shipping a build
// that needs real sign-in to succeed, analogous to `backend/.env.example`'s
// header comment.
//
// Real values are intended to be supplied via `--dart-define` (or
// `--dart-define-from-file=<untracked-file>`) at build time, read through
// `String.fromEnvironment(...)` defaults into this same class, so call
// sites never need to change. [apiBaseUrl] now works this way; the OAuth
// identifiers below still do not, because they are not secrets and the
// Google client ID is already the real one.
//
// `googleServerClientId` must stay in sync with the backend's
// `GOOGLE_OAUTH_CLIENT_ID` (see `backend/.env.example`) — both sides verify
// against the same OAuth audience.

/// Placeholder OAuth/API configuration for the auth/onboarding flow.
///
/// Not a secret leak: every field here is an obvious placeholder string,
/// safe to commit, matching `backend/.env.example`'s "commit the example,
/// not the real values" precedent.
abstract final class AuthConfig {
  /// Base URL of the backend's auth API.
  ///
  /// Supplied at build time so one codebase can point at either environment
  /// without a source edit:
  ///
  /// ```
  /// flutter build apk --release \
  ///   --dart-define=API_BASE_URL=https://ethio-lang.vercel.app
  /// ```
  ///
  /// The default is the local dev server, per `backend/.env.example`'s
  /// local-first pattern, so `flutter run` keeps working untouched. Note
  /// that a plain `flutter build` with no define therefore produces an APK
  /// pointing at the *phone's own* localhost, which resolves to nothing --
  /// pass the define for any build that leaves your machine.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );

  /// Google OAuth client ID used to initialize `google_sign_in` on the
  /// client. This is the Web application client (used for the web/iOS
  /// init path); Android matches by package name + SHA-1 fingerprint
  /// registered in Google Cloud Console instead.
  static const String googleClientId =
      '475970937717-h80aqt3b2b7psrt918udc102r6ts61fq.apps.googleusercontent.com';

  /// Google OAuth server client ID — must match the backend's
  /// `GOOGLE_OAUTH_CLIENT_ID` audience so tokens issued for this client
  /// verify successfully server-side. Same Web application client as
  /// [googleClientId] — the ID token's audience is always the server
  /// client ID, regardless of which platform obtained it.
  static const String googleServerClientId =
      '475970937717-h80aqt3b2b7psrt918udc102r6ts61fq.apps.googleusercontent.com';

  /// Apple "Sign in with Apple" Services ID (used for the web/Android
  /// authentication flow; unused while that flow is deferred per this
  /// bolt's checkpoint decisions, but declared for forward compatibility).
  static const String appleServicesId = 'REPLACE_WITH_APPLE_SERVICES_ID';

  /// Apple app Bundle ID (iOS native Sign in with Apple capability).
  static const String appleBundleId = 'REPLACE_WITH_APPLE_BUNDLE_ID';

  /// Apple Developer Team ID.
  static const String appleTeamId = 'REPLACE_WITH_APPLE_TEAM_ID';

  /// Apple Sign-in-with-Apple-for-web Key ID.
  static const String appleKeyId = 'REPLACE_WITH_APPLE_KEY_ID';
}
