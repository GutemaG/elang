import 'package:flutter/material.dart';

import 'secure_storage_service.dart';

/// Reads and writes the Appearance choice: System, Light or Dark
/// (022-light-and-dark-themes, story 006).
///
/// Kept on the phone only, like the Sound switch
/// ([SoundPreferenceRepository]): it must apply before sign-in, and it
/// survives sign-out, which clears only the session.
class AppearanceRepository {
  AppearanceRepository({required this._storage});

  static const String _storageKey = 'appearance';

  final SecureStorageService _storage;

  /// System when nothing is stored, or the stored value isn't one we know.
  Future<ThemeMode> load() async {
    final raw = await _storage.read(_storageKey);
    return ThemeMode.values.asNameMap()[raw] ?? ThemeMode.system;
  }

  Future<void> save(ThemeMode mode) => _storage.write(_storageKey, mode.name);
}
