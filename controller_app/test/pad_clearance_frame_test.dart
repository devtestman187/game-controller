import 'dart:math' as math;

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

/// [rect] in frame px, from the device px it is measured in at [scale].
Rect frameRect(Rect rect, double scale) =>
    Rect.fromLTRB(rect.left / scale, rect.top / scale, rect.right / scale, rect.bottom / scale);

void main() {
  setUpAll(loadHostFonts);
  setUpAll(loadPuzzles);

  testWidgets('the board under the gate keeps clear of the pad\'s device rects, divided by the scale', (tester) async {
    // [pumpHostApp]'s 852x393 screen: the gate lays the frame out in 852x341 of
    // device px (scale 0.63148148), so the board draws in 1349.21x540 frame px
    // while the pad measures on the screen (M16 phonehost3 pad).
    const screen = Size(852, 393);
    final s = frameScaleAt(screen);
    await pumpHostApp(tester);
    final host = await soloRound(tester);

    final info = tester.widget<party.HostFrameInfo>(find.byType(party.HostFrameInfo).first);
    expect(info.scale, closeTo(s, 1e-9), reason: 'the round is drawn in the gate\'s frame');

    // The pad's own answer about the board as the device shows it: the room
    // below the bar, 852 x 341 device px.
    final play = tester.widget<PuzzlePlayView>(find.byType(PuzzlePlayView));
    final playBox = tester.getSize(find.byType(PuzzlePlayView));
    final deviceBox = Size(playBox.width * s, playBox.height * s);
    expect(deviceBox.width, closeTo(screen.width, 1e-6));
    expect(deviceBox.height, closeTo(screen.height - topBarHeightPx, 1e-6));
    final pad = hostContainer(tester).read(party.hostPadProvider);
    final deviceRects = pad.rects(deviceBox);
    expect(deviceRects, isNotEmpty, reason: 'the phone draws a pad over the round it hosts');
    expect(play.padRects.length, deviceRects.length);
    for (var i = 0; i < deviceRects.length; i++) {
      final expected = frameRect(deviceRects[i], s);
      expect(play.padRects[i].left, closeTo(expected.left, 1e-6), reason: 'rect $i left');
      expect(play.padRects[i].top, closeTo(expected.top, 1e-6), reason: 'rect $i top');
      expect(play.padRects[i].right, closeTo(expected.right, 1e-6), reason: 'rect $i right');
      expect(play.padRects[i].bottom, closeTo(expected.bottom, 1e-6), reason: 'rect $i bottom');
    }
    expect(play.pxPerMm, closeTo(pad.pxPerMm / s, 1e-9));

    await tester.runAsync(host.dispose);
  });
}
