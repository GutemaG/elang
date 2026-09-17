import '../../shared/services/answer_feedback_player.dart';
import '../../shared/services/connectivity_monitor.dart';
import '../../shared/services/http_lesson_api.dart';
import '../../shared/services/lesson_api.dart';
import '../../shared/services/lesson_audio_player.dart';
import '../../shared/services/lesson_pack_downloader.dart';
import '../../shared/services/lesson_pack_store.dart';
import '../../shared/services/session_repository.dart';
import '../../shared/services/sound_preference_repository.dart';
import '../../shared/services/sync_engine.dart';

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
///
/// [connectivityMonitor]/[lessonPackStore]/[lessonPackDownloader] are new
/// as of `009-offline-caching-and-sync-ui` -- offline lesson caching and
/// download management.
///
/// [feedbackPlayer] defaults to a [SoundGatedAnswerFeedbackPlayer] wrapping
/// the real player, checking [soundPreferenceRepository] fresh on every
/// call (`005-profile-and-settings`, FR-5) rather than the bare
/// [SystemAnswerFeedbackPlayer].
class LessonDependencies {
  LessonDependencies({
    required SessionRepository sessionRepository,
    required SoundPreferenceRepository soundPreferenceRepository,
    LessonApi? lessonApi,
    LessonAudioPlayer? audioPlayer,
    AnswerFeedbackPlayer? feedbackPlayer,
    ConnectivityMonitor? connectivityMonitor,
    LessonPackStore? lessonPackStore,
    LessonPackDownloader? lessonPackDownloader,
    SyncEngine? syncEngine,
  }) : lessonApi = lessonApi ?? HttpLessonApi(sessionRepository: sessionRepository),
       audioPlayer = audioPlayer ?? AudioplayersLessonAudioPlayer(),
       feedbackPlayer =
           feedbackPlayer ??
           SoundGatedAnswerFeedbackPlayer(
             player: SystemAnswerFeedbackPlayer(),
             soundPreferenceRepository: soundPreferenceRepository,
           ),
       connectivityMonitor = connectivityMonitor ?? ConnectivityPlusMonitor(),
       lessonPackStore = lessonPackStore ?? SqfliteLessonPackStore() {
    this.lessonPackDownloader =
        lessonPackDownloader ??
        LessonPackDownloader(
          lessonApi: this.lessonApi,
          packStore: this.lessonPackStore,
        );
    this.syncEngine =
        syncEngine ??
        SyncEngine(
          lessonApi: this.lessonApi,
          connectivityMonitor: this.connectivityMonitor,
        );
  }

  final LessonApi lessonApi;
  final LessonAudioPlayer audioPlayer;
  final AnswerFeedbackPlayer feedbackPlayer;
  final ConnectivityMonitor connectivityMonitor;
  final LessonPackStore lessonPackStore;
  late final LessonPackDownloader lessonPackDownloader;
  late final SyncEngine syncEngine;
}
