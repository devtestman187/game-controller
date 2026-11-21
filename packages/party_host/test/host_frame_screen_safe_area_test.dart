import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';

import 'support/toy_fonts.dart';

/// The slack the frame's math is compared with, as `host_frame_test.dart` has
/// it: [Size] is two doubles, and 1024 x 768 gives a frame width of 960 within
/// one part in 10^15.
const _tolerance = 1e-9;

/// A notched phone in landscape, in device px: a 30 px notch above, a 20 px
/// home bar below and the cutout's 40 px corners.
const _notch = FakeViewPadding(top: 30, bottom: 20, left: 40, right: 40);

/// One device, with the scale and the frame the design's math gives it (DESIGN
/// section 2; the numbers are `host_frame_test.dart`'s).
class _Case {
  const _Case({required this.label, required this.device, required this.scale, required this.frame});

  /// The device in the brief's words, for the test's name.
  final String label;

  /// The device's logical size: its physical size at a device pixel ratio of 1.
  final Size device;

  /// How many device logical pixels one frame pixel is drawn at.
  final double scale;

  /// The size the host lays out in, in frame px.
  final Size frame;

  /// A device inset in frame px: the frame divides the device's insets by the
  /// scale (`host_frame.dart`), so the same strip of the screen is covered.
  double frameInset(double deviceInset) => deviceInset / scale;
}

/// The five devices every slice of the phone-host layout is checked at:
///
/// * 640x360, a small phone: s = 640/960 = .667, frame 960x540.
/// * 852x393, a phone in landscape: s = 393/540 = .728, frame 1170.687x540.
/// * 1024x768, a tablet: s = 1024/960 = 1.067, frame 960x720.
/// * 1280x800, a laptop: s = 1280/960 = 1.333, frame 960x600.
/// * 1920x1080, the TV: s = 1920/960 = 2, frame 960x540.
const _cases = [
  _Case(label: '640x360, a small phone', device: Size(640, 360), scale: 0.6666666666666666, frame: Size(960, 540)),
  _Case(
    label: '852x393, a phone in landscape',
    device: Size(852, 393),
    scale: 0.7277777777777777,
    frame: Size(1170.6870229007634, 540),
  ),
  _Case(label: '1024x768, a tablet', device: Size(1024, 768), scale: 1.0666666666666667, frame: Size(960, 720)),
  _Case(label: '1280x800, a laptop', device: Size(1280, 800), scale: 1.3333333333333333, frame: Size(960, 600)),
  _Case(label: '1920x1080, the TV', device: Size(1920, 1080), scale: 2, frame: Size(960, 540)),
];

/// The two sizes a notched phone host is checked at (the brief's pair).
final _notchedCases = [_cases[0], _cases[1]];

/// The keys the scaffold's three regions are found by.
const _headerKey = Key('hostFrameHeader');
const _bodyKey = Key('hostFrameBody');
const _footerKey = Key('hostFrameFooter');

/// The night's two round choices, as the header's segment offers them.
const _roundOptions = [RoundOption(value: 3, label: '3 rounds'), RoundOption(value: 5, label: '5 rounds')];

/// The look the frame's screens are drawn in: the TV's sizes, which are the
/// frame's, in the Sunny palette.
ToyLook _look() => ToyLook.build(palette: ToyPalette.sunny, tv: true);

/// Mounts [home] the way a host app does (DESIGN section 5): the app's
/// [ProviderScope], the look and its theme, and the frame above the navigator
/// at [device]'s size with a device pixel ratio of 1. When [padding] is given,
/// the device claims that safe area, as a notched phone does.
Future<void> _pumpFrame(WidgetTester tester, Size device, {required Widget home, FakeViewPadding? padding}) async {
  final look = _look();
  tester.view.physicalSize = device;
  tester.view.devicePixelRatio = 1;
  if (padding != null) tester.view.padding = padding;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      child: ToyLookScope(
        look: look,
        child: MaterialApp(theme: toyTheme(look), builder: hostFrameBuilder, home: home),
      ),
    ),
  );
}

/// The screen the frame holds: the header's title and round segment, a body
/// that fills its box, and the footer's button.
class _TestScreen extends StatelessWidget {
  const _TestScreen({required this.trailing});

  final Widget trailing;

  @override
  Widget build(BuildContext context) => HostFrameScreen(
    title: 'Party night',
    trailing: trailing,
    body: const SizedBox.expand(key: Key('bodyFill')),
    footer: const [ToyButton(label: 'Start', onPressed: _ignore)],
  );
}

void _ignore() {}

void main() {
  setUpAll(loadLookFonts);

  for (final frameCase in _notchedCases) {
    testWidgets('${frameCase.label}: a notched phone draws the header and footer inside its safe area', (tester) async {
      await _pumpFrame(
        tester,
        frameCase.device,
        padding: _notch,
        home: const _TestScreen(trailing: SizedBox.shrink()),
      );

      // The header starts under the notch and stops one header short of it,
      // and the footer stops above the home bar (device px: the frame's
      // rects are drawn at the scale).
      final header = tester.getRect(find.byKey(_headerKey));
      expect(header.top, moreOrLessEquals(_notch.top, epsilon: _tolerance), reason: 'the notch is claimed once');
      expect(header.left, moreOrLessEquals(_notch.left, epsilon: _tolerance));
      expect(header.right, moreOrLessEquals(frameCase.device.width - _notch.right, epsilon: _tolerance));
      expect(
        header.height,
        moreOrLessEquals(64 * frameCase.scale, epsilon: _tolerance),
        reason: 'the header keeps its 64 frame px inside the safe area',
      );

      final footer = tester.getRect(find.byKey(_footerKey));
      expect(footer.bottom, moreOrLessEquals(frameCase.device.height - _notch.bottom, epsilon: _tolerance));
      expect(footer.height, moreOrLessEquals(84 * frameCase.scale, epsilon: _tolerance));

      // The body is what gives the insets their room: it takes the frame less
      // the insets, the header and the footer, and still fills its width.
      final body = tester.getSize(find.byKey(_bodyKey));
      expect(
        body.height,
        moreOrLessEquals(
          frameCase.frame.height - 64 - 84 - frameCase.frameInset(_notch.top) - frameCase.frameInset(_notch.bottom),
          epsilon: _tolerance,
        ),
        reason: 'the body is the only part that flexes',
      );
      expect(
        body.width,
        moreOrLessEquals(
          frameCase.frame.width - frameCase.frameInset(_notch.left) - frameCase.frameInset(_notch.right),
          epsilon: _tolerance,
        ),
      );
      expect(tester.takeException(), isNull, reason: 'nothing overflows the frame');
    });

    testWidgets('${frameCase.label}: without a safe area the header and footer take the frame\'s edges', (
      tester,
    ) async {
      await _pumpFrame(tester, frameCase.device, home: const _TestScreen(trailing: SizedBox.shrink()));

      final header = tester.getRect(find.byKey(_headerKey));
      expect(header.top, moreOrLessEquals(0, epsilon: _tolerance));
      expect(header.left, moreOrLessEquals(0, epsilon: _tolerance));
      expect(header.right, moreOrLessEquals(frameCase.device.width, epsilon: _tolerance));
      expect(header.height, moreOrLessEquals(64 * frameCase.scale, epsilon: _tolerance));

      final footer = tester.getRect(find.byKey(_footerKey));
      expect(footer.bottom, moreOrLessEquals(frameCase.device.height, epsilon: _tolerance));
      expect(footer.height, moreOrLessEquals(84 * frameCase.scale, epsilon: _tolerance));

      final body = tester.getSize(find.byKey(_bodyKey));
      expect(body.height, moreOrLessEquals(frameCase.frame.height - 64 - 84, epsilon: _tolerance));
      expect(body.width, moreOrLessEquals(frameCase.frame.width, epsilon: _tolerance));
      expect(tester.takeException(), isNull);
    });
  }

  for (final frameCase in _cases) {
    testWidgets('${frameCase.label}: the 48 px round chip fits the 64 px header beside its title', (tester) async {
      await _pumpFrame(
        tester,
        frameCase.device,
        home: const _TestScreen(
          trailing: RoundSegment(value: 3, onChanged: _ignoreChoice, options: _roundOptions),
        ),
      );

      final header = tester.getRect(find.byKey(_headerKey));
      final chip = tester.getRect(find.byType(RoundSegment));
      expect(
        tester.getSize(find.byType(RoundSegment)).height,
        moreOrLessEquals(roundChipHeightPx, epsilon: _tolerance),
        reason: 'the chip is 48 frame px',
      );
      expect(chip.top, greaterThanOrEqualTo(header.top), reason: 'the chip is inside the header, not over its edge');
      expect(chip.bottom, lessThanOrEqualTo(header.bottom));
      expect(
        chip.top - header.top,
        moreOrLessEquals((64 - roundChipHeightPx) / 2 * frameCase.scale, epsilon: _tolerance),
        reason: '8 frame px of the look\'s room above and below the chip',
      );

      // The title starts at the frame's gutter and stops before the chip.
      final title = tester.getRect(find.text('Party night'));
      expect(
        title.left,
        moreOrLessEquals(hostFrameGutterPx * frameCase.scale, epsilon: _tolerance),
        reason: 'the title is at the header\'s left, hostFrameGutterPx from the frame\'s edge',
      );
      expect(title.right, lessThanOrEqualTo(chip.left - 16 * frameCase.scale));
      expect(tester.takeException(), isNull);
    });
  }
}

void _ignoreChoice(int _) {}
