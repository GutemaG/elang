import '../../shared/services/answer_feedback_player.dart';
import '../../shared/services/http_lesson_api.dart';
import '../../shared/services/lesson_api.dart';
import '../../shared/services/lesson_audio_player.dart';
import '../../shared/services/session_repository.dart';

/// Bag of shared services the lesson-loop feature depends on, constructed
/// once at app start-up — same "no DI framework, plain constructor-
/// injected bundle" pattern as `AuthDependencies`.
///
/// [HttpLessonApi] is the real, `001-lesson-service`-backed default as of
/// `007-core-lesson-loop-ui` (previously [FakeLessonApi] while that
/// backend didn't exist yet). Requires a [SessionRepository] -- unlike
/// [HttpAuthApi], every lesson-service call is authenticated, and the
/// session token isn't known until after sign-in, so it's read fresh per
/// request rather than baked in at construction (see
/// `HttpLessonApi`'s doc comment).
class LessonDependencies {
  LessonDependencies({
    required SessionRepository sessionRepository,
    LessonApi? lessonApi,
    LessonAudioPlayer? audioPlayer,
    AnswerFeedbackPlayer? feedbackPlayer,
  }) : lessonApi = lessonApi ?? HttpLessonApi(sessionRepository: sessionRepository),
       audioPlayer = audioPlayer ?? AudioplayersLessonAudioPlayer(),
       feedbackPlayer = feedbackPlayer ?? SystemAnswerFeedbackPlayer();

  final LessonApi lessonApi;
  final LessonAudioPlayer audioPlayer;
  final AnswerFeedbackPlayer feedbackPlayer;
}
