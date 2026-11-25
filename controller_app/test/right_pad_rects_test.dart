import 'package:controller/src/gyro.dart';
import 'package:controller/src/host/host_start_sheet.dart';
import 'package:controller/src/layout.dart';
import 'package:controller/src/sticks.dart';
import 'package:controller/src/ui/joined_view.dart';
import 'package:controller/src/ui/top_bar_metrics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart' as party;

import 'support/host_app.dart';

/// The two screens the right hand's controls are tested on: a tablet held
/// upright, where the HUD must keep clear of them (B-044), and the owner's
/// phone on its side (m12-phone-layout §0.2).
const portrait = Size(1640, 2360);
const landscape = Size(852, 393);

/// The room a host screen lays its pad out in, below its bar, in device px.
const hostRoom = Size(852, 340);

const fixedSticks = StickSettings();
const floatingSticks = StickSettings(floating: true);

/// Whether [rect] lies inside a screen of [box].
bool inside(Rect rect, Size box) =>
    rect.left >= 0 && rect.top >= 0 && rect.right <= box.width && rect.bottom <= box.height;

/// The Start button as the right hand's layout draws it in [box], under the bar.
Rect startOf(Size box, PadMode mode, StickSettings sticks) {
  final body = Size(box.width, box.height - topBarHeightPx);
  final bar = const Offset(0, topBarHeightPx);
  final start = mode == PadMode.sticks ? stickLayout(body, buttonSize: sticks.buttonSize).start : padLayout(body).start;
  return start.shift(bar);
}

void main() {
  // The modes, each with how many rects its right hand has: the face buttons
  // and Start, and the right stick (or its zone when floating) in stick mode.
  const cases = [
    ('D-pad', PadMode.dpad, StickSettings(), 2),
    ('fixed sticks', PadMode.sticks, fixedSticks, 3),
    ('floating sticks', PadMode.sticks, floatingSticks, 3),
    ('gyro', PadMode.gyro, StickSettings(), 2),
  ];

  group('rightPadRects: the right hand\'s controls, which the HUD keeps clear of (B-044)', () {
    for (final box in [portrait, landscape]) {
      for (final (name, mode, sticks, count) in cases) {
        test('$name at $box: $count rects inside the box, the Start button among them', () {
          final rects = rightPadRects(box, mode: mode, mm: phonePxPerMm, sticks: sticks);
          expect(rects.length, count);
          for (final rect in rects) {
            expect(inside(rect, box), isTrue, reason: '$rect is outside $box');
          }
          expect(rects, contains(startOf(box, mode, sticks)));
        });

        test('$name at $box: no right-hand rect meets a left-hand rect', () {
          final rects = rightPadRects(box, mode: mode, mm: phonePxPerMm, sticks: sticks);
          final left = leftPadRects(box, mode: mode, mm: phonePxPerMm, sticks: sticks);
          for (final rect in rects) {
            for (final other in left) {
              expect(rect.overlaps(other), isFalse, reason: '$rect meets $other');
            }
          }
        });
      }
    }
  });

  group('the host phone\'s HUD rects (B-044)', () {
    testWidgets('"Play on this phone" gives the right hand\'s rects, moved up into the room as the pad\'s are', (
      tester,
    ) async {
      await pumpHostApp(tester);
      final host = await soloRound(tester);
      final pad = hostContainer(tester).read(party.hostPadProvider);
      final mode = hostContainer(tester).read(gyroProvider).mode;
      final sticks = hostContainer(tester).read(stickSettingsProvider);
      // The room's rects are asked for the room plus the bar, then moved back
      // up by the bar, as _hostPadRects does for the left hand.
      final expected = [
        for (final rect in rightPadRects(
          Size(hostRoom.width, hostRoom.height + topBarHeightPx),
          mode: mode,
          mm: pad.pxPerMm,
          sticks: sticks,
        ))
          rect.translate(0, -topBarHeightPx),
      ];
      expect(pad.hudRects(hostRoom), expected);
      await tester.runAsync(host.dispose);
    });

    testWidgets('"Show on this device" shares no view, so it gives the HUD no rects', (tester) async {
      await pumpHostApp(tester);
      final host = await enterHostMode(tester, choice: HostChoice.onDevice);
      final pad = hostContainer(tester).read(party.hostPadProvider);
      expect(pad.hudRects(portrait), isEmpty);
      await tester.runAsync(host.dispose);
    });
  });
}
