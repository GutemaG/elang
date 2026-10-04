// The Sounds charts' data: reading the server's JSON, saving it on the
// phone, and asking the server only for what changed (ETags, versions).

import 'dart:convert';

import 'package:elang/features/sounds/sound_chart.dart';
import 'package:elang/features/sounds/sound_chart_api.dart';
import 'package:elang/features/sounds/sound_chart_store.dart';
import 'package:elang/features/sounds/sound_charts.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../helpers/fake_media_cache.dart';
import 'sound_fixtures.dart';

void main() {
  group('a chart', () {
    test('reads the server\'s JSON and writes the same back', () {
      final chart = fidel();
      expect(
        SoundChart.fromJson(jsonDecode(jsonEncode(chart.toJson()))).toJson(),
        chart.toJson(),
      );

      final grid = chart.groups.first;
      expect(grid.rows.map((r) => r.map((x) => x.glyph).join()), [
        'ሀሁሂ',
        'ሐሑሒ',
      ]);
      expect(grid.letters[3].sameAs, 'ሀ');
      expect(chart.letters.first.example!.meaning['am'], 'አገር');
      expect(chart.groups.last.rows.single.single.glyph, 'ሏ');
      expect(chart.audioUrls, contains('$clip/hager.m4a'));
      // ሐ plays ሀ's recording, so it is fetched once.
      expect(chart.audioUrls.where((u) => u == '$clip/ha.m4a'), hasLength(1));
    });

    test('picks the app language, then English', () {
      expect(inLanguage({'en': 'Fidel', 'am': 'ፊደል'}, 'am'), 'ፊደል');
      expect(inLanguage({'en': 'Fidel'}, 'om'), 'Fidel');
      expect(inLanguage({}, 'om'), '');
    });

    test('makes a local backend\'s /media addresses absolute', () {
      final json = fidelJson();
      ((json['groups']! as List).first as Map)['letters'] = [
        {
          'id': 'x',
          'glyph': 'ሀ',
          'romanization': 'he',
          'audio_url': '/media/audio/am/sounds/a.m4a',
        },
      ];
      final chart = SoundChart.fromJson(json)
          .resolvedAgainst('http://10.0.2.2:8000');
      expect(
        chart.letters.first.audioUrl,
        'http://10.0.2.2:8000/media/audio/am/sounds/a.m4a',
      );
    });
  });

  group('HttpSoundChartApi', () {
    late List<http.Request> requests;
    late http.Response Function(http.Request) reply;

    HttpSoundChartApi api() => HttpSoundChartApi(
      baseUrl: 'https://api.example',
      client: MockClient((request) async {
        requests.add(request);
        return reply(request);
      }),
    );

    setUp(() => requests = []);

    test('sends the saved ETag and reads "not modified"', () async {
      reply = (_) => http.Response('', 304, headers: {'etag': '"am-3"'});

      final fetched = await api().chart('am', etag: '"am-3"');

      expect(requests.single.url.path, '/api/v1/sound-charts/am');
      expect(requests.single.headers['If-None-Match'], '"am-3"');
      expect(fetched.notModified, isTrue);
      expect(fetched.etag, '"am-3"');
    });

    test('reads a chart, in UTF-8, with its ETag', () async {
      reply = (_) => http.Response.bytes(
        utf8.encode(jsonEncode(fidelJson())),
        200,
        headers: {'etag': '"am-3"', 'content-type': 'application/json'},
      );

      final fetched = await api().chart('am');

      expect(requests.single.headers.containsKey('If-None-Match'), isFalse);
      expect(fetched.value!.letters.first.glyph, 'ሀ');
      expect(fetched.etag, '"am-3"');
    });

    test('a chart that is gone says so; other failures are errors', () async {
      reply = (_) => http.Response('{}', 404);
      await expectLater(
        api().chart('om'),
        throwsA(
          isA<SoundChartApiException>().having(
            (e) => e.notFound,
            'notFound',
            isTrue,
          ),
        ),
      );
      reply = (_) => http.Response('{}', 500);
      await expectLater(
        api().index(),
        throwsA(
          isA<SoundChartApiException>().having(
            (e) => e.notFound,
            'notFound',
            isFalse,
          ),
        ),
      );
      reply = (_) => throw http.ClientException('offline');
      await expectLater(api().index(), throwsA(isA<SoundChartApiException>()));
    });

    test('reads the list of charts', () async {
      reply = (_) => http.Response.bytes(
        utf8.encode(
          jsonEncode({
            'charts': [summary().toJson()],
          }),
        ),
        200,
        headers: {'etag': '"i"'},
      );
      final fetched = await api().index();
      expect(fetched.value!.single.icon, 'ሀ');
    });
  });

  group('SoundCharts', () {
    late FakeSoundChartApi api;
    late InMemorySoundChartStore store;
    late FakeMediaCache media;

    SoundCharts charts() =>
        SoundCharts(api: api, store: store, mediaCache: media);

    setUp(() {
      api = FakeSoundChartApi();
      store = InMemorySoundChartStore();
      media = FakeMediaCache();
    });

    test(
      'knows the charts, and asks again with the ETag it was given',
      () async {
        final first = charts();
        var notified = 0;
        first.addListener(() => notified++);
        await first.load();

        expect(first.has('am'), isTrue);
        expect(first.has('om'), isFalse);
        expect(notified, 1);

        // The next launch: the saved list shows at once, and the server says
        // nothing changed.
        final next = charts();
        await next.load();
        expect(next.has('am'), isTrue);
        expect(api.asked, ['index null', 'index "i-am3"']);
      },
    );

    test('offline, the saved list stays', () async {
      await charts().load();
      api.offline = true;

      final offline = charts();
      await offline.load();

      expect(offline.has('am'), isTrue);
    });

    test(
      'downloads a chart once, saves it, and fetches its sounds ahead',
      () async {
        final repo = charts();
        await repo.load();

        final chart = await repo.chart('am');
        expect(chart!.version, 3);
        expect(
          media.warmed.single,
          containsAll(['$clip/ha.m4a', '$clip/hager.m4a']),
        );

        // Same version as the list names: the saved copy, no request.
        final again = charts();
        await again.load();
        api.asked.clear();
        expect((await again.chart('am'))!.version, 3);
        expect(api.asked, isEmpty);
      },
    );

    test('a newer version is downloaded; an unchanged one is not', () async {
      final repo = charts();
      await repo.load();
      await repo.chart('am');

      // The list moved on, but the chart's ETag still matches: 304.
      api.charts = [summary(version: 4)];
      await repo.refresh();
      api.asked.clear();
      expect((await repo.chart('am'))!.version, 3);
      expect(api.asked, ['chart am "am-3"']);

      api.byLanguage['am'] = fidel(version: 4);
      expect((await repo.chart('am'))!.version, 4);
      expect((await store.loadChart('am'))!.etag, '"am-4"');
    });

    test('offline, the saved chart however old; with none, an error', () async {
      final repo = charts();
      await repo.load();
      await repo.chart('am');
      api
        ..charts = [summary(version: 9)]
        ..offline = true;

      expect((await repo.chart('am'))!.version, 3);
      await store.removeChart('am');
      await expectLater(
        repo.chart('am'),
        throwsA(isA<SoundChartApiException>()),
      );
    });

    test('a chart turned off is forgotten', () async {
      final repo = charts();
      await repo.load();
      await repo.chart('am');
      api.byLanguage.remove('am');
      api.charts = [];

      // The list still names it, at another version.
      api.charts = [summary(version: 5)];
      await repo.refresh();
      api.charts = [];
      expect(await repo.chart('am'), isNull);
      expect(await store.loadChart('am'), isNull);
      await Future<void>.delayed(Duration.zero);
      expect(repo.has('am'), isFalse);
    });
  });
}
