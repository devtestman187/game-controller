import 'dart:io';

import 'package:connection/connection.dart';
import 'package:controller/src/host/phone_host.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart' as party;
import 'package:protocol/protocol.dart';

import 'support/host_app.dart';
import 'support/pump_app.dart';

/// The first host's consent prompt (B-023) is for the adult whose phone it is:
/// a joined phone's A and B, and the remote's keys, are not an answer, and
/// only a thumb on the hosting phone's own buttons answers it (B-023
/// follow-up). Once it is answered, the phones work the menus as before.
void main() {
  // The puzzle files are read once, before any test runs: no test here waits
  // on their real reads while it runs (s9g).
  setUpAll(loadPuzzles);
  // The joined phone connects over a socket on this machine, as a real phone
  // does: the test binding blocks real WebSockets by default.
  setUp(() => HttpOverrides.global = null);

  testWidgets('a joined phone\'s A leaves the first host\'s prompt unanswered', (tester) async {
    final app = await _promptUp(tester);
    final host = hostOf(tester);
    final phone = await joinPhone(tester, host, 'phone-b');
    await _frames(tester);

    // Its A is silent: the prompt and the answer are the hosting phone's own
    // (B-023), so nothing is pressed, closed or saved.
    await _pressPad(tester, host, phone, 'phone-b', GamepadButton.a);
    await _stillAsking(tester, app, 'A phone\'s A is not the adult\'s answer');

    await tester.runAsync(phone.dispose);
    await tester.runAsync(host.dispose);
  });

  testWidgets('a joined phone\'s B leaves the first host\'s prompt up', (tester) async {
    final app = await _promptUp(tester);
    final host = hostOf(tester);
    final phone = await joinPhone(tester, host, 'phone-b');
    await _frames(tester);

    // Its B is silent too, where the menus' B would close the prompt.
    await _pressPad(tester, host, phone, 'phone-b', GamepadButton.b);
    await _stillAsking(tester, app, 'A phone\'s B is not the adult\'s answer');

    await tester.runAsync(phone.dispose);
    await tester.runAsync(host.dispose);
  });

  testWidgets('the remote\'s OK and Enter leave the first host\'s prompt unanswered', (tester) async {
    final app = await _promptUp(tester);

    // The remote's OK ("select") and Enter press the button with the focus,
    // which is "Don't share": neither is the adult's answer.
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await settle(tester);
    await _stillAsking(tester, app, 'The remote\'s OK is not the adult\'s answer');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settle(tester);
    await _stillAsking(tester, app, 'Enter is not the adult\'s answer');
    expect(find.byType(party.ShapeRaceScreen), findsNothing, reason: 'no key pressed the picker under the prompt');

    await _disposeHost(tester);
  });

  testWidgets('the remote\'s back leaves the first host\'s prompt up', (tester) async {
    final app = await _promptUp(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester);
    await _stillAsking(tester, app, 'A remote\'s back is not the adult\'s answer');

    await _disposeHost(tester);
  });

  testWidgets('a thumb on "Don\'t share" answers the prompt, as before', (tester) async {
    final app = await _promptUp(tester);

    await tester.tap(find.byKey(const Key('consentNo')));
    await settle(tester);
    expect(find.byKey(const Key('consentDialog')), findsNothing, reason: 'the answer closes the prompt');
    expect(hostContainer(tester).read(party.statsStateProvider).consent, isFalse);
    expect(app.prefs.getBool('statsConsent'), isFalse);
    expect(find.byType(party.ControllerMenus), findsOneWidget, reason: 'the answer leaves the host route up');

    await _disposeHost(tester);
  });

  testWidgets('after the answer, the joined phone\'s A and B work the host\'s menus again', (tester) async {
    // "Show on this device": the picker alone, so a phone's A presses its card
    // and nothing of the phone's own takes the focus.
    final app = await pumpHostApp(tester);
    await _host(tester, const Key('hostOnDevice'));
    final host = hostOf(tester);
    final phone = await joinPhone(tester, host, 'phone-b');
    await _frames(tester);

    // A press while the prompt is up is neither an answer nor a press the
    // menus keep for later: the phone has to press again once it is answered.
    await _pressPad(tester, host, phone, 'phone-b', GamepadButton.a);
    await _stillAsking(tester, app, 'nothing the phone pressed answered the prompt');
    await tester.tap(find.byKey(const Key('consentYes')));
    await settle(tester);
    expect(find.byKey(const Key('consentDialog')), findsNothing);
    await _frames(tester);

    // The menus read the phone again: its A presses the picker's card, and its
    // B goes back to the picker.
    await _pressPad(tester, host, phone, 'phone-b', GamepadButton.a);
    await untilShown(tester, find.byType(party.ShapeRaceScreen), 'The Shape Race screen');
    await _pressPad(tester, host, phone, 'phone-b', GamepadButton.b);
    await untilShown(tester, find.byKey(const Key('pickShapeRace')), 'The game picker');

    await tester.runAsync(phone.dispose);
    await tester.runAsync(host.dispose);
  });
}

/// The app with "Host a game", then "Play on this phone", up to the prompt a
/// player sees before it is answered (B-023).
Future<TestApp> _promptUp(WidgetTester tester) async {
  final app = await pumpHostApp(tester);
  await _host(tester, const Key('hostOnPhone'));
  return app;
}

/// Taps "Host a game" and [way], the two taps before the prompt, and checks it
/// came up (B-023).
Future<void> _host(WidgetTester tester, Key way) async {
  await tester.tap(find.byKey(const Key('hostGame')));
  await settle(tester);
  await tester.tap(find.byKey(way));
  await settle(tester);
  expect(
    find.byKey(const Key('consentDialog')),
    findsOneWidget,
    reason: 'the first host asks about sharing stats (B-023)',
  );
}

/// The prompt is still the only thing that could answer: it is up, and neither
/// the state nor the saved setting holds an answer.
Future<void> _stillAsking(WidgetTester tester, TestApp app, String why) async {
  // A prompt closed by the input starts its exit; the frame the test checks is
  // the one after it.
  await settle(tester);
  expect(find.byKey(const Key('consentDialog')), findsOneWidget, reason: why);
  expect(hostContainer(tester).read(party.statsStateProvider).consent, isNull, reason: why);
  expect(app.prefs.getBool('statsConsent'), isNull, reason: why);
}

/// The frames the host's menus need to have read a phone before its press.
Future<void> _frames(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// Presses and lets go of [button] on [id]'s phone, waiting on the host's own
/// state each way: a socket message only arrives while the real event loop
/// runs, and a press left held would send the menus its repeat a beat later.
Future<void> _pressPad(
  WidgetTester tester,
  PhoneHost host,
  ControllerClient phone,
  String id,
  GamepadButton button,
) async {
  final sent = switch (button) {
    GamepadButton.a => ControllerButton.a,
    GamepadButton.b => ControllerButton.b,
    _ => fail('Only A and B work the menus: $button'),
  };
  phone.sendInput({sent});
  await until(
    tester,
    () => host.service.gameHost.gamepad(id).pressed(button),
    () => 'The press never reached the host (${phone.snapshot})',
  );
  phone.sendInput(const {});
  await until(
    tester,
    () => !host.service.gameHost.gamepad(id).pressed(button),
    () => 'The release never reached the host (${phone.snapshot})',
  );
}

/// Waits for the host under the route to finish starting, then disposes it:
/// its server binds outside the test's clock, and a test's teardown fails on a
/// server it left listening.
Future<void> _disposeHost(WidgetTester tester) async {
  final host = hostOf(tester);
  await until(tester, () => host.started, () => 'The host did not start');
  await tester.runAsync(host.dispose);
}
