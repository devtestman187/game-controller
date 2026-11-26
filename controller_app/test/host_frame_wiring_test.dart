import 'dart:math' as math;

import 'package:controller/src/ui/top_bar_metrics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart' as party;

import 'support/host_app.dart';
import 'support/pump_app.dart';
import 'support/test_font.dart';

/// The frame [party.HostFrame] draws for [screen] with the phone's bar over
/// its top: `s = min(W/960, (H - bar)/540)` and the frame that follows, which
/// is what the gate's `MediaQuery` gives it (host_frame.dart works them out
/// from the size alone).
(double, Size) frameAt(Size screen) {
  final scale = math.min(screen.width / 960, (screen.height - topBarHeightPx) / 540);
  return (scale, Size(screen.width / scale, (screen.height - topBarHeightPx) / scale));
}

void main() {
  setUpAll(loadHostFonts);
  setUpAll(loadPuzzles);

  for (final screen in const [Size(852, 393), Size(640, 360)]) {
    testWidgets('the picker is in the frame, which starts below the bar at ${screen.width.toInt()}x'
        '${screen.height.toInt()}', (tester) async {
      await pumpHostApp(tester, screen: screen);
      final host = await enterHostMode(tester);
      await settle(tester);

      // The picker is inside a frame, and it is the frame the bar leaves.
      final picker = find.byType(party.GamesScreen);
      final info = find.ancestor(of: picker, matching: find.byType(party.HostFrameInfo));
      expect(info, findsOneWidget);
      final (scale, frame) = frameAt(screen);
      final data = tester.widget<party.HostFrameInfo>(info);
      expect(data.scale, closeTo(scale, 1e-9));
      expect(data.frame.width, closeTo(frame.width, 1e-9));
      expect(data.frame.height, closeTo(540, 1e-9), reason: 'the frame is 960x540-shaped: 540 high');
      expect(data.extraW, greaterThan(0), reason: 'a phone host is wider than 16:9 in this frame');

      // The frame's rect starts at the bar: the whole area below it, and not
      // one pixel of the bar's strip.
      final frameRect = tester.getRect(find.byType(party.HostFrame));
      expect(frameRect.left, closeTo(0, 1e-6));
      expect(frameRect.top, closeTo(topBarHeightPx, 1e-6));
      expect(frameRect.width, closeTo(screen.width, 1e-6));
      expect(frameRect.height, closeTo(screen.height - topBarHeightPx, 1e-6));
      expect(tester.getRect(picker).size, frameRect.size, reason: 'the picker fills the frame');

      // The picker's header starts at the frame's top and is 64 frame px tall,
      // drawn at the frame's scale.
      final header = find.descendant(of: picker, matching: find.byKey(const Key('hostTitleBar')));
      expect(tester.getRect(header).top, closeTo(topBarHeightPx, 1e-6));
      expect(tester.getRect(header).height, closeTo(64 * scale, 1e-6));

      // The strip over the frame is the look's background, so the sky behind
      // the bar ends at a line of its own rather than at a black band.
      final look = party.ToyLookScope.of(tester.element(picker));
      final strip = find.byKey(const Key('hostFrameBarStrip'));
      expect(tester.widget<ColoredBox>(strip).color, look.colors.background);
      final stripRect = tester.getRect(strip);
      expect((stripRect.left, stripRect.top), (0.0, 0.0));
      expect(stripRect.width, closeTo(screen.width, 1e-6));
      expect(stripRect.height, topBarHeightPx);

      await tester.runAsync(host.dispose);
    });
  }

  testWidgets('the Connect screen is not in the frame', (tester) async {
    await pumpApp(tester);
    expect(find.byType(party.HostFrameInfo), findsNothing);
    expect(find.byType(party.HostFrame), findsNothing);
  });

  testWidgets('a joined phone is not in the frame', (tester) async {
    await pumpApp(tester, paired: true);
    expect(find.byType(party.HostFrameInfo), findsNothing);
    expect(find.byType(party.HostFrame), findsNothing);
  });

  testWidgets('a "Play on this phone" round keeps its pad exactly where it was', (tester) async {
    await pumpHostApp(tester);
    final host = await soloRound(tester);

    final face = find.byKey(const Key('faceButtons'));
    final dpad = find.byKey(const Key('dpad'));
    // Start is in the compact bar over the round, not on the pad.
    final start = find.byKey(const Key('barStart'));
    // The pad's rects recorded by this same pump before the frame was wired
    // (M16 phonehost2 wph): the frame's 0.63148 scale never reaches them.
    expect(tester.getRect(face), const Rect.fromLTRB(510, 60, 827, 377));
    expect(tester.getRect(dpad), const Rect.fromLTRB(25, 60, 342, 377));
    expect(tester.getRect(start), const Rect.fromLTRB(644, 6, 740, 50));
    for (final pad in [face, dpad, start, find.byKey(const Key('hostChip'))]) {
      expect(find.ancestor(of: pad, matching: find.byType(party.HostFrameInfo)), findsNothing);
    }

    await tester.runAsync(host.dispose);
  });
}
