import 'dart:async';

import 'package:connection/connection.dart';
import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

import 'helpers.dart';
import 'wire_phone.dart';

/// A controller that shows the game (M12).
const _view = [Capability.view];

final _start = const ViewStartMessage(game: 'arena', snapshotVersion: 1, setup: {}, hz: 30);

/// Step [n] of a game, 33 ms after the one before.
FrameMessage _frame(int n) => FrameMessage(n: n, atMs: 1000 + n * 33, snapshot: {'v': 1, 't': n});

const _end = ViewEndMessage(reason: ViewEndReason.quit);

/// Every message that is part of a view, in the order [phone] got it.
List<Message> _views(WirePhone phone) => phone.fromHost
    .where(
      (m) =>
          m is ViewStartMessage ||
          m is FrameMessage ||
          m is ViewEndMessage ||
          m is HostAwayMessage ||
          m is HostBackMessage,
    )
    .toList();

/// Runs everything a running view sends: a start, a frame, the host going away
/// and back, and the end.
void _sendWholeView(ServerGameHost host) {
  host.startView(_start);
  host.publishFrame(_frame(0));
  host.hostAway(30);
  host.hostAway(null);
  host.endView(_end);
}

void main() {
  // The away messages need the view capability, like the other view messages.
  test('host_away and host_back need the view capability', () {
    expect(HostServer.capabilityFor(const HostAwayMessage(secondsLeft: 30)), Capability.view);
    expect(HostServer.capabilityFor(const HostBackMessage()), Capability.view);
  });

  for (final t in TestTransport.values) {
    group(t.name, () {
      test('during a view, hostAway(30) reaches a viewer as HostAway(30) and hostAway(null) as HostBack', () async {
        final server = await startHost(t);
        final host = ServerGameHost(server);
        addTearDown(host.dispose);
        final client = newClient(t, capabilities: _view);
        final events = <ViewEvent>[];
        final three = Completer<void>();
        final sub = client.view.listen((event) {
          events.add(event);
          if (events.length == 3 && !three.isCompleted) three.complete();
        });
        addTearDown(sub.cancel);
        client.connect(addressOf(server, t), code: server.pairingCode);
        await clientStatus(client, ClientStatus.connected);
        await hostUntil(server, (h) => h.connected.isNotEmpty);

        host.startView(_start);
        host.hostAway(30);
        host.hostAway(null);
        await three.future.timeout(const Duration(seconds: 5));

        expect(events[0], isA<ViewStarted>());
        final away = events[1] as HostAway;
        expect(away.secondsLeft, 30);
        expect(away.arrivedAtMs, isNonNegative, reason: 'this phone\'s clock when it handled the message');
        expect(events[2], isA<HostBack>());
        expect(events, hasLength(3), reason: 'and nothing else');
      });

      test('hostAway with no view running reaches a connected phone as HostAway(30) then HostBack', () async {
        final server = await startHost(t);
        final host = ServerGameHost(server);
        addTearDown(host.dispose);
        final viewer = await WirePhone.open(
          server,
          t,
          controllerId: 'phone-1',
          capabilities: _view,
          code: server.pairingCode,
        );

        host.hostAway(30);
        host.hostAway(null);
        await viewer.drain();

        final messages = _views(viewer);
        expect(messages.map((m) => m.type), [
          'host_away',
          'host_back',
        ], reason: 'the phone shows a host-away card without a view_start');
        expect((messages.first as HostAwayMessage).secondsLeft, 30);
      });

      test('a viewer that pairs while the host is away is told, with the time left', () async {
        final server = await startHost(t);
        final host = ServerGameHost(server);
        addTearDown(host.dispose);
        host.startView(_start);
        host.publishFrame(_frame(0));
        host.hostAway(30);

        final late = await WirePhone.open(
          server,
          t,
          controllerId: 'phone-1',
          capabilities: _view,
          code: server.pairingCode,
        );
        await late.drain();

        expect(_views(late).map((m) => m.type), ['view_start', 'frame', 'host_away']);
        expect(
          (_views(late).last as HostAwayMessage).secondsLeft,
          inInclusiveRange(29, 30),
          reason: 'the grace still to go: 30 s given, the pairing a moment later',
        );

        // The host is back: a viewer that pairs now hears nothing of its away.
        host.hostAway(null);
        final after = await WirePhone.open(
          server,
          t,
          controllerId: 'phone-2',
          capabilities: _view,
          code: server.pairingCode,
        );
        await after.drain();
        expect(_views(after).map((m) => m.type), ['view_start', 'frame'], reason: 'the host is here again');
      });

      test('a controller without view gets no away message while a viewer does', () async {
        final server = await startHost(t);
        final host = ServerGameHost(server);
        addTearDown(host.dispose);
        final viewer = await WirePhone.open(
          server,
          t,
          controllerId: 'phone-1',
          capabilities: _view,
          code: server.pairingCode,
        );
        final other = await WirePhone.open(
          server,
          t,
          controllerId: 'phone-2',
          capabilities: const [Capability.metrics],
          code: server.pairingCode,
        );

        _sendWholeView(host);
        await viewer.drain();
        await other.drain();
        expect(_views(viewer).map((m) => m.type), ['view_start', 'frame', 'host_away', 'host_back', 'view_end']);
        expect(_views(other), isEmpty);
      });

      test('with shareView false a viewer gets no game view, and true reaches it from the next view_start', () async {
        final server = await startHost(t);
        final host = ServerGameHost(server)..shareView = false;
        addTearDown(host.dispose);
        final viewer = await WirePhone.open(
          server,
          t,
          controllerId: 'phone-1',
          capabilities: _view,
          code: server.pairingCode,
        );

        expect(host.hasViewers, isFalse, reason: 'the host shares no game view with this phone');
        _sendWholeView(host);
        await viewer.drain();
        expect(_views(viewer).map((m) => m.type), [
          'host_away',
          'host_back',
        ], reason: 'no start, frame or end goes out; the host\'s own away is not part of the view');

        host.shareView = true;
        host.publishFrame(_frame(1));
        await viewer.drain();
        expect(_views(viewer).map((m) => m.type), [
          'host_away',
          'host_back',
        ], reason: 'a running view keeps the setting it began with');

        host.startView(_start);
        await viewer.drain();
        expect(_views(viewer).map((m) => m.type), [
          'host_away',
          'host_back',
          'view_start',
        ], reason: 'the change applies from the next start');
        expect(host.hasViewers, isTrue);
      });
    });
  }

  // No channel: the memory host keeps the calls for the test to check.
  test('the memory host records the hostAway calls', () {
    final host = MemoryGameHost();
    host.startView(_start);
    host.hostAway(30);
    host.hostAway(null);
    expect(host.hostAways, [30, null]);
  });
}
