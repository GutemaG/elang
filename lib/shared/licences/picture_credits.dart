import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The credits of the pictures bundled with the app (019-image-choice-
/// exercise-types, story 005): one entry per picture, beside the pictures
/// in `assets/pictures/`, kept identical to `backend/sample_pictures/`'s.
const pictureCreditsAsset = 'assets/pictures/credits.json';

/// The heading the credits are listed under on the licence page.
const pictureCreditsPackage = 'Sample pictures';

/// One licence-page entry per picture in [creditsJson], in the file's
/// order: its title, author and source, its licence, and what was changed.
///
/// That is Creative Commons' recommended credit (title, author, source,
/// licence), plus the changes CC BY-SA asks to be noted. Every picture is
/// listed, even one whose licence (CC0) asks for no credit. Nothing here
/// names a picture, so one added to the file is listed with no code change.
List<LicenseEntry> pictureCreditEntries(String creditsJson) {
  final pictures = ((jsonDecode(creditsJson) as Map)['pictures'] as List)
      .cast<Map<String, dynamic>>();
  return [
    for (final picture in pictures)
      LicenseEntryWithLineBreaks(const [
        pictureCreditsPackage,
      ], _creditOf(picture)),
  ];
}

String _creditOf(Map<String, dynamic> picture) {
  String? field(String name) {
    final value = picture[name];
    return value is String && value.trim().isNotEmpty ? value.trim() : null;
  }

  final subject = field('subject') ?? field('file') ?? 'Picture';
  final author = field('author');
  final source = field('source');
  final by = [
    if (author != null) 'By $author',
    if (source != null) 'from $source',
  ].join(', ');
  final changes = field('changes');
  // Paragraphs, which the licence page separates with a blank line.
  return [
    subject,
    if (by.isNotEmpty) by,
    ?field('source_url'),
    if (field('licence') case final licence?) 'Licence: $licence',
    ?field('licence_url'),
    if (changes != null) 'Changes: $changes',
  ].join('\n\n');
}

/// Lists the bundled pictures' credits on Flutter's licence page. Call once,
/// before `runApp`.
///
/// The file is only read when the licence page asks for its entries. If it
/// can't be read, the page still opens with every other licence.
void registerPictureCredits({AssetBundle? bundle}) {
  LicenseRegistry.addLicense(() async* {
    final String json;
    try {
      json = await (bundle ?? rootBundle).loadString(pictureCreditsAsset);
    } on Object catch (error) {
      debugPrint('Picture credits could not be read: $error');
      return;
    }
    yield* Stream.fromIterable(pictureCreditEntries(json));
  });
}
