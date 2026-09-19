import '../models/beans_status.dart';
import '../models/due_item.dart';
import '../models/exercise.dart';
import '../models/lesson_completion_result.dart';
import '../models/lesson_content.dart';
import '../models/practice_completion_result.dart';
import '../models/skill_tree.dart';
import 'lesson_api.dart';

/// In-memory stand-in for `001-lesson-service`.
///
/// `001-lesson-service` hasn't published its API contract yet (see this
/// bolt's `implementation-plan.md` Dependencies section), so every lesson
/// screen is built and exercised against this fake instead of a real
/// network call — same pattern as `FakeAuthApi` stood in for
/// `001-auth-service`. Swap in a real `LessonApi` implementation once that
/// contract lands (bolt 007); no call site outside this file should need
/// to change.
///
/// Holds mutable, session-scoped state (skill nodes, beans, streak, Amole,
/// XP) so the dashboard visibly reflects a completed lesson's effects —
/// there is no real backend to persist any of this.
class FakeLessonApi implements LessonApi {
  FakeLessonApi({this.latency = const Duration(milliseconds: 400)}) {
    _nodes = List.of(_seedNodes);
  }

  final Duration latency;

  static const int _beansMax = 5;
  static const int _regenMinutesPerBean = 30;
  static const int _refillCostAmole = 350;
  static const int _xpPerCorrectAnswer = 5;
  static const int _dailyXpTarget = 30;

  int _beans = _beansMax;
  int _amoleBalance = 420;
  int _streakCount = 5;
  bool _streakIncreasedToday = false;
  int _totalXp = 340;
  int _dailyXpTotal = 0;

  late List<SkillTreeNode> _nodes;

  static final List<SkillTreeNode> _seedNodes = [
    const SkillTreeNode(
      id: 'skill-alphabet',
      categoryId: 'cat-foundations',
      lessonId: 'lesson-alphabet',
      title: 'Alphabet & Fidel',
      subtitle: 'ፊደል መግቢያ',
      state: SkillNodeState.completed,
      crownLevel: 3,
    ),
    const SkillTreeNode(
      id: 'skill-greetings',
      categoryId: 'cat-foundations',
      lessonId: 'lesson-greetings',
      title: 'Basic Greetings',
      subtitle: 'ሰላምታ',
      state: SkillNodeState.completed,
      crownLevel: 2,
    ),
    const SkillTreeNode(
      id: 'skill-coffee',
      categoryId: 'cat-foundations',
      lessonId: 'lesson-coffee',
      title: 'Coffee & Hospitality',
      subtitle: 'ቡና እና እንግዳ ተቀባይነት',
      state: SkillNodeState.active,
    ),
    const SkillTreeNode(
      id: 'skill-family',
      categoryId: 'cat-foundations',
      lessonId: 'lesson-family',
      title: 'Family & Introductions',
      subtitle: 'ቤተሰብ',
      state: SkillNodeState.locked,
    ),
    const SkillTreeNode(
      id: 'skill-numbers',
      lessonId: 'lesson-numbers',
      title: 'Numbers',
      subtitle: 'ቁጥሮች',
      state: SkillNodeState.active,
      categoryId: 'cat-numbers',
    ),
    const SkillTreeNode(
      id: 'skill-time',
      lessonId: 'lesson-time',
      title: 'Time',
      subtitle: 'ጊዜ',
      state: SkillNodeState.locked,
      categoryId: 'cat-numbers',
    ),
  ];

  static const List<SkillCategory> _categories = [
    SkillCategory(
      id: 'cat-foundations',
      title: 'Foundations & Greetings',
      subtitle: 'ሰላምታ እና ፊደል መግቢያ',
    ),
    SkillCategory(
      id: 'cat-numbers',
      title: 'Numbers & Time',
      subtitle: 'ቁጥሮች እና ጊዜ',
    ),
  ];

  static final Map<String, LessonContent> _lessonBank = {
    'lesson-alphabet': LessonContent(
      lessonId: 'lesson-alphabet',
      skillId: 'skill-alphabet',
      title: 'Alphabet & Fidel',
      beansAtStart: _beansMax,
      beansMax: _beansMax,
      exercises: const [
        MultipleChoiceExercise(
          id: 'alphabet-1',
          prompt: 'ሀ',
          promptTranslation: 'Which sound does this Fidel make?',
          options: ['ha', 'le', 'me', 'se'],
          correctOptionIndex: 0,
        ),
        MultipleChoiceExercise(
          id: 'alphabet-2',
          prompt: 'ለ',
          promptTranslation: 'Which sound does this Fidel make?',
          options: ['ha', 'le', 'me', 'se'],
          correctOptionIndex: 1,
        ),
      ],
    ),
    'lesson-greetings': LessonContent(
      lessonId: 'lesson-greetings',
      skillId: 'skill-greetings',
      title: 'Basic Greetings',
      beansAtStart: _beansMax,
      beansMax: _beansMax,
      exercises: const [
        MultipleChoiceExercise(
          id: 'greetings-1',
          prompt: 'ሰላም',
          promptTranslation: 'What does this greeting mean?',
          options: ['Hello', 'Goodbye', 'Thank you', 'Please'],
          correctOptionIndex: 0,
        ),
        ListeningExercise(
          id: 'greetings-2',
          audioUrl: 'https://cdn.buna.app/audio/amesegenalehu.mp3',
          instruction: 'Tap what you hear',
          options: ['አመሰግናለሁ', 'ይቅርታ', 'እሺ', 'ደህና ሁን'],
          correctOptionIndex: 0,
        ),
      ],
    ),
    'lesson-coffee': LessonContent(
      lessonId: 'lesson-coffee',
      skillId: 'skill-coffee',
      title: 'Coffee & Hospitality',
      beansAtStart: _beansMax,
      beansMax: _beansMax,
      exercises: const [
        MultipleChoiceExercise(
          id: 'coffee-1',
          prompt: 'ቡና',
          promptTranslation: 'What does this word mean?',
          options: ['Coffee', 'Tea', 'Water', 'Bread'],
          correctOptionIndex: 0,
        ),
        ListeningExercise(
          id: 'coffee-2',
          audioUrl: 'https://cdn.buna.app/audio/buna-tetu.mp3',
          instruction: 'Tap what you hear',
          options: ['ቡና ጠጡ', 'ውሃ ጠጡ', 'ዳቦ ብሉ', 'ሻይ ጠጡ'],
          correctOptionIndex: 0,
        ),
        SentenceConstructionExercise(
          id: 'coffee-3',
          promptTranslation: 'Please drink coffee',
          wordBank: ['ቡና', 'እባክዎ', 'ጠጡ', 'ውሃ', 'ብሉ'],
          correctSentence: ['እባክዎ', 'ቡና', 'ጠጡ'],
        ),
        MatchPairsExercise(
          id: 'coffee-4',
          prompt: 'Match each word to its meaning',
          leftTiles: [
            MatchPairsTile(id: 'l1', text: 'ቡና'),
            MatchPairsTile(id: 'l2', text: 'ሻይ'),
            MatchPairsTile(id: 'l3', text: 'ውሃ'),
          ],
          rightTiles: [
            MatchPairsTile(id: 'r1', text: 'Coffee'),
            MatchPairsTile(id: 'r2', text: 'Tea'),
            MatchPairsTile(id: 'r3', text: 'Water'),
          ],
          correctPairs: {'l1': 'r1', 'l2': 'r2', 'l3': 'r3'},
        ),
      ],
    ),
    'lesson-family': LessonContent(
      lessonId: 'lesson-family',
      skillId: 'skill-family',
      title: 'Family & Introductions',
      beansAtStart: _beansMax,
      beansMax: _beansMax,
      exercises: const [
        MultipleChoiceExercise(
          id: 'family-1',
          prompt: 'እናት',
          promptTranslation: 'What does this word mean?',
          options: ['Mother', 'Father', 'Sister', 'Brother'],
          correctOptionIndex: 0,
        ),
        SentenceConstructionExercise(
          id: 'family-2',
          promptTranslation: 'This is my family',
          wordBank: ['ቤተሰቤ', 'ይህ', 'ነው', 'ጓደኛዬ', 'እናቴ'],
          correctSentence: ['ይህ', 'ቤተሰቤ', 'ነው'],
        ),
      ],
    ),
    'lesson-numbers': LessonContent(
      lessonId: 'lesson-numbers',
      skillId: 'skill-numbers',
      title: 'Numbers',
      beansAtStart: _beansMax,
      beansMax: _beansMax,
      exercises: const [
        MultipleChoiceExercise(
          id: 'numbers-1',
          prompt: 'አንድ',
          promptTranslation: 'What does this word mean?',
          options: ['One', 'Two', 'Three', 'Four'],
          correctOptionIndex: 0,
        ),
      ],
    ),
    'lesson-time': LessonContent(
      lessonId: 'lesson-time',
      skillId: 'skill-time',
      title: 'Time',
      beansAtStart: _beansMax,
      beansMax: _beansMax,
      exercises: const [
        MultipleChoiceExercise(
          id: 'time-1',
          prompt: 'ዛሬ',
          promptTranslation: 'What does this word mean?',
          options: ['Today', 'Tomorrow', 'Yesterday', 'Morning'],
          correctOptionIndex: 0,
        ),
      ],
    ),
  };

  @override
  Future<SkillTreeResponse> getSkillTree() async {
    await Future<void>.delayed(latency);
    return SkillTreeResponse(
      categories: _categories,
      nodes: List.unmodifiable(_nodes),
      streakCount: _streakCount,
      beans: _beans,
      beansMax: _beansMax,
      totalXp: _totalXp,
    );
  }

  @override
  Future<LessonContent> startLesson(String lessonId) async {
    await Future<void>.delayed(latency);
    final content = _lessonBank[lessonId];
    if (content == null) {
      throw StateError('Unknown lessonId: $lessonId');
    }
    return LessonContent(
      lessonId: content.lessonId,
      skillId: content.skillId,
      title: content.title,
      exercises: content.exercises,
      beansAtStart: _beans,
      beansMax: _beansMax,
    );
  }

  final Set<String> _seenAttemptIds = {};

  @override
  Future<LessonCompletionResult> completeLesson({
    required String lessonId,
    required String attemptId,
    required int correctCount,
    required int totalCount,
    required Duration timeSpent,
    required int beansRemainingAtEnd,
    required DateTime clientCompletedAt,
    List<String> missedExerciseIds = const [],
  }) async {
    await Future<void>.delayed(latency);

    // Mirrors the real backend's idempotency contract (ADR-5, Decision 2):
    // a repeated attemptId must not re-award XP/streak/crown state. The
    // fake has no persisted-attempt store to replay an exact prior result
    // from, but it can at least guarantee "no double award" for the
    // account-state fields this fake tracks.
    if (!_seenAttemptIds.add(attemptId)) {
      final accuracyPercent = totalCount == 0
          ? 0
          : ((correctCount / totalCount) * 100).round();
      return LessonCompletionResult(
        xpEarned: 0,
        dailyXpTotal: _dailyXpTotal,
        dailyXpTarget: _dailyXpTarget,
        streakCount: _streakCount,
        streakIncreasedToday: false,
        accuracyPercent: accuracyPercent,
        correctCount: correctCount,
        totalCount: totalCount,
        timeSpent: timeSpent,
      );
    }

    _beans = beansRemainingAtEnd.clamp(0, _beansMax);

    final xpEarned = correctCount * _xpPerCorrectAnswer;
    _totalXp += xpEarned;
    _dailyXpTotal += xpEarned;

    final streakIncreasedNow = !_streakIncreasedToday;
    if (streakIncreasedNow) {
      _streakCount += 1;
      _streakIncreasedToday = true;
    }

    final nodeIndex = _nodes.indexWhere((n) => n.lessonId == lessonId);
    String? skillUnlockedTitle;
    int? crownLevel;
    bool crownLeveledUp = false;
    bool streakFreezeUnlocked = false;

    if (nodeIndex != -1) {
      final node = _nodes[nodeIndex];
      if (node.state == SkillNodeState.active) {
        _nodes[nodeIndex] = node.copyWith(
          state: SkillNodeState.completed,
          crownLevel: 1,
        );
        crownLevel = 1;
        // Progression is per category: only a later skill in the same
        // category unlocks.
        final nextLockedIndex = _nodes.indexWhere(
          (n) =>
              n.categoryId == node.categoryId &&
              n.state == SkillNodeState.locked,
        );
        if (nextLockedIndex != -1) {
          final nextNode = _nodes[nextLockedIndex];
          _nodes[nextLockedIndex] = nextNode.copyWith(
            state: SkillNodeState.active,
          );
          skillUnlockedTitle = nextNode.title;
        }
      } else {
        final newCrown = (node.crownLevel + 1).clamp(0, 5);
        crownLeveledUp = newCrown > node.crownLevel;
        crownLevel = newCrown;
        streakFreezeUnlocked = crownLeveledUp && newCrown == 5;
        _nodes[nodeIndex] = node.copyWith(crownLevel: newCrown);
      }
    }

    final accuracyPercent = totalCount == 0
        ? 0
        : ((correctCount / totalCount) * 100).round();

    return LessonCompletionResult(
      xpEarned: xpEarned,
      dailyXpTotal: _dailyXpTotal,
      dailyXpTarget: _dailyXpTarget,
      streakCount: _streakCount,
      streakIncreasedToday: streakIncreasedNow,
      accuracyPercent: accuracyPercent,
      correctCount: correctCount,
      totalCount: totalCount,
      timeSpent: timeSpent,
      skillUnlockedTitle: skillUnlockedTitle,
      crownLevel: crownLevel,
      crownLeveledUp: crownLeveledUp,
      streakFreezeUnlocked: streakFreezeUnlocked,
    );
  }

  @override
  Future<BeansStatus> getBeansStatus() async {
    await Future<void>.delayed(latency);
    // The fake has no persisted "last consumed at" timestamp to regenerate
    // from, so it anchors the countdown to "now" whenever this is called —
    // reasonable for a modal that's opened right as beans hit 0, and
    // avoids a stateful regen clock this bolt doesn't need to model.
    final DateTime? nextBeanAt = _beans < _beansMax
        ? DateTime.now().add(const Duration(minutes: _regenMinutesPerBean))
        : null;
    return BeansStatus(
      beans: _beans,
      beansMax: _beansMax,
      nextBeanAt: nextBeanAt,
      regenMinutesPerBean: _regenMinutesPerBean,
      amoleBalance: _amoleBalance,
      refillCostAmole: _refillCostAmole,
    );
  }

  @override
  Future<RefillResult> refillBeansWithAmole() async {
    await Future<void>.delayed(latency);
    if (_amoleBalance < _refillCostAmole) {
      return const RefillFailure(RefillFailureReason.insufficientAmole);
    }
    _amoleBalance -= _refillCostAmole;
    _beans = _beansMax;
    return RefillSuccess(newBeans: _beans, newAmoleBalance: _amoleBalance);
  }

  // Bolt 020-practice-ui: this fake predates Practice and has no vocab-item
  // content to draw from -- no seeded content ever has anything due, same
  // "nothing modeled" honesty as a fresh account would see for real.
  @override
  Future<int> getDueCount() async {
    await Future<void>.delayed(latency);
    return 0;
  }

  @override
  Future<List<DueItem>> getDueItems({int limit = 20}) async {
    await Future<void>.delayed(latency);
    return const [];
  }

  @override
  Future<PracticeCompletionResult> completePracticeSession({
    required String sessionId,
    required List<PracticeResult> results,
    required Duration timeSpent,
  }) async {
    await Future<void>.delayed(latency);
    final correctCount = results.where((r) => r.correct).length;
    return PracticeCompletionResult(
      xpEarned: correctCount * _xpPerCorrectAnswer,
      amoleEarned: 0,
      correctCount: correctCount,
      totalCount: results.length,
      accuracyPercent: results.isEmpty
          ? 0
          : ((correctCount / results.length) * 100).round(),
    );
  }
}
