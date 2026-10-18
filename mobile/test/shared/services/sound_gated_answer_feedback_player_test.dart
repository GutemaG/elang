// Tests for `SoundGatedAnswerFeedbackPlayer` (`005-profile-and-settings`,
// FR-5): gates the real player behind the sound-on/off preference, checked
// fresh on every call.

import 'package:flutter_test/flutter_test.dart';

import 'package:elang/shared/services/answer_feedback_player.dart';
import 'package:elang/shared/services/sound_preference_repository.dart';

import '../../helpers/fake_answer_feedback_player.dart';
import '../../helpers/in_memory_secure_storage_service.dart';

void main() {
  test('delegates playCorrect/playIncorrect when sound is enabled (the default)', () async {
    final inner = FakeAnswerFeedbackPlayer();
    final gated = SoundGatedAnswerFeedbackPlayer(
      player: inner,
      soundPreferenceRepository: SoundPreferenceRepository(
        storage: InMemorySecureStorageService(),
      ),
    );

    await gated.playCorrect();
    await gated.playIncorrect();

    expect(inner.cues, [FeedbackCue.correct, FeedbackCue.incorrect]);
  });

  test('suppresses both calls when sound is disabled', () async {
    final inner = FakeAnswerFeedbackPlayer();
    final storage = InMemorySecureStorageService();
    await SoundPreferenceRepository(storage: storage).setSoundEnabled(false);
    final gated = SoundGatedAnswerFeedbackPlayer(
      player: inner,
      soundPreferenceRepository: SoundPreferenceRepository(storage: storage),
    );

    await gated.playCorrect();
    await gated.playIncorrect();

    expect(inner.cues, isEmpty);
  });

  test('checks the preference fresh on every call, not just at construction', () async {
    final inner = FakeAnswerFeedbackPlayer();
    final storage = InMemorySecureStorageService();
    final soundPreferenceRepository = SoundPreferenceRepository(storage: storage);
    final gated = SoundGatedAnswerFeedbackPlayer(
      player: inner,
      soundPreferenceRepository: soundPreferenceRepository,
    );

    await gated.playCorrect();
    expect(inner.cues, [FeedbackCue.correct]);

    await soundPreferenceRepository.setSoundEnabled(false);
    await gated.playCorrect();
    expect(inner.cues, [FeedbackCue.correct]); // still just the one

    await soundPreferenceRepository.setSoundEnabled(true);
    await gated.playIncorrect();
    expect(inner.cues, [FeedbackCue.correct, FeedbackCue.incorrect]);
  });

  test('dispose delegates through unconditionally', () async {
    var disposed = false;
    final inner = _DisposeTrackingPlayer(onDispose: () => disposed = true);
    final gated = SoundGatedAnswerFeedbackPlayer(
      player: inner,
      soundPreferenceRepository: SoundPreferenceRepository(
        storage: InMemorySecureStorageService(),
      ),
    );

    await gated.dispose();

    expect(disposed, isTrue);
  });
}

class _DisposeTrackingPlayer implements AnswerFeedbackPlayer {
  _DisposeTrackingPlayer({required this.onDispose});

  final void Function() onDispose;

  @override
  Future<void> playCorrect() async {}

  @override
  Future<void> playIncorrect() async {}

  @override
  Future<void> dispose() async => onDispose();
}
