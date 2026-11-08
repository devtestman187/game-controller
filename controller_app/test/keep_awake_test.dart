import 'package:controller/src/host/host_start_sheet.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/testing.dart' as party_test;

import 'support/host_app.dart';

/// m12 bug 1108a fix2 (Q2): a phone keeps its screen on for the whole time it
/// hosts, in both modes, so a phone waiting for players cannot dim or lock
/// (which pauses and then abandons the round); stopping the host lets it sleep
/// again.
void main() {
  // The puzzle files are read once, before any test runs (s9g).
  setUpAll(loadPuzzles);

  testWidgets('a "Show on this device" host keeps the screen on with no controller, and lets it sleep when it stops', (
    tester,
  ) async {
    final awake = party_test.FakeScreenAwake();
    await pumpHostApp(tester, awake: awake);
    expect(awake.on, isFalse, reason: 'nothing is hosted before "Host a game"');

    final host = await enterHostMode(tester, choice: HostChoice.onDevice);
    // Nobody has joined: the host's own rule would let the screen sleep here,
    // and this phone is the screen the players are coming to watch.
    expect(host.service.state.host.connected, isEmpty);
    expect(awake.on, isTrue, reason: 'a screen that dims or locks while it waits would abandon the round');

    await stopHosting(tester, host);
    expect(awake.on, isFalse, reason: 'no host, no game to stay awake for');
  });

  testWidgets('a "Play on this phone" host keeps the screen on too', (tester) async {
    final awake = party_test.FakeScreenAwake();
    await pumpHostApp(tester, awake: awake);

    final host = await enterHostMode(tester);
    expect(awake.on, isTrue);

    await stopHosting(tester, host);
    expect(awake.on, isFalse);
  });
}
