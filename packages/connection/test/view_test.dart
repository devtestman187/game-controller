import 'dart:async';

import 'package:connection/connection.dart';
import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

import 'fake_host.dart';
import 'helpers.dart';
import 'wire_phone.dart';

/// A controller that shows the game (M12).
const _view = [Capability.view];

final _start = ViewStartMessage(
  game: 'shape_race',
  snapshotVersion: 1,
  setup: {'puzzle': 'boat', 'level': 2, 'timeLimitS': 120, 'teams': true},
  hz: 60,
);

/// Step [n] of a game: at 672 + 16n ms on the host, one sound in the first.
FrameMessage _frame(int n) => FrameMessage(
  n: n,
  atMs: 672 + n * 16,
  snapshot: {'v': 1, 't': 16000 + n * 16},
  sounds: n == 0 ? const ['snap'] : const [],
  acks: {'phone-1': n},
  roster: {'phone-1': (number: 1, name: 'Ada')},
);

const _end = ViewEndMessage(reason: ViewEndReason.finished);

/// The view messages [phone] got, in the order the host sent them.
List<Message> _views(WirePhone phone) =>
    phone.fromHost.where((m) => m is ViewStartMessage || m is FrameMessage || m is ViewEndMessage).toList();

void main() {
  // The three view messages need the view capability, like layout and status.
  test('the view messages need the view capability', () {
    expect(HostServer.capabilityFor(_start), Capability.view);
    expect(HostServer.capabilityFor(_frame(0)), Capability.view);
    expect(HostServer.capabilityFor(_end), Capability.view);
  });

  for (final t in TestTransport.values) {
    group(t.name, () {
      test('a controller that did not list view gets none of the view messages', () async {
        final server = await startHost(t);
        final host = ServerGameHost(server);
        addTearDown(host.dispose);
        final viewer = await WirePhone.open(
          server,
          t,
          controllerId: 'viewer',
          capabilities: _view,
          code: server.pairingCode,
        );
        final other = await WirePhone.open(
          server,
          t,
          controllerId: 'phone-1',
          capabilities: const [Capability.metrics],
          code: server.pairingCode,
        );

        host.startView(_start);
        host.publishFrame(_frame(0));
        host.endView(_end);

        await viewer.drain();
        await other.drain();
        expect(_views(viewer), hasLength(3), reason: 'the view was really on');
        expect(_views(other), isEmpty);
        expect(server.snapshot.connected, hasLength(2), reason: 'both still connected');
      });

      test('a controller that listed view gets the start, the frames and the end, with every field', () async {
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

        host.startView(_start);
        host.publishFrame(_frame(0));
        host.publishFrame(_frame(1));
        host.endView(_end);

        await viewer.drain();
        final views = _views(viewer);
        expect(views.map((m) => m.type), ['view_start', 'frame', 'frame', 'view_end']);

        final start = views[0] as ViewStartMessage;
        expect(start.game, 'shape_race');
        expect(start.snapshotVersion, 1);
        expect(start.setup, _start.setup);
        expect(start.hz, 60);

        final first = views[1] as FrameMessage;
        expect(first.n, 0);
        expect(first.atMs, 672);
        expect(first.snapshot, {'v': 1, 't': 16000});
        expect(first.sounds, ['snap']);
        expect(first.acks, {'phone-1': 0});
        expect(first.roster, {'phone-1': (number: 1, name: 'Ada')});

        final second = views[2] as FrameMessage;
        expect(second.n, 1);
        expect(second.atMs, 688);
        expect(second.sounds, isEmpty, reason: 'snd is left out when empty');

        expect((views[3] as ViewEndMessage).reason, ViewEndReason.finished);
      });

      test('hasViewers counts only a paired controller that listed view', () async {
        final server = await startHost(t);
        final host = ServerGameHost(server);
        addTearDown(host.dispose);
        await WirePhone.open(server, t, controllerId: 'phone-2', code: server.pairingCode);
        expect(host.hasViewers, isFalse, reason: 'a controller without view never counts');

        await WirePhone.open(server, t, controllerId: 'viewer', capabilities: _view, code: server.pairingCode);
        expect(host.hasViewers, isTrue);

        server.dropAllConnections();
        await hostUntil(server, (h) => h.connected.isEmpty);
        expect(host.hasViewers, isFalse, reason: 'the only viewer is gone');
      });

      test('a viewer that pairs mid-view gets the start and the latest frame, and nothing older', () async {
        final server = await startHost(t);
        final host = ServerGameHost(server);
        addTearDown(host.dispose);
        host.startView(_start);
        host.publishFrame(_frame(0));
        host.publishFrame(_frame(1));
        host.publishFrame(_frame(2));

        final late = await WirePhone.open(
          server,
          t,
          controllerId: 'phone-1',
          capabilities: _view,
          code: server.pairingCode,
        );
        await late.drain();

        final views = _views(late);
        expect(views, hasLength(2));
        expect(views[0], isA<ViewStartMessage>());
        expect((views[1] as FrameMessage).n, 2, reason: 'the latest frame, not 0 or 1');
      });

      test('a viewer that pairs after the view ended gets nothing', () async {
        final server = await startHost(t);
        final host = ServerGameHost(server);
        addTearDown(host.dispose);
        final early = await WirePhone.open(
          server,
          t,
          controllerId: 'viewer',
          capabilities: _view,
          code: server.pairingCode,
        );
        host.startView(_start);
        host.publishFrame(_frame(0));
        host.endView(_end);
        await early.drain();
        expect(_views(early), hasLength(3));

        final late = await WirePhone.open(
          server,
          t,
          controllerId: 'phone-1',
          capabilities: _view,
          code: server.pairingCode,
        );
        await late.drain();
        expect(_views(late), isEmpty);
      });

      test('publishFrame sends nothing before the view starts or after it ended', () async {
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

        host.publishFrame(_frame(0));
        await viewer.drain();
        expect(viewer.fromHost.whereType<FrameMessage>(), isEmpty, reason: 'no startView yet');

        host.startView(_start);
        host.publishFrame(_frame(1));
        host.endView(_end);
        host.publishFrame(_frame(2));
        await viewer.drain();
        expect(viewer.fromHost.whereType<FrameMessage>().map((f) => f.n), [1], reason: '2 is after the end');
      });

      test('a viewer that drops and reconnects mid-view gets the start and the latest frame again', () async {
        final server = await startHost(t);
        final host = ServerGameHost(server);
        addTearDown(host.dispose);
        final client = newClient(t, capabilities: _view);
        final log = _ViewLog(client.view);
        client.connect(addressOf(server, t), code: server.pairingCode);
        await clientStatus(client, ClientStatus.connected);
        await hostUntil(server, (h) => h.connected.isNotEmpty);

        host.startView(_start);
        host.publishFrame(_frame(0));
        await log.until(2);
        expect(log.events[0], isA<ViewStarted>());
        expect((log.events[1] as ViewFrame).frame.n, 0);

        server.dropAllConnections();
        await clientStatus(client, ClientStatus.reconnecting);
        await clientStatus(client, ClientStatus.connected);
        await log.until(4);
        expect(log.events[2], isA<ViewStarted>(), reason: 'the start comes again');
        expect((log.events[3] as ViewFrame).frame.n, 0, reason: 'with the latest frame');
        expect(log.events, hasLength(4), reason: 'and nothing older');
      });

      test('the host reports the last input seq it applied for a player', () async {
        final server = await startHost(t);
        final host = ServerGameHost(server);
        addTearDown(host.dispose);
        final phone = await WirePhone.open(server, t, controllerId: 'phone-1', code: server.pairingCode);
        expect(host.inputSeq('phone-1'), isNull, reason: 'no input yet');

        phone.send(InputStateMessage(seq: 1));
        phone.send(InputStateMessage(seq: 2));
        phone.send(InputStateMessage(seq: 3));
        await phone.drain();
        expect(host.inputSeq('phone-1'), 3);

        phone.send(InputStateMessage(seq: 2));
        await phone.drain();
        expect(host.inputSeq('phone-1'), 3, reason: 'an older seq is dropped');

        final keyboard = host.addLocalPlayer(nickname: 'Keyboard');
        expect(host.inputSeq(keyboard.id), isNull, reason: 'a local player has no seq');
      });

      test('a viewer\'s metrics stages become stage samples on the host, and an unpaired phone\'s do not', () async {
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
        final lurker = await WirePhone.open(server, t, controllerId: 'lurker', capabilities: _view);

        final samples = <StageSample>[];
        final three = Completer<void>();
        host.stages.listen((s) {
          samples.add(s);
          if (samples.length == 3 && !three.isCompleted) three.complete();
        });

        viewer.send(
          MetricsMessage(
            segment: 's1',
            index: 1,
            mode: 'dpad',
            durationMs: 1000,
            stages: {
              LatencyStage.touchToFrame: [40, 62],
              LatencyStage.frameJitter: [0],
            },
          ),
        );
        await three.future.timeout(const Duration(seconds: 5));
        expect(samples, [
          (playerId: 'phone-1', stage: LatencyStage.touchToFrame, ms: 40),
          (playerId: 'phone-1', stage: LatencyStage.touchToFrame, ms: 62),
          (playerId: 'phone-1', stage: LatencyStage.frameJitter, ms: 0),
        ]);

        lurker.send(
          MetricsMessage(
            segment: 's2',
            index: 1,
            mode: 'dpad',
            durationMs: 10,
            stages: {
              LatencyStage.touchToFrame: [1000],
            },
          ),
        );
        await lurker.drain();
        await viewer.drain();
        expect(samples.where((s) => s.playerId == 'lurker'), isEmpty);
      });

      test('the client emits the start, the frames with their arrival time, and the end', () async {
        final server = await startHost(t);
        final host = ServerGameHost(server);
        addTearDown(host.dispose);
        final client = newClient(t, capabilities: _view);
        final log = _ViewLog(client.view);
        client.connect(addressOf(server, t), code: server.pairingCode);
        await clientStatus(client, ClientStatus.connected);
        await hostUntil(server, (h) => h.connected.isNotEmpty);

        host.startView(_start);
        host.publishFrame(_frame(0));
        await log.until(2);
        host.publishFrame(_frame(1));
        await log.until(3);
        host.endView(_end);
        await log.until(4);

        final started = log.events[0] as ViewStarted;
        expect(started.start.game, 'shape_race');
        expect(started.start.hz, 60);
        final first = log.events[1] as ViewFrame;
        expect(first.frame.n, 0);
        expect(first.arrivedAtMs, isNonNegative);
        final second = log.events[2] as ViewFrame;
        expect(second.frame.n, 1);
        expect(second.arrivedAtMs, greaterThanOrEqualTo(first.arrivedAtMs), reason: 'a real clock, going forward');
        expect((log.events[3] as ViewEnded).end.reason, ViewEndReason.finished);
      });

      test('a client that did not list view ignores the view messages a host sends anyway', () async {
        final host = await FakeHost.start(t);
        const codec = MessageCodec();
        final sent = Completer<void>();
        host.onChannel = (channel) => channel.incoming.listen((data) {
          final m = codec.decode(data);
          if (m is HelloMessage) {
            channel.send(codec.encode(const WelcomeMessage(hostId: 'h', hostName: 'Viewing TV', appVersion: 't')));
          } else if (m is PairRequestMessage) {
            channel.send(codec.encode(const PairResultMessage.accepted(token: 'tok')));
            // A TV that ignores what this phone lists and sends the game anyway.
            channel.send(codec.encode(_start));
            channel.send(codec.encode(_frame(0)));
            channel.send(codec.encode(_end));
            if (!sent.isCompleted) sent.complete();
          } else if (m is PingMessage) {
            channel.send(codec.encode(PongMessage.answering(m)));
          }
        });
        final client = newClient(t, connector: host);
        final log = _ViewLog(client.view);
        client.connect(host.address, code: '1234');
        await clientStatus(client, ClientStatus.connected);
        await sent.future.timeout(const Duration(seconds: 5));
        // A pong after them: everything the TV sent before it is handled.
        await clientUntil(client, (s) => (s.rttStats?.samples ?? 0) >= 1);
        expect(log.events, isEmpty);
        expect(client.snapshot.status, ClientStatus.connected, reason: 'dropped, not a protocol error');
      });
    });
  }

  // No channel: the memory host keeps the calls for the test to check.
  test('the memory host records the view calls and its input seqs', () {
    final host = MemoryGameHost();
    expect(host.hasViewers, isFalse);
    host.hasViewers = true;
    host.startView(_start);
    host.publishFrame(_frame(0));
    host.endView(_end);
    expect(host.hasViewers, isTrue);
    expect(host.viewStarts, [_start]);
    expect(host.frames.single.n, 0);
    expect(host.viewEnds.single.reason, ViewEndReason.finished);

    expect(host.inputSeq('phone-1'), isNull);
    host.inputSeqs['phone-1'] = 3;
    expect(host.inputSeq('phone-1'), 3);
  });
}

/// A client's view events, kept as they arrive so a test can wait for the
/// nth one: the stream is a broadcast one, so it listens from the start.
final class _ViewLog {
  _ViewLog(Stream<ViewEvent> view) {
    addTearDown(_arrived.close);
    addTearDown(() => _sub.cancel());
    _sub = view.listen((event) {
      events.add(event);
      if (!_arrived.isClosed) _arrived.add(null);
    });
  }

  /// Every event so far, in order.
  final events = <ViewEvent>[];

  final _arrived = StreamController<void>.broadcast();
  late final StreamSubscription<ViewEvent> _sub;

  /// Waits until [count] events have arrived.
  Future<void> until(int count) async {
    while (events.length < count) {
      await _arrived.stream.first.timeout(const Duration(seconds: 5));
    }
  }
}
