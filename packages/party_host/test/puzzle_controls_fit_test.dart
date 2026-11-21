import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:party_host/testing.dart';
import 'package:puzzle_game/puzzle_game.dart';

import 'support/host_harness.dart';
import 'support/toy_fonts.dart';

/// Round-off allowed when a frame pixel is compared with a device pixel:
/// [Size] is two doubles and the frame's scale leaves noise in the last digits.
const _slop = 1e-6;

/// The frame's text floor, in frame px (DESIGN section 1, rule 3): the card's
/// compact buttons draw their label no smaller.
const _floorPx = 20.0;

/// The keys the results' compact controls have always had (the S6b decision):
/// the series' Shuffle and its replay (Rematch in a race, Play again on one
/// board) and Change teams.
const _controlKeys = [Key('shuffle'), Key('rematch'), Key('playAgain'), Key('changeTeams')];

class _Case {
  const _Case({required this.label, required this.device});

  final String label;
  final Size device;
}

const _devices = [
  _Case(label: '640x360, a small phone', device: Size(640, 360)),
  _Case(label: '852x393, a phone in landscape', device: Size(852, 393)),
  _Case(label: '1024x768, a tablet', device: Size(1024, 768)),
  _Case(label: '1280x800, a laptop', device: Size(1280, 800)),
  _Case(label: '1920x1080, the TV', device: Size(1920, 1080)),
];

/// One results round the controls are checked on: a series round, whose card
/// carries Shuffle, its replay and Change teams, and a non-night `any <level>`
/// round, whose card carries Change teams alone.
class _Round {
  const _Round({required this.label, required this.choice, required this.anyRound, required this.controls});

  final String label;
  final PuzzleChoice choice;

  /// Whether the round is an `any <level> puzzle` one (it draws a match of its
  /// own, so a test can lock its pieces).
  final bool anyRound;

  /// The keys of the compact controls its card carries.
  final List<Key> controls;
}

const _rounds = [
  _Round(
    label: 'a series round',
    choice: PuzzleChoice(level: Level.easy, puzzleId: 'house'),
    anyRound: false,
    controls: [Key('shuffle'), Key('rematch'), Key('changeTeams')],
  ),
  _Round(
    label: 'an any-puzzle round',
    choice: PuzzleChoice(level: Level.easy),
    anyRound: true,
    controls: [Key('changeTeams')],
  ),
];

/// The phones the sample host already has, and the most a side seats: the
/// test adds the phones a bigger round needs.
const _samplePhones = 2;
const _playersASide = 2;

/// The sides of a round of [phones]: the first four sit two a side, since the
/// puzzle seats two, and any phone beyond that watches.
Map<String, PuzzleSide> _teams(int phones) => {
  for (var i = 1; i <= min(phones, _playersASide * 2); i++)
    'p$i': i <= _playersASide ? PuzzleSide.left : PuzzleSide.right,
};

/// [child] in the host frame, as both host apps draw every screen (DESIGN
/// section 5): [hostFrameBuilder] over it, so the round lays out at the frame's
/// size and in the frame's type.
class _InFrame extends StatelessWidget {
  const _InFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => hostFrameBuilder(context, child);
}

/// The phones of a round of [phones] joined to the host at [device]'s size.
Future<FakeHostService> _hostWith(WidgetTester tester, Size device, int phones) async {
  final ids = [for (var i = 1; i <= phones; i++) 'p$i'];
  final fake = await pumpHost(tester, screen: const StubHome(), size: device);
  var state = fake.state;
  for (var number = _samplePhones + 1; number <= phones; number++) {
    state = withController(state, phoneInfo('p$number', number));
  }
  fake.state = state;
  fake.emit();
  await neutral(tester, fake, ids);
  return fake;
}

/// Starts the round at [device] and plays it out to its results.
Future<void> _openResults(WidgetTester tester, _Case device, _Round r, int phones) async {
  await _hostWith(tester, device.device, phones);
  final teams = _teams(phones);
  final match = r.anyRound ? PuzzleMatch(housePuzzle(), teams: teams, random: Random(1)) : null;
  tester
      .state<NavigatorState>(find.byType(Navigator))
      .push(
        MaterialPageRoute<void>(
          builder: (_) => _InFrame(
            child: PuzzleScreen(choice: r.choice, teams: teams, match: match),
          ),
        ),
      );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  lockEveryPiece(tester);
  await endRound(tester);
  await tester.pump(const Duration(milliseconds: 300));
}

/// The label a compact control of [key] draws.
RenderParagraph _label(WidgetTester tester, Key key) =>
    tester.renderObject<RenderParagraph>(find.descendant(of: find.byKey(key), matching: find.byType(Text)).first);

/// Whether [inner] sits whole inside [outer], [_slop] px of round-off allowed.
bool _inside(Rect outer, Rect inner) =>
    inner.left >= outer.left - _slop &&
    inner.top >= outer.top - _slop &&
    inner.right <= outer.right + _slop &&
    inner.bottom <= outer.bottom + _slop;

void main() {
  setUpAll(loadLookFonts);

  for (final device in _devices) {
    for (final r in _rounds) {
      for (final phones in const [4, 6]) {
        testWidgets('${device.label}, ${r.label}, $phones players: every compact control keeps its whole label, '
            'on screen and under a thumb, with nothing scrolling', (tester) async {
          await _openResults(tester, device, r, phones);
          expect(tester.takeException(), isNull, reason: 'the results fit the frame (DESIGN rule 6)');

          final bodyKey = find.byKey(const Key('hostFrameBody'));
          expect(
            find.descendant(of: bodyKey, matching: find.byType(Scrollable)),
            findsNothing,
            reason: 'nothing scrolls on a host screen (DESIGN section 1, rule 6)',
          );

          final body = tester.getRect(bodyKey);
          final view = Offset.zero & (tester.view.physicalSize / tester.view.devicePixelRatio);
          for (final key in _controlKeys) {
            final finder = find.byKey(key);
            if (!r.controls.contains(key)) {
              expect(finder, findsNothing, reason: '$key is not this round\'s control');
              continue;
            }
            expect(finder, findsOneWidget, reason: '$key is this round\'s control');

            // The label is whole: the box it is drawn in is at least as wide
            // as the words want, so the look's ellipsis never runs.
            final label = _label(tester, key);
            final wanted = label.getMaxIntrinsicWidth(double.infinity);
            expect(
              label.didExceedMaxLines,
              isFalse,
              reason: '$key draws its label whole (wanted $wanted, given ${label.constraints.maxWidth})',
            );
            expect(wanted, lessThanOrEqualTo(label.constraints.maxWidth + _slop), reason: '$key\'s label fits its box');
            expect(
              label.text.style?.fontSize,
              greaterThanOrEqualTo(_floorPx - _slop),
              reason: '$key\'s label is frame type (DESIGN rule 3)',
            );

            // The whole button is on the screen, in the body, and a tap
            // reaches it.
            final rect = tester.getRect(finder);
            expect(_inside(body, rect), isTrue, reason: '$key is in the body: $rect');
            expect(_inside(view, rect), isTrue, reason: '$key is on the screen: $rect');
            expect(finder.hitTestable(), findsOneWidget, reason: '$key can be pressed');
          }
        });
      }
    }
  }
}
