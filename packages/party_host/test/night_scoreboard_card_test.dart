import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:party_host/testing.dart';

import 'support/host_harness.dart';
import 'support/night_harness.dart';
import 'support/toy_fonts.dart';

/// The slack sizes are compared with, as `night_scoreboard_frame_test.dart`
/// has it: [Size] is two doubles, and a frame's arithmetic leaves noise in the
/// last digits.
const _tolerance = 1e-9;

/// The design frame's width, in frame px (DESIGN section 1, rule 1): the
/// stage of every device that is not a wide phone.
const _stage960Px = 960.0;

/// The narrowest a score row's bar may be in the 960 px stage (DESIGN section
/// 1, rule 4): a bar as long as the room the card's contents leave is about a
/// tenth of the stage, so 300 px proves the card, not a row, sets its width.
const _barMinWidthPx = 300.0;

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

/// The names the four and the six phones join with: at most ten characters, the
/// longest a real host keeps, so the rows show what they show with real names
/// (DESIGN section 6).
const _fourNames = ['Alexandria', 'Nightshade', 'Bartholome', 'Maxi'];
const _sixNames = [..._fourNames, 'WWWWWWWWWW', 'iiiiiiiiii'];

/// The points a round gave the joined players (P1 first): a leader, then two
/// players level in third, so the rows carry a full bar, a short bar and a
/// "+n" (DESIGN section 4).
const _fourPoints = {'p1': 9, 'p2': 5, 'p3': 2, 'p4': 2};
const _sixPoints = {'p1': 9, 'p2': 7, 'p3': 3, 'p4': 3, 'p5': 2, 'p6': 1};

/// The night a test scores: three rounds, the three awards by hand.
const _nightLength = NightLength.three;

/// The rounds a test records before it looks: one, so the scoreboard is between
/// rounds, or all three, so it shows the final scores.
const _betweenRounds = 1;

/// The keys the frame's footer and the scoreboard's card are found by.
const _footerKey = Key('hostFrameFooter');
const _cardKey = Key('nightScoreboard');
const _backKey = Key('nightBackToGames');

const _fourPlayers = 4;
const _sixPlayers = 6;

/// Every way a roster and its points go together: four players and six.
const _rosters = [(_fourPlayers, _fourNames, _fourPoints), (_sixPlayers, _sixNames, _sixPoints)];

/// The night's scoreboard drawn in the host's frame, as the app draws every
/// screen (DESIGN section 5): [hostFrameBuilder] over it, so the screen lays
/// out at the frame's size with the frame's type.
class _NightInFrame extends StatelessWidget {
  const _NightInFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => hostFrameBuilder(context, child);
}

Key _rowKey(String id) => Key('nightRow-$id');

/// Mounts the host at [device]'s size on the scoreboard in the frame, with the
/// phones of [names] joined and [rounds] of the night's three recorded, each
/// round giving [points] and P1 winning it.
Future<void> _pumpScoreboard(
  WidgetTester tester,
  Size device, {
  required List<String> names,
  required Map<String, int> points,
  required int rounds,
}) async {
  final fake = await pumpHost(
    tester,
    screen: const _NightInFrame(child: NightScoreboardScreen()),
    size: device,
  );
  // The sample state's own two phones make way for the roster a test names.
  fake.removeController('p1');
  fake.removeController('p2');
  var state = fake.state;
  for (var i = 0; i < names.length; i++) {
    state = withController(state, phoneInfo('p${i + 1}', i + 1, name: names[i]));
  }
  fake.state = state;
  fake.emit();
  await tester.pumpAndSettle();

  final night = appContainer(tester).read(partyNightProvider.notifier)
    ..start(length: _nightLength, awards: threeAwards);
  for (var i = 0; i < rounds; i++) {
    night.recordRound(roundResult(points: points, winners: {'p1'}));
  }
  await tester.pumpAndSettle();
}

/// The card fills the stage: the frame's width less the frame's gutter at each
/// side, whatever its rows say (DESIGN section 1, rule 4).
void _expectCardFillsStage(WidgetTester tester, _Case frameCase) {
  expect(
    tester.getSize(find.byKey(_cardKey)).width,
    moreOrLessEquals(frameCase.frame.width - 2 * hostFrameGutterPx, epsilon: _tolerance),
    reason: 'the card is the stage width, not the width of its contents',
  );
}

/// The room left over for the bar is the card's own: in the 960 px stage it is
/// more than [_barMinWidthPx] (DESIGN section 1, rule 4).
void _expectBarRoomOfStage(WidgetTester tester, _Case frameCase, String id) {
  if (frameCase.frame.width != _stage960Px) return;
  final bar = find.descendant(of: find.byKey(_rowKey(id)), matching: find.byKey(const Key('scoreRowBar')));
  expect(
    tester.getSize(bar).width,
    greaterThan(_barMinWidthPx),
    reason: "$id's bar is measured against the stage, not the row",
  );
}

void main() {
  setUpAll(loadLookFonts);

  for (final frameCase in _cases) {
    for (final (players, names, points) in _rosters) {
      testWidgets('${frameCase.label}, $players players between rounds: the card fills the stage and a bar is wide', (
        tester,
      ) async {
        await _pumpScoreboard(tester, frameCase.device, names: names, points: points, rounds: _betweenRounds);

        _expectCardFillsStage(tester, frameCase);
        _expectBarRoomOfStage(tester, frameCase, 'p1');
        expect(
          tester.widget<Text>(find.byKey(const Key('nightRoundPoints-p1'))).style?.fontSize,
          ToyType.frameSmall.fontSize,
          reason: '"+n" is the frame\'s small size',
        );
      });

      testWidgets('${frameCase.label}, $players players on the final scores: the winner is taller, the one-button '
          'footer is on screen and the card fills the stage', (tester) async {
        await _pumpScoreboard(tester, frameCase.device, names: names, points: points, rounds: _nightLength.rounds);

        _expectCardFillsStage(tester, frameCase);
        _expectBarRoomOfStage(tester, frameCase, 'p1');
        expect(
          tester.getSize(find.byKey(_rowKey('p1'))).height,
          moreOrLessEquals(scoreWinnerRowHeightPx, epsilon: _tolerance),
          reason: "the winner's row is taller than the others",
        );
        expect(
          tester.getSize(find.byKey(_rowKey('p2'))).height,
          moreOrLessEquals(scoreRowHeightPx, epsilon: _tolerance),
          reason: 'every other row keeps the 52 px line',
        );
        expect(
          find.descendant(of: find.byKey(_footerKey), matching: find.byType(HostButton)),
          findsOneWidget,
          reason: 'the final scores end the night with one button',
        );
        final back = tester.getRect(find.byKey(_backKey));
        expect(back.left, greaterThanOrEqualTo(0), reason: 'Back to games is on screen');
        expect(back.top, greaterThanOrEqualTo(0), reason: 'Back to games is on screen');
        expect(back.right, lessThanOrEqualTo(frameCase.device.width), reason: 'Back to games is on screen');
        expect(
          back.bottom,
          lessThanOrEqualTo(frameCase.device.height + _tolerance),
          reason: 'Back to games is on screen',
        );
        expect(find.byKey(_backKey).hitTestable(), findsOneWidget, reason: 'Back to games can be pressed');
      });
    }
  }
}
