import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:party_host/testing.dart';

import 'support/host_harness.dart';
import 'support/toy_fonts.dart';

/// The slack the frame's math is compared with, as `host_frame_screen_test.dart`
/// has it: [Size] is two doubles, and 1024 x 768 gives a frame width of 960
/// within one part in 10^15.
const _tolerance = 1e-9;

/// The design's text floor in frame px (DESIGN section 1, rule 3): the frame's
/// smallest type, so no text on a frame screen may be drawn under it.
const _frameTextFloorPx = 20.0;

/// The floor in device dp at 640x360, where one frame px is two thirds of a dp
/// (DESIGN section 2): 20 x 0.6667 = 13.3 dp, the S7 verdict's criterion.
const _smallestTextFloorDp = 13.3;

/// One device, with the scale and the frame the design's math gives it (DESIGN
/// section 2; the numbers are `host_frame_screen_test.dart`'s).
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

  /// The body's height: the frame less the 64 px header and the 84 px footer
  /// (DESIGN section 1, rule 5).
  double get bodyHeight => frame.height - 64 - 84;
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

/// The keys the frame's body and footer are found by.
const _bodyKey = Key('hostFrameBody');
const _footerKey = Key('hostFrameFooter');
const _bandKey = Key('hostFrameFooterBand');

/// The picker's three game cards, and the footer's settings button.
const _cardKeys = [Key('pickShapeRace'), Key('pickArena'), Key('pickPartyNight')];
const _settingsKey = Key('openPuzzleSettings');

/// The four phones the picker is checked with: names at most 10 characters,
/// the longest a real host keeps.
const _playerNames = ['Bartholome', 'Maxi', 'Alexandria', 'Chris'];

/// The picker drawn in the host's frame, as the app draws every screen (DESIGN
/// section 5): [hostFrameBuilder] over it, so the screen lays out at the
/// frame's size with the frame's type.
class _PickerInFrame extends StatelessWidget {
  const _PickerInFrame();

  @override
  Widget build(BuildContext context) => hostFrameBuilder(context, const GamesScreen());
}

/// Mounts the host at [device]'s size on the game picker, in the frame, with
/// the four phones of [_playerNames] joined.
Future<FakeHostService> _pumpPicker(WidgetTester tester, Size device) async {
  final fake = await pumpHost(tester, screen: const _PickerInFrame(), size: device);
  // The sample state's own two phones make way for the four the picker is
  // checked with, as the hosts have them.
  fake.removeController('p1');
  fake.removeController('p2');
  var state = fake.state;
  for (var i = 0; i < _playerNames.length; i++) {
    state = withController(state, phoneInfo('p${i + 1}', i + 1, name: _playerNames[i]));
  }
  fake.state = state;
  fake.emit();
  await tester.pumpAndSettle();
  return fake;
}

/// How each text the picker shows is drawn, in frame px: the look's style
/// merged over the inherited one, as the text on screen reads it.
List<(String, double)> _textSizes(WidgetTester tester) {
  final sizes = <(String, double)>[];
  final texts = find.descendant(of: find.byType(GamesScreen), matching: find.byType(Text));
  for (final element in texts.evaluate()) {
    final text = element.widget as Text;
    final style = DefaultTextStyle.of(element).style.merge(text.style);
    sizes.add((text.data ?? text.textSpan?.toPlainText() ?? '', style.fontSize ?? 0));
  }
  return sizes;
}

void main() {
  setUpAll(loadLookFonts);

  for (final frameCase in _cases) {
    testWidgets('${frameCase.label}: the three cards and the playtest line fill the body, so nothing scrolls', (
      tester,
    ) async {
      await _pumpPicker(tester, frameCase.device);

      final scrollable = find.descendant(of: find.byType(GamesScreen), matching: find.byType(Scrollable));
      expect(scrollable, findsOneWidget, reason: 'the body keeps the design\'s unreachable safety net (rule 6)');
      expect(
        tester.state<ScrollableState>(scrollable).position.maxScrollExtent,
        0,
        reason: 'the body has room for the cards and their line, so nothing scrolls (DESIGN section 1, rule 6)',
      );
      expect(tester.takeException(), isNull, reason: 'nothing overflows the frame');

      final body = tester.getRect(find.byKey(_bodyKey));
      expect(body.height, moreOrLessEquals(frameCase.bodyHeight * frameCase.scale, epsilon: _tolerance));

      final cards = [for (final key in _cardKeys) tester.getRect(find.byKey(key))];
      for (final (i, key) in _cardKeys.indexed) {
        final card = cards[i];
        expect(card.left, greaterThanOrEqualTo(0), reason: '$key is on screen');
        expect(card.top, greaterThanOrEqualTo(body.top), reason: '$key is inside the body');
        expect(card.right, lessThanOrEqualTo(frameCase.device.width), reason: '$key is on screen');
        expect(card.bottom, lessThanOrEqualTo(body.bottom), reason: '$key is inside the body');
        expect(find.byKey(key).hitTestable(), findsOneWidget, reason: '$key can be pressed');
        expect(card.height, moreOrLessEquals(cards.first.height, epsilon: _tolerance), reason: 'the cards are equal');
        expect(card.top, moreOrLessEquals(cards.first.top, epsilon: _tolerance), reason: 'they stand in one row');
        // The frame's width less its two gutters, shared out: the three cards
        // and the two gaps between them (DESIGN section 1, rule 4).
        final stage = frameCase.frame.width - 2 * hostFrameGutterPx;
        expect(
          card.width,
          moreOrLessEquals((stage - 2 * ToySizes.space16) / 3 * frameCase.scale, epsilon: 1e-6),
          reason: '$key takes a third of the stage',
        );
      }

      // The playtest line sits under the cards, inside the body.
      final line = tester.getRect(find.text(HostText.playtestLine));
      expect(line.top, greaterThanOrEqualTo(cards.first.bottom), reason: 'the line is under the cards');
      expect(line.bottom, lessThanOrEqualTo(body.bottom), reason: 'the line is inside the body');

      // The settings button is the footer's, above the frame's bottom edge.
      final footer = tester.getRect(find.byKey(_footerKey));
      final settings = tester.getRect(find.byKey(_settingsKey));
      expect(find.descendant(of: find.byKey(_footerKey), matching: find.byKey(_settingsKey)), findsOneWidget);
      expect(settings.bottom, lessThanOrEqualTo(footer.bottom), reason: 'the settings button is on its band');
      expect(settings.bottom, lessThanOrEqualTo(frameCase.device.height), reason: 'and on screen');
      expect(find.byKey(_settingsKey).hitTestable(), findsOneWidget, reason: 'the settings button can be pressed');
    });

    testWidgets('${frameCase.label}: every text on the picker is at least 20 frame px', (tester) async {
      await _pumpPicker(tester, frameCase.device);

      final sizes = _textSizes(tester);
      expect(sizes, isNotEmpty);
      for (final (label, size) in sizes) {
        expect(
          size,
          greaterThanOrEqualTo(_frameTextFloorPx),
          reason: '"$label" is a frame size (DESIGN section 1, rule 3)',
        );
      }
    });
  }

  testWidgets('640x360: the picker\'s smallest text is 14.7 dp, above the floor S7 measured it under', (tester) async {
    final frameCase = _cases.first;
    await _pumpPicker(tester, frameCase.device);

    final smallest = _textSizes(tester).map((entry) => entry.$2).reduce((a, b) => a < b ? a : b);
    // The card lines and the playtest line are the frame's body, 22 frame px;
    // drawn at s = 0.6667 that is 14.7 dp, over the 13.3 dp floor the S7 report
    // measured the picker under (its "What S8 would have to change" 1).
    expect(smallest, 22, reason: 'the smallest type on the picker is the frame\'s body');
    expect(smallest * frameCase.scale, moreOrLessEquals(14.666666666666666, epsilon: _tolerance));
    expect(smallest * frameCase.scale, greaterThanOrEqualTo(_smallestTextFloorDp));
  });

  testWidgets('640x360: the settings button stands on the footer band inside its ink outline', (tester) async {
    final frameCase = _cases.first;
    await _pumpPicker(tester, frameCase.device);

    final look = ToyLookScope.of(tester.element(find.byKey(_bandKey)));
    final view = tester.widget<HostButton>(find.byKey(_settingsKey));
    final band = tester.getRect(find.byKey(_bandKey));
    final settings = tester.getRect(find.byKey(_settingsKey));
    expect(view.label, HostText.puzzleSettings);
    // The band's outline is drawn inside its box on all four sides (B-034);
    // the button is the look's height, centred in the room the outline leaves
    // and right-aligned at the stage's edge.
    expect(settings.height, moreOrLessEquals(look.sizes.buttonHeight * frameCase.scale, epsilon: _tolerance));
    final bandTopPx = band.top / frameCase.scale;
    final bandHeightPx = band.height / frameCase.scale;
    final buttonTopPx = settings.top / frameCase.scale;
    expect(
      buttonTopPx - bandTopPx,
      moreOrLessEquals(
        (bandHeightPx - 2 * look.sizes.outlineWidth - look.sizes.buttonHeight) / 2 + look.sizes.outlineWidth,
        epsilon: 1e-6,
      ),
      reason: 'the button is centred between the band\'s top ink line and its bottom outline',
    );
    expect(settings.right, moreOrLessEquals((960 - hostFrameGutterPx) * frameCase.scale, epsilon: 1e-6));
  });
}
