import 'dart:async';

import 'package:connection/connection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metrics/metrics.dart';
import 'package:party_host/party_host.dart';

/// How long the tests wait for a reading in flight.
const timeout = Duration(seconds: 5);

Future<void> waitFor(bool Function() test, {Duration limit = timeout}) async {
  final end = DateTime.now().add(limit);
  while (!test()) {
    if (DateTime.now().isAfter(end)) throw TimeoutException('condition not met');
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

/// A monitor that answers with the readings a test lines up, counting what it
/// was asked for.
class FakeMonitor implements HostDeviceMonitor {
  FakeMonitor([List<HostDeviceSample?> samples = const []]) : samples = [...samples];

  /// The readings still to be handed out, in order; an empty list answers
  /// null.
  final List<HostDeviceSample?> samples;

  /// How many readings were asked for.
  int reads = 0;

  @override
  Future<HostDeviceSample?> sample() async {
    reads++;
    return samples.isEmpty ? null : samples.removeAt(0);
  }
}

/// A monitor whose adapter fails, as a missing plugin does.
class BrokenMonitor implements HostDeviceMonitor {
  int reads = 0;

  @override
  Future<HostDeviceSample?> sample() async {
    reads++;
    throw StateError('no battery plugin');
  }
}

void main() {
  late HostServer server;
  late ServerGameHost host;
  late SessionCollector session;

  setUp(() {
    server = HostServer(hostId: 'host', hostName: 'Phone', appVersion: '0.12.0', listeners: const []);
    host = ServerGameHost(server);
    session = SessionCollector(
      id: 's8',
      hostType: HostType.phone,
      hostApp: '0.12.0',
      startedAt: DateTime.utc(2026, 11, 7, 9),
      startMs: 0,
    );
    session.joined('p', number: 1, atMs: 0);
  });

  tearDown(() async {
    await host.dispose();
    await server.dispose();
  });

  HostDeviceSampler start(HostDeviceMonitor monitor, {Duration period = const Duration(milliseconds: 10)}) {
    final sampler = HostDeviceSampler(host: host, monitor: monitor, session: () => session, period: period);
    addTearDown(sampler.dispose);
    return sampler;
  }

  /// The session's `host.device`, as the summary writes it.
  Map<String, Object?>? device() => (session.summary(0)['host'] as Map)['device'] as Map<String, Object?>?;

  /// The round that ended, as the summary writes it.
  Map<String, Object?> round() => (session.summary(0)['rounds'] as List).last as Map<String, Object?>;

  test('a reading every period counts its seconds in the device\'s thermal state', () async {
    final monitor = FakeMonitor(const [
      HostDeviceSample(battery: 0.9, thermal: 'nominal'),
      HostDeviceSample(battery: 0.8, charging: true, thermal: 'nominal'),
    ]);
    start(monitor, period: const Duration(seconds: 1));
    await waitFor(() => (device()?['thermalS'] as Map?)?['nominal'] == 2);
    expect(device(), {
      'batteryStart': 0.9,
      'batteryEnd': 0.8,
      'charging': true,
      'thermalS': {'nominal': 2},
    });
    expect(monitor.reads, greaterThanOrEqualTo(2));
  });

  test('a round takes the battery of its start and of its end, and the heat at the end', () async {
    start(FakeMonitor(const [HostDeviceSample(battery: 0.9), HostDeviceSample(battery: 0.8, thermal: 'fair')]));
    session.roundStarted(hz: 60);
    host.record(const GameRecord(game: 'arena', name: 'round_start', data: {'hz': 60}));
    session.roundEnded('arena', timeS: 12, modes: {'p': 'dpad'});
    host.record(const GameRecord(game: 'arena', name: 'round_end'));
    await waitFor(() => round().containsKey('battery'));
    expect(round()['battery'], {'start': 0.9, 'end': 0.8});
    expect(round()['thermal'], 'fair');
  });

  test('a reading with no battery still gives the round its heat, and no battery block', () async {
    start(FakeMonitor(const [HostDeviceSample(thermal: 'nominal'), HostDeviceSample(thermal: 'fair')]));
    session.roundStarted(hz: 30);
    host.record(const GameRecord(game: 'arena', name: 'round_start', data: {'hz': 30}));
    session.roundEnded('arena', timeS: 5, modes: {'p': 'dpad'});
    host.record(const GameRecord(game: 'arena', name: 'round_end'));
    await waitFor(() => round().containsKey('thermal'));
    expect(round().containsKey('battery'), isFalse);
    expect(round()['thermal'], 'fair');
  });

  test('a host with no monitor records no battery and no heat', () async {
    start(const NoHostDeviceMonitor());
    session.roundStarted(hz: 60);
    host.record(const GameRecord(game: 'arena', name: 'round_start', data: {'hz': 60}));
    session.roundEnded('arena', timeS: 5, modes: {'p': 'dpad'});
    host.record(const GameRecord(game: 'arena', name: 'round_end'));
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(round().containsKey('battery'), isFalse);
    expect(round().containsKey('thermal'), isFalse);
    expect((session.summary(0)['host'] as Map).containsKey('device'), isFalse);
  });

  test('a round the sampler saw no start of gets no battery', () async {
    start(FakeMonitor(const [HostDeviceSample(battery: 0.9)]));
    session.roundStarted(hz: 60);
    session.roundEnded('arena', timeS: 5, modes: {'p': 'dpad'});
    host.record(const GameRecord(game: 'arena', name: 'round_end'));
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(round().containsKey('battery'), isFalse);
  });

  test('a failed reading is logged, and the timer keeps reading', () async {
    final broken = BrokenMonitor();
    final lines = <String>[];
    final sampler = HostDeviceSampler(
      host: host,
      monitor: broken,
      session: () => session,
      period: const Duration(milliseconds: 10),
      log: lines.add,
    );
    addTearDown(sampler.dispose);
    await waitFor(() => broken.reads >= 2);
    expect(lines, isNotEmpty);
    expect(lines.first, contains('battery'));
    expect(device(), isNull, reason: 'no reading said anything');
  });

  test('dispose stops the timer and the round hooks', () async {
    final monitor = FakeMonitor();
    final sampler = start(monitor);
    await waitFor(() => monitor.reads >= 1);
    await sampler.dispose();
    final reads = monitor.reads;
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(monitor.reads, reads, reason: 'no reading after dispose');
  });
}
