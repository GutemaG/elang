import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../../l10n/app_localizations.dart';
import '../../l10n/app_localizations_en.dart';
import '../services/app_language_repository.dart';

/// A language the app's own words can be shown in (024-app-localization).
///
/// **To add one**, add its `lib/l10n/app_<code>.arb` and a line to [all].
/// Nothing else changes: the backend takes any 2-3 letter code.
@immutable
class AppLanguage {
  const AppLanguage(this.code, this.nativeName, this.englishName);

  final String code;

  /// The language's name in itself, as the picker shows it: አማርኛ.
  final String nativeName;

  /// Its name in English, under the native one in the picker.
  final String englishName;

  Locale get locale => Locale(code);

  static const english = AppLanguage('en', 'English', 'English');

  /// Every app language, in the picker's order.
  static const all = [
    english,
    AppLanguage('am', 'አማርኛ', 'Amharic'),
    AppLanguage('om', 'Afaan Oromoo', 'Afaan Oromo'),
  ];

  /// Whether the app has words for [code].
  static bool has(String? code) => all.any((l) => l.code == code);

  /// The language for [code]; English for none, `""` or one the app has no
  /// words for (a code another app version sent to the account).
  static AppLanguage of(String? code) =>
      all.firstWhere((l) => l.code == code, orElse: () => english);

  /// What `MaterialApp` needs: the app's words, Flutter's own (Material,
  /// Cupertino, widgets), and English ones for Flutter's own words in a
  /// language Flutter has none for (Afaan Oromo).
  static const List<LocalizationsDelegate<dynamic>> delegates = [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    _EnglishMaterialFallback(),
    _EnglishCupertinoFallback(),
  ];

  static List<Locale> get locales => [for (final l in all) l.locale];
}

/// Month and weekday names in the app language: Gregorian, from the ARB
/// files, since `intl` has no Afaan Oromo dates (FR-8).
extension AppDates on AppLocalizations {
  /// "March", for [month] 1 to 12.
  String monthName(int month) => monthNames.split(',')[month - 1];

  /// "Mar", for [month] 1 to 12.
  String monthShort(int month) => monthShortNames.split(',')[month - 1];

  /// One letter per weekday, Monday first.
  List<String> get weekdayLetters => weekdayInitials.split(',');
}

extension AppLocalizationsContext on BuildContext {
  /// The app's words in the current language. English where no
  /// localizations are above (a screen pumped on its own in a test).
  AppLocalizations get l10n =>
      AppLocalizations.of(this) ?? AppLocalizationsEn();
}

/// The learner's app language, app-wide: `MaterialApp` draws in
/// [language], and changing it redraws every screen at once and keeps it on
/// the phone (story 003). [value] is the stored code, `null` until one is
/// chosen; it may be a code this version has no words for (shown as
/// English).
///
/// The account keeps it too (story 006): a Settings change is [send]t at
/// once and, if that fails, at the next session check ([syncWithAccount]).
class AppLanguageController extends ValueNotifier<String?> {
  AppLanguageController({
    required this._repository,
    String? initial,
    this._unsent = false,
    this.send,
  }) : super(initial);

  /// A controller starting from the stored choice, read before the first
  /// frame so the app never shows a frame of English first.
  static Future<AppLanguageController> load(
    AppLanguageRepository repository, {
    Future<bool> Function(String code)? send,
  }) async {
    final stored = await repository.load();
    return AppLanguageController(
      repository: repository,
      initial: stored.code,
      unsent: stored.unsent,
      send: send,
    );
  }

  final AppLanguageRepository _repository;

  /// Saves a code on the account; `true` once saved. Never throws.
  Future<bool> Function(String code)? send;

  /// A Settings change the account has not taken yet.
  bool _unsent;

  AppLanguage get language => AppLanguage.of(value);

  /// The learner chose [code] in Settings: applies at once, keeps it, and
  /// sends it to the account.
  Future<void> choose(String code) async {
    value = code;
    _unsent = true;
    await _repository.save(code, unsent: true);
    await _sendUnsent();
  }

  /// Sign-up's "I speak" choice (story 005): taken only if nothing is
  /// chosen yet and the app has [code]. Not sent: an account that already
  /// has a language wins at the next session check.
  Future<void> adoptSignUpLanguage(String code) async {
    if (value != null || !AppLanguage.has(code)) return;
    value = code;
    await _repository.save(code, unsent: false);
  }

  /// The account's app language from a session check (`""` = none): an
  /// unsent change is sent; otherwise the account's language is taken, or,
  /// if it has none, given the phone's.
  Future<void> syncWithAccount(String accountCode) async {
    if (_unsent) {
      await _sendUnsent();
    } else if (accountCode.isNotEmpty) {
      if (accountCode != value) {
        value = accountCode;
        await _repository.save(accountCode, unsent: false);
      }
    } else if (value case final code?) {
      await send?.call(code);
    }
  }

  Future<void> _sendUnsent() async {
    final code = value;
    final sender = send;
    if (code == null || sender == null) return;
    if (await sender(code) && value == code) {
      _unsent = false;
      await _repository.save(code, unsent: false);
    }
  }
}

/// Hands the [AppLanguageController] down the tree, as `AppearanceScope`
/// does the Appearance choice.
class AppLanguageScope extends InheritedNotifier<AppLanguageController> {
  const AppLanguageScope({
    super.key,
    required AppLanguageController controller,
    required super.child,
  }) : super(notifier: controller);

  /// The nearest controller, or `null` where the app provides none (a
  /// screen pumped on its own in a test).
  static AppLanguageController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppLanguageScope>()?.notifier;
}

/// Flutter's Material words in English for an app language Flutter has
/// none for, so such a language never fails to load.
class _EnglishMaterialFallback
    extends LocalizationsDelegate<MaterialLocalizations> {
  const _EnglishMaterialFallback();

  @override
  bool isSupported(Locale locale) =>
      AppLanguage.has(locale.languageCode) &&
      !GlobalMaterialLocalizations.delegate.isSupported(locale);

  @override
  Future<MaterialLocalizations> load(Locale locale) =>
      DefaultMaterialLocalizations.load(locale);

  @override
  bool shouldReload(_EnglishMaterialFallback old) => false;
}

/// [_EnglishMaterialFallback] for Flutter's Cupertino words.
class _EnglishCupertinoFallback
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const _EnglishCupertinoFallback();

  @override
  bool isSupported(Locale locale) =>
      AppLanguage.has(locale.languageCode) &&
      !GlobalCupertinoLocalizations.delegate.isSupported(locale);

  @override
  Future<CupertinoLocalizations> load(Locale locale) =>
      DefaultCupertinoLocalizations.load(locale);

  @override
  bool shouldReload(_EnglishCupertinoFallback old) => false;
}
