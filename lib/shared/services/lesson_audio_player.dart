import 'package:audioplayers/audioplayers.dart' as ap;

/// Thin abstraction over playing a single remote audio clip.
///
/// Kept as an interface (rather than `LessonScreen`/`LessonController`
/// touching `audioplayers` directly) so widget tests can substitute a
/// recording fake at this boundary instead of exercising a real platform
/// channel — same "mock at the network/DB/plugin boundary only" convention
/// `SecureStorageService`/`AuthApi` already follow in this codebase.
abstract class LessonAudioPlayer {
  /// Plays (or replays, from the start) the clip at [url].
  Future<void> play(String url);

  Future<void> dispose();
}

/// Real implementation backed by the `audioplayers` package.
class AudioplayersLessonAudioPlayer implements LessonAudioPlayer {
  AudioplayersLessonAudioPlayer() : _player = ap.AudioPlayer();

  final ap.AudioPlayer _player;

  @override
  Future<void> play(String url) async {
    await _player.stop();
    await _player.play(ap.UrlSource(url));
  }

  @override
  Future<void> dispose() => _player.dispose();
}
