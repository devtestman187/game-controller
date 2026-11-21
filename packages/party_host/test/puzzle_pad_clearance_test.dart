import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:puzzle_game/puzzle_game.dart';

import 'support/host_harness.dart';

/// The phone's own density, in device px per mm: 160 dpi / 25.4 (the host
/// app's `pxPerMmProvider` on a 1x phone, and `phonePxPerMm`).
const _devicePxPerMm = 6.299212598425197;

/// The phone host's bar, in device px (`topBarHeightPx`): its gate gives the
/// frame the screen less this, so 852x393 leaves a 852x341 room.
const _hostBarPx = 52.0;

/// The design frame every host screen is laid out in (host_frame.dart).
const _frameWidthPx = 960.0;
const _frameHeightPx = 540.0;

/// The up arm of the pad the phone draws over the game it hosts, and its left
/// arm, in device px (wph-report, "The board's pad clearance").
const _upArmDevice = Rect.fromLTRB(129.6, 60.0, 237.4, 218.5);
const _leftArmDevice = Rect.fromLTRB(25.0, 164.6, 183.5, 272.4);

/// The scale and frame [HostFrame] makes of the room the phone host's gate
/// leaves at [screen] (DESIGN section 2): `s = min(W/960, H/540)` over the
/// room below the bar, 0.63148148 at 852x393 and 0.57037037 at 640x360.
Size roomBelowBar(Size screen) => Size(screen.width, screen.height - _hostBarPx);

double frameScale(Size room) => min(room.width / _frameWidthPx, room.height / _frameHeightPx);

/// Opens a phones round that keeps clear of a pad whose device rects are
/// [deviceRects], and returns its play view. [asked] receives the box the pad
/// was asked about. [framed] draws the app in [HostFrame], as both host apps
/// do; [size] is the device's size.
Future<PuzzlePlayView> openRoundWithPad(
  WidgetTester tester, {
  required Size size,
  required List<Rect> deviceRects,
  required void Function(Size box) asked,
  bool framed = false,
}) async {
  const teams = {'p1': PuzzleSide.left, 'p2': PuzzleSide.right};
  final match = PuzzleMatch(housePuzzle(), teams: teams, random: Random(1), target: LayoutTarget.phones);
  final fake = await pumpHost(
    tester,
    screen: const StubHome(),
    size: size,
    framed: framed,
    overrides: [
      hostPadProvider.overrideWithValue((
        pxPerMm: _devicePxPerMm,
        rects: (Size box) {
          asked(box);
          return deviceRects;
        },
      )),
    ],
  );
  fake.shareView = true;
  tester
      .state<NavigatorState>(find.byType(Navigator))
      .push(
        MaterialPageRoute<void>(
          builder: (_) => PuzzleScreen(
            choice: const PuzzleChoice(level: Level.easy),
            teams: teams,
            match: match,
          ),
        ),
      );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  return tester.widget<PuzzlePlayView>(find.byType(PuzzlePlayView));
}

/// [rect] in frame px, from the device px it is measured in at [scale]: every
/// edge divided by the scale (`device = frame x s`).
Rect frameRect(Rect rect, double scale) =>
    Rect.fromLTRB(rect.left / scale, rect.top / scale, rect.right / scale, rect.bottom / scale);

/// [actual] matches [expected] to the last bit a frame's scale allows.
void expectRects(List<Rect> actual, List<Rect> expected) {
  expect(actual.length, expected.length);
  for (var i = 0; i < expected.length; i++) {
    expect(actual[i].left, closeTo(expected[i].left, 1e-9), reason: 'rect $i left');
    expect(actual[i].top, closeTo(expected[i].top, 1e-9), reason: 'rect $i top');
    expect(actual[i].right, closeTo(expected[i].right, 1e-9), reason: 'rect $i right');
    expect(actual[i].bottom, closeTo(expected[i].bottom, 1e-9), reason: 'rect $i bottom');
  }
}

void main() {
  for (final screen in const [Size(852, 393), Size(640, 360)]) {
    testWidgets('a board in the frame keeps clear of the pad\'s device rects, divided by the scale, at '
        '${screen.width.toInt()}x${screen.height.toInt()}', (tester) async {
      final room = roomBelowBar(screen);
      final s = frameScale(room);
      Size? asked;
      final view = await openRoundWithPad(
        tester,
        size: room,
        framed: true,
        deviceRects: const [_upArmDevice, _leftArmDevice],
        asked: (box) => asked = box,
      );

      // The app is in the frame the gate's room makes it.
      final info = tester.widget<HostFrameInfo>(find.byType(HostFrameInfo).first);
      expect(info.scale, closeTo(s, 1e-9));
      expect(info.frame.height, closeTo(_frameHeightPx, 1e-9));

      // The pad is asked about the board as the device shows it, so its
      // answer is a device measurement: the room, not the frame.
      expect(asked, isNotNull);
      expect(asked!.width, closeTo(room.width, 1e-6), reason: 'the pad is asked about the device box');
      expect(asked!.height, closeTo(room.height, 1e-6));

      // The board, laid out in frame px, gets those rects back in its own px.
      expectRects(view.padRects, [
        for (final rect in const [_upArmDevice, _leftArmDevice]) frameRect(rect, s),
      ]);
      expect(view.pxPerMm, closeTo(_devicePxPerMm / s, 1e-9));
    });
  }

  testWidgets('a board with no frame above gets the pad\'s rects and density as they are', (tester) async {
    // The TV, and "Show on this device": the board is the device, so there is
    // no scale between the pad's answer and the box it is laid out in.
    Size? asked;
    final view = await openRoundWithPad(
      tester,
      size: const Size(960, 540),
      deviceRects: const [_upArmDevice],
      asked: (box) => asked = box,
    );
    expect(find.byType(HostFrameInfo), findsNothing);
    final box = tester.getSize(find.byType(PuzzlePlayView));
    expect(asked, box);
    expectRects(view.padRects, const [_upArmDevice]);
    expect(view.pxPerMm, _devicePxPerMm);
  });
}
