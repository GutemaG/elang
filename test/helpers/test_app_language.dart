// An app language kept in memory, for tests that build the app
// (024-app-localization, bolt 078).

import 'package:elang/shared/l10n/app_language.dart';
import 'package:elang/shared/services/app_language_repository.dart';

import 'in_memory_secure_storage_service.dart';

/// A controller starting at [code] (`null`: never chosen, so English),
/// saving to [storage] (a fresh in-memory store by default).
AppLanguageController testAppLanguage({
  String? code,
  InMemorySecureStorageService? storage,
  Future<bool> Function(String code)? send,
}) => AppLanguageController(
  repository: AppLanguageRepository(
    storage: storage ?? InMemorySecureStorageService(),
  ),
  initial: code,
  send: send,
);
