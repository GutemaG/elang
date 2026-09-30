// An Appearance choice kept in memory, for tests that build the app
// (022-light-and-dark-themes, bolt 070).

import 'package:elang/shared/services/appearance_repository.dart';
import 'package:elang/shared/theme/appearance.dart';
import 'package:flutter/material.dart';

import 'in_memory_secure_storage_service.dart';

/// A controller starting at [mode], saving to [storage] (a fresh in-memory
/// store by default).
AppearanceController testAppearance({
  ThemeMode mode = ThemeMode.system,
  InMemorySecureStorageService? storage,
}) => AppearanceController(
  repository: AppearanceRepository(
    storage: storage ?? InMemorySecureStorageService(),
  ),
  initial: mode,
);
