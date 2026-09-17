import 'dart:async';

import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:vibration/vibration.dart';

import 'sound_preference_repository.dart';

/// Plays the short sound + vibration cue that fires the instant an exercise
/// answer is graded -- one cue for correct, a distinctly different one for
/// incorrect, so grading is felt as well as seen.
///
/// Kept as an interface (mirrors [LessonAudioPlayer]) so widget tests never
/// touch the `audioplayers`/`vibration` platform channels directly -- same
/// "mock at the plugin boundary only" convention `coding-standards.md`
/// already establishes for this codebase.
abstract class AnswerFeedbackPlayer {
  Future<void> playCorrect();
  Future<void> playIncorrect();
  Future<void> dispose();
}

/// Real implementation: a bright ascending chime + a short buzz for a
/// correct answer; a low double-buzz tone + a matching double-pulse ("zig
/// zig") vibration for an incorrect one, so the two are never confusable by
/// feel alone.
///
/// Sound is loaded via [rootBundle] and played as a [ap.BytesSource]
/// rather than an [ap.AssetSource]: `AssetSource` goes through
/// `audioplayers`' `AudioCache`, which round-trips the asset through a
/// `path_provider` temp file before playback -- a code path this project
/// had never actually exercised on a real device before this feature (the
/// existing listening-exercise audio only ever used `UrlSource`, which
/// skips `AudioCache` entirely). `BytesSource` hands the decoded bytes to
/// the platform player directly, avoiding that path.
///
/// Vibration goes through the `vibration` package (talks to the vibration
/// motor directly) rather than `flutter/services.dart`'s `HapticFeedback`,
/// which on Android routes through `View.performHapticFeedback` -- that's
/// gated behind the phone's system "touch vibration" setting and has no
/// way to express a custom multi-pulse pattern, so it can silently do
/// nothing depending on the device.
class SystemAnswerFeedbackPlayer implements AnswerFeedbackPlayer {
  SystemAnswerFeedbackPlayer()
    : _correctPlayer = ap.AudioPlayer(),
      _incorrectPlayer = ap.AudioPlayer();

  final ap.AudioPlayer _correctPlayer;
  final ap.AudioPlayer _incorrectPlayer;

  Future<Uint8List>? _correctBytes;
  Future<Uint8List>? _incorrectBytes;

  Future<Uint8List> get _correct =>
      _correctBytes ??= _loadBytes('assets/sounds/correct.wav');

  Future<Uint8List> get _incorrect =>
      _incorrectBytes ??= _loadBytes('assets/sounds/incorrect.wav');

  Future<Uint8List> _loadBytes(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }

  @override
  Future<void> playCorrect() async {
    unawaited(_vibrate(duration: 60, amplitude: 190));
    await _play(_correctPlayer, _correct);
  }

  @override
  Future<void> playIncorrect() async {
    // A single [wait, buzz, wait, buzz] pattern rather than two sequential
    // calls, so the pulses land back-to-back instead of drifting apart
    // under scheduling jitter.
    unawaited(_vibrate(pattern: [0, 130, 90, 130], amplitude: 255));
    await _play(_incorrectPlayer, _incorrect);
  }

  Future<void> _play(ap.AudioPlayer player, Future<Uint8List> bytes) async {
    try {
      await player
          .play(ap.BytesSource(await bytes))
          .timeout(const Duration(seconds: 3));
    } catch (e) {
      // A missed grading cue is a papercut, not a reason to break the
      // lesson -- but a stuck/failed platform call should still be
      // visible while developing rather than silently doing nothing
      // forever.
      debugPrint('AnswerFeedbackPlayer: sound cue failed: $e');
    }
  }

  Future<void> _vibrate({
    int duration = 500,
    List<int> pattern = const [],
    int amplitude = -1,
  }) async {
    try {
      if (!await Vibration.hasVibrator()) return;
      final useAmplitude = await Vibration.hasAmplitudeControl();
      await Vibration.vibrate(
        duration: duration,
        pattern: pattern,
        amplitude: useAmplitude ? amplitude : -1,
      );
    } catch (e) {
      debugPrint('AnswerFeedbackPlayer: vibration cue failed: $e');
    }
  }

  @override
  Future<void> dispose() async {
    await _correctPlayer.dispose();
    await _incorrectPlayer.dispose();
  }
}

/// Gates a real [AnswerFeedbackPlayer] behind the sound-on/off preference
/// (`005-profile-and-settings`, FR-5). Checks the current preference fresh
/// on every call -- so a toggle flipped in Settings takes effect on the
/// very next graded answer, no restart needed -- rather than caching it at
/// construction, since this player is built once at app start-up
/// (`LessonDependencies`), long before any toggle could be flipped.
class SoundGatedAnswerFeedbackPlayer implements AnswerFeedbackPlayer {
  SoundGatedAnswerFeedbackPlayer({
    required AnswerFeedbackPlayer player,
    required SoundPreferenceRepository soundPreferenceRepository,
  }) : _player = player,
       _soundPreferenceRepository = soundPreferenceRepository;

  final AnswerFeedbackPlayer _player;
  final SoundPreferenceRepository _soundPreferenceRepository;

  @override
  Future<void> playCorrect() async {
    if (!await _soundPreferenceRepository.getSoundEnabled()) return;
    await _player.playCorrect();
  }

  @override
  Future<void> playIncorrect() async {
    if (!await _soundPreferenceRepository.getSoundEnabled()) return;
    await _player.playIncorrect();
  }

  @override
  Future<void> dispose() => _player.dispose();
}
