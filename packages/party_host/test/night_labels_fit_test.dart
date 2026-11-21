import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:party_host/src/ui/night_start_names.dart';
import 'package:party_host/testing.dart';

import 'support/host_harness.dart';
import 'support/phone_fit_matrix_support.dart';
import 'support/toy_fonts.dart';

/// One device the labels and names are checked at: the five sizes the owner's
/// decision names (COMMON), the same table `night_start_frame_test.dart` has.
class _Case {
  const _Case({required this.label, required this.device});

  /// The device in the brief's words, for the test's name.
  final String label;

  /// The device's logical size: its physical size at a device pixel ratio of 1.
  final Size device;
}

/// The five sizes the phone host fits at (COMMON).
const _cases = [
  _Case(label: '640x360, a small phone', device: Size(640, 360)),
  _Case(label: '852x393, a phone in landscape', device: Size(852, 393)),
  _Case(label: '1024x768, a tablet', device: Size(1024, 768)),
  _Case(label: '1280x800, a laptop', device: Size(1280, 800)),
  _Case(label: '1920x1080, the TV', device: Size(1920, 1080)),
];

/// The night's two footer buttons by key.
const _shapeRaceKey = Key('nightShapeRace');
const _bumperKey = Key('nightBumper');

/// The seed the start card's awards are drawn from, as the frame test fixes it.
const _seed = 7;

/// The frame's stage, in frame px: what the card's lines have to share.
const _stagePx = 960 - 2 * hostFrameGutterPx;

/// The night's start screen drawn in the host's frame, as every host app draws
/// it (DESIGN section 5): [hostFrameBuilder] over it, so it lays out at the
/// frame's size with the frame's type.
class _NightInFrame extends StatelessWidget {
  const _NightInFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => hostFrameBuilder(context, child);
}

/// Mounts the host at [device]'s size on the night's start card with [names]
/// joined: the sample state's own two phones make way for them.
Future<FakeHostService> _pumpNight(WidgetTester tester, Size device, List<String> names) async {
  final fake = await pumpHost(
    tester,
    screen: const _NightInFrame(child: NightStartScreen(seed: _seed)),
    size: device,
  );
  fake.removeController('p1');
  fake.removeController('p2');
  var state = fake.state;
  for (var i = 0; i < names.length; i++) {
    state = withController(state, phoneInfo('p${i + 1}', i + 1, name: names[i]));
  }
  fake.state = state;
  fake.emit();
  await tester.pumpAndSettle();
  return fake;
}

/// The paragraph a text is drawn in: the one whose room and cut a label's fit
/// is read from.
RenderParagraph _paragraph(WidgetTester tester, Finder text) => tester.renderObject<RenderParagraph>(text);

/// How wide [paragraph]'s text wants to be at its own style, in frame px: the
/// font engine's measurement, never an estimate.
double _intrinsicWidthPx(RenderParagraph paragraph) {
  final painter = TextPainter(text: paragraph.text, textDirection: TextDirection.ltr, maxLines: 1)..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}

/// The width a night footer button was laid out at, in frame px: the frame lays
/// its screens out in frame px and the fitted box scales them to the device.
double _buttonWidthPx(WidgetTester tester, Key key) => tester.getSize(find.byKey(key)).width;

void main() {
  setUpAll(loadLookFonts);

  for (final frameCase in _cases) {
    testWidgets('${frameCase.label}: "Shape Race" and "Bumper Round" are drawn whole in the footer', (tester) async {
      await _pumpNight(tester, frameCase.device, matrixFourNames);
      expect(tester.takeException(), isNull, reason: 'nothing overflows the frame');

      final labels = {_shapeRaceKey: 'Shape Race', _bumperKey: 'Bumper Round'};
      for (final MapEntry(key: key, value: label) in labels.entries) {
        final paragraph = _paragraph(tester, find.descendant(of: find.byKey(key), matching: find.text(label)));
        final room = paragraph.constraints.maxWidth;
        expect(
          _intrinsicWidthPx(paragraph),
          lessThanOrEqualTo(room),
          reason: '"$label" wants ${_intrinsicWidthPx(paragraph)} px of the ${room.round()} px its button leaves it',
        );
        expect(paragraph.didExceedMaxLines, isFalse, reason: '"$label" is not ellipsised');
      }

      final pair = _buttonWidthPx(tester, _shapeRaceKey) + nightFooterButtonGapPx + _buttonWidthPx(tester, _bumperKey);
      expect(
        pair,
        lessThanOrEqualTo(nightFooterButtonsWidthPx),
        reason: 'the pair takes ${pair.round()} px of the footer\'s ${nightFooterButtonsWidthPx.round()} px budget',
      );
    });

    testWidgets('${frameCase.label}: six ten-character nicknames are drawn whole, and the card still fits', (
      tester,
    ) async {
      await _pumpNight(tester, frameCase.device, matrixSixNames);

      expect(
        find.descendant(of: find.byType(NightStartScreen), matching: find.byType(Scrollable)),
        findsNothing,
        reason: 'the names re-flow rather than scroll (DESIGN section 1, rule 6)',
      );
      expect(tester.takeException(), isNull, reason: 'nothing overflows the body');

      for (final name in matrixSixNames) {
        expect(find.text(name), findsOneWidget, reason: '$name joined, so the card names them whole');
        final paragraph = _paragraph(tester, find.text(name));
        final room = paragraph.constraints.maxWidth;
        expect(
          _intrinsicWidthPx(paragraph),
          lessThanOrEqualTo(room),
          reason: '"$name" wants ${_intrinsicWidthPx(paragraph)} px of the ${room.round()} px its slot leaves it',
        );
        expect(paragraph.didExceedMaxLines, isFalse, reason: '"$name" is not ellipsised');
      }

      for (final key in [_shapeRaceKey, _bumperKey]) {
        final rect = tester.getRect(find.byKey(key));
        expect(rect.left, greaterThanOrEqualTo(0), reason: '$key is on screen');
        expect(rect.top, greaterThanOrEqualTo(0), reason: '$key is on screen');
        expect(rect.right, lessThanOrEqualTo(frameCase.device.width), reason: '$key is on screen');
        expect(rect.bottom, lessThanOrEqualTo(frameCase.device.height), reason: '$key is on screen');
      }

      final texts = find.descendant(of: find.byType(NightStartScreen), matching: find.byType(Text));
      expect(texts, findsWidgets);
      for (final element in texts.evaluate()) {
        final text = element.widget as Text;
        final style = DefaultTextStyle.of(element).style.merge(text.style);
        expect(
          style.fontSize,
          greaterThanOrEqualTo(20),
          reason: '"${text.data ?? text.textSpan?.toPlainText()}" is a frame size (DESIGN rule 3)',
        );
      }
    });
  }

  testWidgets('the six names stand two rows of three, so each has the stage\'s third', (tester) async {
    await _pumpNight(tester, const Size(640, 360), matrixSixNames);

    final slotPx = _stagePx / nightStartNamesSplitColumns;
    for (final name in matrixSixNames) {
      expect(
        nameWidthPx(name),
        lessThanOrEqualTo(slotPx - nightStartNameGapPx - awardTileDiscPx - ToySizes.space8),
        reason: '"$name" fits one of the $nightStartNamesSplitColumns-column slots of $slotPx px',
      );
    }
    final tops = [for (final name in matrixSixNames) tester.getRect(find.text(name)).top];
    expect(tops.toSet().length, 2, reason: 'the six names take two lines');
  });
}
