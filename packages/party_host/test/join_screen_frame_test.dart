import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
/// smallest type, so no text on the join screen may be drawn under it.
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

/// The keys the frame's regions and the join screen's parts are found by.
const _headerKey = Key('hostFrameHeader');
const _bodyKey = Key('hostFrameBody');
const _footerKey = Key('hostFrameFooter');

/// The players the screen is checked with: 10-character nicknames at most, the
/// longest a real host keeps. Two sides of two join; the rest watch.
const _playerNames = ['Bartholome', 'Maxi', 'Alexandria', 'Chris', 'Nightshade', 'Jo'];

/// The players a case joins: nobody, two a side, and six phones with two
/// watching (the most Shape Race seats: two a side, `maxPerSide`).
const _counts = [0, 4, 6];

/// How a text on the join screen is drawn, in frame px: the look's style
/// merged over the inherited one, as the text on screen reads it.
List<(String, double)> _textSizes(WidgetTester tester) {
  final sizes = <(String, double)>[];
  final texts = find.descendant(of: find.byType(JoinScreen), matching: find.byType(Text));
  for (final element in texts.evaluate()) {
    final text = element.widget as Text;
    final style = DefaultTextStyle.of(element).style.merge(text.style);
    sizes.add((text.data ?? text.textSpan?.toPlainText() ?? '', style.fontSize ?? 0));
  }
  return sizes;
}

/// Mounts the host in the frame at [device]'s size with [players] phones, then
/// walks Home → Play → Shape Race → the house puzzle and joins two a side.
Future<FakeHostService> _pumpJoin(WidgetTester tester, Size device, int players) async {
  final fake = await pumpHost(tester, screen: const StubHome(), size: device, framed: true);
  // The sample state's own two phones make way for the names this is checked
  // with, as the hosts have them.
  fake.removeController('p1');
  fake.removeController('p2');
  var state = fake.state;
  for (var i = 0; i < players; i++) {
    state = withController(state, phoneInfo('p${i + 1}', i + 1, name: _playerNames[i]));
  }
  fake.state = state;
  fake.emit();
  await tester.pumpAndSettle();

  await tapVisible(tester, find.byKey(const Key('openPlay')));
  await tester.pumpAndSettle();
  await tapVisible(tester, find.byKey(const Key('pickShapeRace')));
  await tester.pumpAndSettle();
  await tapVisible(tester, find.byKey(const Key('puzzle-house')));
  // The join screen's own 16 ms timer never settles: a fixed beat, as the
  // other join tests wait it out.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  expect(find.byType(JoinScreen), findsOneWidget);

  if (players == 0) return fake;
  final ids = [for (var i = 0; i < players; i++) 'p${i + 1}'];
  await neutral(tester, fake, ids);
  // Two a side is what Shape Race seats (`maxPerSide`); a fifth and sixth
  // phone keep watching and show on the "not joined" line.
  for (final id in ids.take(2 * maxPerSide)) {
    await press(tester, fake, id, GamepadButton.a);
  }
  return fake;
}

void main() {
  setUpAll(loadLookFonts);

  for (final frameCase in _cases) {
    for (final count in _counts) {
      testWidgets('${frameCase.label}, $count players: the sides fit the body with nothing to scroll, and every '
          'text is a frame size', (tester) async {
        await _pumpJoin(tester, frameCase.device, count);
        expect(tester.takeException(), isNull, reason: 'nothing overflows the frame');

        // No scrollable at all: the sides are short enough for the body
        // (DESIGN section 1, rule 6), and the join screen's scroll is gone.
        final scrollable = find.descendant(of: find.byType(JoinScreen), matching: find.byType(Scrollable));
        expect(scrollable, findsNothing, reason: 'the join screen does not scroll');

        final body = tester.getRect(find.byKey(_bodyKey));
        expect(body.height, moreOrLessEquals(frameCase.bodyHeight * frameCase.scale, epsilon: _tolerance));

        // The two sides, the format line and — with phones watching — the "not
        // joined" line are all inside the body.
        final parts = [
          find.byKey(const Key('side-left')),
          find.byKey(const Key('side-right')),
          find.byKey(const Key('joinFormat')),
          if (count > 2 * maxPerSide) find.byKey(const Key('notJoined')),
        ];
        for (final part in parts) {
          expect(part, findsOneWidget);
          final rect = tester.getRect(part);
          expect(rect.top, greaterThanOrEqualTo(body.top - _tolerance), reason: '$part is inside the body');
          expect(rect.bottom, lessThanOrEqualTo(body.bottom + _tolerance), reason: '$part is inside the body');
          expect(rect.left, greaterThanOrEqualTo(0), reason: '$part is on screen');
          expect(rect.right, lessThanOrEqualTo(frameCase.device.width), reason: '$part is on screen');
        }

        // Start and Back are the footer's, whole and pressable at every size.
        final footer = tester.getRect(find.byKey(_footerKey));
        for (final key in [const Key('joinStart'), const Key('joinBack')]) {
          final button = find.byKey(key);
          expect(find.descendant(of: find.byKey(_footerKey), matching: button), findsOneWidget);
          expect(button.hitTestable(), findsOneWidget, reason: '$key can be pressed');
          final rect = tester.getRect(button);
          expect(rect.top, greaterThanOrEqualTo(footer.top - _tolerance), reason: '$key is on the footer');
          expect(rect.bottom, lessThanOrEqualTo(frameCase.device.height), reason: '$key is on screen');
        }

        // The pairing code is in the header, where a player looks (M16 item 3).
        final header = tester.getRect(find.byKey(_headerKey));
        final code = find.byKey(const Key('joinCode'));
        expect(find.descendant(of: find.byKey(_headerKey), matching: code), findsOneWidget);
        final codeRect = tester.getRect(code);
        expect(codeRect.top, greaterThanOrEqualTo(header.top - _tolerance), reason: 'the code is in the header');
        expect(codeRect.bottom, lessThanOrEqualTo(header.bottom + _tolerance), reason: 'the code is in the header');
        expect(codeRect.right, lessThanOrEqualTo(frameCase.device.width), reason: 'the code is on screen');

        // No type under the design's floor (DESIGN section 1, rule 3).
        final sizes = _textSizes(tester);
        expect(sizes, isNotEmpty);
        for (final (label, size) in sizes) {
          expect(size, greaterThanOrEqualTo(_frameTextFloorPx), reason: '"$label" is a frame size');
        }
      });
    }
  }

  testWidgets('640x360: the join screen\'s smallest text is 13.3 dp, over the floor S7 measured it under', (
    tester,
  ) async {
    final frameCase = _cases.first;
    await _pumpJoin(tester, frameCase.device, 4);

    final smallest = _textSizes(tester).map((entry) => entry.$2).reduce((a, b) => a < b ? a : b);
    expect(smallest, _frameTextFloorPx, reason: 'the smallest type is the sides\' names, the frame\'s floor');
    expect(smallest * frameCase.scale, moreOrLessEquals(13.333333333333334, epsilon: _tolerance));
    expect(smallest * frameCase.scale, greaterThanOrEqualTo(_smallestTextFloorDp));
  });

  testWidgets('640x360: a 10-character nickname fits its 52 px seat, with a 38 px badge beside it', (tester) async {
    final frameCase = _cases.first;
    await _pumpJoin(tester, frameCase.device, 4);

    final left = find.byKey(const Key('side-left'));
    final name = find.descendant(of: left, matching: find.text('P1 Bartholome'));
    expect(name, findsOneWidget);
    final paragraph = tester.renderObject<RenderParagraph>(name);
    expect(paragraph.didExceedMaxLines, isFalse, reason: 'the name is whole, not ellipsised');

    // The seat is the scoreboard's row: 38 px badge, 52 px line. The frame
    // draws them at the device's scale.
    final badge = find.descendant(of: left, matching: find.byType(ToyBadge)).first;
    expect(tester.getRect(badge).width, moreOrLessEquals(38 * frameCase.scale, epsilon: 1e-6));
    final row = tester.getRect(name).height;
    expect(row, lessThanOrEqualTo(52 * frameCase.scale), reason: 'the name sits in a 52 px seat');
    expect(tester.takeException(), isNull);
  });
}
