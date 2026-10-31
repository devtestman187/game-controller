import 'dart:convert';

import 'package:metrics/metrics.dart';
import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

/// A 120 x 60 mm controller: the D-pad on the left, B as a 10 mm circle on
/// the right, and Start in the middle.
TouchMap testMap() => TouchMap(
  [
    const TouchShape.rect(Controls.dpad, 10, 20, 30, 30),
    const TouchShape.rect('start', 55, 25, 12, 6),
    TouchShape.circle('b', 100, 30, 5),
  ],
  widthMm: 120,
  heightMm: 60,
);

SegmentRecorder recorder({String mode = 'dpad'}) =>
    SegmentRecorder(id: 's1', mode: mode, startMs: 1000, map: testMap(), settings: const {'buttonSize': 0.75});

void main() {
  group('geometry', () {
    test('a touch on a control hits it; elsewhere the nearest one and how far', () {
      final map = testMap();
      expect(map.hit(20, 30).control, Controls.dpad);
      expect(map.hit(100, 30).control, 'b');
      final miss = map.hit(108, 30); // 3 mm right of B's edge.
      expect(miss.control, isNull);
      expect(miss.nearest, 'b');
      expect(miss.distanceMm, closeTo(3, 1e-9));
    });

    test('empty taps go to a coarse grid cell', () {
      final map = testMap();
      expect(map.cell(1, 1), '0,0');
      expect(map.cell(119, 59), '5,2');
      expect(map.cell(65, 45), '3,2');
      expect(map.cell(-5, 200), '0,2', reason: 'clamped into the grid');
    });
  });

  group('touch counters', () {
    test('a tap just beside B is a near miss next to B, and an empty tap', () {
      final r = recorder()..touchDown(108, 30, 1100);
      final data = r.toJson(2000);
      expect(data['near'], {'b': 1});
      expect(data['empty'], {'5,1': 1});
      expect(data['touches'], 1);
    });

    test('a tap in a blank area far from everything is an empty tap only', () {
      final r = recorder()..touchDown(60, 5, 1100);
      final data = r.toJson(2000);
      expect(data['empty'], {'3,0': 1});
      expect(data.containsKey('near'), isFalse);
    });

    test('a tap on a control is neither', () {
      final data = (recorder()..touchDown(100, 30, 1100)).toJson(2000);
      expect(data.containsKey('empty'), isFalse);
      expect(data.containsKey('near'), isFalse);
    });

    test('presses, durations and controls held together', () {
      final r = recorder()
        ..held({'a'}, 1000)
        ..held({'a', Controls.dpad}, 1100)
        ..held({Controls.dpad}, 1300)
        ..held({}, 1600)
        ..held({'a'}, 2000);
      final data = r.toJson(2500); // a is still held: 500 ms so far.
      expect(data['presses'], {'a': 2, Controls.dpad: 1});
      expect(data['pressMs'], {'a': 300 + 500, Controls.dpad: 500});
      expect(data['pressMaxMs'], {'a': 500, Controls.dpad: 500});
      expect(data['multi'], {'1': 2, '2': 1});
    });

    test('slide-offs per control', () {
      final r = recorder()
        ..slideOff('a')
        ..slideOff('a')
        ..slideOff('start');
      expect(r.toJson(1000)['slide'], {'a': 2, 'start': 1});
    });

    test('four taps on one spot within a second are one rapid repeat', () {
      final r = recorder();
      for (var i = 0; i < 6; i++) {
        r.touchDown(100, 30, 1000 + i * 150);
      }
      // Four taps far apart in time are not.
      for (var i = 0; i < 4; i++) {
        r.touchDown(20, 30, 5000 + i * 600);
      }
      expect(r.toJson(9000)['rapid'], {'b': 1});
    });

    test('rapid taps on an empty spot count as empty', () {
      final r = recorder();
      for (var i = 0; i < 4; i++) {
        r.touchDown(60, 5, 1000 + i * 100);
      }
      expect(r.toJson(2000)['rapid'], {Controls.empty: 1});
    });

    test('stick times: touched, in the dead zone, at full deflection, and reversals', () {
      final r = recorder(mode: 'sticks')
        ..stick(Controls.leftStick, 0, 0, touched: true, atMs: 1000) // dead zone 200 ms
        ..stick(Controls.leftStick, 1, 0, touched: true, atMs: 1200) // full 300 ms
        ..stick(Controls.leftStick, -0.5, 0, touched: true, atMs: 1500) // reversal, 100 ms
        ..stick(Controls.leftStick, 0.6, 0, touched: true, atMs: 1600) // reversal, 400 ms
        ..stick(Controls.leftStick, 0, 0, touched: false, atMs: 2000); // let go
      final sticks = r.toJson(3000)['sticks'] as Map;
      expect(sticks[Controls.leftStick], {'touchMs': 1000, 'deadMs': 200, 'fullMs': 300, 'reversals': 2});
    });

    test('a new touch on a stick does not count a reversal from the last one', () {
      final r = recorder(mode: 'sticks')
        ..stick(Controls.rightStick, 0.8, 0, touched: true, atMs: 0)
        ..stick(Controls.rightStick, 0, 0, touched: false, atMs: 100)
        ..stick(Controls.rightStick, -0.8, 0, touched: true, atMs: 200);
      expect(((r.toJson(300)['sticks'] as Map)[Controls.rightStick] as Map)['reversals'], 0);
    });

    test('gyro: time at full tilt, steering reversals and recalibrations', () {
      final r = recorder(mode: 'gyro')
        ..tilt(0.5, 0, 1000)
        ..tilt(-1, 0, 1500)
        ..tilt(0.4, 0, 2000)
        ..recalibrated();
      final gyro = r.toJson(2500)['gyro'] as Map;
      expect(gyro['fullMs'], 500);
      expect(gyro['reversals'], 2);
      expect(gyro['recal'], 1);
      expect(gyro['touchMs'], 1500);
    });

    test('haptic events per type', () {
      final r = recorder()
        ..haptic('hit')
        ..haptic('hit')
        ..haptic('success');
      expect(r.toJson(1000)['haptics'], {'hit': 2, 'success': 1});
    });

    test('a long busy segment stays well under the 4 KB batch limit', () {
      final r = recorder(mode: 'sticks');
      for (var i = 0; i < 5000; i++) {
        r.touchDown((i * 7) % 120, (i * 13) % 60, i * 10);
        r.held({if (i.isEven) 'a', if (i % 3 == 0) Controls.dpad, if (i % 5 == 0) 'lb'}, i * 10);
        r.stick(Controls.leftStick, (i % 20 - 10) / 10, 0, touched: true, atMs: i * 10);
      }
      final batch = MetricsMessage(segment: 's1', index: 1, mode: 'sticks', durationMs: 50000, data: r.toJson(50000));
      expect(const MessageCodec().encode(batch).length, lessThan(4096));
    });
  });

  group('sanitizing a batch from a phone', () {
    test('keeps known counters only, and drops names, strings and junk', () {
      final clean = sanitizeSegmentData({
        'v': 1,
        'touches': 12,
        'presses': {'a': 3, 'b': 'x', 'Bob\'s phone': 2, 'c' * 40: 1},
        'empty': {'2,1': 4, '9,9': -1},
        'settings': {'buttonSize': 0.75, 'floating': true, 'nickname': 'Bob'},
        'nickname': 'Bob',
        'wifi': {'ssid': 'Home'},
        'sticks': {
          'ls': {'touchMs': 100},
          'xx': {'a': 1},
        },
      });
      expect(clean['presses'], {'a': 3});
      expect(clean['empty'], {'2,1': 4});
      expect(clean['settings'], {'buttonSize': 0.75, 'floating': true});
      expect(clean['sticks'], {
        'ls': {'touchMs': 100},
      });
      expect(clean.containsKey('nickname'), isFalse);
      expect(clean.containsKey('wifi'), isFalse);
      expect(jsonEncode(clean), isNot(contains('Bob')));
    });
  });

  group('delay stats', () {
    test('median, 95th percentile and max', () {
      final d = DelayStats();
      for (var i = 1; i <= 100; i++) {
        d.add(i);
      }
      expect(d.median, 51);
      expect(d.p95, 95);
      expect(d.maxValue, 100);
      expect(d.toJson(), {'n': 100, 'median': 51, 'p95': 95, 'max': 100});
    });

    test('values past the histogram still give the right max', () {
      final d = DelayStats()
        ..add(5)
        ..add(9000);
      expect(d.maxValue, 9000);
      expect(d.quantile(1), 9000);
    });

    test('no samples, no stats', () => expect(DelayStats().toJson(), isNull));
  });

  group('rating scheduler', () {
    test('first after three games, then every five games and at least three minutes apart', () {
      final s = RatingScheduler();
      final asked = [for (var game = 1; game <= 20; game++) s.gameEnded('p1', game * 60 * 1000)];
      // Games 3, then 8 (5 later, 5 min later), 13, 18.
      expect(
        [
          for (var i = 0; i < asked.length; i++)
            if (asked[i]) i + 1,
        ],
        [3, 8, 13, 18],
      );
    });

    test('quick games wait for the time gap', () {
      final s = RatingScheduler();
      final asked = [for (var game = 1; game <= 30; game++) s.gameEnded('p1', game * 10 * 1000)];
      // Game 3 at 30 s; then not before 3 minutes later (game 21 at 210 s).
      expect(
        [
          for (var i = 0; i < asked.length; i++)
            if (asked[i]) i + 1,
        ],
        [3, 21],
      );
    });

    test('players are counted separately', () {
      final s = RatingScheduler();
      s.gameEnded('p1', 0);
      s.gameEnded('p1', 0);
      expect(s.gameEnded('p2', 0), isFalse);
      expect(s.gameEnded('p1', 0), isTrue);
    });
  });

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
        'dpad': {'ms': 40000, 'games': 0, 'wins': 0},
        'sticks': {'ms': 30000, 'games': 1, 'wins': 1},
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
        'keyboard': {'ms': 0, 'games': 1, 'wins': 0},
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
