import 'package:connectivity_plus/connectivity_plus.dart';

/// Thin abstraction over device connectivity state.
///
/// Kept as an interface (rather than screens/controllers touching
/// `connectivity_plus` directly) so widget tests can substitute a
/// deterministic fake instead of a real platform channel -- same
/// "mock at the network/DB/plugin boundary only" convention this
/// codebase's other plugin-backed services (`LessonAudioPlayer`,
/// `AnswerFeedbackPlayer`) already follow.
///
/// A "true" result only ever means "the device reports a network
/// interface" -- not that any particular server is actually reachable.
/// That's an acceptable approximation for this feature: a false positive
/// (device thinks it's online but a request still fails) is already
/// handled by every existing `LessonApi` call site's error path, and a
/// false negative is rare enough not to design around.
abstract class ConnectivityMonitor {
  Future<bool> isOnline();

  /// Emits the current online/offline state on every connectivity change
  /// (not just once at subscription time).
  Stream<bool> get onConnectivityChanged;
}

/// Real implementation backed by the `connectivity_plus` package.
class ConnectivityPlusMonitor implements ConnectivityMonitor {
  ConnectivityPlusMonitor() : _connectivity = Connectivity();

  final Connectivity _connectivity;

  bool _isOnline(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);

  @override
  Future<bool> isOnline() async {
    final results = await _connectivity.checkConnectivity();
    return _isOnline(results);
  }

  @override
  Stream<bool> get onConnectivityChanged =>
      _connectivity.onConnectivityChanged.map(_isOnline);
}
