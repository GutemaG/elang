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
///
/// [play] accepts either a remote URL (the normal online case) or a local
/// file path (009-offline-caching-and-sync-ui: a downloaded lesson pack's
/// audio, rewritten to a local path by `LessonPackStore`) -- distinguished
/// by whether the string has an `http`/`https` scheme, since a bare local
/// path never does.
class AudioplayersLessonAudioPlayer implements LessonAudioPlayer {
  AudioplayersLessonAudioPlayer() : _player = ap.AudioPlayer();

  final ap.AudioPlayer _player;

  @override
  Future<void> play(String url) async {
    await _player.stop();
    final isRemote = url.startsWith('http://') || url.startsWith('https://');
    await _player.play(isRemote ? ap.UrlSource(url) : ap.DeviceFileSource(url));
  }

  @override
  Future<void> dispose() => _player.dispose();
}
