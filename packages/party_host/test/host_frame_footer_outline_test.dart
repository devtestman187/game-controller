import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';

import 'support/toy_fonts.dart';

/// The slack the frame's math is compared with, as `host_frame_screen_test.dart`
/// has it: [Size] is two doubles, and 960 frame px at s = 2 come to 1920 within
/// one part in 10^15.
const _tolerance = 1e-6;

/// One device, with the scale one frame px is drawn at (the numbers are
/// `host_frame_screen_test.dart`'s).
class _Case {
  const _Case({required this.label, required this.device, required this.scale});

  /// The device in the brief's words, for the test's name.
  final String label;

  /// The device's logical size: its physical size at a device pixel ratio of 1.
  final Size device;

  /// How many device logical pixels one frame pixel is drawn at.
  final double scale;
}

/// The five devices every slice of the phone-host layout is checked at:
///
/// * 640x360, a small phone: s = 640/960 = .667, frame 960x540.
/// * 852x393, a phone in landscape: s = 393/540 = .728, frame 1170.687x540.
/// * 1024x768, a tablet: s = 1024/960 = 1.067, frame 960x720.
/// * 1280x800, a laptop: s = 1280/960 = 1.333, frame 960x600.
/// * 1920x1080, the TV: s = 1920/960 = 2, frame 960x540.
const _cases = [
  _Case(label: '640x360, a small phone', device: Size(640, 360), scale: 0.6666666666666666),
  _Case(label: '852x393, a phone in landscape', device: Size(852, 393), scale: 0.7277777777777777),
  _Case(label: '1024x768, a tablet', device: Size(1024, 768), scale: 1.0666666666666667),
  _Case(label: '1280x800, a laptop', device: Size(1280, 800), scale: 1.3333333333333333),
  _Case(label: '1920x1080, the TV', device: Size(1920, 1080), scale: 2),
];

/// The footer and its band, and the band's two buttons.
const _footerKey = Key('hostFrameFooter');
const _bandKey = Key('hostFrameFooterBand');
const _firstButtonKey = Key('footerFirst');
const _secondButtonKey = Key('footerSecond');

/// The look the frame's screens are drawn in: the TV's sizes (a 4 px outline,
/// 64 px buttons), in the Sunny palette.
ToyLook _look() => ToyLook.build(palette: ToyPalette.sunny, tv: true);

/// Mounts [home] the way a host app does (DESIGN section 5): the app's
/// [ProviderScope], the look and its theme, and the frame above the navigator
/// at [device]'s size with a device pixel ratio of 1. Returns the look the
/// screen was drawn in.
Future<ToyLook> _pumpFrame(WidgetTester tester, Size device, {required Widget home}) async {
  final look = _look();
  tester.view.physicalSize = device;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      child: ToyLookScope(
        look: look,
        child: MaterialApp(theme: toyTheme(look), builder: hostFrameBuilder, home: home),
      ),
    ),
  );
  return look;
}

/// A screen whose footer holds two way-on buttons: the buttons the band's
/// outline has to hold whole (B-034).
class _FooterScreen extends StatelessWidget {
  const _FooterScreen();

  @override
  Widget build(BuildContext context) => HostFrameScreen(
    title: 'Party night',
    body: const SizedBox.shrink(),
    footer: [
      ToyButton(key: _firstButtonKey, label: 'Shape Race', onPressed: () {}),
      ToyButton(key: _secondButtonKey, label: 'Bumper Round', onPressed: () {}),
    ],
  );
}

void main() {
  setUpAll(loadLookFonts);

  for (final frameCase in _cases) {
    testWidgets('${frameCase.label}: the footer band is a rounded ink outline on all four sides', (tester) async {
      final look = await _pumpFrame(tester, frameCase.device, home: const _FooterScreen());
      final scale = frameCase.scale;
      final outlinePx = look.sizes.outlineWidth;

      // The footer keeps its 84 px: the band is drawn inside it (B-034).
      final footer = tester.getRect(find.byKey(_footerKey));
      expect(
        footer.height,
        moreOrLessEquals(hostFrameFooterHeightPx * scale, epsilon: _tolerance),
        reason: 'the footer stays 84 frame px',
      );

      final decoration = tester.widget<DecoratedBox>(find.byKey(_bandKey)).decoration as BoxDecoration;
      expect(decoration.color, look.colors.paper, reason: 'the buttons stand on the look\'s paper');
      final border = decoration.border as Border;
      for (final (side, name) in [
        (border.top, 'top'),
        (border.right, 'right'),
        (border.bottom, 'bottom'),
        (border.left, 'left'),
      ]) {
        expect(side.color, look.colors.ink, reason: 'the band\'s $name is a line of ink (B-034)');
        expect(side.width, moreOrLessEquals(outlinePx, epsilon: _tolerance), reason: 'the look\'s outline width');
      }
      expect(
        decoration.borderRadius,
        BorderRadius.circular(ToySizes.cardCorner),
        reason: 'the band is rounded like the look\'s cards',
      );

      // The band keeps its inset from the frame's sides and bottom, so every
      // side of the outline is inside the frame; its top is the footer's top.
      final band = tester.getRect(find.byKey(_bandKey));
      final inset = hostFrameFooterInsetPx * scale;
      expect(band.top, moreOrLessEquals(footer.top, epsilon: _tolerance));
      expect(band.left - footer.left, moreOrLessEquals(inset, epsilon: _tolerance));
      expect(footer.right - band.right, moreOrLessEquals(inset, epsilon: _tolerance));
      expect(footer.bottom - band.bottom, moreOrLessEquals(inset, epsilon: _tolerance));

      // Both buttons stand inside the outline, whole and unclipped.
      final inkPx = outlinePx * scale;
      for (final key in [_firstButtonKey, _secondButtonKey]) {
        final button = tester.getRect(find.byKey(key));
        expect(
          button.height,
          moreOrLessEquals(look.sizes.buttonHeight * scale, epsilon: _tolerance),
          reason: '$key is drawn whole, not clipped',
        );
        expect(button.left, greaterThanOrEqualTo(band.left + inkPx - _tolerance), reason: '$key is inside the band');
        expect(button.top, greaterThanOrEqualTo(band.top + inkPx - _tolerance), reason: '$key is inside the band');
        expect(button.right, lessThanOrEqualTo(band.right - inkPx + _tolerance), reason: '$key is inside the band');
        expect(button.bottom, lessThanOrEqualTo(band.bottom - inkPx + _tolerance), reason: '$key is inside the band');
      }
      expect(tester.takeException(), isNull, reason: 'nothing overflows the band');
    });
  }
}
