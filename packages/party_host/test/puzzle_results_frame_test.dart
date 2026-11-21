import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';

import 'support/host_harness.dart';

/// One device, with the frame the design's math gives it (DESIGN section 2;
/// the numbers are `host_frame_screen_test.dart`'s).
class _Case {
  const _Case({required this.label, required this.device, required this.frame});

  /// The device in the brief's words, for the test's name.
  final String label;

  /// The device's logical size: its physical size at a device pixel ratio of 1.
  final Size device;

  /// The size the host lays out in, in frame px.
  final Size frame;
}

/// The five devices every slice of the phone-host layout is checked at:
///
/// * 640x360, a small phone: s = 640/960 = .667, frame 960x540, body 392.
/// * 852x393, a phone in landscape: s = 393/540 = .728, frame 1170.687x540,
///   body 392.
/// * 1024x768, a tablet: s = 1024/960 = 1.067, frame 960x720, body 572.
/// * 1280x800, a laptop: s = 1280/960 = 1.333, frame 960x600, body 452.
/// * 1920x1080, the TV: s = 1920/960 = 2, frame 960x540, body 392.
const _cases = [
  _Case(label: '640x360, a small phone', device: Size(640, 360), frame: Size(960, 540)),
  _Case(label: '852x393, a phone in landscape', device: Size(852, 393), frame: Size(1170.6870229007634, 540)),
  _Case(label: '1024x768, a tablet', device: Size(1024, 768), frame: Size(960, 720)),
  _Case(label: '1280x800, a laptop', device: Size(1280, 800), frame: Size(960, 600)),
  _Case(label: '1920x1080, the TV', device: Size(1920, 1080), frame: Size(960, 540)),
];

/// The frame's text floor, in frame px (DESIGN section 1, rule 3): no host
/// screen draws smaller type, and a badge's number is type.
const _floorPx = 20.0;

/// How [ToyBadge] sizes its number against its disc: toy_look's
/// `toy_badge.dart` draws it at 0.55 of the diameter, so a 20 px number needs
/// a disc of 20 / 0.55 = 36.36 px.
const _numberShare = 0.55;

/// The badge sizes the results draw (DESIGN section 4: the shapes' names are
/// 24 px and its pieces 20 px; a row's badge is 38, and 28 is what a card too
/// small for 38 asks for).
const _badgeSizes = [38.0, 28.0];

/// [child] in the host frame, as the apps draw every host screen (M16
/// phonehost1 S1): the frame's layout and the frame's own type.
class _InFrame extends StatelessWidget {
  const _InFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => hostFrameBuilder(context, Scaffold(body: Center(child: child)));
}

void main() {
  for (final frameCase in _cases) {
    testWidgets('${frameCase.label}: the results\' badges keep the 20 px number floor at 38 and 28', (tester) async {
      for (final size in _badgeSizes) {
        await pumpHost(
          tester,
          size: frameCase.device,
          screen: _InFrame(child: PlayerBadge(number: 4, size: size)),
        );

        final badge = tester.widget<ToyBadge>(find.byType(ToyBadge));
        expect(
          badge.diameter * _numberShare,
          greaterThanOrEqualTo(_floorPx - 1e-9),
          reason: 'a $size px badge draws its number as frame type (DESIGN rule 3)',
        );
        expect(badge.diameter, greaterThanOrEqualTo(size), reason: 'the floor never shrinks a badge');
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('inside the frame a badge narrower than 37 px grows to it, and 38 stays 38', (tester) async {
    // 38 * 0.55 = 20.9 px, over the floor; 36 * 0.55 = 19.8 and 28 * 0.55 =
    // 15.4, under it, so those discs grow to the smallest that clears it: 37
    // (20 / 0.55 = 36.36, rounded up), whose number is 20.35 px.
    for (final (requested, drawn) in [(38.0, 38.0), (36.0, 37.0), (28.0, 37.0)]) {
      await pumpHost(
        tester,
        screen: _InFrame(child: PlayerBadge(number: 4, size: requested)),
      );
      expect(tester.widget<ToyBadge>(find.byType(ToyBadge)).diameter, drawn);
    }
  });
}
