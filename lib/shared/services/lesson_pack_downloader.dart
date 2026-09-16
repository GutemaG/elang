import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../models/exercise.dart';
import '../models/lesson_content.dart';
import 'lesson_api.dart';
import 'lesson_pack_store.dart';

/// A lesson's download state, as shown by the skill-tree dashboard's
/// download affordance (009-offline-caching-and-sync-ui, story 001).
enum LessonDownloadStatus { notDownloaded, downloading, downloaded, failed }

/// Downloads a lesson's content and audio for offline use, then persists it
/// via [LessonPackStore].
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

  /// Fetches [lessonId]'s content, downloads every listening exercise's
  /// audio into local storage, and persists the result. Safe to call again
  /// for an already-downloaded lesson (re-downloads and overwrites, e.g. to
  /// pick up a content-version change -- no separate "update" method).
  Future<void> downloadLesson(String lessonId) async {
    _statusByLessonId[lessonId] = LessonDownloadStatus.downloading;
    notifyListeners();
    try {
      final content = await _lessonApi.startLesson(lessonId);
      final withLocalAudio = await _downloadAudioAndRewrite(content);
      await _packStore.save(withLocalAudio);
      _statusByLessonId[lessonId] = LessonDownloadStatus.downloaded;
    } catch (e, stackTrace) {
      // A failed download leaves no partial pack behind -- `_packStore.save`
      // is never reached unless every audio file downloaded successfully,
      // so there's nothing half-written to clean up.
      debugPrint('LessonPackDownloader: download failed for $lessonId: $e\n$stackTrace');
      _statusByLessonId[lessonId] = LessonDownloadStatus.failed;
    }
    notifyListeners();
  }

  Future<LessonContent> _downloadAudioAndRewrite(LessonContent content) async {
    final hasAudio = content.exercises.any((e) => e is ListeningExercise);
    if (!hasAudio) return content;

    final documentsDir = await getApplicationDocumentsDirectory();
    final packDir = Directory('${documentsDir.path}/lesson_packs/${content.lessonId}');
    await packDir.create(recursive: true);

    final rewrittenExercises = <Exercise>[];
    for (final exercise in content.exercises) {
      if (exercise is ListeningExercise) {
        final localPath = await _downloadAudioFile(exercise.audioUrl, packDir, exercise.id);
        rewrittenExercises.add(
          ListeningExercise(
            id: exercise.id,
            audioUrl: localPath,
            instruction: exercise.instruction,
            options: exercise.options,
            correctOptionIndex: exercise.correctOptionIndex,
          ),
        );
      } else {
        rewrittenExercises.add(exercise);
      }
    }

    return LessonContent(
      lessonId: content.lessonId,
      skillId: content.skillId,
      title: content.title,
      exercises: rewrittenExercises,
      beansAtStart: content.beansAtStart,
      beansMax: content.beansMax,
      contentVersion: content.contentVersion,
    );
  }

  Future<String> _downloadAudioFile(String url, Directory packDir, String exerciseId) async {
    final response = await _httpClient.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw LessonPackDownloadException(
        'Failed to download audio for exercise $exerciseId: HTTP ${response.statusCode}',
      );
    }
    final extension = url.contains('.') ? url.substring(url.lastIndexOf('.')) : '.mp3';
    final file = File('${packDir.path}/$exerciseId$extension');
    await file.writeAsBytes(response.bodyBytes);
    return file.path;
  }
}

class LessonPackDownloadException implements Exception {
  const LessonPackDownloadException(this.message);

  final String message;

  @override
  String toString() => 'LessonPackDownloadException: $message';
}
