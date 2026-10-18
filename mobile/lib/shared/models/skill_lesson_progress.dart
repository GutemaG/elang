import 'skill_tree.dart';

/// Where the lesson being played sits within its skill: lesson
/// [lessonNumber] of [lessonCount] in [skillTitle].
///
/// A skill only turns green once every one of its lessons is done, so the
/// lesson screen and its summary say which lesson this is and how many are
/// left. Without it, finishing lesson 1 of 2 looks like nothing happened,
/// and the next tap on the same node opening different questions looks
/// like a bug.
class SkillLessonProgress {
  const SkillLessonProgress({
    required this.skillTitle,
    required this.lessonsDoneBefore,
    required this.lessonCount,
  });

  /// The progress for a lesson started from [node], or `null` when there
  /// is nothing worth saying: a single-lesson skill, a review of a finished
  /// skill, or an older backend that sends no lesson counts.
  static SkillLessonProgress? forNode(SkillTreeNode node) {
    if (node.state != SkillNodeState.active || node.lessonCount < 2) {
      return null;
    }
    return SkillLessonProgress(
      skillTitle: node.title,
      lessonsDoneBefore: node.lessonsDone,
      lessonCount: node.lessonCount,
    );
  }

  final String skillTitle;

  /// Lessons of this skill already done in the current pass, before this
  /// one.
  final int lessonsDoneBefore;
  final int lessonCount;

  /// This lesson's position in the skill, 1-based.
  int get lessonNumber => (lessonsDoneBefore + 1).clamp(1, lessonCount);

  /// Lessons still to do once this one is finished.
  int get lessonsLeftAfter => lessonCount - lessonNumber;

  /// True when finishing this lesson completes the skill.
  bool get finishesSkill => lessonsLeftAfter == 0;
}
