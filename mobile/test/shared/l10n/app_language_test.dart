// The app language (024-app-localization, bolt 078): the list of
// languages, the choice kept on the phone (story 003), the sign-up default
// (story 005), the account (story 006), and the localizations themselves
// (story 002).

import 'package:elang/l10n/app_localizations.dart';
import 'package:elang/shared/l10n/app_language.dart';
import 'package:elang/shared/services/app_language_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/in_memory_secure_storage_service.dart';

/// Records what is sent to the account, answering with [succeeds].
class _Account {
  final sent = <String>[];
  bool succeeds = true;

  Future<bool> send(String code) async {
    sent.add(code);
    return succeeds;
  }
}

void main() {
  group('AppLanguage', () {
    test('lists English, Amharic and Afaan Oromo by their own names', () {
      expect([for (final l in AppLanguage.all) l.code], ['en', 'am', 'om']);
      expect(
        [for (final l in AppLanguage.all) l.nativeName],
        ['English', 'አማርኛ', 'Afaan Oromoo'],
      );
    });

    test('anything it has no words for is English', () {
      for (final code in [null, '', 'ti', 'xx']) {
        expect(AppLanguage.of(code), AppLanguage.english, reason: '$code');
      }
      expect(AppLanguage.of('om').nativeName, 'Afaan Oromoo');
      expect(AppLanguage.has('am'), isTrue);
      expect(AppLanguage.has('ti'), isFalse);
    });
  });

  group('kept on the phone', () {
    late InMemorySecureStorageService storage;
    late AppLanguageRepository repository;

    setUp(() {
      storage = InMemorySecureStorageService();
      repository = AppLanguageRepository(storage: storage);
    });

    test('nothing stored is English, never chosen', () async {
      final controller = await AppLanguageController.load(repository);
      expect(controller.value, isNull);
      expect(controller.language, AppLanguage.english);
    });

    test('a choice applies at once and is there after a restart', () async {
      final controller = await AppLanguageController.load(repository);
      var heard = 0;
      controller.addListener(() => heard++);

      await controller.choose('am');

      expect(controller.language.code, 'am');
      expect(heard, 1);
      final restarted = await AppLanguageController.load(repository);
      expect(restarted.language.code, 'am');
    });

    test('a stored code the app has no words for reads as English', () async {
      await repository.save('ti', unsent: false);
      final controller = await AppLanguageController.load(repository);
      expect(controller.value, 'ti');
      expect(controller.language, AppLanguage.english);
    });
  });

  group('sign-up', () {
    late AppLanguageRepository repository;

    setUp(
      () => repository = AppLanguageRepository(
        storage: InMemorySecureStorageService(),
      ),
    );

    test('takes the spoken language, and does not send it', () async {
      final account = _Account();
      final controller = AppLanguageController(
        repository: repository,
        send: account.send,
      );

      await controller.adoptSignUpLanguage('am');

      expect(controller.language.code, 'am');
      expect(account.sent, isEmpty);
      expect((await repository.load()).unsent, isFalse);
    });

    test('keeps a language already chosen', () async {
      final controller = AppLanguageController(
        repository: repository,
        initial: 'om',
      );
      await controller.adoptSignUpLanguage('am');
      expect(controller.language.code, 'om');
    });

    test('keeps English for a language the app has no words for', () async {
      final controller = AppLanguageController(repository: repository);
      await controller.adoptSignUpLanguage('ti');
      expect(controller.value, isNull);
    });

    test(
      'a later pick replaces an earlier one, even after a restart',
      () async {
        final first = AppLanguageController(repository: repository);
        await first.adoptSignUpLanguage('am');

        // The app is closed and opened again, and English is picked.
        final reopened = await AppLanguageController.load(repository);
        expect(reopened.value, 'am');
        await reopened.adoptSignUpLanguage('en');

        expect(reopened.value, 'en');
        expect((await repository.load()).code, 'en');
      },
    );

    test('a later pick with no words goes back to English', () async {
      final controller = AppLanguageController(repository: repository);
      await controller.adoptSignUpLanguage('am');
      await controller.adoptSignUpLanguage('ti');

      expect(controller.value, isNull);
      expect((await repository.load()).code, isNull);
    });

    test('never replaces a language chosen in Settings', () async {
      final controller = AppLanguageController(repository: repository);
      await controller.adoptSignUpLanguage('am');
      await controller.choose('om');
      await controller.adoptSignUpLanguage('en');

      expect(controller.value, 'om');
    });

    test("never replaces the account's language", () async {
      final controller = AppLanguageController(repository: repository);
      await controller.adoptSignUpLanguage('am');
      await controller.syncWithAccount('am');
      await controller.adoptSignUpLanguage('en');

      expect(controller.value, 'am');
    });
  });

  group('the account', () {
    late AppLanguageRepository repository;
    late _Account account;

    setUp(() {
      repository = AppLanguageRepository(
        storage: InMemorySecureStorageService(),
      );
      account = _Account();
    });

    Future<AppLanguageController> controller() =>
        AppLanguageController.load(repository, send: account.send);

    test('a Settings choice is sent at once', () async {
      final c = await controller();
      await c.choose('om');
      expect(account.sent, ['om']);
      expect((await repository.load()).unsent, isFalse);
    });

    test('a failed send is kept, and sent at the next session check, even '
        'after a restart', () async {
      account.succeeds = false;
      final c = await controller();
      await c.choose('am');
      expect(c.language.code, 'am', reason: 'the phone keeps the choice');
      expect((await repository.load()).unsent, isTrue);

      account.succeeds = true;
      final restarted = await controller();
      await restarted.syncWithAccount('om');

      expect(account.sent, ['am', 'am']);
      expect(restarted.language.code, 'am', reason: 'not the older account');
      expect((await repository.load()).unsent, isFalse);
    });

    test("a new phone takes the account's language", () async {
      final c = await controller();
      await c.syncWithAccount('om');
      expect(c.language.code, 'om');
      expect(account.sent, isEmpty);
      expect((await controller()).language.code, 'om');
    });

    test("the account's language wins over the sign-up default", () async {
      final c = await controller();
      await c.adoptSignUpLanguage('am');
      await c.syncWithAccount('om');
      expect(c.language.code, 'om');
    });

    test("an account with none is given the phone's", () async {
      final c = await controller();
      await c.adoptSignUpLanguage('am');
      await c.syncWithAccount('');
      expect(account.sent, ['am']);
    });

    test('nothing chosen and nothing on the account sends nothing', () async {
      final c = await controller();
      await c.syncWithAccount('');
      expect(account.sent, isEmpty);
      expect(c.value, isNull);
    });

    test(
      "an account code the app lacks is kept, and shown as English",
      () async {
        final c = await controller();
        await c.syncWithAccount('ti');
        expect(c.value, 'ti');
        expect(c.language, AppLanguage.english);
      },
    );
  });

  group('the localizations', () {
    Future<BuildContext> pumpIn(WidgetTester tester, Locale locale) async {
      late BuildContext captured;
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          localizationsDelegates: AppLanguage.delegates,
          supportedLocales: AppLanguage.locales,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                captured = context;
                return const TextField();
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return captured;
    }

    testWidgets('each language has its own words, plurals included', (
      tester,
    ) async {
      final expected = {
        'en': ('App language', '1 day', '3 days'),
        'am': ('የመተግበሪያ ቋንቋ', '1 ቀን', '3 ቀናት'),
        'om': ('Afaan appii', 'guyyaa 1', 'guyyoota 3'),
      };
      for (final MapEntry(key: code, value: words) in expected.entries) {
        final l10n = (await pumpIn(tester, Locale(code))).l10n;
        expect(l10n.appLanguageTitle, words.$1, reason: code);
        expect(l10n.dayCount(1), words.$2, reason: code);
        expect(l10n.dayCount(3), words.$3, reason: code);
      }
    });

    testWidgets("Afaan Oromo gets Flutter's own words in English, and "
        'Amharic its own', (tester) async {
      final oromo = await pumpIn(tester, const Locale('om'));
      expect(tester.takeException(), isNull);
      expect(MaterialLocalizations.of(oromo).okButtonLabel, 'OK');
      expect(AppLocalizations.of(oromo), isNotNull);

      final amharic = await pumpIn(tester, const Locale('am'));
      expect(MaterialLocalizations.of(amharic).okButtonLabel, isNot('OK'));
    });

    testWidgets('with no localizations above, the words are English', (
      tester,
    ) async {
      late BuildContext captured;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            captured = context;
            return const SizedBox();
          },
        ),
      );
      expect(captured.l10n.close, 'Close');
    });
  });
}
