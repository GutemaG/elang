import 'package:flutter/foundation.dart';

/// Display names for the language codes courses use (`am`, `om`, `sid`, ...).
/// These are labels only -- which courses exist always comes from the
/// backend.
///
/// Languages are data on the server (the admin site adds them), and every
/// course the server sends carries its two languages' names, which
/// [Course.fromJson] passes to [rememberLanguageNames]. So a language added
/// after this build is still named, with no app update. The built-in table
/// covers the languages the backend starts with, for before any course has
/// arrived.
const Map<String, (String, String)> _builtIn = {
  'am': ('Amharic', 'አማርኛ'),
  'om': ('Afaan Oromo', 'Afaan Oromoo'),
  'ti': ('Tigrinya', 'ትግርኛ'),
  'so': ('Somali', 'Soomaali'),
  'aa': ('Afar', 'Qafaraf'),
  'sid': ('Sidama', 'Sidaamu Afoo'),
  'wal': ('Wolaytta', 'Wolayttatto'),
  'sgw': ('Gurage', 'ጉራጊኛ'),
  'hdy': ('Hadiyya', 'Hadiyyisa'),
  'gmv': ('Gamo', 'Gamo'),
  'drs': ('Gedeo', "Gede'uffa"),
  'kbr': ('Kafa', 'Kafi noonoo'),
  'stv': ("Silt'e", 'ስልጥኛ'),
  'har': ('Harari', 'ሀረሪ'),
  'gez': ("Ge'ez", 'ግዕዝ'),
  'en': ('English', 'English'),
};

/// Names the server has sent this run, which win over [_builtIn].
final Map<String, (String, String)> _fromServer = {};

/// Keeps the server's names for [code]. A name that is just the code (the
/// server's answer for a code it has no row for) is not a name, so it never
/// replaces a better one.
void rememberLanguageNames(
  String code, {
  required String name,
  required String nativeName,
}) {
  if (name.isEmpty || nativeName.isEmpty || name == code) return;
  _fromServer[code] = (name, nativeName);
}

/// Forgets every name the server sent, so tests start alike.
@visibleForTesting
void forgetServerLanguageNames() => _fromServer.clear();

/// The language's name in English, e.g. Amharic; an unknown code is shown
/// as itself.
String languageName(String code) =>
    _fromServer[code]?.$1 ?? _builtIn[code]?.$1 ?? code;

/// A one-character stand-in for a language, used where a flag would go
/// (011-dashboard-ui-polish): the first character of the language's own name,
/// so Amharic reads as Fidel and Afaan Oromo as Latin. No artwork needed, and
/// any future language gets a sensible letter for free.
String languageGlyph(String code) {
  final name = languageNativeName(code);
  return name.isEmpty ? '?' : String.fromCharCode(name.runes.first);
}

/// The language's name in its own language.
String languageNativeName(String code) =>
    _fromServer[code]?.$2 ?? _builtIn[code]?.$2 ?? code;
