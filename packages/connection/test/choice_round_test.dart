import 'dart:async';

import 'package:connection/connection.dart';
import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

import 'helpers.dart';
import 'wire_phone.dart';

const _cards = [
  ChoiceCard(id: 'save', title: 'Save +2'),
  ChoiceCard(id: 'build', title: 'Build', cost: 3, maxCount: 3),
  ChoiceCard(id: 'locked', title: 'Locked', enabled: false),
];

/// The grace time the away tests use, in ms.
const _graceMs = 200;

/// A round that lasts long enough for a test to close it by hand.
const _longRound = Duration(seconds: 30);

/// The fake clock's start and the time left a resend shows after [_clockStepMs].
const _clockStepMs = 4000;

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

Future<_Setup> _setup(
  TestTransport t, {
  String? defaultId = 'save',
  Duration duration = _longRound,
  bool start = true,
}) async {
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
    round: 7,
    title: 'Shop',
    cardsFor: (_) => _cards,
    players: const ['phone-1', 'phone-2'],
    duration: duration,
    grace: const Duration(milliseconds: _graceMs),
    defaultId: defaultId,
    currency: 'Bolts',
    nowMs: () => clock.ms,
  );
  addTearDown(round.dispose);
  if (start) round.start();
  await capable.drain();
  await old.drain();
  return _Setup(server, capable, old, round, clock);
}

/// Waits until the round has set the away first phone to the default.
Future<void> _untilLocked(ChoiceRound round) async {
  if (round.lockedIds.contains('phone-1')) return;
  await round.changes.firstWhere((_) => round.lockedIds.contains('phone-1')).timeout(const Duration(seconds: 5));
}

void main() {
  for (final t in TestTransport.values) {
    group(t.name, () {
      test('start sends the round only to the phone that lists the choices capability', () async {
        final s = await _setup(t);

        final sent = s.capable.fromHost.whereType<ChoicesMessage>().toList();
        expect(sent, hasLength(1));
        expect(sent.single.round, 7);
        expect(sent.single.cards, _cards);
        expect(sent.single.defaultId, 'save');
        expect(sent.single.currency, 'Bolts');
        expect(sent.single.endsInMs, _longRound.inMilliseconds);
        expect(s.old.fromHost.whereType<ChoicesMessage>(), isEmpty);
      });

      test('a pick, a lock and an undo leave the last pick at close', () async {
        final s = await _setup(t);

        s.capable.send(const ChoicePickMessage(round: 7, pick: 'build', count: 2));
        s.capable.send(const ChoicePickMessage(round: 7, pick: 'build', count: 2, locked: true));
        await s.capable.drain();
        expect(s.round.lockedIds, {'phone-1'});
        s.capable.send(const ChoicePickMessage(round: 7, pick: 'save'));
        await s.capable.drain();
        expect(s.round.lockedIds, isEmpty);

        final out = s.round.close();

        expect(out['phone-1'], const ChoiceOutcome(cardId: 'save', count: 1, byDefault: false));
      });

      test('a pick cleared with a null pick falls back to the default', () async {
        final s = await _setup(t);

        s.capable.send(const ChoicePickMessage(round: 7, pick: 'build'));
        s.capable.send(const ChoicePickMessage(round: 7));
        await s.capable.drain();

        expect(s.round.close()['phone-1'], const ChoiceOutcome(cardId: 'save', count: 1, byDefault: true));
      });

      test('nothing chosen gets the default, and a null default gets no card', () async {
        final withDefault = await _setup(t);
        expect(withDefault.round.close()['phone-1'], const ChoiceOutcome(cardId: 'save', count: 1, byDefault: true));

        final abstain = await _setup(t, defaultId: null);
        expect(abstain.round.close()['phone-1'], const ChoiceOutcome(cardId: null, count: 0, byDefault: true));
      });

      test(
        'a pick for a disabled or unknown card, another round, or from a phone without the cap is ignored',
        () async {
          final s = await _setup(t);

          s.capable.send(const ChoicePickMessage(round: 7, pick: 'locked'));
          s.capable.send(const ChoicePickMessage(round: 7, pick: 'nope'));
          s.capable.send(const ChoicePickMessage(round: 8, pick: 'build'));
          s.old.send(const ChoicePickMessage(round: 7, pick: 'build'));
          await s.capable.drain();
          await s.old.drain();
          s.round.pick('stranger', pickId: 'build');

          final out = s.round.close();
          expect(out['phone-1'], const ChoiceOutcome(cardId: 'save', count: 1, byDefault: true));
          expect(out['phone-2'], const ChoiceOutcome(cardId: 'save', count: 1, byDefault: true));
          expect(out, hasLength(2));
        },
      );

      test('the count is held between 1 and the card maxCount', () async {
        final s = await _setup(t);

        s.round.pick('phone-1', pickId: 'build', count: 9);
        expect(s.round.close()['phone-1']?.count, 3);

        final low = await _setup(t);
        low.round.pick('phone-1', pickId: 'build', count: 0);
        expect(low.round.close()['phone-1']?.count, 1);
      });

      test('a reconnect resends the pick and lock with the time left', () async {
        final s = await _setup(t);
        s.capable.send(const ChoicePickMessage(round: 7, pick: 'build', count: 2, locked: true));
        await s.capable.drain();
        s.clock.ms = _clockStepMs;

        s.server.dropAllConnections();
        await hostUntil(s.server, (h) => stateOf(h, 'phone-1') == ControllerState.disconnected);
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
        expect(resent.picked, 'build');
        expect(resent.pickedCount, 2);
        expect(resent.locked, isTrue);
        expect(resent.endsInMs, _longRound.inMilliseconds - _clockStepMs);
      });

      test('a player away for the grace time gets the default by default, until a pick changes it', () async {
        final s = await _setup(t);
        s.capable.send(const ChoicePickMessage(round: 7, pick: 'build'));
        await s.capable.drain();

        s.server.dropAllConnections();
        await _untilLocked(s.round);

        expect(s.round.lockedIds, contains('phone-1'));
        s.round.pick('phone-1', pickId: 'build', count: 2);
        expect(s.round.close()['phone-1'], const ChoiceOutcome(cardId: 'build', count: 2, byDefault: false));
      });

      test('a player away at close time with no pick change gets byDefault true', () async {
        final s = await _setup(t);
        s.capable.send(const ChoicePickMessage(round: 7, pick: 'build'));
        await s.capable.drain();
        s.server.dropAllConnections();
        await _untilLocked(s.round);

        expect(s.round.close()['phone-1'], const ChoiceOutcome(cardId: 'save', count: 1, byDefault: true));
      });

      test('close is idempotent and sends the end once; the old phone gets an outcome too', () async {
        final s = await _setup(t);
        s.round.pick('phone-2', pickId: 'build', count: 2);

        final first = s.round.close();
        final second = s.round.close();
        await s.capable.drain();
        await s.old.drain();

        expect(second, same(first));
        final ends = s.capable.fromHost.whereType<ChoicesEndMessage>().toList();
        expect(ends, hasLength(1));
        expect(ends.single.result, 'save');
        expect(ends.single.byDefault, isTrue);
        expect(s.old.fromHost.whereType<ChoicesEndMessage>(), isEmpty);
        expect(first['phone-2'], const ChoiceOutcome(cardId: 'build', count: 2, byDefault: false));
        s.round.pick('phone-1', pickId: 'build');
        expect(s.round.outcomes['phone-1']?.cardId, 'save');
      });

      test('the timer ends the round', () async {
        final s = await _setup(t, duration: const Duration(milliseconds: 100));

        await s.round.changes.first.timeout(const Duration(seconds: 5));

        expect(s.round.isClosed, isTrue);
        await s.capable.drain();
        expect(s.capable.fromHost.whereType<ChoicesEndMessage>(), hasLength(1));
      });
    });
  }
}
