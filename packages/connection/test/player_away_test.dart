import 'dart:async';

import 'package:connection/connection.dart';
import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

import 'helpers.dart';
import 'wire_phone.dart';

/// The grace the "kept" tests run with: long enough that a busy machine never
/// runs it out in the middle of one (m12 bug 1107d).
const _grace = Duration(seconds: 5);

final _start = ViewStartMessage(game: 'shape_race', snapshotVersion: 1, setup: const {}, hz: 60);

const _end = ViewEndMessage(reason: ViewEndReason.finished);

/// The host's players once [test] accepts them: them now, or the next list
/// the host reports (the stream is hot, so this listens before it changes).
Future<List<GamePlayer>> playersUntil(
  ServerGameHost host,
  bool Function(List<GamePlayer> players) test, {
  Duration timeout = const Duration(seconds: 5),
}) {
  if (test(host.players)) return Future.value(host.players);
  return host.playersChanged
      .firstWhere(test)
      .timeout(timeout, onTimeout: () => throw TimeoutException('Host stuck at ${host.players}'));
}

/// A paired phone, connected to [server] the way [t] does.
Future<ControllerClient> join(HostServer server, TestTransport t, ControllerClient client) async {
  client.connect(addressOf(server, t), code: server.pairingCode);
  await clientStatus(client, ClientStatus.connected);
  return client;
}

void main() {
  for (final t in TestTransport.values) {
    group(t.name, () {
      test('a player whose phone drops keeps their slot, away', () async {
        final server = await startHost(t);
        final host = ServerGameHost(server, awayGrace: _grace);
        addTearDown(host.dispose);
        host.startView(_start);
        final one = await join(server, t, newClient(t));
        await playersUntil(host, (p) => p.length == 1);

        one.disconnect();
        final away = await playersUntil(host, (p) => p.any((x) => x.away));

        expect(away, hasLength(1), reason: 'the round keeps the slot, and only the slot');
        final player = away.single;
        expect(player.id, 'phone-1');
        expect(player.number, 1, reason: 'the number stays with the player');
        expect(player.nickname, 'Phone phone-1');
        expect(player.away, isTrue);
        expect(player.local, isFalse);
        expect(host.gamepad('phone-1'), GamepadState.neutral, reason: 'a phone that is gone holds nothing down');
        expect(host.inputSeq('phone-1'), isNull);
        expect(host.inputArrivedAtMs('phone-1'), isNull);
      });

      test('the away slot keeps its number when another phone joins', () async {
        final server = await startHost(t);
        final host = ServerGameHost(server, awayGrace: _grace);
        addTearDown(host.dispose);
        host.startView(_start);
        final one = await join(server, t, newClient(t));
        await playersUntil(host, (p) => p.length == 1);

        one.disconnect();
        await playersUntil(host, (p) => p.any((x) => x.away));
        await join(server, t, newClient(t, id: 'phone-2'));
        final players = await playersUntil(host, (p) => p.length == 2);

        expect({for (final p in players) p.id: (p.number, p.away)}, {'phone-1': (1, true), 'phone-2': (2, false)});
      });

      test('the slot ends when the grace is over', () async {
        final server = await startHost(t);
        final host = ServerGameHost(server, awayGrace: const Duration(seconds: 1));
        addTearDown(host.dispose);
        host.startView(_start);
        final one = await join(server, t, newClient(t));
        await playersUntil(host, (p) => p.length == 1);

        one.disconnect();
        await playersUntil(host, (p) => p.any((x) => x.away));
        final players = await playersUntil(host, (p) => p.isEmpty);

        expect(players, isEmpty, reason: 'the round went on without them after 1 s');
      });

      test('goOnWithout ends an away player\'s slot at once', () async {
        final server = await startHost(t);
        final host = ServerGameHost(server, awayGrace: _grace);
        addTearDown(host.dispose);
        host.startView(_start);
        final one = await join(server, t, newClient(t));
        await playersUntil(host, (p) => p.length == 1);

        one.disconnect();
        await playersUntil(host, (p) => p.any((x) => x.away));
        host.goOnWithout('phone-1');

        expect(host.players, isEmpty, reason: 'no wait for the timer');
        expect(await playersUntil(host, (p) => p.isEmpty), isEmpty, reason: 'and the listeners are told');
      });

      test('goOnWithout for a player who is here does nothing', () async {
        final server = await startHost(t);
        final host = ServerGameHost(server, awayGrace: _grace);
        addTearDown(host.dispose);
        host.startView(_start);
        await join(server, t, newClient(t));
        await playersUntil(host, (p) => p.length == 1);

        host.goOnWithout('phone-1');

        expect(host.players.map((p) => p.id), ['phone-1']);
      });

      test('a phone that comes back within the grace is not away', () async {
        final server = await startHost(t);
        final host = ServerGameHost(server, awayGrace: _grace);
        addTearDown(host.dispose);
        host.startView(_start);
        final one = await join(server, t, newClient(t));
        await playersUntil(host, (p) => p.length == 1);

        one.disconnect();
        await playersUntil(host, (p) => p.any((x) => x.away));
        await join(server, t, one);
        final players = await playersUntil(host, (p) => p.length == 1 && !p.single.away);

        expect(players.single.number, 1, reason: 'it gets its own number back');
      });

      test('a phone that comes back gets its game layout again', () async {
        bool snapped(GameLayoutMessage m) => m.labels[ControllerButton.a] == 'Snap';
        final server = await startHost(t);
        final host = ServerGameHost(server, awayGrace: _grace);
        addTearDown(host.dispose);
        host.startView(_start);
        final one = await join(server, t, newClient(t, capabilities: const [Capability.layout]));
        await playersUntil(host, (p) => p.length == 1);
        host.setLayout('phone-1', GameLayoutMessage(labels: {ControllerButton.a: 'Snap'}));
        await one.layouts.firstWhere(snapped).timeout(const Duration(seconds: 5));

        one.disconnect();
        await playersUntil(host, (p) => p.any((x) => x.away));
        expect(one.layout.isStandard, isTrue, reason: 'the phone forgot it when the connection ended');

        final again = one.layouts.firstWhere(snapped);
        await join(server, t, one);
        await again.timeout(const Duration(seconds: 5));
        expect(one.layout.labels, {ControllerButton.a: 'Snap'}, reason: 'the host sends it again to a kept slot');
      });

      test('a simulated controller that goes leaves at once', () async {
        final server = await startHost(t);
        final host = ServerGameHost(server);
        addTearDown(host.dispose);
        host.startView(_start);
        await WirePhone.open(server, t, controllerId: 'sim-1', platform: 'sim', code: server.pairingCode);
        await playersUntil(host, (p) => p.length == 1);
        expect(host.players.single.simulated, isTrue);

        server.dropAllConnections();
        await hostUntil(server, (h) => h.connected.isEmpty);

        expect(host.players, isEmpty, reason: 'the round never waits for a simulated controller');
      });

      test('every away slot ends when the round is over', () async {
        final server = await startHost(t);
        final host = ServerGameHost(server, awayGrace: _grace);
        addTearDown(host.dispose);
        host.startView(_start);
        final one = await join(server, t, newClient(t));
        await playersUntil(host, (p) => p.length == 1);
        host.startView(_start);

        one.disconnect();
        await playersUntil(host, (p) => p.any((x) => x.away));
        host.endView(_end);

        expect(host.players, isEmpty, reason: 'a rematch never waits for someone who left');
      });

      test('a phone that drops with no round running leaves at once', () async {
        final server = await startHost(t);
        final host = ServerGameHost(server, awayGrace: _grace);
        addTearDown(host.dispose);
        final one = await join(server, t, newClient(t));
        await playersUntil(host, (p) => p.length == 1);

        one.disconnect();
        final players = await playersUntil(host, (p) => p.isEmpty);

        expect(players, isEmpty, reason: 'on the picker nobody waits, so the next round never starts paused');
      });

      test('dispose cancels the away timers', () async {
        final server = await startHost(t);
        final grace = const Duration(milliseconds: 500);
        final timers = <Timer>[];
        ServerGameHost? host;
        final zone = ZoneSpecification(
          createTimer: (self, parent, zone, duration, f) {
            final timer = parent.createTimer(zone, duration, f);
            if (duration == grace) timers.add(timer);
            return timer;
          },
        );
        await runZoned(() async {
          host = ServerGameHost(server, awayGrace: grace)..startView(_start);
          final one = await join(server, t, newClient(t));
          await playersUntil(host!, (p) => p.length == 1);
          one.disconnect();
          await playersUntil(host!, (p) => p.any((x) => x.away));
        }, zoneSpecification: zone);

        expect(timers, hasLength(1), reason: 'one timer for the one away player');
        expect(timers.single.isActive, isTrue, reason: 'the grace is running');
        await host!.dispose();
        expect(timers.single.isActive, isFalse, reason: 'dispose stops the grace');
      });
    });
  }

  // No channel: the memory host drops the player the round goes on without.
  test('the memory host drops the away player when the round goes on', () {
    final host = MemoryGameHost();
    host.setPlayer(const GamePlayer(id: 'p1', number: 1, away: true));
    host.setPlayer(const GamePlayer(id: 'p2', number: 2));

    host.goOnWithout('p1');

    expect(host.goOnWithouts, ['p1']);
    expect(host.players.map((p) => p.id), ['p2']);
    host.goOnWithout('p2');
    expect(host.players.map((p) => p.id), ['p2'], reason: 'a player who is here stays');
  });
}
