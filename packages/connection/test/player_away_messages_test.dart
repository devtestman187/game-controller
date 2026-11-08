import 'dart:async';
import 'dart:convert';

import 'package:connection/connection.dart';
import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

import 'fake_host.dart';
import 'helpers.dart';
import 'wire_phone.dart';

/// A controller that shows the game (M12).
const _view = [Capability.view];

final _start = ViewStartMessage(game: 'arena', snapshotVersion: 1, setup: const {}, hz: 30);

/// Step [n] of a game, 33 ms after the one before.
FrameMessage _frame(int n) => FrameMessage(n: n, atMs: 1000 + n * 33, snapshot: {'v': 1, 't': n});

const _end = ViewEndMessage(reason: ViewEndReason.finished);

/// The grace the "kept" tests run with: long enough for the seconds left to be
/// a whole 10 whenever the message is built (m12 bug 1107d).
const _grace = Duration(seconds: 10);

/// The messages a viewer hears about the away players, in the order it got
/// them.
List<Message> _awayMessages(WirePhone phone) =>
    phone.fromHost.where((m) => m is PlayerAwayMessage || m is PlayerBackMessage).toList();

/// Every message of a view, in the order it came: the start, the frames, the
/// away players and the end.
List<Message> _viewMessages(WirePhone phone) => phone.fromHost
    .where(
      (m) =>
          m is ViewStartMessage ||
          m is FrameMessage ||
          m is ViewEndMessage ||
          m is PlayerAwayMessage ||
          m is PlayerBackMessage,
    )
    .toList();

/// A paired phone, connected to [server] the way [t] does.
Future<ControllerClient> join(HostServer server, TestTransport t, ControllerClient client) async {
  client.connect(addressOf(server, t), code: server.pairingCode);
  await clientStatus(client, ClientStatus.connected);
  return client;
}

/// A viewer that watches a running view, and a controller that shows nothing:
/// the two phones every test here drops and brings back.
Future<({WirePhone viewer, ControllerClient phone})> _twoPhones(
  HostServer server,
  TestTransport t,
  ServerGameHost host,
) async {
  final viewer = await WirePhone.open(server, t, controllerId: 'viewer', capabilities: _view, code: server.pairingCode);
  final phone = await join(server, t, newClient(t));
  host.startView(_start);
  await hostUntil(server, (h) => h.connected.length == 2);
  return (viewer: viewer, phone: phone);
}

void main() {
  // The away messages need the view capability, like the other view messages.
  test('player_away and player_back need the view capability', () {
    expect(
      HostServer.capabilityFor(const PlayerAwayMessage(playerId: 'p2', number: 2, secondsLeft: 30)),
      Capability.view,
    );
    expect(HostServer.capabilityFor(const PlayerBackMessage(playerId: 'p2')), Capability.view);
  });

  for (final t in TestTransport.values) {
    group(t.name, () {
      test('a drop and a return send player_away and player_back, in order, with the seconds left', () async {
        final server = await startHost(t);
        final host = ServerGameHost(server, awayGrace: _grace);
        addTearDown(host.dispose);
        final (:viewer, :phone) = await _twoPhones(server, t, host);

        phone.disconnect();
        await playersUntil(host, (p) => p.any((x) => x.away));
        await viewer.drain();

        final away = _awayMessages(viewer).single as PlayerAwayMessage;
        expect(away.playerId, 'phone-1');
        expect(away.number, 2, reason: 'the viewer paired first, so phone-1 is player 2');
        expect(away.secondsLeft, 10, reason: 'the whole grace: the message is built when the slot is held');

        await join(server, t, phone);
        await playersUntil(host, (p) => p.every((x) => !x.away));
        await viewer.drain();

        final back = _awayMessages(viewer).last as PlayerBackMessage;
        expect(_awayMessages(viewer).map((m) => m.type), ['player_away', 'player_back'], reason: 'in that order');
        expect(back.playerId, 'phone-1');
      });

      test('a viewer that pairs mid-away gets view_start, the latest frame and then player_away', () async {
        final server = await startHost(t);
        final host = ServerGameHost(server);
        addTearDown(host.dispose);
        final phone = await join(server, t, newClient(t));
        host.startView(_start);
        host.publishFrame(_frame(0));

        phone.disconnect();
        await playersUntil(host, (p) => p.any((x) => x.away));

        final late = await WirePhone.open(
          server,
          t,
          controllerId: 'viewer',
          capabilities: _view,
          code: server.pairingCode,
        );
        await late.drain();

        expect(_viewMessages(late).map((m) => m.type), ['view_start', 'frame', 'player_away']);
        final away = _viewMessages(late).last as PlayerAwayMessage;
        expect(away.playerId, 'phone-1');
        expect(away.number, 1);
        expect(
          away.secondsLeft,
          inInclusiveRange(1, ServerGameHost.hostGraceS),
          reason: 'the grace, or a second less by now: the default is 30 s',
        );
      });

      test('the phone that comes back hears no player_back for itself', () async {
        final server = await startHost(t);
        final host = ServerGameHost(server, awayGrace: _grace);
        addTearDown(host.dispose);
        final viewer = await WirePhone.open(
          server,
          t,
          controllerId: 'viewer',
          capabilities: _view,
          code: server.pairingCode,
        );
        final phone = await join(server, t, newClient(t, capabilities: _view));
        host.startView(_start);
        await hostUntil(server, (h) => h.connected.length == 2);
        final events = <ViewEvent>[];
        final sub = phone.view.listen(events.add);
        addTearDown(sub.cancel);

        phone.disconnect();
        await playersUntil(host, (p) => p.any((x) => x.away));
        final started = phone.view.where((e) => e is ViewStarted).first;
        await join(server, t, phone);
        await started.timeout(const Duration(seconds: 5));
        await playersUntil(host, (p) => p.every((x) => !x.away));
        await viewer.drain();

        expect(events.whereType<PlayerBack>(), isEmpty, reason: 'it never showed a card for its own player');
        expect(events.whereType<PlayerAway>(), isEmpty, reason: 'the away message came while it was gone');
        expect(_awayMessages(viewer).map((m) => m.type), ['player_away', 'player_back']);
      });

      test('the grace running out sends player_back', () async {
        final server = await startHost(t);
        final host = ServerGameHost(server, awayGrace: const Duration(seconds: 1));
        addTearDown(host.dispose);
        final (:viewer, :phone) = await _twoPhones(server, t, host);

        phone.disconnect();
        await playersUntil(host, (p) => p.any((x) => x.away));
        await playersUntil(host, (p) => p.every((x) => !x.away));
        await viewer.drain();

        final back = _awayMessages(viewer).last as PlayerBackMessage;
        expect(_awayMessages(viewer).map((m) => m.type), ['player_away', 'player_back']);
        expect(back.playerId, 'phone-1', reason: 'the round goes on without them');
      });

      test('goOnWithout sends player_back at once', () async {
        final server = await startHost(t);
        final host = ServerGameHost(server, awayGrace: _grace);
        addTearDown(host.dispose);
        final (:viewer, :phone) = await _twoPhones(server, t, host);

        phone.disconnect();
        await playersUntil(host, (p) => p.any((x) => x.away));
        host.goOnWithout('phone-1');
        await viewer.drain();

        expect(_awayMessages(viewer).map((m) => m.type), ['player_away', 'player_back']);
      });

      test('the round ending takes the slot without a player_back', () async {
        final server = await startHost(t);
        final host = ServerGameHost(server, awayGrace: _grace);
        addTearDown(host.dispose);
        final (:viewer, :phone) = await _twoPhones(server, t, host);

        phone.disconnect();
        await playersUntil(host, (p) => p.any((x) => x.away));
        host.endView(_end);
        await viewer.drain();

        expect(_viewMessages(viewer).map((m) => m.type), ['view_start', 'player_away', 'view_end']);
      });

      test('a controller without view gets neither message', () async {
        final server = await startHost(t);
        final host = ServerGameHost(server, awayGrace: _grace);
        addTearDown(host.dispose);
        final (:viewer, :phone) = await _twoPhones(server, t, host);
        final other = await WirePhone.open(server, t, controllerId: 'other', code: server.pairingCode);

        phone.disconnect();
        await playersUntil(host, (p) => p.any((x) => x.away));
        await other.drain();
        await viewer.drain();
        expect(_awayMessages(viewer), hasLength(1), reason: 'the view was really on');
        expect(_awayMessages(other), isEmpty);
      });

      test('a host that shows the game on its own screen sends neither message', () async {
        final server = await startHost(t);
        final host = ServerGameHost(server, awayGrace: _grace)..shareView = false;
        addTearDown(host.dispose);
        final watcher = await WirePhone.open(
          server,
          t,
          controllerId: 'watcher',
          capabilities: _view,
          code: server.pairingCode,
        );
        final phone = await join(server, t, newClient(t));
        host.startView(_start);

        phone.disconnect();
        await playersUntil(host, (p) => p.any((x) => x.away));
        await watcher.drain();
        expect(_awayMessages(watcher), isEmpty, reason: 'a view that is not shared is no view');
      });

      test('the phone hears PlayerAway with the number and seconds, then PlayerBack', () async {
        final server = await startHost(t);
        final host = ServerGameHost(server, awayGrace: _grace);
        addTearDown(host.dispose);
        final watcher = await join(server, t, newClient(t, id: 'watcher', capabilities: _view));
        final phone = await join(server, t, newClient(t));
        host.startView(_start);
        await hostUntil(server, (h) => h.connected.length == 2);

        final away = watcher.view.where((e) => e is PlayerAway).cast<PlayerAway>().first;
        phone.disconnect();
        final event = await away.timeout(const Duration(seconds: 5));
        expect(event.playerId, 'phone-1');
        expect(event.number, 2, reason: 'the watcher paired first, so phone-1 is player 2');
        expect(event.secondsLeft, 10);
        expect(event.arrivedAtMs, isNonNegative, reason: 'this phone\'s clock when it handled the message');

        final back = watcher.view.where((e) => e is PlayerBack).cast<PlayerBack>().first;
        await join(server, t, phone);
        expect((await back.timeout(const Duration(seconds: 5))).playerId, 'phone-1');
      });

      test('a message type this app version does not know is dropped, not a protocol error', () async {
        // A 0.12.0 phone has no decoder for player_away: it reads the frame as
        // an unknown type, which the codec drops (codec.dart) and the client
        // ignores (client_messages.dart), rather than closing with 4003.
        final host = await FakeHost.start(t);
        const codec = MessageCodec();
        final sent = Completer<void>();
        host.onChannel = (channel) => channel.incoming.listen((data) {
          final m = codec.decode(data);
          if (m is HelloMessage) {
            channel.send(codec.encode(const WelcomeMessage(hostId: 'h', hostName: 'New TV', appVersion: 't')));
          } else if (m is PairRequestMessage) {
            channel.send(codec.encode(const PairResultMessage.accepted(token: 'tok')));
            channel.send(jsonEncode({'v': protocolVersion, 't': 'player_hidden', 'player': 'p2'}));
            if (!sent.isCompleted) sent.complete();
          } else if (m is PingMessage) {
            channel.send(codec.encode(PongMessage.answering(m)));
          }
        });
        final client = newClient(t, capabilities: _view, connector: host);
        final events = <ViewEvent>[];
        final sub = client.view.listen(events.add);
        addTearDown(sub.cancel);
        client.connect(host.address, code: '1234');
        await clientStatus(client, ClientStatus.connected);
        await sent.future.timeout(const Duration(seconds: 5));
        // A pong after it: everything the TV sent before is handled by then.
        await clientUntil(client, (s) => (s.rttStats?.samples ?? 0) >= 1);

        expect(events, isEmpty);
        expect(client.snapshot.status, ClientStatus.connected, reason: 'dropped, not a protocol error');
      });
    });
  }
}
