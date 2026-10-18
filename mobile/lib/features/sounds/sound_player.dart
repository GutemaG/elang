import 'dart:async';

import 'package:audioplayers/audioplayers.dart' as ap;

import '../../shared/services/media_cache.dart';

/// Plays a letter's recording, at normal speed or slowed down. Kept as an
/// interface so widget tests can record what was played instead of
/// reaching the `audioplayers` platform channel.
abstract class SoundPlayer {
  /// Plays [url] from the start, replacing whatever was playing. Throws
  /// when it cannot play.
  Future<void> play(String url, {bool slow = false});

  Future<void> stop();

  Future<void> dispose();
}

/// How much slower "Slow" plays: one recording serves both speeds.
const slowRate = 0.7;

/// [SoundPlayer] on `audioplayers`, playing from the file in [MediaCache]
/// when it is there (recordings are fetched ahead when a chart opens), so a
/// tap sounds at once and works offline. A recording not saved yet is
/// streamed.
class AudioplayersSoundPlayer implements SoundPlayer {
  AudioplayersSoundPlayer({this.cache}) : _player = ap.AudioPlayer();

  final MediaCache? cache;
  final ap.AudioPlayer _player;

  /// Only the latest tap may start its sound.
  int _latest = 0;

  @override
  Future<void> play(String url, {bool slow = false}) async {
    final ask = ++_latest;
    ap.Source source = ap.UrlSource(url);
    final cache = this.cache;
    if (cache != null && isWebAddress(url)) {
      try {
        source = ap.DeviceFileSource((await cache.fileFor(url)).path);
      } on Object {
        // Streamed instead.
      }
    }
    if (ask != _latest) return;
    await _player.stop();
    await _player.setPlaybackRate(slow ? slowRate : 1);
    await _player.play(source);
  }

  @override
  Future<void> stop() async {
    _latest++;
    await _player.stop();
  }

  @override
  Future<void> dispose() => _player.dispose();
}
