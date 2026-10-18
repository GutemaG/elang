import '../../../shared/widgets/exercise/answer_action_bar.dart';
import '../../../shared/widgets/exercise/answer_tile.dart';
import '../state/lesson_controller.dart';

/// The kit's grade for the controller's [feedback]: `null` until the
/// question is graded.
AnswerGrade? gradeOf(TileFeedback feedback) => switch (feedback) {
  TileFeedback.none => null,
  TileFeedback.correct => AnswerGrade.correct,
  TileFeedback.incorrect => AnswerGrade.incorrect,
};

/// A choice tile's look. Only the chosen tile shows the grade; the others
/// stay idle (and fade once they stop taking taps).
AnswerTileState choiceStateOf({
  required bool chosen,
  required TileFeedback feedback,
}) {
  if (!chosen) return AnswerTileState.idle;
  return switch (feedback) {
    TileFeedback.none => AnswerTileState.selected,
    TileFeedback.correct => AnswerTileState.correct,
    TileFeedback.incorrect => AnswerTileState.incorrect,
  };
}
