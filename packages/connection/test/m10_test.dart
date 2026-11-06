import 'dart:async';

import 'package:connection/connection.dart';
import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

import 'helpers.dart';

const _all = [Capability.metrics, Capability.rating, Capability.layout, Capability.status];

final puzzleLayout = GameLayoutMessage(
  labels: {ControllerButton.a: 'Pick up', ControllerButton.x: 'Rotate'},
  hidden: {ControllerButton.b},
);

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 150));

void main() {
  for (final t in TestTransport.values) {
    group(t.name, () {
      test('the phone gets the game layout and status, and goes back to standard when it drops', () async {
        final server = await startHost(t, capabilities: _all);
        final host = ServerGameHost(server);
        addTearDown(host.dispose);
        final client = newClient(t, capabilities: _all);
        client.connect(addressOf(server, t), code: server.pairingCode);
        await clientStatus(client, ClientStatus.connected);
        await hostUntil(server, (h) => h.connected.isNotEmpty);

        host.setLayout('phone-1', puzzleLayout);
        host.setStatus('phone-1', StatusMessage(text: 'Roof', progress: 0.5));
        await settle();
        expect(client.layout.labels[ControllerButton.a], 'Pick up');
        expect(client.status.text, 'Roof');

        // A drop: the phone forgets the game's controls...
        server.dropAllConnections();
        await clientStatus(client, ClientStatus.reconnecting);
        expect(client.layout.isStandard, isTrue);
        expect(client.status.isHidden, isTrue);
        // ...and gets them again on reconnecting.
        await clientStatus(client, ClientStatus.connected);
        await settle();
        expect(client.layout.hidden, {ControllerButton.b});
        expect(client.status.text, 'Roof');

        // The game ends: standard again, and the panel goes.
        host.setLayout('phone-1', GameLayoutMessage.standard());
        host.setStatus('phone-1', StatusMessage.hidden());
        await settle();
        expect(client.layout.isStandard, isTrue);
        expect(client.status.isHidden, isTrue);
      });

      test('an older phone gets neither', () async {
        final server = await startHost(t, capabilities: _all);
        final host = ServerGameHost(server);
        addTearDown(host.dispose);
        final client = newClient(t, capabilities: const [Capability.metrics]);
        client.connect(addressOf(server, t), code: server.pairingCode);
        await clientStatus(client, ClientStatus.connected);
        await hostUntil(server, (h) => h.connected.isNotEmpty);
        host.setLayout('phone-1', puzzleLayout);
        host.setStatus('phone-1', StatusMessage(text: 'Roof'));
        await settle();
        expect(client.layout.isStandard, isTrue);
        expect(client.status.isHidden, isTrue);
        expect(server.snapshot.connected, hasLength(1), reason: 'still connected');
      });

      test('status is sent at most 10 times a second, and the newest always arrives', () async {
        final server = await startHost(t, capabilities: _all);
        final host = ServerGameHost(server);
        addTearDown(host.dispose);
        final client = newClient(t, capabilities: _all);
        final received = <StatusMessage>[];
        client.statuses.listen(received.add);
        client.connect(addressOf(server, t), code: server.pairingCode);
        await clientStatus(client, ClientStatus.connected);
        await hostUntil(server, (h) => h.connected.isNotEmpty);

        // About 60 a second for half a second. On Windows a 16 ms delay can take 30 ms (the default timer
        // tick is 15.6 ms), so the allowed count is worked out from the time the loop really took.
        final clock = Stopwatch()..start();
        for (var i = 0; i < 30; i++) {
          host.setStatus('phone-1', StatusMessage(text: 'n$i'));
          await Future<void>.delayed(const Duration(milliseconds: 16));
        }
        await Future<void>.delayed(const Duration(milliseconds: 300));
        clock.stop();
        // At most 10 a second, plus one for the first and one for the last.
        expect(received.length, lessThanOrEqualTo(clock.elapsedMilliseconds ~/ 100 + 2));
        expect(received.last.text, 'n29');
      });

      test('a phone may not send a layout or status to the host', () async {
        final server = await startHost(t, capabilities: _all);
        final client = newClient(t, capabilities: _all);
        client.connect(addressOf(server, t), code: server.pairingCode);
        await clientStatus(client, ClientStatus.connected);
        expect(HostServer.capabilityFor(puzzleLayout), Capability.layout);
        expect(HostServer.capabilityFor(StatusMessage.hidden()), Capability.status);
      });

      test('a quick tap is seen even if its press and release both arrive between two frames', () async {
        final server = await startHost(t, capabilities: _all);
        final host = ServerGameHost(server);
        addTearDown(host.dispose);
        final client = newClient(t, capabilities: _all);
        client.connect(addressOf(server, t), code: server.pairingCode);
        await clientStatus(client, ClientStatus.connected);
        await hostUntil(server, (h) => h.connected.isNotEmpty);

        // Wait for exactly the press and the release (the phone also sends a
        // neutral input when it connects).
        var sawA = false;
        final both = server.messages
            .map((m) => m.message)
            .where((m) => m is InputStateMessage)
            .cast<InputStateMessage>()
            .firstWhere((i) {
              if (i.buttons.contains(ControllerButton.a)) sawA = true;
              return sawA && i.buttons.isEmpty;
            });
        client
          ..sendInput({ControllerButton.a})
          ..sendInput({});
        await both;
        await Future<void>.delayed(Duration.zero);
        expect(server.snapshot.connected.single.input!.buttons, isEmpty);
        // The latest input has nothing held, but the tap still shows...
        expect(host.gamepad('phone-1').pressed(GamepadButton.a), isTrue);
        // ...for a short time only.
        await Future<void>.delayed(const Duration(milliseconds: ServerGameHost.minPressMs + 20));
        expect(host.gamepad('phone-1').pressed(GamepadButton.a), isFalse);
      });
    });
  }

  // A local player has no channel: nothing leaves this process.
  test('sounds go to the app by name; a local player has no layout', () async {
    final server = await startHost(TestTransport.inProcess, capabilities: _all);
    final host = ServerGameHost(server);
    addTearDown(host.dispose);
    final sounds = <String>[];
    host.sounds.listen(sounds.add);
    host.playSound('snap');
    final keyboard = host.addLocalPlayer(nickname: 'Keyboard');
    host.setLayout(keyboard.id, puzzleLayout);
    await settle();
    expect(sounds, ['snap']);
    expect(host.layoutOf(keyboard.id).isStandard, isTrue);
  });
}
