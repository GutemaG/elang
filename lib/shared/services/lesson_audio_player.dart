import 'dart:async';

import 'package:audioplayers/audioplayers.dart' as ap;

import 'media_cache.dart';

/// Thin abstraction over playing a single remote audio clip.
///
/// Kept as an interface (rather than `LessonScreen`/`LessonController`
/// touching `audioplayers` directly) so widget tests can substitute a
/// recording fake at this boundary instead of exercising a real platform
/// channel — same "mock at the network/DB/plugin boundary only" convention
/// `SecureStorageService`/`AuthApi` already follow in this codebase.
abstract class LessonAudioPlayer {
  /// Plays (or replays, from the start) the clip at [url].
  ///
  /// Completes when the clip is over: it reached its end, another [play]
  /// replaced it, or [stop] ended it (bolt 058) -- so a caller can show
  /// "playing" for exactly as long as it plays. Throws if it cannot play.
  Future<void> play(String url);

  /// Ends the clip playing now, if any.
  Future<void> stop();

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
  AudioplayersLessonAudioPlayer() : _player = ap.AudioPlayer() {
    _ends = _player.onPlayerComplete.listen((_) {
      if (_started) _finish();
    });
  }

  final ap.AudioPlayer _player;
  late final StreamSubscription<void> _ends;

  /// The latest play, from its call until its clip is over.
  Completer<void>? _current;

  /// Whether [_current]'s clip has started. An end heard before then is
  /// the previous clip's, and must not end this one.
  bool _started = false;

  void _finish() {
    final current = _current;
    _current = null;
    _started = false;
    if (current != null && !current.isCompleted) current.complete();
  }

  @override
  Future<void> play(String url) async {
    _finish();
    final done = _current = Completer<void>();
    await _player.stop();
    // Replaced while stopping: that newer play has ended this one.
    if (!identical(_current, done)) return done.future;
    final isRemote = url.startsWith('http://') || url.startsWith('https://');
    try {
      await _player.play(
        isRemote ? ap.UrlSource(url) : ap.DeviceFileSource(url),
      );
    } on Object {
      if (identical(_current, done)) _finish();
      rethrow;
    }
    if (identical(_current, done)) {
      // A clip short enough to end while it was starting has no end left
      // to hear.
      if (_player.state == ap.PlayerState.completed) {
        _finish();
      } else {
        _started = true;
      }
    }
    return done.future;
  }

  @override
  Future<void> stop() async {
    _finish();
    await _player.stop();
  }

  @override
  Future<void> dispose() async {
    _finish();
    await _ends.cancel();
    await _player.dispose();
  }
}

/// Plays a web clip from its file in [MediaCache], so a clip heard before
/// -- or fetched ahead when its lesson opened -- starts at once (bolt 057).
///
/// A clip not saved yet is downloaded first; clips are small, and the
/// lesson has usually fetched it ahead already. If the download fails the
/// address is streamed, as before this cache, so the sound still plays.
///
/// A play asked while an earlier one is still downloading replaces it: the
/// learner who moved on to the next question never hears the last one
/// start late. Such a replaced play completes at once, as [play] promises.
class CachingLessonAudioPlayer implements LessonAudioPlayer {
  CachingLessonAudioPlayer({required this._player, required this._cache});

  final LessonAudioPlayer _player;
  final MediaCache _cache;

  /// Counts plays and stops asked for; only the latest play may start its
  /// clip, and a stop means none of those before it may.
  int _latest = 0;

  @override
  Future<void> play(String url) async {
    final ask = ++_latest;
    if (!isWebAddress(url)) return _player.play(url);
    String source;
    try {
      source = (await _cache.fileFor(url)).path;
    } on Object {
      source = url;
    }
    if (ask != _latest) return;
    await _player.play(source);
  }

  @override
  Future<void> stop() {
    _latest++;
    return _player.stop();
  }

  @override
  Future<void> dispose() => _player.dispose();
}
