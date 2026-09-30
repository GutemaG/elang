// The Appearance choice kept on the phone (022-light-and-dark-themes, bolt
// 070, story 006).

import 'package:elang/shared/services/appearance_repository.dart';
import 'package:elang/shared/services/session_repository.dart';
import 'package:elang/shared/theme/appearance.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/in_memory_secure_storage_service.dart';

void main() {
  late InMemorySecureStorageService storage;
  late AppearanceRepository repository;

  setUp(() {
    storage = InMemorySecureStorageService();
    repository = AppearanceRepository(storage: storage);
  });

  group('AppearanceRepository', () {
    test('is System when nothing is stored', () async {
      expect(await repository.load(), ThemeMode.system);
    });

    test('is System when the stored value is not one it knows', () async {
      await storage.write('appearance', 'sepia');
      expect(await repository.load(), ThemeMode.system);
    });

    for (final mode in ThemeMode.values) {
      test('keeps ${mode.name}', () async {
        await repository.save(mode);
        expect(storage.values['appearance'], mode.name);
        expect(await repository.load(), mode);
      });
    }

    test('survives signing out', () async {
      await repository.save(ThemeMode.dark);
      await SessionRepository(storage: storage).clearSession();
      expect(await repository.load(), ThemeMode.dark);
    });
  });

  group('AppearanceController', () {
    test('load starts from the stored choice', () async {
      await repository.save(ThemeMode.light);
      final controller = await AppearanceController.load(repository);
      expect(controller.value, ThemeMode.light);
    });

    test('choose applies at once and keeps the choice', () async {
      final controller = AppearanceController(repository: repository);
      var told = 0;
      controller.addListener(() => told++);

      await controller.choose(ThemeMode.dark);

      expect(controller.value, ThemeMode.dark);
      expect(told, 1);
      expect(await repository.load(), ThemeMode.dark);
    });
  });
}
