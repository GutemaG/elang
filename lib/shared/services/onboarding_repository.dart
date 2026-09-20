import 'dart:convert';

import '../models/pending_onboarding_selection.dart';
import 'secure_storage_service.dart';

/// Owns the lifecycle of the user's pending (pre-auth) onboarding
/// selections.
///
/// Per the implementation plan's "Pending-selection lifecycle" note:
/// - Nothing is written to secure storage until *both* a language and a
///   daily goal are known — an app kill between the two screens should
///   leave no partial/corrupted state, so the in-progress choice is only
///   held in memory until the pair is complete.
/// - Once written, the pending selection is read-not-cleared at sign-in
///   time; it's the sign-in call site's job to decide whether a returning
///   user's real account should ignore it (this repository just stores and
///   returns whatever is there).
/// - A failed sign-in attempt never touches this repository at all, so the
///   pending selection is untouched through failure/retry by construction.
class OnboardingRepository {
  OnboardingRepository({required this._storage});

  static const String _storageKey = 'pending_onboarding_selection';

  final SecureStorageService _storage;

  String? _inProgressLanguageCode;
  String _inProgressFromLanguageCode =
      PendingOnboardingSelection.defaultFromLanguageCode;
  int? _inProgressDailyGoalMinutes;

  /// Records the chosen course. Does not persist anything by itself unless
  /// a daily goal was already chosen first.
  Future<void> selectLanguage(
    String languageCode, {
    String fromLanguageCode = PendingOnboardingSelection.defaultFromLanguageCode,
  }) async {
    _inProgressLanguageCode = languageCode;
    _inProgressFromLanguageCode = fromLanguageCode;
    await _persistIfComplete();
  }

  /// Records the chosen daily-goal preset (in minutes). Does not persist
  /// anything by itself unless a language was already chosen first.
  Future<void> selectDailyGoal(int minutes) async {
    _inProgressDailyGoalMinutes = minutes;
    await _persistIfComplete();
  }

  Future<void> _persistIfComplete() async {
    final languageCode = _inProgressLanguageCode;
    final minutes = _inProgressDailyGoalMinutes;
    if (languageCode == null || minutes == null) return;

    final selection = PendingOnboardingSelection(
      languageCode: languageCode,
      fromLanguageCode: _inProgressFromLanguageCode,
      dailyGoalMinutes: minutes,
    );
    await _storage.write(_storageKey, jsonEncode(selection.toJson()));
  }

  /// Reads whatever pending selection is in secure storage, if any. Does
  /// NOT clear it — callers (e.g. the sign-in flow) decide what to do with
  /// it, including leaving it in place on failure.
  Future<PendingOnboardingSelection?> loadPendingSelection() async {
    final raw = await _storage.read(_storageKey);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return PendingOnboardingSelection.fromJson(decoded);
    } catch (_) {
      // Corrupted/unrecognized payload — treat as "nothing pending" rather
      // than crashing the sign-in flow.
      return null;
    }
  }
}
