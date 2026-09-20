/// Display names for the language codes courses use (`am`, `om`, `en`). These
/// are labels only -- which courses exist always comes from the backend.
String languageName(String code) {
  switch (code) {
    case 'am':
      return 'Amharic';
    case 'om':
      return 'Afaan Oromo';
    case 'en':
      return 'English';
    default:
      return code;
  }
}

/// A one-character stand-in for a language, used where a flag would go
/// (011-dashboard-ui-polish): the first character of the language's own name,
/// so Amharic reads as Fidel and Afaan Oromo as Latin. No artwork needed, and
/// any future language gets a sensible letter for free.
String languageGlyph(String code) {
  final name = languageNativeName(code);
  return name.isEmpty ? '?' : String.fromCharCode(name.runes.first);
}

/// The language's name in its own language.
String languageNativeName(String code) {
  switch (code) {
    case 'am':
      return 'አማርኛ';
    case 'om':
      return 'Afaan Oromoo';
    case 'en':
      return 'English';
    default:
      return code;
  }
}
