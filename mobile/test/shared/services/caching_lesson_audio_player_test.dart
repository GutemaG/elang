// A clip plays from its file in the media cache (bolt 057): a web clip
// plays from the device, a failed download streams the address as before,
// a local file is played as it is, and a newer play or a stop replaces
// one still downloading.

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:elang/shared/services/lesson_audio_player.dart';

import '../../helpers/fake_lesson_audio_player.dart';
import '../../helpers/fake_media_cache.dart';

const _clip = 'https://pub.r2.dev/a/selam.mp3';
final _saved = File('/cache/media_cache/selam.mp3').path;

void main() {
  late FakeLessonAudioPlayer inner;
  late FakeMediaCache cache;
  late CachingLessonAudioPlayer player;

  setUp(() {
    inner = FakeLessonAudioPlayer();
    cache = FakeMediaCache();
    player = CachingLessonAudioPlayer(player: inner, cache: cache);
  });

  test('a web clip plays from its saved file', () async {
    cache.files[_clip] = _saved;

    await player.play(_clip);

    expect(inner.playedUrls, [_saved]);
  });

  test('a clip that cannot be saved is streamed instead', () async {
    await player.play(_clip);

    expect(cache.asked, [_clip]);
    expect(inner.playedUrls, [_clip]);
  });

  test("a downloaded lesson's file plays as it is", () async {
    const local = '/data/lesson_packs/l-1/li-1.mp3';

    await player.play(local);

    expect(cache.asked, isEmpty);
    expect(inner.playedUrls, [local]);
  });

  test('a newer play replaces one still downloading', () async {
    const next = 'https://pub.r2.dev/a/dehna.mp3';
    cache.files[_clip] = _saved;
    cache.files[next] = '/cache/media_cache/dehna.mp3';
    final slow = cache.holds[_clip] = Completer<void>();

    final first = player.play(_clip);
    await player.play(next);
    slow.complete();
    await first;

    expect(inner.playedUrls, ['/cache/media_cache/dehna.mp3']);
  });

  test('a stop means a clip still downloading never starts', () async {
    cache.files[_clip] = _saved;
    final slow = cache.holds[_clip] = Completer<void>();

    final play = player.play(_clip);
    await player.stop();
    slow.complete();
    await play;

    expect(inner.playedUrls, isEmpty);
    expect(inner.stops, 1);
  });
}
