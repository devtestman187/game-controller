import 'package:metrics/metrics.dart';
import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

/// One player in one mode for a thousand seconds, in a session hosted by
/// [hostApp]: enough for the CSVs to have a row each.
SessionCollector collector({String hostApp = '0.14.0+654', String? app = '0.14.0+654'}) {
  final c = SessionCollector(
    id: 'a1',
    hostType: HostType.androidTv,
    hostApp: hostApp,
    startedAt: DateTime.utc(2026, 11, 15),
    startMs: 0,
  );
  c.joined('phone-a', number: 1, atMs: 0, platform: 'android', app: app ?? '');
  c.metrics('phone-a', MetricsMessage(segment: 's1', index: 0, mode: 'dpad', durationMs: 1000, data: {'start': 0}));
  c.roundEnded('arena', timeS: 1, modes: {'phone-a': 'dpad'}, winnerId: 'phone-a');
  return c;
}

/// The player's part of [summary], as the report reads it.
Map player0(Map<String, Object?> summary) => ((summary['players'] as List).first as Map).cast<String, Object?>();

/// A summary in the old shape: no build anywhere.
Map<String, Object?> oldSummary({String hostApp = '0.12.0', String app = '0.13.2'}) => {
  'schema': summarySchema,
  'id': 'a1',
  'host': {'type': 'windows', 'app': hostApp},
  'date': '2026-11-15',
  'durationS': 60,
  'players': [
    {
      'install': 'phone-a',
      'player': 1,
      'platform': 'android',
      'app': app,
      'modes': {
        'dpad': {'ms': 60000, 'activeMs': 60000},
      },
      'segments': [
        {
          'id': 's1',
          'mode': 'dpad',
          'ms': 60000,
          'activeMs': 60000,
          'ended': true,
          'data': {'start': 0},
        },
      ],
      'ratings': [],
    },
  ],
  'rounds': [
    {'game': 'arena', 'hz': 60, 'timeS': 60.0},
  ],
  'frames': {'drawn': 0, 'dropped': 0},
};

void main() {
  group("a version's app and build", () {
    test('a player sends "0.14.0+654": the summary keeps app 0.14.0 and build 654', () {
      final player = player0(collector().summary(1000));
      expect(player['app'], '0.14.0');
      expect(player['build'], '654');
    });

    test('a host sends "0.14.0+654": the summary keeps app 0.14.0 and build 654', () {
      final host = (collector().summary(1000)['host'] as Map).cast<String, Object?>();
      expect(host['app'], '0.14.0');
      expect(host['build'], '654');
    });

    test('a plain version and a "dev" build are no build, and the app stays the bare version', () {
      for (final version in ['0.14.0', '0.14.0+dev']) {
        final summary = collector(hostApp: version, app: version).summary(1000);
        expect((summary['host'] as Map)['app'], '0.14.0', reason: version);
        expect((summary['host'] as Map).containsKey('build'), isFalse, reason: version);
        expect(player0(summary)['app'], '0.14.0', reason: version);
        expect(player0(summary).containsKey('build'), isFalse, reason: version);
      }
    });

    test('ten digits, a letter or no tail are no build, and the app stays the bare version', () {
      for (final version in ['0.14.0+1234567890', '0.14.0+65a', '0.14.0+']) {
        final summary = collector(hostApp: version, app: version).summary(1000);
        expect((summary['host'] as Map)['app'], '0.14.0', reason: version);
        expect((summary['host'] as Map).containsKey('build'), isFalse, reason: version);
        expect(player0(summary)['app'], '0.14.0', reason: version);
        expect(player0(summary).containsKey('build'), isFalse, reason: version);
      }
    });
  });

  group('the stats CSV names the builds', () {
    test('host_build and build come after host_app and app, at the end of the header', () {
      final lines = csv([collector().summary(1000)]).split('\n');
      expect(lines.first, endsWith(',host_app,app,host_build,build'));
      expect(lines.first.split(','), hasLength(37)); // The 35 before, plus the two.
    });

    test('a row ends with host_build and build', () {
      final lines = csv([collector().summary(1000)]).split('\n');
      final fields = lines.last.split(',');
      expect(fields, hasLength(37));
      expect(fields.last, '654');
      expect(fields.sublist(33), ['0.14.0', '0.14.0', '654', '654']);
    });

    test('a plain version leaves both build cells empty', () {
      final fields = csv([collector(hostApp: '0.14.0', app: '0.14.0').summary(1000)]).split('\n').last.split(',');
      expect(fields, hasLength(37));
      expect(fields.sublist(33), ['0.14.0', '0.14.0', '', '']);
    });

    test('an old summary with no build leaves the cells empty, never a crash', () {
      final fields = csv([oldSummary()]).split('\n').last.split(',');
      expect(fields, hasLength(37));
      expect(fields.sublist(33), ['0.12.0', '0.13.2', '', '']);
    });
  });

  group('the round CSV names the host build', () {
    test('host_build is the last column, after start_s', () {
      final lines = csvRounds([collector().summary(1000)]).split('\n');
      expect(lines.first, endsWith(',start_s,host_build'));
      expect(lines.first.split(','), hasLength(18)); // The 17 before, plus the build.
    });

    test('a round row carries the host build as its last cell', () {
      final lines = csvRounds([collector().summary(1000)]).split('\n');
      expect(lines.last.split(','), hasLength(18));
      expect(lines.last.split(',')[16], '');
      expect(lines.last, endsWith(',654'));
    });

    test('an old summary with no build leaves the cell empty', () {
      final line = csvRounds([oldSummary()]).split('\n').last;
      expect(line.split(','), hasLength(18));
      expect(line, endsWith(','));
    });
  });
}
