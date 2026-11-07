import 'package:metrics/metrics.dart';
import 'package:test/test.dart';

/// A phone-hosted session, so the summary's host type is the one a monitor
/// runs on.
SessionCollector collector() => SessionCollector(
  id: 's8',
  hostType: HostType.phone,
  hostApp: '0.12.0',
  startedAt: DateTime.utc(2026, 11, 7, 9),
  startMs: 0,
);

/// The summary's `host` block.
Map<String, Object?> hostOf(SessionCollector c) => c.summary(0)['host']! as Map<String, Object?>;

/// The summary's `host.device`, or null when no sample said anything.
Map<String, Object?>? deviceOf(SessionCollector c) => hostOf(c)['device'] as Map<String, Object?>?;

void main() {
  test('two samples 30 s apart give the host its start, its end and its thermal seconds', () {
    final c = collector();
    c.deviceSample(const HostDeviceSample(battery: 0.9, thermal: 'nominal'));
    c.deviceSample(const HostDeviceSample(battery: 0.8, charging: true, thermal: 'nominal'), forS: 30);
    expect(hostOf(c), {
      'type': 'phone',
      'app': '0.12.0',
      'device': {
        'batteryStart': 0.9,
        'batteryEnd': 0.8,
        'charging': true,
        'thermalS': {'nominal': 30},
      },
    });
  });

  test('a sample with no battery still counts the charging, low power and heat', () {
    final c = collector();
    c.deviceSample(const HostDeviceSample(charging: true, lowPower: true, thermal: 'serious'), forS: 30);
    expect(deviceOf(c), {
      'charging': true,
      'lowPower': true,
      'thermalS': {'serious': 30},
    });
  });

  test('the levels are rounded to two decimals and a broken reading is skipped', () {
    final c = collector();
    c.deviceSample(const HostDeviceSample(battery: 0.8765));
    c.deviceSample(const HostDeviceSample(battery: 1.2), forS: 30);
    c.deviceSample(const HostDeviceSample(battery: 0.8), forS: 30);
    expect(deviceOf(c), {'batteryStart': 0.88, 'batteryEnd': 0.8});
  });

  test('a session with no sample has no host.device', () {
    expect(hostOf(collector()).containsKey('device'), isFalse);
  });

  test('a round keeps the battery and heat of its start and end samples', () {
    final c = collector();
    c.joined('p', number: 1, atMs: 0);
    c.roundStarted(hz: 60);
    c.roundEnded('arena', timeS: 12, modes: {'p': 'dpad'});
    c.roundBattery(start: 0.5, end: 0.45, thermal: 'fair');
    expect(c.summary(0)['rounds'], [
      {
        'game': 'arena',
        'hz': 60,
        'timeS': 12.0,
        'players': 1,
        'battery': {'start': 0.5, 'end': 0.45},
        'thermal': 'fair',
      },
    ]);
  });

  test('a round is filled once, and a session with no round writes nothing', () {
    final c = collector();
    c.roundBattery(start: 0.5, end: 0.4, thermal: 'fair');
    expect(c.summary(0)['rounds'], isEmpty, reason: 'no round ended yet');

    c.roundStarted();
    c.roundEnded('arena', timeS: 1, modes: const {});
    c.roundBattery(start: 0.5, end: 0.4, thermal: 'fair');
    c.roundBattery(start: 0.9, end: 0.9, thermal: 'serious');
    expect(c.summary(0)['rounds'], [
      {
        'game': 'arena',
        'timeS': 1.0,
        'players': 0,
        'battery': {'start': 0.5, 'end': 0.4},
        'thermal': 'fair',
      },
    ]);
  });

  test('a round that ran on the charger keeps that in its battery block', () {
    final c = collector();
    c.roundStarted(hz: 60);
    c.roundEnded('arena', timeS: 90, modes: const {});
    c.roundBattery(start: 0.77, end: 0.79, charging: true, thermal: 'serious');
    final round = (c.summary(0)['rounds'] as List).single as Map;
    // The report leaves such a round out of the battery drop (m12 §1).
    expect(round['battery'], {'start': 0.77, 'end': 0.79, 'charging': true});
    expect(round['thermal'], 'serious');
  });

  test('a round with no battery sample has no battery block', () {
    final c = collector();
    c.roundStarted(hz: 30);
    c.roundEnded('arena', timeS: 2, modes: const {});
    c.roundBattery(thermal: 'nominal');
    expect((c.summary(0)['rounds'] as List).single, {
      'game': 'arena',
      'hz': 30,
      'timeS': 2.0,
      'players': 0,
      'thermal': 'nominal',
    });
  });
}
