import 'package:flutter_test/flutter_test.dart';

import 'package:elang/shared/services/sound_preference_repository.dart';

import '../../helpers/in_memory_secure_storage_service.dart';

void main() {
  test('defaults to true (sound on) when never set', () async {
    final repo = SoundPreferenceRepository(storage: InMemorySecureStorageService());
    expect(await repo.getSoundEnabled(), true);
  });

  test('persists a set value across reads', () async {
    final storage = InMemorySecureStorageService();
    final repo = SoundPreferenceRepository(storage: storage);

    await repo.setSoundEnabled(false);
    expect(await repo.getSoundEnabled(), false);

    await repo.setSoundEnabled(true);
    expect(await repo.getSoundEnabled(), true);
  });

  test('a second repository instance reads what the first wrote', () async {
    final storage = InMemorySecureStorageService();
    await SoundPreferenceRepository(storage: storage).setSoundEnabled(false);

    final reader = SoundPreferenceRepository(storage: storage);
    expect(await reader.getSoundEnabled(), false);
  });
}
