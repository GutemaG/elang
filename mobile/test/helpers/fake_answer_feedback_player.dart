// Recording fake for [AnswerFeedbackPlayer], used across widget tests so
// grading's sound/haptic cue can be asserted on without depending on the
// `audioplayers` platform channel or `HapticFeedback`'s `MethodChannel`
// (neither has a test-environment implementation).
//
// Mocking here is at the plugin boundary only, per `coding-standards.md`'s
// "mock at the network/DB boundary only" testing convention.

import 'package:elang/shared/services/answer_feedback_player.dart';

enum FeedbackCue { correct, incorrect }

class FakeAnswerFeedbackPlayer implements AnswerFeedbackPlayer {
  final List<FeedbackCue> cues = [];

  @override
  Future<void> playCorrect() async {
    cues.add(FeedbackCue.correct);
  }

  @override
  Future<void> playIncorrect() async {
    cues.add(FeedbackCue.incorrect);
  }

  @override
  Future<void> dispose() async {}
}
