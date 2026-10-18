// `ProviderProfile` reads the name/email/photo claims out of a provider's ID
// token for Settings, and never fails on a token it cannot read.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:elang/shared/models/provider_profile.dart';
import 'package:elang/shared/models/session_state.dart';

String _jwt(Map<String, Object?> claims) {
  String part(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${part({'alg': 'RS256'})}.${part(claims)}.signature';
}

void main() {
  test('reads name, email and picture from a Google ID token', () {
    final profile = ProviderProfile.fromIdToken(
      _jwt({
        'sub': '123',
        'name': 'Abebe Bikila',
        'email': 'abebe@example.com',
        'picture': 'https://lh3.googleusercontent.com/a/photo',
      }),
    );

    expect(profile.name, 'Abebe Bikila');
    expect(profile.email, 'abebe@example.com');
    expect(profile.photoUrl, 'https://lh3.googleusercontent.com/a/photo');
  });

  test('missing or blank claims read as null (Apple shares no name)', () {
    final profile = ProviderProfile.fromIdToken(
      _jwt({'sub': '123', 'email': 'x@privaterelay.appleid.com', 'name': ' '}),
    );

    expect(profile.name, isNull);
    expect(profile.photoUrl, isNull);
    expect(profile.email, 'x@privaterelay.appleid.com');
  });

  test('a token that is not a readable JWT gives an empty profile', () {
    for (final token in [
      '',
      'not-a-jwt',
      'a.%%%.c',
      'a.${base64Url.encode(utf8.encode('[1]'))}.c',
    ]) {
      final profile = ProviderProfile.fromIdToken(token);
      expect(profile.name, isNull, reason: token);
      expect(profile.email, isNull, reason: token);
    }
  });

  test('the profile round-trips through a saved session', () {
    const session = SessionState(
      token: 't',
      authProvider: 'google',
      displayName: 'Abebe Bikila',
      email: 'abebe@example.com',
      photoUrl: 'https://example.com/p.jpg',
    );

    final restored = SessionState.fromJson(session.toJson());

    expect(restored.displayName, 'Abebe Bikila');
    expect(restored.email, 'abebe@example.com');
    expect(restored.photoUrl, 'https://example.com/p.jpg');
  });

  test('a session saved before profiles existed reads with no profile', () {
    final restored = SessionState.fromJson({
      'token': 't',
      'authProvider': 'google',
    });

    expect(restored.displayName, isNull);
    expect(restored.token, 't');
  });
}
