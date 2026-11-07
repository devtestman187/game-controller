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

        final layout = client.layouts.firstWhere((l) => !l.isStandard);
        final status = client.statuses.firstWhere((s) => !s.isHidden);
        host.setLayout('phone-1', puzzleLayout);
        host.setStatus('phone-1', StatusMessage(text: 'Roof', progress: 0.5));
        await layout;
        await status;
        expect(client.layout.labels[ControllerButton.a], 'Pick up');
        expect(client.status.text, 'Roof');

        // A drop: the phone forgets the game's controls...
        final layoutAgain = client.layouts.firstWhere((l) => !l.isStandard);
        final statusAgain = client.statuses.firstWhere((s) => !s.isHidden);
        server.dropAllConnections();
        await clientStatus(client, ClientStatus.reconnecting);
        expect(client.layout.isStandard, isTrue);
        expect(client.status.isHidden, isTrue);
        // ...and gets them again on reconnecting.
        await clientStatus(client, ClientStatus.connected);
        await layoutAgain;
        await statusAgain;
        expect(client.layout.hidden, {ControllerButton.b});
        expect(client.status.text, 'Roof');

        // The game ends: standard again, and the panel goes.
        final standard = client.layouts.firstWhere((l) => l.isStandard);
        final hidden = client.statuses.firstWhere((s) => s.isHidden);
        host.setLayout('phone-1', GameLayoutMessage.standard());
        host.setStatus('phone-1', StatusMessage.hidden());
        await standard;
        await hidden;
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
        // The round trip shows the phone took everything the host sent it.
        await hapticRoundTrip(server, client);
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
        final newest = Completer<void>();
        client.statuses.listen((s) {
          received.add(s);
          if (s.text == 'n29' && !newest.isCompleted) newest.complete();
        });
        client.connect(addressOf(server, t), code: server.pairingCode);
        await clientStatus(client, ClientStatus.connected);
        await hostUntil(server, (h) => h.connected.isNotEmpty);

        // About 60 a second for half a second: the rate the limit is about, so
        // the 16 ms spacing is the input, not a wait. On Windows a 16 ms delay
        // can take 30 ms (the default timer tick is 15.6 ms), so the allowed
        // count is worked out from the time the loop really took.
        final clock = Stopwatch()..start();
        for (var i = 0; i < 30; i++) {
          host.setStatus('phone-1', StatusMessage(text: 'n$i'));
          await Future<void>.delayed(const Duration(milliseconds: 16));
        }
        // The last one goes when its gap is up, so the test ends on that event.
        await newest.future.timeout(const Duration(seconds: 5));
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
        await both; // The host applies an input before it passes the message on.
        expect(server.snapshot.connected.single.input!.buttons, isEmpty);
        // The latest input has nothing held, but the tap still shows...
        expect(host.gamepad('phone-1').pressed(GamepadButton.a), isTrue);
        // ...for a short time only: two heartbeats of the phone are longer
        // than minPressMs, and they are events rather than a sleep.
        final samples = server.snapshot.connected.single.rttStats?.samples ?? 0;
        await hostUntil(server, (h) => (h.connected.single.rttStats?.samples ?? 0) >= samples + 2);
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
    final snap = host.sounds.first;
    host.playSound('snap');
    final keyboard = host.addLocalPlayer(nickname: 'Keyboard');
    host.setLayout(keyboard.id, puzzleLayout);
    await snap;

    expect(sounds, ['snap']);
    expect(host.layoutOf(keyboard.id).isStandard, isTrue);
  });
}
