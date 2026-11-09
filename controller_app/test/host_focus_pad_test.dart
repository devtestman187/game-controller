import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:connection/connection.dart';
import 'package:controller/src/host/host_start_sheet.dart';
import 'package:controller/src/host/phone_host.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart' as party;

import 'support/host_app.dart';
import 'support/pump_app.dart';

/// A phone that joins [host] over a socket on this machine, as one on the LAN
/// would: the menus see it as a phone, not as the host's own player.
Future<ControllerClient> joinPhone(WidgetTester tester, PhoneHost host, String id) async {
  final state = host.service.state;
  final port = state.host.port;
  if (port == null) fail('The host is not listening');
  final client = ControllerClient(
    identity: ControllerIdentity(controllerId: id, name: id, platform: 'android', appVersion: 't'),
    connector: WebSocketConnector(),
    heartbeatInterval: const Duration(milliseconds: 100),
    heartbeatTimeout: const Duration(seconds: 2),
    retryDelays: const [Duration(milliseconds: 50)],
  );
  client.connect(
    HostAddress(addresses: ['127.0.0.1'], port: port),
    code: state.host.pairingCode,
  );
  await until(
    tester,
    () => client.snapshot.isConnected && host.service.gameHost.players.any((p) => p.id == id),
    () => 'The phone did not join: ${client.snapshot} / ${host.service.gameHost.players}',
  );
  return client;
}

/// Presses and lets go of [id]'s pad, waiting on the host's own state each
/// way: a socket message only arrives while the real event loop runs, and a
/// press left held would send the menus its repeat a beat later.
Future<void> padPress(
  WidgetTester tester,
  PhoneHost host,
  ControllerClient phone,
  String id, {
  int dx = 0,
  int dy = 0,
}) async {
  phone.sendInput(const {}, dx: dx, dy: dy);
  await until(
    tester,
    () => host.service.gameHost.gamepad(id).dpadX == dx && host.service.gameHost.gamepad(id).dpadY == dy,
    () => 'the press never reached the host (${phone.snapshot})',
  );
  phone.sendInput(const {});
  await until(
    tester,
    () => host.service.gameHost.gamepad(id).dpadX == 0 && host.service.gameHost.gamepad(id).dpadY == 0,
    () => 'the release never reached the host (${phone.snapshot})',
  );
}

bool lit(WidgetTester tester, String key) => tester
    .widget<party.HostCardFocus>(find.descendant(of: find.byKey(Key(key)), matching: find.byType(party.HostCardFocus)))
    .isLit;

bool focused(WidgetTester tester, String key) {
  final text = find.descendant(of: find.byKey(Key(key)), matching: find.byType(Text)).first;
  return Focus.of(tester.element(text)).hasFocus;
}

/// The test screen's pixels, as the party_host tests read them back, so a test
/// can say what the look paints outside the widgets' own boxes.
final class ScreenPixels {
  const ScreenPixels(this._bytes, this._width);

  final Uint8List _bytes;
  final int _width;

  /// The colour of the pixel at ([x], [y]), 0xRRGGBB.
  int at(int x, int y) {
    final i = 4 * (y * _width + x);
    return _bytes[i] << 16 | _bytes[i + 1] << 8 | _bytes[i + 2];
  }
}

/// A colour as the pixels are: 0xRRGGBB.
int argb(Color colour) => colour.toARGB32() & 0xFFFFFF;

/// The whole test screen as the app drew it.
Future<ScreenPixels> screenPixels(WidgetTester tester) async {
  final size = tester.view.physicalSize / tester.view.devicePixelRatio;
  final layer = tester.binding.renderViews.first.debugLayer! as OffsetLayer;
  final image = (await tester.runAsync(() => layer.toImage(Offset.zero & size)))!;
  final data = (await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.rawRgba)))!;
  return ScreenPixels(data.buffer.asUint8List(), image.width);
}

/// How many pixels of [ink] the look paints in the band round [box]'s edge:
/// what the focus look adds to the edge of the thing that has the focus.
int edgeInk(ScreenPixels pixels, Rect box, int ink) {
  const band = 6.0;
  var count = 0;
  for (var y = box.top.floor(); y < box.bottom.ceil(); y++) {
    for (var x = box.left.floor(); x < box.right.ceil(); x++) {
      final near = x - box.left < band || box.right - x <= band || y - box.top < band || box.bottom - y <= band;
      if (near && pixels.at(x, y) == ink) count++;
    }
  }
  return count;
}

/// The box of the widget that has the focus, in the test screen's pixels.
Rect focusedRect() {
  final box = FocusManager.instance.primaryFocus!.context!.findRenderObject()! as RenderBox;
  return box.localToGlobal(Offset.zero) & box.size;
}

/// The look's focus colour, as the pixels are.
int focusInk(WidgetTester tester) =>
    argb(party.ToyLookScope.of(tester.element(find.byType(party.ControllerMenus))).colors.focus);

void main() {
  setUpAll(loadPuzzles);
  // The joined phone connects over a socket on this machine, as a real phone
  // does: the test binding blocks real HTTP and WebSockets by default.
  setUp(() => HttpOverrides.global = null);

  testWidgets('a joined phone\'s pad rings the card it moves to on "Show on this device"', (tester) async {
    await pumpHostApp(tester, tablet: true, screen: const Size(1024, 768));
    final host = await enterHostMode(tester, choice: HostChoice.onDevice);
    final phone = await joinPhone(tester, host, 'phone-b');
    await settle(tester);

    // The picker is up and its first card has the focus, but a touch-first
    // host shows no focus look until a pad moves the focus (m12 bug 1107f).
    expect(find.byType(party.ControllerMenus), findsOneWidget);
    expect(focused(tester, 'pickShapeRace'), isTrue, reason: 'the Shape Race card starts with the focus');
    final shapeRace = tester.getRect(find.byKey(const Key('pickShapeRace')));
    final ink = focusInk(tester);
    expect(edgeInk(await screenPixels(tester), shapeRace, ink), 0, reason: 'no ring until a pad moves the focus');

    // The phone presses right: the menus move the focus to the Arena card, and
    // its ring paints. This is the owner's case (Nov 9, 2026): the ring was
    // drawn under the card's own paper, so nothing on the screen showed what
    // the pad had selected.
    await padPress(tester, host, phone, 'phone-b', dx: 1);
    await until(tester, () => focused(tester, 'pickArena'), () => 'the menus did not move the focus');
    expect(lit(tester, 'pickArena'), isTrue);
    final arena = tester.getRect(find.byKey(const Key('pickArena')));
    expect(
      edgeInk(await screenPixels(tester), arena, ink),
      greaterThan(0),
      reason: 'the ring must paint round the card the pad moved to',
    );
    expect(edgeInk(await screenPixels(tester), shapeRace, ink), 0, reason: 'and the card it left has none');

    // A finger on the phone's own screen takes the ring away...
    await tester.tap(find.text(party.HostText.playtestLine));
    await settle(tester);
    expect(hostContainer(tester).read(party.hostFocusLookProvider), isFalse);
    expect(edgeInk(await screenPixels(tester), arena, ink), 0, reason: 'a thumb takes the ring away');

    // ...and the next pad press brings it back: the menus keep what the phone
    // held and act on the press (m13 s21: the wrapper's Theme used to swap in
    // and out of the tree, which remounted them, and this first press went
    // nowhere).
    await padPress(tester, host, phone, 'phone-b', dx: 1);
    await until(
      tester,
      () => hostContainer(tester).read(party.hostFocusLookProvider),
      () => 'the next pad press did not bring the focus look back',
    );
    expect(edgeInk(await screenPixels(tester), focusedRect(), ink), greaterThan(0));

    await tester.runAsync(phone.dispose);
    await tester.runAsync(host.dispose);
  });
}
