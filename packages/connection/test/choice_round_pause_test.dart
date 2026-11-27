import 'dart:async';

import 'package:connection/connection.dart';
import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

import 'helpers.dart';
import 'wire_phone.dart';

const _cards = [
  ChoiceCard(id: 'save', title: 'Save +2'),
  ChoiceCard(id: 'build', title: 'Build', cost: 3, maxCount: 3),
];

/// The grace time the away tests use, in ms.
const _graceMs = 300;

/// A round that lasts long enough for a test to close it by hand.
const _longRound = Duration(seconds: 30);

/// The fake-clock reading a test pauses at; the time left is the round's length minus this.
const _pauseAtMs = 4000;

/// A round the end timer would end during a test if the pause did not freeze it.
const _shortRound = Duration(milliseconds: 300);

/// A round long enough that ending after the time left, not the full length, is told apart in real time.
const _midRound = Duration(seconds: 3);

/// The time left of [_midRound] when a test pauses it, in ms.
const _midLeftMs = 300;

/// How long a test waits past a round's original end, so an end timer left running would have fired.
const _pastEnd = Duration(milliseconds: 700);

/// A wait shorter than the grace time, in which no away timer may have fired.
const _insideGrace = Duration(milliseconds: 100);

/// The time a test allows the round to end after resume, well under [_midRound].
const _wellBeforeFullLength = Duration(milliseconds: 1500);

/// The most time a test waits for the round to reach a state, so a stuck test fails.
const _waitLimit = Duration(seconds: 5);

final class _Setup {
  _Setup(this.server, this.capable, this.old, this.round, this.clock);

  final HostServer server;
  final WirePhone capable;
  final WirePhone old;
  final ChoiceRound round;
  final _Clock clock;
}

final class _Clock {
  int ms = 0;
}

Future<_Setup> _setup(TestTransport t, {Duration duration = _longRound, bool start = true}) async {
  final server = await startHost(t);
  final capable = await WirePhone.open(
    server,
    t,
    controllerId: 'phone-1',
    capabilities: const [Capability.choices],
    code: server.pairingCode,
  );
  final old = await WirePhone.open(server, t, controllerId: 'phone-2', code: server.pairingCode);
  final clock = _Clock();
  final round = ChoiceRound(
    server: server,
    players: const ['phone-1', 'phone-2'],
    setup: ChoiceRoundSetup(round: 7, title: 'Shop', cardsFor: (_) => _cards, defaultId: 'save', currency: 'Bolts'),
    timing: ChoiceTiming(
      duration: duration,
      grace: const Duration(milliseconds: _graceMs),
      nowMs: () => clock.ms,
    ),
  );
  addTearDown(round.dispose);
  await capable.drain();
  await old.drain();
  if (start) round.start();
  await capable.drain();
  await old.drain();
  return _Setup(server, capable, old, round, clock);
}

Future<void> _untilLocked(ChoiceRound round) async {
  if (round.lockedIds.contains('phone-1')) return;
  await round.changes.firstWhere((_) => round.lockedIds.contains('phone-1')).timeout(_waitLimit);
}

Future<void> _untilClosed(ChoiceRound round) async {
  if (round.isClosed) return;
  await round.changes.firstWhere((_) => round.isClosed).timeout(_waitLimit);
}

Future<void> _dropPhones(_Setup s) async {
  s.server.dropAllConnections();
  await hostUntil(s.server, (h) => stateOf(h, 'phone-1') == ControllerState.disconnected);
}

void main() {
  for (final t in TestTransport.values) {
    group(t.name, () {
      test('a paused round does not end at its original end time and stays open', () async {
        final s = await _setup(t, duration: _shortRound);
        s.clock.ms = 100;

        s.round.pause();
        await Future<void>.delayed(_pastEnd);

        expect(s.round.isPaused, isTrue);
        expect(s.round.isClosed, isFalse);
      });

      test('resume ends the round after about the time left, not the full length', () async {
        final s = await _setup(t, duration: _midRound);
        s.clock.ms = _midRound.inMilliseconds - _midLeftMs;
        s.round.pause();
        await Future<void>.delayed(_insideGrace);
        final watch = Stopwatch()..start();

        s.round.resume();
        expect(s.round.isPaused, isFalse);
        await Future<void>.delayed(_insideGrace ~/ 2);
        expect(s.round.isClosed, isFalse);
        await _untilClosed(s.round);

        expect(watch.elapsed, lessThan(_wellBeforeFullLength));
      });

      test('a pick made before and during the pause is kept', () async {
        final s = await _setup(t);
        s.round.pick('phone-1', pickId: 'build', count: 2);

        s.round.pause();
        s.round.pick('phone-2', pickId: 'build', count: 3);
        final out = s.round.close();

        expect(out['phone-1'], const ChoiceOutcome(cardId: 'build', count: 2, byDefault: false));
        expect(out['phone-2'], const ChoiceOutcome(cardId: 'build', count: 3, byDefault: false));
      });

      test('a player who drops during the pause is not defaulted, and only after a full grace after resume', () async {
        final s = await _setup(t);
        s.round.pause();

        await _dropPhones(s);
        await Future<void>.delayed(_pastEnd);
        expect(s.round.lockedIds, isEmpty);

        s.round.resume();
        await Future<void>.delayed(_insideGrace);
        expect(s.round.lockedIds, isEmpty);
        final watch = Stopwatch()..start();
        await _untilLocked(s.round);

        expect(watch.elapsedMilliseconds, greaterThan(_graceMs - _insideGrace.inMilliseconds * 2));
        expect(s.round.close()['phone-1'], const ChoiceOutcome(cardId: 'save', count: 1, byDefault: true));
      });

      test('a player already away when the pause starts is not defaulted during the pause', () async {
        final s = await _setup(t);
        await _dropPhones(s);
        // The round has no signal for a drop, so wait less than the grace: the drop is seen well inside it,
        // and the grace has not run out before the pause.
        await Future<void>.delayed(_insideGrace);

        s.round.pause();
        await Future<void>.delayed(_pastEnd);

        expect(s.round.lockedIds, isEmpty);
      });

      test('a player already set to the default before the pause keeps it after resume', () async {
        final s = await _setup(t);
        await _dropPhones(s);
        await _untilLocked(s.round);

        s.round.pause();
        s.round.resume();
        await Future<void>.delayed(_pastEnd);

        expect(s.round.lockedIds, contains('phone-1'));
        expect(s.round.close()['phone-1'], const ChoiceOutcome(cardId: 'save', count: 1, byDefault: true));
      });

      test('a host pick made during the pause survives resume', () async {
        final s = await _setup(t);
        s.round.pause();
        s.round.pick('phone-2', pickId: 'build', count: 3);

        s.round.resume();
        await Future<void>.delayed(_pastEnd);

        expect(s.round.close()['phone-2'], const ChoiceOutcome(cardId: 'build', count: 3, byDefault: false));
      });

      test('the paused and resumed states reach the capable phone with the frozen time left', () async {
        final s = await _setup(t);
        s.clock.ms = _pauseAtMs;
        final leftMs = _longRound.inMilliseconds - _pauseAtMs;

        s.round.pause();
        s.clock.ms = _pauseAtMs * 2;
        s.round.resume();
        await s.capable.drain();
        await s.old.drain();

        final states = s.capable.fromHost.whereType<ChoicesMessage>().toList();
        expect(states.map((m) => m.paused), [false, true, false]);
        expect(states[1].endsInMs, leftMs);
        expect(states[2].endsInMs, leftMs);
        expect(s.old.fromHost.whereType<ChoicesMessage>(), isEmpty);
      });

      test('a reconnect during a pause is sent paused true with the frozen time left', () async {
        final s = await _setup(t);
        s.clock.ms = _pauseAtMs;
        s.round.pause();
        await _dropPhones(s);
        s.clock.ms = _pauseAtMs * 2;

        final back = await WirePhone.open(
          s.server,
          t,
          controllerId: 'phone-1',
          capabilities: const [Capability.choices],
          code: s.server.pairingCode,
        );
        await hostUntil(s.server, (h) => stateOf(h, 'phone-1') == ControllerState.connected);
        await back.drain();

        final resent = back.fromHost.whereType<ChoicesMessage>().single;
        expect(resent.paused, isTrue);
        expect(resent.endsInMs, _longRound.inMilliseconds - _pauseAtMs);
      });

      test('close while paused returns the picks and defaults and sends the end once', () async {
        final s = await _setup(t);
        s.round.pick('phone-2', pickId: 'build', count: 2);
        s.round.pause();

        final out = s.round.close();
        s.round.close();
        await s.capable.drain();

        expect(s.round.isPaused, isFalse);
        expect(out['phone-1'], const ChoiceOutcome(cardId: 'save', count: 1, byDefault: true));
        expect(out['phone-2'], const ChoiceOutcome(cardId: 'build', count: 2, byDefault: false));
        expect(s.capable.fromHost.whereType<ChoicesEndMessage>(), hasLength(1));
      });

      test('pause before start, after close and twice do nothing', () async {
        final s = await _setup(t, start: false);
        s.round.pause();
        expect(s.round.isPaused, isFalse);
        s.round.resume();
        s.round.start();
        await s.capable.drain();
        expect(s.round.isPaused, isFalse);

        s.round.pause();
        s.round.pause();
        await s.capable.drain();
        expect(s.capable.fromHost.whereType<ChoicesMessage>().map((m) => m.paused), [false, true]);

        s.round.close();
        s.round.pause();
        s.round.resume();
        await s.capable.drain();
        expect(s.round.isPaused, isFalse);
        expect(s.capable.fromHost.whereType<ChoicesMessage>(), hasLength(2));
        expect(s.capable.fromHost.whereType<ChoicesEndMessage>(), hasLength(1));
      });
    });
  }
}
