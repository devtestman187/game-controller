import 'dart:convert';

import 'package:metrics/metrics.dart';
import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

void main() {
  group('game values', gameValues);

  group('session summary', () {
    test('a simulated session produces the known summary', () {
      final c = SessionCollector(
        id: 'sess-1',
        hostType: HostType.windows,
        hostApp: '0.9.0',
        startedAt: DateTime.utc(2026, 10, 31, 12, 30),
        startMs: 0,
      );
      const device = DeviceInfo(
        kind: DeviceInfo.phone,
        model: 'Pixel 8',
        os: 'Android 15',
        widthMm: 150,
        heightMm: 70,
        haptics: true,
      );
      c.joined('phone-a', number: 1, atMs: 0, platform: 'android', app: '0.9.0', device: device);
      c.joined('kb', number: 2, atMs: 0, local: true);

      // Two mode segments: 40 s of D-pad, then sticks.
      c.metrics(
        'phone-a',
        MetricsMessage(segment: 'a-1', index: 0, mode: 'dpad', durationMs: 20000, data: {'start': 0, 'touches': 10}),
      );
      c.metrics(
        'phone-a',
        MetricsMessage(
          segment: 'a-1',
          index: 1,
          mode: 'dpad',
          durationMs: 40000,
          ended: true,
          data: {
            'start': 0,
            'touches': 30,
            'presses': {'a': 12},
            'near': {'b': 2},
            'empty': {'5,1': 3},
          },
        ),
      );
      // A stale, repeated batch changes nothing.
      c.metrics('phone-a', MetricsMessage(segment: 'a-1', index: 0, mode: 'dpad', durationMs: 1, data: const {}));
      c.metrics(
        'phone-a',
        MetricsMessage(
          segment: 'a-2',
          index: 0,
          mode: 'sticks',
          durationMs: 30000,
          data: {
            'start': 40000,
            'touches': 20,
            'presses': {'a': 5, 'ls': 3},
          },
        ),
      );
      for (final ms in [10, 12, 14, 30]) {
        c.stage('phone-a', 'sent_to_received', ms);
      }
      c.ping('phone-a', 8);
      for (var i = 0; i < 70; i++) {
        c.input('phone-a');
      }
      c.mode('phone-a', 'sticks');
      c.roundStarted();
      c.gameEvent('arena', 'wall_hit', 'phone-a');
      c.roundEnded('arena', timeS: 12.345, modes: {'phone-a': 'sticks', 'kb': 'keyboard'}, winnerId: 'phone-a');
      c.rating(
        'phone-a',
        RatingMessage(id: 'r1', face: RatingFace.good, tags: [RatingTag.buttonsTooSmall]),
        game: 'arena',
      );
      c.frames(4200, 3);

      // A Wi-Fi drop: back after 2.5 s.
      c.left('phone-a', 50000);
      c.joined('phone-a', number: 1, atMs: 52500, platform: 'android', app: '0.9.0', device: device);

      final s = c.summary(70000);
      expect(s['schema'], summarySchema);
      expect(s['date'], '2026-10-31');
      expect(s['durationS'], 70);
      expect(s['host'], {'type': 'windows', 'app': '0.9.0'});
      expect(s['rounds'], [
        {'game': 'arena', 'timeS': 12.35, 'players': 2, 'winner': 1},
      ]);
      expect(s['frames'], {'drawn': 4200, 'dropped': 3});

      final players = s['players'] as List;
      final p1 = players[0] as Map;
      expect(p1['install'], 'phone-a');
      expect(p1['connectedS'], 68); // 50 s + 17.5 s
      expect(p1['disconnects'], 1);
      expect(p1['reconnect'], {'n': 1, 'median': 2500, 'p95': 2500, 'max': 2500});
      expect(p1['inputs'], 70);
      expect(p1['firstMode'], 'dpad');
      expect(p1['switches'], [
        {'from': 'dpad', 'to': 'sticks', 'atS': 40},
      ]);
      expect(p1['modes'], {
        // These phones sent no active time: it falls back to the segment time.
        'dpad': {'ms': 40000, 'activeMs': 40000, 'games': 0, 'wins': 0},
        'sticks': {'ms': 30000, 'activeMs': 30000, 'games': 1, 'wins': 1},
      });
      expect((p1['stages'] as Map)['sent_to_received'], {'n': 4, 'median': 14, 'p95': 30, 'max': 30});
      expect(p1['ratings'], [
        {
          'game': 'arena',
          'face': 'good',
          'tags': ['buttons_too_small'],
          'mode': 'sticks',
        },
      ]);
      expect(p1['games'], {
        'arena': {'wall_hit': 1, 'wins': 1, 'rounds': 1},
      });
      expect(((p1['segments'] as List)[0] as Map)['data'], containsPair('near', {'b': 2}));

      final kb = players[1] as Map;
      expect(kb['local'], isTrue);
      expect(kb['modes'], {
        'keyboard': {'ms': 0, 'activeMs': 0, 'games': 1, 'wins': 0},
      });

      // Small, and no names or network details.
      final text = jsonEncode(s);
      expect(text.length, lessThan(50 * 1024));
      for (final banned in ['Phone', 'Keyboard', '192.168', 'name', 'nickname', 'address']) {
        expect(text, isNot(contains(banned)), reason: banned);
      }

      // And the report reads it.
      final rows = rowsOf(s);
      final sticks = rows.firstWhere((r) => r.mode == 'sticks' && r.install == 'phone-a');
      expect(sticks.presses, 8);
      expect(sticks.good, 1);
      expect(sticks.wins, 1);
      final dpad = rows.firstWhere((r) => r.mode == 'dpad');
      expect(dpad.near, 2);
      expect(dpad.empty, 3);
      expect(dpad.earlySwitch, isTrue);
      expect(dpad.firstMode, isTrue);
      expect(dpad.frustrationPerMin, closeTo(5 / (40 / 60), 1e-9));
      expect(report([s]), contains('By input mode'));
      expect(csv([s]).split('\n'), hasLength(1 + rows.length));
    });

    test('device strings that look like names are dropped', () {
      final c = SessionCollector(
        id: 's',
        hostType: HostType.androidTv,
        hostApp: '0.9.0',
        startedAt: DateTime.utc(2026),
        startMs: 0,
      );
      c.joined(
        'p',
        number: 1,
        atMs: 0,
        platform: 'ios',
        app: '0.9.0',
        device: const DeviceInfo(kind: DeviceInfo.phone, model: "Bob's iPhone", os: 'iOS 26.0'),
      );
      final device = ((c.summary(0)['players'] as List)[0] as Map)['device'] as Map;
      expect(device.containsKey('model'), isFalse);
      expect(device['os'], 'iOS 26.0');
    });

    test('a phone that sends too many segments is capped', () {
      final c = SessionCollector(
        id: 's',
        hostType: HostType.androidTv,
        hostApp: '0.9.0',
        startedAt: DateTime.utc(2026),
        startMs: 0,
      );
      c.joined('p', number: 1, atMs: 0);
      for (var i = 0; i < 500; i++) {
        c.metrics('p', MetricsMessage(segment: 'seg$i', index: 0, mode: 'dpad', durationMs: 100, data: const {}));
      }
      expect(((c.summary(0)['players'] as List)[0] as Map)['segments'], hasLength(200));
    });
  });
}

void gameValues() {
  test('puzzle measurements are kept per player as count, mean and max', () {
    final c = SessionCollector(
      id: 's',
      hostType: HostType.windows,
      hostApp: '0.10.0',
      startedAt: DateTime.utc(2026),
      startMs: 0,
    );
    c.joined('p', number: 1, atMs: 0);
    for (final v in [2.0, 4.0, 9.0]) {
      c.gameValue('puzzle', 'angleErrorDeg', 'p', v);
    }
    c.gameValue('puzzle', 'angleErrorDeg', 'p', double.nan);
    c.gameValue('puzzle', 'angleErrorDeg', 'nobody', 1);
    final p = (c.summary(0)['players'] as List).single as Map;
    expect(p['gameStats'], {
      'puzzle': {
        'angleErrorDeg': {'n': 3, 'mean': 5.0, 'max': 9.0},
      },
    });
  });
}
