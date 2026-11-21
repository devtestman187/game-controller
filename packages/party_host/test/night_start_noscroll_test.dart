import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:party_host/testing.dart';

import 'support/host_harness.dart';
import 'support/night_harness.dart';
import 'support/toy_fonts.dart';

/// One device, with the frame the design's math gives it (DESIGN section 2;
/// the numbers are `night_start_frame_test.dart`'s).
class _Case {
  const _Case({required this.label, required this.device});

  /// The device in the brief's words, for the test's name.
  final String label;

  /// The device's logical size: its physical size at a device pixel ratio of 1.
  final Size device;
}

/// The five devices every slice of the phone-host layout is checked at:
/// 640x360, 852x393, 1024x768, 1280x800 and 1920x1080 (DESIGN section 2).
const _cases = [
  _Case(label: '640x360, a small phone', device: Size(640, 360)),
  _Case(label: '852x393, a phone in landscape', device: Size(852, 393)),
  _Case(label: '1024x768, a tablet', device: Size(1024, 768)),
  _Case(label: '1280x800, a laptop', device: Size(1280, 800)),
  _Case(label: '1920x1080, the TV', device: Size(1920, 1080)),
];

/// The frame's body, the room the card has between the header and the footer.
const _bodyKey = Key('hostFrameBody');

/// What the card is drawn with: four players, or the six a night may hold, and
/// a night already set up or a fresh one (brief fstart).
const _rosters = {
  4: ['Bartholome', 'Maxi', 'Alexandria', 'Chris'],
  6: ['Bartholome', 'Maxi', 'Alexandria', 'Chris', 'Nightshade', 'Zed'],
};

/// The seed the start card's awards are drawn from: fixed, so every size shows
/// the same three tiles and the same content.
const _seed = 7;

/// The night's start screen drawn in the host's frame, as the app draws every
/// screen (DESIGN section 5): [hostFrameBuilder] over it, so the screen lays
/// out at the frame's size with the frame's type.
class _NightInFrame extends StatelessWidget {
  const _NightInFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => hostFrameBuilder(context, child);
}

/// Mounts the host at [device]'s size on the night's start screen, in the
/// frame, with [players] phones joined and, with [running], the night already
/// set up and left before round 1.
Future<void> _pumpNight(
  WidgetTester tester,
  _Case frameCase, {
  required List<String> players,
  required bool running,
}) async {
  final fake = await pumpHost(
    tester,
    screen: const _NightInFrame(child: NightStartScreen(seed: _seed)),
    size: frameCase.device,
  );
  // The sample state's own two phones make way for the ones the card shows.
  fake.removeController('p1');
  fake.removeController('p2');
  var state = fake.state;
  for (var i = 0; i < players.length; i++) {
    state = withController(state, phoneInfo('p${i + 1}', i + 1, name: players[i]));
  }
  fake.state = state;
  fake.emit();
  await tester.pumpAndSettle();
  if (running) {
    appContainer(tester).read(partyNightProvider.notifier).start(length: NightLength.five, awards: threeAwards);
    await tester.pumpAndSettle();
  }
}

/// Every line of the card, from its top to the pick-round line that the column
/// keeps at the body's bottom: what has to fit the body at every size.
Map<String, Finder> _lines() => {
  'the awards title': find.text(NightText.awardsTitle),
  'the awards row': find.byType(AwardTile).last,
  'the cat\'s line': find.text(NightText.catLine),
  'the players line': find.descendant(of: find.byType(NightStartScreen), matching: find.byType(PlayerBadge)).last,
  'the pick-round line': find.text(NightText.pickRound(1)),
};

void main() {
  setUpAll(loadLookFonts);

  for (final frameCase in _cases) {
    for (final MapEntry(key: players, value: names) in _rosters.entries) {
      for (final running in [false, true]) {
        final night = running ? 'a running night' : 'a fresh night';
        testWidgets('${frameCase.label}, $players players, $night: the night start has no scrollable, and its '
            'content ends inside the body', (tester) async {
          await _pumpNight(tester, frameCase, players: names, running: running);

          // DESIGN section 1, rule 6: no scrolling on a host screen. The card
          // is laid out to fit the frame's body, so it needs no list at all.
          expect(
            find.descendant(of: find.byType(NightStartScreen), matching: find.byType(Scrollable)),
            findsNothing,
            reason: 'the night start draws no scrollable (DESIGN section 1, rule 6)',
          );
          expect(tester.takeException(), isNull, reason: 'nothing overflows the body');

          final body = tester.getRect(find.byKey(_bodyKey));
          for (final MapEntry(key: line, value: finder) in _lines().entries) {
            expect(finder, findsOneWidget, reason: '$line is on the card');
            final rect = tester.getRect(finder);
            expect(rect.top, greaterThanOrEqualTo(body.top), reason: '$line starts inside the body');
            expect(rect.bottom, lessThanOrEqualTo(body.bottom), reason: '$line ends inside the body');
            expect(rect.left, greaterThanOrEqualTo(body.left), reason: '$line starts inside the body');
            expect(rect.right, lessThanOrEqualTo(body.right), reason: '$line ends inside the body');
          }
        });
      }
    }
  }
}
