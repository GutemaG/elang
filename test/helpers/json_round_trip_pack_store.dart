// A [FakeLessonPackStore] that keeps each pack as encoded JSON text, the
// way `SqfliteLessonPackStore` does, so a pack played offline has been
// through the real `packContentToJson` / `packContentFromJson` mapping --
// which [FakeLessonPackStore] skips by keeping the object itself
// (016-spell-from-tiles-exercise-type, bolt 033).

import 'dart:convert';

import 'package:elang/shared/models/lesson_content.dart';
import 'package:elang/shared/services/lesson_pack_store.dart';

import 'fake_lesson_pack_store.dart';

class JsonRoundTripPackStore extends FakeLessonPackStore {
  final Map<String, String> _json = {};

  @override
  Future<void> save(
    LessonContent content, {
    String? courseId,
    String? courseTitle,
  }) async {
    _json[content.lessonId] = jsonEncode(packContentToJson(content));
    await super.save(content, courseId: courseId, courseTitle: courseTitle);
  }

  @override
  Future<LessonContent?> load(String lessonId) async {
    final text = _json[lessonId];
    if (text == null) return null;
    return packContentFromJson(jsonDecode(text) as Map<String, dynamic>);
  }

  @override
  Future<void> delete(String lessonId) async {
    _json.remove(lessonId);
    await super.delete(lessonId);
  }
}
