import 'package:metrics/metrics.dart';
import 'package:test/test.dart';

/// A collector where phone-a joined with [app] and, a second later, joined
/// again with [rejoin]: a reconnect that may or may not name a version.
SessionCollector rejoined({required String app, required String rejoin}) {
  final c = SessionCollector(
    id: 'a1',
    hostType: HostType.androidTv,
    hostApp: '0.14.0+654',
    startedAt: DateTime.utc(2026, 11, 15),
    startMs: 0,
  );
  c.joined('phone-a', number: 1, atMs: 0, platform: 'android', app: app);
  c.joined('phone-a', number: 1, atMs: 1000, platform: 'android', app: rejoin);
  return c;
}

/// The player's part of [summary], as the report reads it.
Map<String, Object?> player0(Map<String, Object?> summary) =>
    ((summary['players'] as List).first as Map).cast<String, Object?>();

/// A summary from another app, whose host and player both carry [build] as
/// their build: what a hand-edited or a future summary could hold.
Map<String, Object?> summaryWithBuilds(String build) => {
  'schema': summarySchema,
  'id': 'a1',
  'host': {'type': 'windows', 'app': '0.14.0', 'build': build},
  'date': '2026-11-15',
  'durationS': 60,
  'players': [
    {
      'install': 'phone-a',
      'player': 1,
      'platform': 'android',
      'app': '0.14.0',
      'build': build,
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
      'ratings': <Object?>[],
    },
  ],
  'rounds': [
    {'game': 'arena', 'hz': 60, 'timeS': 60.0},
  ],
  'frames': {'drawn': 0, 'dropped': 0},
};

/// A row as a caller of the library builds one, with its two build cells as
/// given.
ModeRow row({required String hostBuild, required String build}) => ModeRow(
  session: 'a1',
  date: '2026-11-15',
  hostType: HostType.androidTv,
  install: 'phone-a',
  deviceKind: 'phone',
  model: 'Pixel 8',
  platform: 'android',
  watched: null,
  mode: 'dpad',
  ms: 60000,
  activeMs: 60000,
  touches: 1,
  presses: 2,
  empty: 0,
  near: 0,
  slide: 0,
  rapid: 0,
  games: 1,
  wins: 1,
  good: 0,
  okay: 0,
  bad: 0,
  earlySwitch: false,
  firstMode: true,
  hostBuild: hostBuild,
  build: build,
);

void main() {
  group('a reconnect and the build it names', () {
    test('a reconnect with a new bare version takes the new app and no build', () {
      final player = player0(rejoined(app: '0.14.0+654', rejoin: '0.15.0').summary(2000));
      expect(player['app'], '0.15.0');
      expect(player.containsKey('build'), isFalse);
    });

    test('a reconnect that names no version keeps the app and the build', () {
      final player = player0(rejoined(app: '0.14.0+654', rejoin: '').summary(2000));
      expect(player['app'], '0.14.0');
      expect(player['build'], '654');
    });
  });

  group('a build cell never shifts the row', () {
    test('a hand-built row with a comma in both builds keeps the header field count', () {
      final fields = row(hostBuild: '65,4', build: '1,2').toCsv().split(',');
      expect(fields, hasLength(ModeRow.csvHeader.split(',').length)); // 37
      expect(fields.sublist(35), ['', '']);
    });

    for (final bad in ['65a', '1,2']) {
      test("a summary whose build is '$bad' reads the two build cells empty, in a 37-field row", () {
        final fields = rowsOf(summaryWithBuilds(bad)).single.toCsv().split(',');
        expect(fields, hasLength(37));
        expect(fields.sublist(35), ['', '']);
      });
    }
  });
}
