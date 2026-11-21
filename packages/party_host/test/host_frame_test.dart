import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';

/// The slack the frame's math is compared with: [Size] is two doubles, and
/// 1024 x 768 gives a frame width of 960 within one part in 10^15.
const _tolerance = 1e-9;

/// The key on the probe the frame wraps: its render box carries the frame's
/// layout size.
const _probeKey = Key('probe');

/// The key on the button the hit test taps.
const _buttonKey = Key('button');

/// One device with what the design's math gives it (DESIGN sections 2 and 3):
/// the scale, the frame, the frame's spare dimensions and the spot Thumby
/// takes.
class _Case {
  const _Case({
    required this.label,
    required this.device,
    required this.scale,
    required this.frame,
    required this.extraW,
    required this.extraH,
    required this.spot,
  });

  /// The device in the brief's words, for the test's name.
  final String label;

  /// The device's logical size: its physical size at a device pixel ratio of 1.
  final Size device;

  /// How many device logical pixels one frame pixel is drawn at.
  final double scale;

  /// The size the host lays out in, in frame px.
  final Size frame;

  /// The frame's spare width, in frame px.
  final double extraW;

  /// The frame's spare height, in frame px.
  final double extraH;

  /// Where the frame puts Thumby.
  final ThumbySpot spot;
}

/// The devices the host is checked at, with the numbers the design's math
/// gives them (computed for this test; see the report):
///
/// * 640x360, a small phone: s = 640/960 = .667, frame 960x540, no spare.
/// * 852x393, a phone in landscape: s = 393/540 = .728, frame 1170.687x540,
///   extra width 210.687.
/// * 1024x768, a tablet: s = 1024/960 = 1.067, frame 960x720, extra height 180.
/// * 1280x800, a laptop: s = 1280/960 = 1.333, frame 960x600, extra height 60.
/// * 1920x1080, the TV: s = 1920/960 = 2, frame 960x540, no spare.
const _cases = [
  _Case(
    label: '640x360, a small phone',
    device: Size(640, 360),
    scale: 0.6666666666666666,
    frame: Size(960, 540),
    extraW: 0,
    extraH: 0,
    spot: ThumbySpot.corner,
  ),
  _Case(
    label: '852x393, a phone in landscape',
    device: Size(852, 393),
    scale: 0.7277777777777777,
    frame: Size(1170.6870229007634, 540),
    extraW: 210.68702290076344,
    extraH: 0,
    spot: ThumbySpot.side,
  ),
  _Case(
    label: '1024x768, a tablet',
    device: Size(1024, 768),
    scale: 1.0666666666666667,
    frame: Size(960, 720),
    extraW: 0,
    extraH: 180,
    spot: ThumbySpot.strip,
  ),
  _Case(
    label: '1280x800, a laptop',
    device: Size(1280, 800),
    scale: 1.3333333333333333,
    frame: Size(960, 600),
    extraW: 0,
    extraH: 60,
    spot: ThumbySpot.corner,
  ),
  _Case(
    label: '1920x1080, the TV',
    device: Size(1920, 1080),
    scale: 2,
    frame: Size(960, 540),
    extraW: 0,
    extraH: 0,
    spot: ThumbySpot.corner,
  ),
];

/// What the probe saw: the frame the host gives a screen, and the media query
/// a screen reads inside it.
typedef _Seen = ({
  double scale,
  Size frame,
  double extraW,
  double extraH,
  ThumbySpot spot,
  Size mediaSize,
  double devicePixelRatio,
  EdgeInsets padding,
});

/// The screen the frame wraps in these tests: reports what it sees, then fills
/// the frame so its layout size can be read back.
class _Probe extends StatelessWidget {
  const _Probe(this.seen);

  /// Takes what the probe saw, once per build.
  final void Function(_Seen seen) seen;

  @override
  Widget build(BuildContext context) {
    final info = HostFrameInfo.of(context);
    final media = MediaQuery.of(context);
    seen((
      scale: info.scale,
      frame: info.frame,
      extraW: info.extraW,
      extraH: info.extraH,
      spot: info.thumbySpot,
      mediaSize: media.size,
      devicePixelRatio: media.devicePixelRatio,
      padding: media.padding,
    ));
    return const SizedBox.expand(key: _probeKey);
  }
}

/// A probe that keeps nothing: a test that only needs the room the frame gives
/// the stage.
void _ignore(_Seen seen) {}

/// Mounts [home] the way a host app will (DESIGN section 5): a MaterialApp
/// whose builder puts the frame above the navigator, at [device]'s size with a
/// device pixel ratio of 1, so logical and physical pixels are the same.
Future<void> pumpFrame(WidgetTester tester, Size device, {required Widget home}) async {
  tester.view.physicalSize = device;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(builder: hostFrameBuilder, home: home));
}

void main() {
  for (final frameCase in _cases) {
    testWidgets('${frameCase.label}: the screen is laid out at the frame, not the device', (tester) async {
      _Seen? seen;
      await pumpFrame(tester, frameCase.device, home: _Probe((value) => seen = value));

      expect(seen, isNotNull);
      final laidOut = tester.getSize(find.byKey(_probeKey));
      expect(laidOut.width, moreOrLessEquals(frameCase.frame.width, epsilon: _tolerance));
      expect(laidOut.height, moreOrLessEquals(frameCase.frame.height, epsilon: _tolerance));
      expect(seen!.mediaSize.width, moreOrLessEquals(frameCase.frame.width, epsilon: _tolerance));
      expect(seen!.mediaSize.height, moreOrLessEquals(frameCase.frame.height, epsilon: _tolerance));
      expect(seen!.devicePixelRatio, 1);

      // The frame is drawn over the whole device: the probe's paint rect is
      // the device's, though it was laid out in the frame's own pixels.
      final painted = tester.getRect(find.byKey(_probeKey));
      expect(painted.width, moreOrLessEquals(frameCase.device.width, epsilon: _tolerance));
      expect(painted.height, moreOrLessEquals(frameCase.device.height, epsilon: _tolerance));
    });

    testWidgets('${frameCase.label}: the frame info gives scale, frame, spare room and the Thumby spot', (
      tester,
    ) async {
      _Seen? seen;
      await pumpFrame(tester, frameCase.device, home: _Probe((value) => seen = value));

      expect(seen!.scale, moreOrLessEquals(frameCase.scale, epsilon: _tolerance));
      expect(seen!.frame.width, moreOrLessEquals(frameCase.frame.width, epsilon: _tolerance));
      expect(seen!.frame.height, moreOrLessEquals(frameCase.frame.height, epsilon: _tolerance));
      expect(seen!.extraW, moreOrLessEquals(frameCase.extraW, epsilon: _tolerance));
      expect(seen!.extraH, moreOrLessEquals(frameCase.extraH, epsilon: _tolerance));
      // The spare room is never negative, and only one dimension ever has any.
      expect(seen!.extraW, greaterThanOrEqualTo(0));
      expect(seen!.extraH, greaterThanOrEqualTo(0));
      expect(seen!.extraW > 0 && seen!.extraH > 0, isFalse);
      expect(seen!.spot, frameCase.spot);
    });
  }

  testWidgets('a tap at a device pixel lands on the button drawn under it', (tester) async {
    var taps = 0;
    await pumpFrame(
      tester,
      const Size(640, 360),
      home: Scaffold(
        body: Stack(
          children: [
            Positioned(
              left: 100,
              top: 50,
              width: 200,
              height: 60,
              child: FilledButton(key: _buttonKey, onPressed: () => taps++, child: const Text('Go')),
            ),
          ],
        ),
      ),
    );

    // 640x360 is a scale of 2/3, so the button's frame rect of 100,50 200x60
    // is drawn at 66.67,33.33 133.33x40 on the device.
    final rect = tester.getRect(find.byKey(_buttonKey));
    expect(rect.left, moreOrLessEquals(100 * 2 / 3, epsilon: _tolerance));
    expect(rect.top, moreOrLessEquals(50 * 2 / 3, epsilon: _tolerance));
    expect(rect.width, moreOrLessEquals(200 * 2 / 3, epsilon: _tolerance));
    expect(rect.height, moreOrLessEquals(60 * 2 / 3, epsilon: _tolerance));

    // The button's middle is 200,80 in the frame: 133.33,53.33 on the device.
    await tester.tapAt(const Offset(200 * 2 / 3, 80 * 2 / 3));
    await tester.pump();
    expect(taps, 1);

    // A tap on the frame's empty right side, 700,400 in frame px, misses it.
    await tester.tapAt(const Offset(700 * 2 / 3, 400 * 2 / 3));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('at 1920x1080 a pad press moves the focus to the next button', (tester) async {
    final first = FocusNode();
    final second = FocusNode();
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    await pumpFrame(
      tester,
      const Size(1920, 1080),
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(focusNode: first, autofocus: true, onPressed: () {}, child: const Text('One')),
              TextButton(focusNode: second, onPressed: () {}, child: const Text('Two')),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    expect(first.hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(second.hasFocus, isTrue);
    expect(first.hasFocus, isFalse);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(first.hasFocus, isTrue);
  });

  testWidgets('the Thumby slot draws nothing and reserves no room until M17', (tester) async {
    await pumpFrame(
      tester,
      const Size(852, 393),
      home: const Column(
        children: [
          ThumbySlot(),
          Expanded(child: _Probe(_ignore)),
        ],
      ),
    );

    expect(tester.getSize(find.byType(ThumbySlot)), Size.zero);
    // The stage still has the whole frame: nothing was taken for him.
    expect(tester.getSize(find.byKey(_probeKey)).height, moreOrLessEquals(540, epsilon: _tolerance));
  });

  testWidgets('the Thumby slot draws nothing outside the frame either', (tester) async {
    // Centre gives it loose constraints, as a row or a column would.
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: ThumbySlot()),
      ),
    );
    expect(tester.getSize(find.byType(ThumbySlot)), Size.zero);
  });

  testWidgets('a device safe area is the same strip of screen inside the frame', (tester) async {
    tester.view.padding = const FakeViewPadding(top: 40, left: 60);
    addTearDown(tester.view.reset);
    _Seen? seen;
    await pumpFrame(tester, const Size(1920, 1080), home: _Probe((value) => seen = value));

    // 1920x1080 is drawn at scale 2, so 40 and 60 device px are 20 and 30
    // frame px.
    expect(seen!.padding.top, moreOrLessEquals(20, epsilon: _tolerance));
    expect(seen!.padding.left, moreOrLessEquals(30, epsilon: _tolerance));
  });

  testWidgets('outside the frame there is no frame info to read', (tester) async {
    HostFrameInfo? found;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            found = HostFrameInfo.maybeOf(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(found, isNull);
  });
}
