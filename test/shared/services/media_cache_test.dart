// Clips and pictures kept on the device (bolt 057): a miss downloads and
// saves, a hit makes no request, two asks share one download, a failed
// download leaves nothing, the least recently used files go first when the
// cache is full, and fetching ahead runs in order and drops failures. Files
// are written for real, into a temp folder standing in for the app's cache
// folder.

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:elang/shared/services/media_cache.dart';

const _cdn = 'https://pub.r2.dev';

/// Serves every address as its own bytes (the address, repeated to [size]
/// bytes), and records each request.
class _Server {
  _Server({this.size = 10});

  final int size;
  final List<String> requests = [];
  final Set<String> failing = {};

  /// Addresses held until their completer completes.
  final Map<String, Completer<void>> holds = {};

  late final client = MockClient((request) async {
    final url = request.url.toString();
    requests.add(url);
    final hold = holds[url];
    if (hold != null) await hold.future;
    if (failing.contains(url)) return http.Response('gone', 404);
    return http.Response.bytes(_bytesOf(url, size), 200);
  });
}

List<int> _bytesOf(String url, int size) =>
    List.generate(size, (i) => url.codeUnitAt(i % url.length));

void main() {
  late Directory root;
  late Directory folder;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('media_cache_test');
    folder = Directory('${root.path}/media_cache');
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  DiskMediaCache cacheFor(_Server server, {int maxBytes = 1000}) =>
      DiskMediaCache(
        httpClient: server.client,
        directory: () async => folder,
        maxBytes: maxBytes,
      );

  List<String> namesOnDisk() =>
      folder.listSync().map((f) => f.uri.pathSegments.last).toList()..sort();

  group('file names', () {
    test('the address hashed, with its extension, never its query', () {
      final name = cacheFileName('$_cdn/a/selam.mp3?v=2');
      expect(name, matches(RegExp(r'^[0-9a-f]{40}\.mp3$')));
      expect(cacheFileName('$_cdn/a/selam.mp3?v=3'), isNot(name));
      expect(
        cacheFileName('$_cdn/p/house'),
        matches(RegExp(r'^[0-9a-f]{40}$')),
      );
    });
  });

  group('fileFor', () {
    test('a miss downloads and saves; a hit makes no request', () async {
      final server = _Server();
      final cache = cacheFor(server);
      const url = '$_cdn/a/selam.mp3';

      final first = await cache.fileFor(url);
      expect(await first.readAsBytes(), _bytesOf(url, 10));
      expect(first.path, endsWith('.mp3'));

      final second = await cache.fileFor(url);
      expect(second.path, first.path);
      expect(server.requests, [url]);
    });

    test('a file saved before a restart is used without a request', () async {
      const url = '$_cdn/a/selam.mp3';
      await cacheFor(_Server()).fileFor(url);

      final server = _Server();
      final restarted = cacheFor(server);
      expect(await (await restarted.fileFor(url)).readAsBytes(), isNotEmpty);
      expect(server.requests, isEmpty);
    });

    test('two asks at once share one download', () async {
      final server = _Server();
      const url = '$_cdn/a/selam.mp3';
      final gate = server.holds[url] = Completer<void>();
      final cache = cacheFor(server);

      final a = cache.fileFor(url);
      final b = cache.fileFor(url);
      gate.complete();

      expect((await a).path, (await b).path);
      expect(server.requests, [url]);
    });

    test('a failed download throws and leaves no file', () async {
      final server = _Server();
      const url = '$_cdn/a/missing.mp3';
      server.failing.add(url);
      final cache = cacheFor(server);

      await expectLater(
        cache.fileFor(url),
        throwsA(isA<MediaCacheException>()),
      );
      expect(folder.existsSync() ? namesOnDisk() : <String>[], isEmpty);

      // Not remembered as failed: it is tried again next time.
      server.failing.clear();
      expect(await cache.fileFor(url), isA<File>());
      expect(server.requests, [url, url]);
    });

    test('a file the phone cleared is downloaded again', () async {
      final server = _Server();
      const url = '$_cdn/a/selam.mp3';
      final cache = cacheFor(server);
      await cache.fileFor(url);

      await folder.delete(recursive: true);

      expect(await (await cache.fileFor(url)).exists(), isTrue);
      expect(server.requests, [url, url]);
    });

    test('a download cut short last time is cleared away', () async {
      await folder.create(recursive: true);
      await File('${folder.path}/abc.mp3.part').writeAsBytes([1, 2]);

      await cacheFor(_Server()).fileFor('$_cdn/a/selam.mp3');

      expect(namesOnDisk().where((n) => n.endsWith('.part')), isEmpty);
    });
  });

  group('the size limit', () {
    test('the least recently used files go first, never the newest', () async {
      // Ten bytes each, room for three.
      final server = _Server();
      final cache = cacheFor(server, maxBytes: 30);
      Future<void> tick() => Future.delayed(const Duration(milliseconds: 5));
      final a = await cache.fileFor('$_cdn/a.mp3');
      await tick();
      final b = await cache.fileFor('$_cdn/b.mp3');
      await tick();
      final c = await cache.fileFor('$_cdn/c.mp3');
      await tick();
      // Played again: now more recent than b and c.
      await cache.fileFor('$_cdn/a.mp3');
      await tick();

      final d = await cache.fileFor('$_cdn/d.mp3');

      expect(await a.exists(), isTrue);
      expect(await b.exists(), isFalse);
      expect(await c.exists(), isTrue);
      expect(await d.exists(), isTrue);
    });

    test('a single file larger than the limit is still kept', () async {
      final server = _Server(size: 50);
      final cache = cacheFor(server, maxBytes: 30);

      final big = await cache.fileFor('$_cdn/big.webp');

      expect(await big.exists(), isTrue);
    });

    test('the order survives a restart', () async {
      final first = cacheFor(_Server(), maxBytes: 30);
      final old = await first.fileFor('$_cdn/old.mp3');
      await old.setLastModified(DateTime(2020));
      await first.fileFor('$_cdn/new.mp3');

      final restarted = cacheFor(_Server(), maxBytes: 30);
      await restarted.fileFor('$_cdn/x.mp3');
      await restarted.fileFor('$_cdn/y.mp3');

      expect(await old.exists(), isFalse);
      expect(
        await File('${folder.path}/${cacheFileName('$_cdn/new.mp3')}').exists(),
        isTrue,
      );
    });
  });

  group('warm', () {
    List<String> saved() => folder.existsSync()
        ? namesOnDisk().where((n) => !n.endsWith('.part')).toList()
        : <String>[];

    test(
      'fetches in order, three at a time, skipping non-web sources',
      () async {
        final server = _Server();
        final urls = [for (var i = 0; i < 5; i++) '$_cdn/$i.mp3'];
        final gates = {for (final url in urls) url: Completer<void>()};
        server.holds.addAll(gates);
        final cache = cacheFor(server);

        cache.warm([
          urls[0],
          'assets/pictures/dog.webp',
          '/data/lesson_packs/l-1/li-1.mp3',
          ...urls.skip(1),
        ]);
        await _until(() => server.requests.length == 3);
        await _settle();
        expect(server.requests, urls.take(3));

        gates[urls[0]]!.complete();
        await _until(() => server.requests.length == 4);
        expect(server.requests, urls.take(4));

        for (final gate in gates.values) {
          if (!gate.isCompleted) gate.complete();
        }
        await _until(() => saved().length == 5);
        expect(server.requests, urls);
      },
    );

    test('a newer batch goes ahead of what is still waiting', () async {
      final server = _Server();
      final early = [for (var i = 0; i < 5; i++) '$_cdn/early-$i.mp3'];
      final gates = {for (final url in early) url: Completer<void>()};
      server.holds.addAll(gates);
      final cache = cacheFor(server);

      cache.warm(early);
      await _until(() => server.requests.length == 3);
      cache.warm(['$_cdn/now.mp3']);
      gates[early[0]]!.complete();
      await _until(() => server.requests.length == 4);

      expect(server.requests[3], '$_cdn/now.mp3');
      for (final gate in gates.values) {
        if (!gate.isCompleted) gate.complete();
      }
      await _until(() => saved().length == 6);
    });

    test('a failure is dropped and the rest still download', () async {
      final server = _Server();
      server.failing.add('$_cdn/bad.mp3');
      final cache = cacheFor(server);

      cache.warm(['$_cdn/bad.mp3', '$_cdn/good.mp3']);
      await _until(() => saved().isNotEmpty);
      await _settle();

      expect(saved(), [cacheFileName('$_cdn/good.mp3')]);
    });
  });
}

/// Waits, on the real clock, until [done] holds: the cache writes real
/// files, which an event-queue pump does not wait for.
Future<void> _until(bool Function() done) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!done()) {
    if (DateTime.now().isAfter(deadline)) fail('timed out waiting');
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
}

/// A moment for anything that should not happen to show that it did.
Future<void> _settle() => Future.delayed(const Duration(milliseconds: 50));
