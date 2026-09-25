import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../models/course.dart';
import '../models/exercise.dart';
import '../models/lesson_content.dart';
import 'lesson_api.dart';
import 'lesson_pack_store.dart';

/// A lesson's download state, as shown by the skill-tree dashboard's
/// download affordance (009-offline-caching-and-sync-ui, story 001).
enum LessonDownloadStatus { notDownloaded, downloading, downloaded, failed }

/// Downloads a lesson's content, clips and pictures for offline use, then
/// persists it via [LessonPackStore].
///
/// A `ChangeNotifier` (same pattern as `LessonController`) so the dashboard
/// can show live per-lesson download progress without polling.
class LessonPackDownloader extends ChangeNotifier {
  LessonPackDownloader({
    required this._lessonApi,
    required this._packStore,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  final LessonApi _lessonApi;
  final LessonPackStore _packStore;
  final http.Client _httpClient;

  final Map<String, LessonDownloadStatus> _statusByLessonId = {};

  /// The course new downloads are filed under (010-multi-language-courses).
  /// The dashboard sets it whenever it shows a course, so the download
  /// affordance deep in the tree needs no course plumbing.
  Course? currentCourse;

  LessonDownloadStatus statusFor(String lessonId) =>
      _statusByLessonId[lessonId] ?? LessonDownloadStatus.notDownloaded;

  /// Populates [statusFor] with `downloaded` for every already-downloaded
  /// lesson -- call once when the dashboard loads so previously-downloaded
  /// packs show correctly without the user re-triggering anything.
  Future<void> refreshDownloadedStatuses() async {
    final downloaded = await _packStore.listDownloadedLessonIds();
    for (final lessonId in downloaded) {
      _statusByLessonId[lessonId] = LessonDownloadStatus.downloaded;
    }
    notifyListeners();
  }

  /// Fetches [lessonId]'s content, downloads every clip and picture into
  /// local storage, and persists the result. Safe to call again
  /// for an already-downloaded lesson (re-downloads and overwrites, e.g. to
  /// pick up a content-version change -- no separate "update" method).
  Future<void> downloadLesson(String lessonId) async {
    _statusByLessonId[lessonId] = LessonDownloadStatus.downloading;
    notifyListeners();
    try {
      final content = await _lessonApi.startLesson(lessonId);
      final withLocalFiles = await _downloadFilesAndRewrite(content);
      await _packStore.save(
        withLocalFiles,
        courseId: currentCourse?.id,
        courseTitle: currentCourse?.title,
      );
      _statusByLessonId[lessonId] = LessonDownloadStatus.downloaded;
    } catch (e, stackTrace) {
      // A failed download leaves no partial pack behind -- `_packStore.save`
      // is never reached unless every file downloaded successfully, and
      // the files this attempt created are removed again (see
      // `_downloadFilesAndRewrite`).
      debugPrint('LessonPackDownloader: download failed for $lessonId: $e\n$stackTrace');
      _statusByLessonId[lessonId] = LessonDownloadStatus.failed;
    }
    notifyListeners();
  }

  /// Downloads every clip and picture [content] uses into this lesson's
  /// folder and points the exercises at the saved files (bolt 054 added
  /// pictures and the audio picture question's clip).
  ///
  /// Files are named after their exercise: `{id}{ext}` for a clip and
  /// `{id}-picture-{n}{ext}` for the picture in choice `n`. An address is
  /// fetched once per pack, so choices sharing a picture share its file.
  ///
  /// If any file fails, those this attempt created are deleted before the
  /// error goes on, so a download that runs out of space leaves nothing
  /// behind. Files an earlier download of this lesson saved are only ever
  /// overwritten, so that pack stays playable.
  Future<LessonContent> _downloadFilesAndRewrite(LessonContent content) async {
    if (!content.exercises.any(_hasFiles)) return content;

    final documentsDir = await getApplicationDocumentsDirectory();
    final packDir = Directory('${documentsDir.path}/lesson_packs/${content.lessonId}');
    await packDir.create(recursive: true);

    final created = <File>[];
    final savedByUrl = <String, String>{};
    Future<String> fetch(String url, String name) async {
      final saved = savedByUrl[url];
      if (saved != null) return saved;
      final path = await _downloadFile(url, packDir, name, created);
      savedByUrl[url] = path;
      return path;
    }

    Future<List<PictureChoice>> fetchPictures(String exerciseId, List<PictureChoice> choices) async => [
      for (var n = 0; n < choices.length; n++)
        PictureChoice(
          imageUrl: await fetch(choices[n].imageUrl, '$exerciseId-picture-$n'),
          altText: choices[n].altText,
        ),
    ];

    final rewrittenExercises = <Exercise>[];
    try {
      for (final exercise in content.exercises) {
        rewrittenExercises.add(switch (exercise) {
          ListeningExercise e => ListeningExercise(
            id: e.id,
            audioUrl: await fetch(e.audioUrl, e.id),
            instruction: e.instruction,
            options: e.options,
            correctOptionIndex: e.correctOptionIndex,
          ),
          ImageChoiceExercise e => ImageChoiceExercise(
            id: e.id,
            prompt: e.prompt,
            choices: await fetchPictures(e.id, e.choices),
            correctOptionIndex: e.correctOptionIndex,
          ),
          AudioImageChoiceExercise e => AudioImageChoiceExercise(
            id: e.id,
            audioUrl: await fetch(e.audioUrl, e.id),
            instruction: e.instruction,
            choices: await fetchPictures(e.id, e.choices),
            correctOptionIndex: e.correctOptionIndex,
          ),
          _ => exercise,
        });
      }
    } catch (_) {
      for (final file in created) {
        try {
          if (await file.exists()) await file.delete();
        } on Object {
          // Best effort: a file that can't be removed is only wasted space.
        }
      }
      rethrow;
    }

    return LessonContent(
      lessonId: content.lessonId,
      skillId: content.skillId,
      title: content.title,
      exercises: rewrittenExercises,
      beansAtStart: content.beansAtStart,
      beansMax: content.beansMax,
      contentVersion: content.contentVersion,
      // Dropping this made an offline completion of any lesson with a
      // skipped exercise report a short `total_count`, which the server
      // rejects -- so it could never sync.
      unrenderableCount: content.unrenderableCount,
    );
  }

  /// Whether [exercise] has a clip or pictures to download.
  static bool _hasFiles(Exercise exercise) =>
      exercise is ListeningExercise || exercise is ImageChoiceExercise || exercise is AudioImageChoiceExercise;

  /// Saves [url] as `{name}{ext}` in [packDir], adding it to [created] if it
  /// was not there before.
  Future<String> _downloadFile(String url, Directory packDir, String name, List<File> created) async {
    final response = await _httpClient.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw LessonPackDownloadException('Failed to download $url for $name: HTTP ${response.statusCode}');
    }
    final file = File('${packDir.path}/$name${_extensionOf(url)}');
    final existed = await file.exists();
    await file.writeAsBytes(response.bodyBytes);
    if (!existed) created.add(file);
    return file.path;
  }

  /// The extension of [url]'s last path segment, such as `.webp`; a query
  /// string never ends up in a file name. Empty when there is none: the
  /// app reads clips and pictures by their content, not their name.
  static String _extensionOf(String url) {
    final segments = Uri.parse(url).pathSegments;
    final last = segments.isEmpty ? '' : segments.last;
    final dot = last.lastIndexOf('.');
    return dot <= 0 ? '' : last.substring(dot);
  }
}

class LessonPackDownloadException implements Exception {
  const LessonPackDownloadException(this.message);

  final String message;

  @override
  String toString() => 'LessonPackDownloadException: $message';
}
