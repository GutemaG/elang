// Recording fake for [LessonAudioPlayer], used across widget tests so
// listening-exercise playback can be exercised without depending on the
// `audioplayers` platform channel (which has no test-environment
// implementation).
//
// Mocking here is at the plugin boundary only, per `coding-standards.md`'s
// "mock at the network/DB boundary only" testing convention.

import 'package:elang/shared/services/lesson_audio_player.dart';

class FakeLessonAudioPlayer implements LessonAudioPlayer {
  final List<String> playedUrls = [];

  @override
  Future<void> play(String url) async {
    playedUrls.add(url);
  }

  @override
  Future<void> dispose() async {}
}
