import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:connection/connection.dart';
import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

import 'helpers.dart';

/// The fake controllers one host serves in a load run (the eight-phone party).
const phoneCount = 8;

/// Each phone sends this many inputs a second, as a pad polls at 60 Hz.
const inputRateHz = 60;

/// The plain run's length in seconds: short, so the suite stays quick.
const plainRunS = 3;

/// The LOAD8 run's length in seconds: long enough to read a steady rate.
const loadRunS = 30;

/// Every phone's Random seed, so the same run sends the same inputs.
const inputSeed = 17;

/// The values one axis of a pad reads: -1, 0 and 1.
const axisSteps = 3;

/// Groups the input count for the summary line: wall ms per this many inputs.
const inputBlock = 1000;

/// How long the host may take to hear the last input after the phones stop.
const drainTimeout = Duration(seconds: 10);

/// The load tests' own limit: a LOAD8 run is 30 s, plus pairing and draining.
const loadTimeout = Timeout(Duration(minutes: 2));

/// Set by `LOAD8=1 bash tools/load8.sh` (or `--dart-define=LOAD8=1`): the long run that prints its numbers.
final _isLoad8 = Platform.environment['LOAD8'] == '1' || const bool.fromEnvironment('LOAD8');

/// What one run measured. Every map is keyed by controller id, in phone order.
final class LoadRun {
  const LoadRun({
    required this.paired,
    required this.dropped,
    required this.sent,
    required this.counted,
    required this.inOrder,
    required this.signatures,
    required this.wall,
    required this.maxLag,
  });

  /// How many phones the host had connected once they all paired.
  final int paired;

  /// The phones the host no longer counts as connected at the end.
  final List<String> dropped;

  /// Each phone's inputsSent: the states its client put on the channel.
  final Map<String, int> sent;

  /// The inputs the host counted per phone (its messages from that phone).
  final Map<String, int> counted;

  /// Whether each phone's inputs reached the host in the order they were sent.
  final Map<String, bool> inOrder;

  /// Each phone's inputs as the host heard them, one string per phone, to compare two runs.
  final Map<String, String> signatures;

  /// Wall time from the first input to the host having every one of them.
  final Duration wall;

  /// The longest wait from a phone's send to the host's handler, over every input.
  final Duration maxLag;
}

/// One fake controller: its client, its seeded inputs, and what it sent and heard back.
final class _FakePhone {
  _FakePhone(this.id, this.client) : rng = Random(inputSeed);

  final String id;
  final ControllerClient client;
  final Random rng;

  /// The elapsed time of each send, in microseconds, keyed by the input's seq.
  final Map<int, int> sentAtUs = {};

  /// The inputs the host heard from this phone, in the order it heard them.
  final List<InputStateMessage> received = [];
}

/// The next seeded input of a pad: the buttons held and the direction pressed.
({Set<ControllerButton> buttons, int dx, int dy}) _nextInput(Random rng) => (
  buttons: {
    for (final b in ControllerButton.values)
      if (rng.nextBool()) b,
  },
  dx: rng.nextInt(axisSteps) - 1,
  dy: rng.nextInt(axisSteps) - 1,
);

/// The input as text, with its buttons sorted, so two runs compare as strings.
String _signature(InputStateMessage m) {
  final buttons = [for (final b in m.buttons) b.name]..sort();
  return '${m.dx},${m.dy},${buttons.join('+')}';
}

/// The input the host's snapshot holds for [id], or null.
InputStateMessage? _lastInput(HostSnapshot s, String id) =>
    s.controllers.where((c) => c.controllerId == id).firstOrNull?.input;

/// Runs [seconds] of 60 Hz input from eight phones to one host on the in-process transport.
Future<LoadRun> runLoad({required int seconds}) async {
  final host = await startHost(TestTransport.inProcess);
  final clock = Stopwatch()..start();
  final fleet = [
    for (var i = 1; i <= phoneCount; i++) _FakePhone('phone-$i', newClient(TestTransport.inProcess, id: 'phone-$i')),
  ];
  final byId = {for (final phone in fleet) phone.id: phone};
  var lagMaxUs = 0;
  var totalHeard = 0;
  int? expected;
  final drained = Completer<void>();
  // Listening before the phones pair, so the pairing's own input state is counted too.
  final sub = host.messages.listen((m) {
    final phone = byId[m.controllerId];
    final message = m.message;
    if (phone == null || message is! InputStateMessage) return;
    phone.received.add(message);
    totalHeard++;
    final sentUs = phone.sentAtUs[message.seq];
    if (sentUs != null) lagMaxUs = max(lagMaxUs, clock.elapsedMicroseconds - sentUs);
    if (totalHeard == expected && !drained.isCompleted) drained.complete();
  });
  for (final phone in fleet) {
    phone.client.connect(addressOf(host, TestTransport.inProcess), code: host.pairingCode);
  }
  await Future.wait([for (final phone in fleet) clientStatus(phone.client, ClientStatus.connected)]);
  final paired = host.snapshot.connected.length;

  final tickUs = Duration.microsecondsPerSecond ~/ inputRateHz;
  final start = clock.elapsedMicroseconds;
  for (var tick = 0; tick < seconds * inputRateHz; tick++) {
    final wait = tick * tickUs - (clock.elapsedMicroseconds - start);
    if (wait > 0) await Future<void>.delayed(Duration(microseconds: wait));
    for (final phone in fleet) {
      final input = _nextInput(phone.rng);
      phone.client.sendInput(input.buttons, dx: input.dx, dy: input.dy);
      // The state just sent carries the client's count as its seq (both move once per state).
      phone.sentAtUs[phone.client.inputsSent] = clock.elapsedMicroseconds;
    }
  }
  expected = fleet.fold<int>(0, (n, phone) => n + phone.client.inputsSent);
  if (totalHeard < expected) await drained.future.timeout(drainTimeout);
  final wall = Duration(microseconds: clock.elapsedMicroseconds - start);
  await sub.cancel();

  // The host's snapshot must show each phone's last input: the wait fails if it never does.
  await hostUntil(host, (h) => fleet.every((p) => _lastInput(h, p.id)?.seq == p.received.lastOrNull?.seq));
  final dropped = [
    for (final phone in fleet)
      if (stateOf(host.snapshot, phone.id) != ControllerState.connected) phone.id,
  ];
  return LoadRun(
    paired: paired,
    dropped: dropped,
    sent: {for (final phone in fleet) phone.id: phone.client.inputsSent},
    counted: {for (final phone in fleet) phone.id: phone.received.length},
    inOrder: {
      for (final phone in fleet)
        phone.id:
            phone.received.isEmpty ||
            [for (final m in phone.received) m.seq].indexed.every((e) => e.$2 == phone.received.first.seq + e.$1),
    },
    signatures: {for (final phone in fleet) phone.id: phone.received.map(_signature).join(' ')},
    wall: wall,
    maxLag: Duration(microseconds: lagMaxUs),
  );
}

/// The one line the LOAD8 run prints: inputs per second, wall ms per 1000 inputs, and the host's lag.
String summaryLine(LoadRun run) {
  final total = run.counted.values.fold(0, (a, b) => a + b);
  final wallUs = run.wall.inMicroseconds;
  final perSecond = total * Duration.microsecondsPerSecond / wallUs;
  final msPerBlock = wallUs * inputBlock / total / Duration.microsecondsPerMillisecond;
  final lagMs = run.maxLag.inMicroseconds / Duration.microsecondsPerMillisecond;
  return '8 phones: ${perSecond.toStringAsFixed(1)} inputs/s, ${msPerBlock.toStringAsFixed(1)} wall ms per '
      '$inputBlock inputs ($total inputs in ${wallUs ~/ Duration.microsecondsPerMillisecond} ms), '
      'max host lag ${lagMs.toStringAsFixed(2)} ms';
}

void main() {
  test('eight phones pair, stay connected, and every input they send reaches the host', () async {
    final run = await runLoad(seconds: _isLoad8 ? loadRunS : plainRunS);
    expect(run.paired, phoneCount, reason: 'all eight phones are connected once paired');
    expect(run.dropped, isEmpty, reason: 'no phone was dropped');
    for (final id in run.sent.keys) {
      expect(run.counted[id], run.sent[id], reason: '$id: the host counted what the phone sent');
      expect(run.inOrder[id], isTrue, reason: '$id: its inputs arrived in the order they were sent');
    }
    final sentTotal = run.sent.values.fold(0, (a, b) => a + b);
    final countedTotal = run.counted.values.fold(0, (a, b) => a + b);
    expect(countedTotal, sentTotal, reason: 'the host counted the sum of the phones\' inputsSent');
    if (_isLoad8) stdout.writeln(summaryLine(run));
  }, timeout: loadTimeout);

  test('the same seed gives the same input counts and the same inputs in two runs', () async {
    final first = await runLoad(seconds: plainRunS);
    final second = await runLoad(seconds: plainRunS);
    expect(second.sent, first.sent, reason: 'the same send counts');
    expect(second.counted, first.counted, reason: 'the same counts at the host');
    expect(second.signatures, first.signatures, reason: 'the same inputs, seed 17');
  }, timeout: loadTimeout);
}
