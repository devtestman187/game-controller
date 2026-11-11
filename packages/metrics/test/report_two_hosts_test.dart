import 'package:metrics/metrics.dart';
import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

/// The session the owner's TV ran (m12 §3): one joined phone that isn't shown
/// the game, and two arena rounds at 60 Hz. No monitor, so no battery or heat.
Map<String, Object?> tvSummary() {
  final c = SessionCollector(
    id: 'tv-1',
    hostType: HostType.windows,
    hostApp: '0.12.0',
    startedAt: DateTime.utc(2026, 11, 7, 18),
    startMs: 0,
  );
  c.joined('phone-t', number: 1, atMs: 0, platform: 'android', app: '0.12.0');
  c.metrics(
    'phone-t',
    MetricsMessage(segment: 't-1', index: 0, mode: 'dpad', durationMs: 180000, data: const {'start': 0}),
  );
  // A TV that keeps its game to itself files no stage sample by rate.
  c.stage('phone-t', 'sent_to_received', 30);
  for (var i = 0; i < 2; i++) {
    c.roundStarted(hz: 60);
    c.roundEnded('arena', timeS: 90, modes: const {'phone-t': 'dpad'});
  }
  return c.summary(180000);
}

/// The session the owner's phone hosted (m12 §3): its own player and one
/// joined phone that draws the game, four rounds at 60 Hz and two at 30, and
/// battery readings with the second phone on the charger for one round.
Map<String, Object?> phoneSummary() {
  final c = SessionCollector(
    id: 'ph-1',
    hostType: HostType.phone,
    hostApp: '0.12.0',
    startedAt: DateTime.utc(2026, 11, 7, 19),
    startMs: 0,
  );
  c
    ..joined('self', number: 1, atMs: 0, inProcess: true, platform: 'android', app: '0.12.0')
    ..joined('phone-a', number: 2, atMs: 0, platform: 'android', app: '0.12.0')
    ..metrics(
      'self',
      MetricsMessage(segment: 's-1', index: 0, mode: 'dpad', durationMs: 400000, data: const {'start': 0}),
    )
    ..metrics(
      'phone-a',
      MetricsMessage(
        segment: 'a-1',
        index: 0,
        mode: 'dpad',
        durationMs: 250000,
        view: (frames: 6000, gaps: 2, late: 6),
      ),
      hz: 60,
    )
    ..metrics(
      'phone-a',
      MetricsMessage(
        segment: 'a-2',
        index: 0,
        mode: 'dpad',
        durationMs: 150000,
        view: (frames: 1800, gaps: 1, late: 3),
      ),
      hz: 30,
    )
    ..stage('self', 'sent_to_received', 20, hz: 60)
    ..stage('self', 'sent_to_received', 25, hz: 30)
    ..stage('phone-a', 'touch_to_frame', 40, hz: 60)
    ..stage('phone-a', 'frame_jitter', 4, hz: 60)
    ..stage('phone-a', 'touch_to_frame', 90, hz: 30)
    ..stage('phone-a', 'frame_jitter', 8, hz: 30)
    ..deviceSample(const HostDeviceSample(battery: 0.80, thermal: 'fair'));
  // Four 100 s rounds at 60 Hz: three on battery losing 1 % each, and one on
  // the charger, whose rise isn't part of the drop.
  const sixty = [(0.80, 0.79, false, 'fair'), (0.79, 0.78, false, 'fair'), (0.78, 0.77, false, 'fair')];
  for (final (start, end, charging, thermal) in sixty) {
    c.roundStarted(hz: 60);
    c.roundEnded('arena', timeS: 100, modes: const {'self': 'dpad', 'phone-a': 'dpad'});
    c.roundBattery(start: start, end: end, charging: charging, thermal: thermal);
  }
  c.roundStarted(hz: 60);
  c.roundEnded('arena', timeS: 100, modes: const {'self': 'dpad', 'phone-a': 'dpad'});
  c.roundBattery(start: 0.77, end: 0.79, charging: true, thermal: 'serious');
  // Two 60 s rounds at 30 Hz: 120 s is under the five minutes a drop needs.
  for (var i = 0; i < 2; i++) {
    c.roundStarted(hz: 30);
    c.roundEnded('arena', timeS: 60, modes: const {'self': 'dpad', 'phone-a': 'dpad'});
    c.roundBattery(start: 0.76, end: 0.75, thermal: 'nominal');
  }
  return c.summary(600000);
}

/// One table line's cells, the padding collapsed.
List<String> cells(String line) => line.trim().split(RegExp(r'\s+'));

/// The line of [text] that starts with [host] and [hz].
List<String> lineOf(String text, String host, int hz) =>
    cells(text.split('\n').firstWhere((line) => cells(line).take(2).join(' ') == '$host $hz'));

void main() {
  group('the exit check: a TV and a phone host in one report (m12 §3)', () {
    test('by host and where they watched: one row per place, a player once', () {
      final text = watchedTable([...rowsOf(tvSummary()), ...rowsOf(phoneSummary())]);
      final lines = text.split('\n');
      expect(lines[0], 'By host and where they watched');
      // The host phone's own player watched on the host (20 and 25 ms input
      // delays, whose upper median is 25), the joined phone on itself, and the
      // TV's phone on the TV. The joined phone's touch samples, 40 ms at 60 Hz
      // and 90 at 30, have 90 as both their upper median and their p95, and its
      // jitter samples, 4 and 8, have 8 as the median.
      expect(cells(lines[3]), ['phone', 'host_phone', '1', '25', '-', '-']);
      expect(cells(lines[4]), ['phone', 'joined_phone', '1', '-', '90/90', '8']);
      expect(cells(lines[5]), ['windows', 'host_screen', '1', '30', '-', '-']);
    });

    test('by frame rate: rounds, minutes, the touch figures, the drop and the heat', () {
      final text = frameRateTable([tvSummary(), phoneSummary()]);
      expect(text.split('\n')[0], 'By frame rate');
      // 400 s at 60 Hz: 6 late frames a minute, 2 gaps, and 300 s of battery
      // losing 3 % of a charge in 1/12 h.
      expect(lineOf(text, 'phone', 60), ['phone', '60', '4', '6.7', '40/40', '0.9', '0.3', '36.0', 'serious']);
      expect(lineOf(text, 'phone', 30), ['phone', '30', '2', '2.0', '90/90', '1.5', '0.5', '-', 'nominal']);
      // A TV keeps its game to itself, so its phone measured nothing to show.
      expect(lineOf(text, 'windows', 60), ['windows', '60', '2', '3.0', '-', '0.0', '0.0', '-', '-']);
    });

    test('the whole report puts the two tables between the modes and enjoyment', () {
      final text = report([tvSummary(), phoneSummary()]);
      expect(text, contains('By input mode'));
      expect(text, contains('By host and where they watched'));
      expect(text, contains('By frame rate'));
      expect(text.indexOf('By device and mode'), lessThan(text.indexOf('By host and where they watched')));
      expect(text.indexOf('By frame rate'), lessThan(text.indexOf('Enjoyment:')));
    });

    test('the round CSV has one row per round, with the battery and the heat', () {
      expect(csvRounds([tvSummary(), phoneSummary()]).split('\n'), [
        'session,host,game,hz,time_s,battery_start,battery_end,thermal,tags',
        'tv-1,windows,arena,60,90.0,,,,',
        'tv-1,windows,arena,60,90.0,,,,',
        'ph-1,phone,arena,60,100.0,0.8,0.79,fair,',
        'ph-1,phone,arena,60,100.0,0.79,0.78,fair,',
        'ph-1,phone,arena,60,100.0,0.78,0.77,fair,',
        'ph-1,phone,arena,60,100.0,0.77,0.79,serious,',
        'ph-1,phone,arena,30,60.0,0.76,0.75,nominal,',
        'ph-1,phone,arena,30,60.0,0.76,0.75,nominal,',
      ]);
    });
  });
}
