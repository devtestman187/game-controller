import 'dart:async';

import 'package:connection/connection.dart';
import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

import 'helpers.dart';

const _both = [Capability.metrics, Capability.rating];

MetricsMessage batch(String seg, int i, {bool ended = false, int presses = 0}) => MetricsMessage(
  segment: seg,
  index: i,
  mode: 'dpad',
  durationMs: i * 10000,
  ended: ended,
  data: {
    'presses': {'a': presses},
  },
);

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 150));

void main() {
  group('capabilities', () {
    test('each side learns what the other supports', () async {
      final host = await startHost(capabilities: _both);
      final client = newClient(capabilities: _both);
      client.connect(addressOf(host), code: host.pairingCode);
      final s = await clientStatus(client, ClientStatus.connected);
      expect(s.hostCapabilities, _both);
      final h = await hostUntil(host, (h) => h.connected.isNotEmpty);
      expect(h.connected.single.capabilities, _both);
      expect(h.connected.single.role, DeviceRole.controller);
    });

    test('a host never sends a message the controller did not list', () async {
      final host = await startHost(capabilities: _both);
      final client = newClient(); // An M8 phone: no capabilities.
      client.connect(addressOf(host), code: host.pairingCode);
      await clientStatus(client, ClientStatus.connected);
      await hostUntil(host, (h) => h.connected.isNotEmpty);
      expect(host.send('phone-1', const RatingAskMessage(id: 'r', game: 'arena')), isFalse);
      expect(host.sendToAll(const RatingAskMessage(id: 'r', game: 'arena')), 0);
      // v1 messages still go to it.
      expect(host.send('phone-1', HapticEventMessage(event: HapticEvent.hit)), isTrue);
    });

    test('a phone does not send metrics to a host that does not take them', () async {
      final host = await startHost(); // An M8 TV app.
      final client = newClient(capabilities: _both);
      final got = <Message>[];
      host.messages.listen((m) => got.add(m.message));
      client.connect(addressOf(host), code: host.pairingCode);
      await clientStatus(client, ClientStatus.connected);
      client.sendMetrics(batch('s1', 0));
      await settle();
      expect(got.whereType<MetricsMessage>(), isEmpty);
      expect(client.metricsWaiting, 1, reason: 'kept for a host that takes them');
    });
  });

  group('metrics batches', () {
    test('reach the host, get acknowledged, and an ended segment is dropped from the outbox', () async {
      final host = await startHost(capabilities: _both);
      final client = newClient(capabilities: _both);
      final got = <MetricsMessage>[];
      host.messages.listen((m) {
        if (m.message is MetricsMessage) got.add(m.message as MetricsMessage);
      });
      client.connect(addressOf(host), code: host.pairingCode);
      await clientStatus(client, ClientStatus.connected);

      client.sendMetrics(batch('s1', 0, presses: 3));
      client.sendMetrics(batch('s1', 1, presses: 5, ended: true));
      await settle();
      expect(got.map((b) => b.index), [0, 1]);
      expect(client.metricsWaiting, 0);
    });

    test('batches sent while the Wi-Fi is off arrive after reconnecting', () async {
      final host = await startHost(capabilities: _both);
      final client = newClient(capabilities: _both);
      final got = <String, MetricsMessage>{};
      host.messages.listen((m) {
        if (m.message case final MetricsMessage b) got[b.segment] = b;
      });
      client.connect(addressOf(host), code: host.pairingCode);
      await clientStatus(client, ClientStatus.connected);
      client.sendMetrics(batch('s1', 0, presses: 1));
      await settle();

      host.dropAllConnections();
      await clientStatus(client, ClientStatus.reconnecting);
      // While away: the first segment ends and a new one starts.
      client.sendMetrics(batch('s1', 1, presses: 4, ended: true));
      client.sendMetrics(batch('s2', 0, presses: 2));
      expect(client.metricsWaiting, 2);

      await clientStatus(client, ClientStatus.connected);
      await settle();
      expect(got['s1']!.index, 1);
      expect(got['s1']!.ended, isTrue);
      expect(got['s2']!.index, 0);
      expect(client.metricsWaiting, 1, reason: 's2 is still open');
    });

    test('an older batch never replaces a newer one in the outbox', () async {
      final client = newClient(capabilities: _both);
      client.sendMetrics(batch('s1', 3));
      client.sendMetrics(batch('s1', 2));
      expect(client.metricsWaiting, 1);
    });

    test('the outbox keeps at most maxOutbox segments', () {
      final client = newClient(capabilities: _both);
      for (var i = 0; i < ControllerClient.maxOutbox + 5; i++) {
        client.sendMetrics(batch('s$i', 0));
      }
      expect(client.metricsWaiting, ControllerClient.maxOutbox);
    });
  });

  group('rating', () {
    test('the host asks, the phone answers', () async {
      final host = await startHost(capabilities: _both);
      final client = newClient(capabilities: _both);
      final answers = <RatingMessage>[];
      host.messages.listen((m) {
        if (m.message case final RatingMessage r) answers.add(r);
      });
      client.ratingAsks.listen((ask) => client.sendRating(RatingMessage(id: ask.id, face: RatingFace.good)));
      client.connect(addressOf(host), code: host.pairingCode);
      await clientStatus(client, ClientStatus.connected);
      await hostUntil(host, (h) => h.connected.isNotEmpty);

      expect(host.send('phone-1', const RatingAskMessage(id: 'r1', game: 'arena')), isTrue);
      await settle();
      expect(answers.single.id, 'r1');
      expect(answers.single.face, RatingFace.good);
    });
  });

  group('gamepad mapping (P4)', () {
    test('D-pad mode: the D-pad and buttons, sticks centered', () {
      final g = GamepadState.fromInput(InputStateMessage(seq: 1, buttons: {ControllerButton.a}, dx: -1, dy: 1));
      expect(g.mode, InputMode.dpad);
      expect(g.buttons, {GamepadButton.a, GamepadButton.dpadLeft, GamepadButton.dpadDown});
      expect((g.dpadX, g.dpadY), (-1, 1));
      expect((g.leftX, g.leftY), (0.0, 0.0));
    });

    test('gyro mode: the tilt is the left stick, and the raw tilt too', () {
      final g = GamepadState.fromInput(InputStateMessage(seq: 1, ax: 0.5, ay: -0.25));
      expect(g.mode, InputMode.gyro);
      expect((g.leftX, g.leftY), (0.5, -0.25));
      expect((g.tiltX, g.tiltY), (0.5, -0.25));
      expect(g.usesDpad, isFalse);
    });

    test('stick mode: both sticks, the D-pad and every button', () {
      final g = GamepadState.fromInput(
        InputStateMessage(
          seq: 1,
          buttons: {ControllerButton.lb, ControllerButton.start},
          dy: -1,
          lx: 1,
          ly: 0,
          rx: 0,
          ry: -1,
        ),
      );
      expect(g.mode, InputMode.sticks);
      expect(g.buttons, {GamepadButton.lb, GamepadButton.start, GamepadButton.dpadUp});
      expect((g.leftX, g.rightY), (1.0, -1.0));
      expect(g.tiltX, isNull);
    });

    test('no input is neutral', () {
      expect(GamepadState.fromInput(null), GamepadState.neutral);
      expect(GamepadState.neutral.isNeutral, isTrue);
    });
  });

  group('game host (P3)', () {
    test('phones and local players share numbers without clashing', () async {
      final server = await startHost(capabilities: _both);
      final host = ServerGameHost(server);
      addTearDown(host.dispose);
      final keyboard = host.addLocalPlayer(nickname: 'Keyboard');
      expect(keyboard.number, 1);

      final client = newClient(capabilities: _both);
      client.connect(addressOf(server), code: server.pairingCode);
      final s = await clientUntil(client, (s) => s.player != null);
      expect(s.player, 2, reason: 'number 1 is the keyboard');
      expect(host.players.map((p) => (p.number, p.local)), [(1, true), (2, false)]);

      keyboard.set(const GamepadState(buttons: {GamepadButton.a}, mode: InputMode.keyboard));
      expect(host.gamepad(keyboard.id).pressed(GamepadButton.a), isTrue);
      expect(host.haptic(keyboard.id, HapticEventMessage(event: HapticEvent.hit)), isFalse);

      keyboard.remove();
      expect(host.players.single.number, 2);
    });

    test('reads a phone through the standard mapping and reports stages', () async {
      final server = await startHost(capabilities: _both);
      final host = ServerGameHost(server);
      addTearDown(host.dispose);
      final stages = <StageSample>[];
      host.stages.listen(stages.add);
      final client = newClient(capabilities: _both);
      client.connect(addressOf(server), code: server.pairingCode);
      await clientStatus(client, ClientStatus.connected);
      client.sendInput({ControllerButton.b}, dx: 1);
      await hostUntil(server, (h) => h.connected.single.input?.buttons.isNotEmpty ?? false);

      final g = host.gamepad('phone-1');
      expect(g.buttons, {GamepadButton.b, GamepadButton.dpadRight});
      expect(host.inputArrivedAtMs('phone-1'), isNotNull);

      host.reportStage('phone-1', LatencyStage.receivedToDrawn, 12);
      expect(host.stageSummary('phone-1', LatencyStage.receivedToDrawn)!.avgMs, 12);
      await Future<void>.delayed(Duration.zero);
      expect(stages.where((s) => s.stage == LatencyStage.receivedToDrawn), hasLength(1));
    });
  });
}
