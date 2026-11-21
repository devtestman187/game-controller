import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:tvtest/src/ui/home/home_screen.dart';
import 'package:tvtest/src/ui/latency_screen.dart';

import 'support/pump_app.dart';

/// The frame's math is compared with this slack: [Size] holds two doubles, and
/// 1024 x 768 gives a frame width a hair off 960 (host_frame_screen_test.dart's
/// tolerance).
const _tolerance = 1e-9;

/// One TV, with the scale and the frame the design's math gives it (M16 DESIGN
/// section 2): `s = min(W/960, H/540)` and the frame is `(W/s, H/s)`.
class _Case {
  const _Case({required this.label, required this.device, required this.scale, required this.frame});

  /// The device in the brief's words, for the test's name.
  final String label;

  /// The device's logical size.
  final Size device;

  /// How many device logical pixels one frame pixel is drawn at.
  final double scale;

  /// The size the home lays out in, in frame px.
  final Size frame;
}

/// The design frame, the TV's 960 x 540 (DESIGN section 1, rule 1).
const _designFrame = Size(960, 540);

/// The three the brief names: the TV, a 720p box and a tablet.
const _cases = [
  _Case(label: '1920x1080, the TV', device: Size(1920, 1080), scale: 2, frame: _designFrame),
  _Case(label: '1280x720, a 720p TV', device: Size(1280, 720), scale: 1280 / 960, frame: _designFrame),
  _Case(label: '1024x768, a tablet', device: Size(1024, 768), scale: 1024 / 960, frame: Size(960, 720)),
];

/// The label of the home button the remote's focus is on, if it is on one.
String? focusedLabel() =>
    FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<HostButton>()?.label;

/// Puts the focus on the home button [label], as the remote's arrows would.
void focusButton(WidgetTester tester, String label) =>
    Focus.of(tester.element(find.descendant(of: find.widgetWithText(HostButton, label), matching: find.text(label))))
        .requestFocus();

void main() {
  for (final c in _cases) {
    testWidgets('the home is drawn in the host frame at ${c.label}', (tester) async {
      await pumpApp(tester, size: c.device);
      expect(tester.takeException(), isNull, reason: 'nothing overflows the frame');

      // The app's one layout, above the home screen: the scale the device
      // gives and the frame the home is laid out in.
      final info = HostFrameInfo.of(tester.element(find.byType(HomeScreen)));
      expect(info.scale, closeTo(c.scale, _tolerance), reason: 's = min(W/960, H/540)');
      expect(info.frame.width, closeTo(c.frame.width, _tolerance));
      expect(info.frame.height, closeTo(c.frame.height, _tolerance));

      // The home takes the whole frame, and inside it a frame pixel is a
      // logical pixel: its MediaQuery says the frame's size, not the device.
      expect(tester.getSize(find.byType(HomeScreen)), c.frame);
      final media = MediaQuery.of(tester.element(find.byType(HomeScreen)));
      expect(media.size.width, closeTo(c.frame.width, _tolerance));
      expect(media.size.height, closeTo(c.frame.height, _tolerance));
      expect(media.devicePixelRatio, 1, reason: 'the scale does the drawing, not the pixels');
    });
  }

  testWidgets('a home button works through the frame at 1920x1080', (tester) async {
    await pumpApp(tester, size: const Size(1920, 1080));
    // A tap on the drawn (scaled) button reaches the frame's widget.
    await tapVisible(tester, find.text('Latency'));
    await tester.pumpAndSettle();
    expect(find.byType(LatencyScreen), findsOneWidget, reason: 'the tap went through the frame');
    expect(tester.takeException(), isNull);
  });

  testWidgets('the d-pad moves the focus between home buttons at 1920x1080', (tester) async {
    await pumpApp(tester, size: const Size(1920, 1080));
    // "New code" is focused on launch; from "Play" an arrow reaches another
    // header button (focus traversal reads the frame's boxes through the
    // FittedBox transform).
    focusButton(tester, 'Play');
    await tester.pump();
    expect(focusedLabel(), 'Play');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    final next = focusedLabel();
    expect(next, isNotNull, reason: 'the arrow kept the focus on a home button');
    expect(next, isNot('Play'), reason: 'the arrow moved the focus to a second button');
  });

  testWidgets('a dialog opened over the home is in the frame too', (tester) async {
    await pumpApp(tester, size: const Size(1920, 1080), consent: null);
    // The first launch's question is a route over the home: the frame is above
    // the navigator, so the dialog is drawn in it.
    final dialog = find.byKey(const Key('consentDialog'));
    expect(dialog, findsOneWidget);
    final info = HostFrameInfo.maybeOf(tester.element(dialog));
    expect(info, isNotNull, reason: 'the dialog is inside HostFrame');
    expect(info!.frame.width, closeTo(_designFrame.width, _tolerance));
    expect(info.frame.height, closeTo(_designFrame.height, _tolerance));
  });
}
