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
