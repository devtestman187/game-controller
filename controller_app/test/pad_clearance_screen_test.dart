import 'dart:math' as math;

import 'package:controller/src/ui/pad_widgets.dart';
import 'package:controller/src/ui/top_bar_metrics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart' as party;
import 'package:puzzle_game/puzzle_game.dart';

import 'support/host_app.dart';
import 'support/test_font.dart';

/// The frame's scale at [screen] on the phone host: the room below its bar,
/// `s = min(W/960, (H - bar)/540)` (host_frame_gate.dart), 0.63148148 at
/// 852x393 and 0.57037037 at 640x360.
double frameScaleAt(Size screen) => math.min(screen.width / 960, (screen.height - topBarHeightPx) / 540);

/// The arms of the D-pad the phone draws over the round it hosts, in the
/// board's own box: the square the screen shows, cut by [dpadArms] as the pad
/// draws it, moved up by the bar the board's box starts under (M16 phonehost3
/// f1).
List<Rect> drawnArmsInBoardBox(WidgetTester tester) {
  final dpad = tester.getRect(find.byKey(const Key('dpad')));
  return [for (final (_, arm) in dpadArms(dpad.width)) arm.shift(dpad.topLeft).translate(0, -topBarHeightPx)];
}

void main() {
  setUpAll(loadHostFonts);
  setUpAll(loadPuzzles);

  // The two phone sizes the board was wrong at, and the D-pad's drawn side
  // each gets from `padLayout`: 317 device px at 852x393 and 213 at 640x360
  // (the width caps at the room's half less its insets, the height at 58 mm).
  const cases = [(size: Size(852, 393), dpadSidePx: 317.0), (size: Size(640, 360), dpadSidePx: 213.0)];

  for (final (:size, :dpadSidePx) in cases) {
    testWidgets('a board played on this phone keeps clear of the pad\'s drawn arms at '
        '${size.width.toInt()}x${size.height.toInt()}', (tester) async {
      await pumpHostApp(tester, screen: size);
      final host = await soloRound(tester);

      // The board draws in the frame the gate lays out in the room below the
      // bar: 1349.21x540 frame px at 852x393, 1122.1x540 at 640x360.
      final s = frameScaleAt(size);
      final info = find.byType(party.HostFrameInfo);
      expect(tester.widget<party.HostFrameInfo>(info.first).scale, closeTo(s, 1e-9));

      // The pad this phone draws over its round, in device px: its D-pad is
      // the square the layout gives it.
      final dpad = tester.getRect(find.byKey(const Key('dpad')));
      expect(dpad.width, closeTo(dpadSidePx, 1e-6), reason: 'the D-pad is $dpadSidePx device px here');

      // The board must keep clear of the arms as they are drawn, in its own
      // box: in frame px, so each drawn arm is divided by the frame's scale.
      final arms = drawnArmsInBoardBox(tester);
      final play = tester.widget<PuzzlePlayView>(find.byType(PuzzlePlayView));
      expect(play.padRects.length, arms.length);
      for (var i = 0; i < arms.length; i++) {
        expect(play.padRects[i].left, closeTo(arms[i].left / s, 1e-6), reason: 'rect $i left');
        expect(play.padRects[i].top, closeTo(arms[i].top / s, 1e-6), reason: 'rect $i top');
        expect(play.padRects[i].right, closeTo(arms[i].right / s, 1e-6), reason: 'rect $i right');
        expect(play.padRects[i].bottom, closeTo(arms[i].bottom / s, 1e-6), reason: 'rect $i bottom');
      }

      await tester.runAsync(host.dispose);
    });
  }
}
