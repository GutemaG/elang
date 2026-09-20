import '../../shared/services/auth_api.dart';
import '../../shared/services/course_api.dart';
import '../../shared/services/http_auth_api.dart';
import '../../shared/services/http_course_api.dart';
import '../../shared/services/onboarding_repository.dart';
import '../../shared/services/secure_storage_service.dart';
import '../../shared/services/session_repository.dart';
import 'auth_flow_controller.dart';

/// Bag of shared services/repositories the auth/onboarding flow depends on,
/// constructed once at app start-up and threaded down through
/// [AuthRoutes]'s route builders.
///
/// There's no DI framework in this project yet, so this is a plain
/// constructor-injected bundle rather than a service locator — it exists so
/// `main.dart` decides what's real vs. fake (e.g. swapping in a test double
/// for [AuthApi]) without every screen needing to know how its dependencies
/// are built. [HttpAuthApi] is the real, `001-auth-service`-backed default
/// as of `003-auth-onboarding-ui`.
class AuthDependencies {
  AuthDependencies({
    SecureStorageService? storage,
    AuthApi? authApi,
    CourseApi? courseApi,
  }) : storage = storage ?? FlutterSecureStorageService(),
       authApi = authApi ?? HttpAuthApi() {
    onboardingRepository = OnboardingRepository(storage: this.storage);
    sessionRepository = SessionRepository(storage: this.storage);
    // The course catalog is public (onboarding, before sign-in); the other
    // course calls read the session token fresh, so one instance serves the
    // whole app (010-multi-language-courses).
    this.courseApi = courseApi ?? HttpCourseApi(sessionRepository: sessionRepository);
    authFlowController = AuthFlowController(
      sessionRepository: sessionRepository,
    );
  }

  final SecureStorageService storage;
  final AuthApi authApi;
  late final CourseApi courseApi;
  late final OnboardingRepository onboardingRepository;
  late final SessionRepository sessionRepository;
  late final AuthFlowController authFlowController;
}
