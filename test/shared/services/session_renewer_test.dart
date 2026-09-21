// Sliding renewal, the app's half: the server renews a session each time
// it is used, and SessionRenewer saves the renewed expiry so the app's own
// offline check at launch does not sign the learner out 30 days after they
// first signed in. It must never block, never throw, and never touch a
// session other than the one it checked.

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:elang/features/auth/auth_flow_controller.dart';
import 'package:elang/shared/models/session_state.dart';
import 'package:elang/shared/services/session_api.dart';
import 'package:elang/shared/services/session_renewer.dart';
import 'package:elang/shared/services/session_repository.dart';

import '../../helpers/in_memory_secure_storage_service.dart';

final _signedInExpiry = DateTime.utc(2026, 10, 1);
final _renewedExpiry = DateTime.utc(2026, 10, 21, 12);

http.Response _valid({String? expiresAt}) => http.Response(
  jsonEncode({
    'valid': true,
    'user': {
      'id': 'user-1',
      'selected_language': 'am',
      'daily_xp_target': 30,
      'notification_enabled': true,
    },
    'expires_at': ?expiresAt,
  }),
  200,
  headers: {'content-type': 'application/json'},
);

Future<SessionRepository> _signedIn({String token = 'tok'}) async {
  final repo = SessionRepository(storage: InMemorySecureStorageService());
  await repo.saveSession(
    SessionState(
      token: token,
      // Far enough ahead that the session counts as valid today.
      expiresAt: DateTime.now().add(const Duration(days: 9)),
      authProvider: 'google',
      displayName: 'Abebe',
    ),
  );
  return repo;
}

SessionRenewer _renewer(SessionRepository repo, http.Client client) =>
    SessionRenewer(
      sessionApi: SessionApi(client: client, baseUrl: 'http://x'),
      sessionRepository: repo,
    );

void main() {
  test('reads the renewed expiry from the session check', () async {
    final api = SessionApi(
      client: MockClient(
        (_) async => _valid(expiresAt: '2026-10-21T12:00:00Z'),
      ),
      baseUrl: 'http://x',
    );

    final result = await api.checkSession('tok');

    expect(result.status, SessionCheckStatus.valid);
    expect(result.expiresAt, _renewedExpiry);
  });

  test('saves the renewed expiry and keeps the rest of the session', () async {
    final repo = await _signedIn();

    await _renewer(
      repo,
      MockClient((_) async => _valid(expiresAt: '2026-10-21T12:00:00Z')),
    ).renew();

    final saved = await repo.getSessionState();
    expect(saved.expiresAt, _renewedExpiry);
    expect(saved.token, 'tok');
    expect(saved.authProvider, 'google');
    expect(saved.displayName, 'Abebe');
  });

  test('offline, the saved session is left exactly as it was', () async {
    final repo = await _signedIn();
    final before = (await repo.getSessionState()).expiresAt;

    await _renewer(
      repo,
      MockClient((_) async => throw http.ClientException('offline')),
    ).renew();

    expect((await repo.getSessionState()).expiresAt, before);
  });

  test('an older backend with no expires_at changes nothing', () async {
    final repo = await _signedIn();
    final before = (await repo.getSessionState()).expiresAt;

    await _renewer(repo, MockClient((_) async => _valid())).renew();

    expect((await repo.getSessionState()).expiresAt, before);
  });

  test('a session refused by the server is not cleared from here', () async {
    final repo = await _signedIn();

    await _renewer(
      repo,
      MockClient(
        (_) async => http.Response(
          jsonEncode({'valid': false}),
          200,
          headers: {'content-type': 'application/json'},
        ),
      ),
    ).renew();

    // The dashboard's "Please sign in again" handles it; nothing is
    // signed out behind the learner's back.
    expect((await repo.getSessionState()).token, 'tok');
  });

  test('a sign-in during the check is not overwritten', () async {
    final repo = await _signedIn(token: 'old');
    final reply = Completer<http.Response>();
    final renewing = _renewer(repo, MockClient((_) => reply.future)).renew();

    await repo.saveSession(
      SessionState(token: 'new', expiresAt: _signedInExpiry),
    );
    reply.complete(_valid(expiresAt: '2026-10-21T12:00:00Z'));
    await renewing;

    final saved = await repo.getSessionState();
    expect(saved.token, 'new');
    expect(saved.expiresAt, _signedInExpiry);
  });

  test('launch routes home at once and renews in the background', () async {
    final repo = await _signedIn();
    final reply = Completer<http.Response>();
    final controller = AuthFlowController(
      sessionRepository: repo,
      renewer: _renewer(repo, MockClient((_) => reply.future)),
    );

    // Resolves while the renewal request is still unanswered.
    expect(
      await controller.resolveStartDestination(),
      AuthStartDestination.home,
    );

    reply.complete(_valid(expiresAt: '2026-10-21T12:00:00Z'));
    await pumpEventQueue();
    expect((await repo.getSessionState()).expiresAt, _renewedExpiry);
  });
}
