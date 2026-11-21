import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:party_host/testing.dart';
import 'package:puzzle_game/puzzle_game.dart';

import 'support/host_harness.dart';
import 'support/night_harness.dart';
import 'support/toy_fonts.dart';

/// The slack sizes are compared with, as `host_frame_screen_test.dart` has it:
/// [Size] is two doubles, and a frame's arithmetic leaves noise in the last
/// digits.
const _tolerance = 1e-9;

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
const _devices = [
  _Case(label: '640x360, a small phone', device: Size(640, 360), frame: Size(960, 540)),
  _Case(label: '852x393, a phone in landscape', device: Size(852, 393), frame: Size(1170.6870229007634, 540)),
  _Case(label: '1024x768, a tablet', device: Size(1024, 768), frame: Size(960, 720)),
  _Case(label: '1280x800, a laptop', device: Size(1280, 800), frame: Size(960, 600)),
  _Case(label: '1920x1080, the TV', device: Size(1920, 1080), frame: Size(960, 540)),
];

/// The frame's text floor, in frame px (DESIGN section 1, rule 3): no host
/// screen draws smaller type.
const _floorPx = 20.0;

/// The keys the frame's regions and the results' parts are looked up by.
const _bodyKey = Key('hostFrameBody');
const _footerKey = Key('hostFrameFooter');
const _cardKey = Key('puzzleResults');
const _titleKey = Key('puzzleResultTitle');
const _chipKey = Key('puzzleResultChip');
const _photoKey = Key('puzzlePhoto-left');

/// The phones the sample host already has, and the most a side seats: the
/// test adds the phones a bigger round needs.
const _samplePhones = 2;
const _playersASide = 2;

/// One results case the tests open: the round, its teams and the buttons the
/// layout owes (the brief's five cases).
class _ResultsCase {
  const _ResultsCase({
    required this.label,
    required this.phones,
    required this.teams,
    required this.choice,
    required this.footer,
    required this.secondary,
    this.anyRound = false,
    this.night = false,
    this.roundsPlayed = 0,
  });

  /// The case in the brief's words, for the test's name.
  final String label;

  /// The phones in the round, P1 first: the roster the host has.
  final List<String> phones;

  /// Each player's side.
  final Map<String, PuzzleSide> teams;

  /// What the round plays.
  final PuzzleChoice choice;

  /// Whether the round is an `any <level> puzzle` one (it draws a match of its
  /// own, so a test can lock its pieces).
  final bool anyRound;

  /// Whether the round is a night's, and how many of the night's rounds are
  /// already recorded.
  final bool night;
  final int roundsPlayed;

  /// The footer's buttons, in the order they show, and the body's.
  final List<Key> footer;
  final List<Key> secondary;
}

/// The five results the tests open: an `any <level>` race for two and for four
/// players, a night's round before its last and its last, and a series round.
final _cases = <_ResultsCase>[
  const _ResultsCase(
    label: 'an any-puzzle race between two players',
    phones: ['p1', 'p2'],
    teams: {'p1': PuzzleSide.left, 'p2': PuzzleSide.right},
    choice: PuzzleChoice(level: Level.easy),
    anyRound: true,
    footer: [Key('nextPuzzle'), Key('resultsBack')],
    secondary: [Key('changeTeams')],
  ),
  const _ResultsCase(
    label: 'a race between two teams of two',
    phones: ['p1', 'p2', 'p3', 'p4'],
    teams: {'p1': PuzzleSide.left, 'p2': PuzzleSide.left, 'p3': PuzzleSide.right, 'p4': PuzzleSide.right},
    choice: PuzzleChoice(level: Level.easy),
    anyRound: true,
    footer: [Key('nextPuzzle'), Key('resultsBack')],
    secondary: [Key('changeTeams')],
  ),
  const _ResultsCase(
    label: "a night's round before its last",
    phones: ['p1'],
    teams: {'p1': PuzzleSide.left},
    choice: PuzzleChoice(level: Level.easy, puzzleId: 'house'),
    night: true,
    footer: [Key('next'), Key('endNight')],
    secondary: [],
  ),
  const _ResultsCase(
    label: "a night's last round",
    phones: ['p1'],
    teams: {'p1': PuzzleSide.left},
    choice: PuzzleChoice(level: Level.easy, puzzleId: 'house'),
    night: true,
    roundsPlayed: 2,
    footer: [Key('next')],
    secondary: [],
  ),
  const _ResultsCase(
    label: 'a series round',
    phones: ['p1'],
    teams: {'p1': PuzzleSide.left},
    choice: PuzzleChoice(level: Level.easy, puzzleId: 'house'),
    footer: [Key('nextPuzzle'), Key('resultsBack')],
    secondary: [Key('shuffle'), Key('playAgain'), Key('changeTeams')],
  ),
];

/// [child] in the host frame, as both host apps draw every screen (DESIGN
/// section 5): [hostFrameBuilder] over it, so the round lays out at the frame's
/// size and in the frame's type, and its header's arrow has a route to pop.
class _InFrame extends StatelessWidget {
  const _InFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => hostFrameBuilder(context, child);
}

/// The phones of [ids] joined to the host at [device]'s size.
Future<FakeHostService> _hostWith(WidgetTester tester, Size device, List<String> ids) async {
  final fake = await pumpHost(tester, screen: const StubHome(), size: device);
  var state = fake.state;
  for (final id in ids) {
    final number = int.parse(id.substring(1));
    if (number > _samplePhones && number <= _samplePhones + _playersASide) {
      state = withController(state, phoneInfo(id, number));
    }
  }
  fake.state = state;
  fake.emit();
  await neutral(tester, fake, ids);
  return fake;
}

/// Pushes the round's screen on a route of its own, in the frame, as the join
/// screen's Start does.
void _pushRound(WidgetTester tester, _ResultsCase c) {
  final match = c.anyRound ? PuzzleMatch(housePuzzle(), teams: c.teams, random: Random(1)) : null;
  tester
      .state<NavigatorState>(find.byType(Navigator))
      .push(
        MaterialPageRoute<void>(
          builder: (_) => _InFrame(
            child: PuzzleScreen(choice: c.choice, teams: c.teams, match: match),
          ),
        ),
      );
}

/// Starts the case's round and plays it out to its results.
Future<void> _openResults(WidgetTester tester, Size device, _ResultsCase c) async {
  await _hostWith(tester, device, c.phones);
  if (c.night) {
    final night = appContainer(tester).read(partyNightProvider.notifier)
      ..start(length: NightLength.three, awards: threeAwards);
    for (var i = 0; i < c.roundsPlayed; i++) {
      night.recordRound(roundResult(points: {c.phones.first: 5}, winners: {c.phones.first}));
    }
  }
  _pushRound(tester, c);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  lockEveryPiece(tester);
  // The finish celebrates first and the card pops in after it: both have to be
  // over before a rect is read.
  await endRound(tester);
  await tester.pump(const Duration(milliseconds: 300));
}

/// Every text under the results' frame screen, with the style it is drawn in
/// (the frame's floor of 20 px, DESIGN section 1, rule 3).
Iterable<({String? text, double? size})> _texts(WidgetTester tester) sync* {
  for (final element in find.descendant(of: find.byType(HostFrameScreen), matching: find.byType(Text)).evaluate()) {
    final text = element.widget as Text;
    final style = DefaultTextStyle.of(element).style.merge(text.style);
    yield (text: text.data, size: style.fontSize);
  }
}

/// Whether [inner] sits whole inside [outer], [slack] px of round-off allowed.
bool _inside(Rect outer, Rect inner, {double slack = 0}) =>
    inner.left >= outer.left - slack &&
    inner.top >= outer.top - slack &&
    inner.right <= outer.right + slack &&
    inner.bottom <= outer.bottom + slack;

void main() {
  setUpAll(loadLookFonts);

  for (final device in _devices) {
    for (final c in _cases) {
      testWidgets('${device.label}, ${c.label}: the results fill the frame with no scroll, '
          'the footer on and the body\'s buttons right of the picture', (tester) async {
        await _openResults(tester, device.device, c);
        expect(tester.takeException(), isNull, reason: 'the results fit the frame (DESIGN rule 6)');
        expect(
          find.descendant(of: find.byKey(_bodyKey), matching: find.byType(Scrollable)),
          findsNothing,
          reason: 'nothing scrolls on a host screen (DESIGN section 1, rule 6)',
        );

        // The way on is in the 84 px footer, on screen and under a thumb.
        final footer = tester.getRect(find.byKey(_footerKey));
        for (final key in c.footer) {
          final rect = tester.getRect(find.byKey(key));
          expect(_inside(footer, rect, slack: _tolerance), isTrue, reason: '$key sits in the footer: $rect');
          expect(find.byKey(key).hitTestable(), findsOneWidget, reason: '$key can be pressed');
        }
        for (final key in const [Key('endNight'), Key('resultsBack'), Key('next')]) {
          if (c.footer.contains(key)) continue;
          expect(find.byKey(key), findsNothing, reason: '$key is not this round\'s way on');
        }

        // The secondary controls are the body's, in the column right of the
        // picture (the S6b decision: the 84 px footer holds the way on alone).
        final body = tester.getRect(find.byKey(_bodyKey));
        final photo = tester.getRect(find.byKey(_photoKey));
        for (final key in c.secondary) {
          final rect = tester.getRect(find.byKey(key));
          expect(_inside(body, rect, slack: _tolerance), isTrue, reason: '$key is in the body: $rect');
          expect(rect.left, greaterThanOrEqualTo(photo.right), reason: '$key is right of the picture');
          expect(rect.width, lessThanOrEqualTo(body.width), reason: '$key fits the body');
        }
        for (final key in const [Key('shuffle'), Key('playAgain'), Key('rematch'), Key('changeTeams')]) {
          if (c.secondary.contains(key)) continue;
          expect(find.byKey(key), findsNothing, reason: '$key is not this round\'s control');
        }

        // The card fills the stage, the pictures stand at its left and the
        // round's words at its right (DESIGN section 1, rule 4; section 4).
        expect(
          tester.getSize(find.byKey(_cardKey)).width,
          moreOrLessEquals(device.frame.width - 2 * hostFrameGutterPx, epsilon: _tolerance),
          reason: 'the card is the stage minus its 24 px gutters',
        );
        expect(photo.right, lessThan(tester.getRect(find.byKey(_titleKey)).left), reason: 'the picture is left');

        // Every word is a frame size, the results' own included.
        final texts = _texts(tester).toList();
        expect(texts, isNotEmpty);
        for (final text in texts) {
          expect(
            text.size,
            greaterThanOrEqualTo(_floorPx - _tolerance),
            reason: '"${text.text}" is a frame size (DESIGN rule 3)',
          );
        }
      });
    }
  }

  testWidgets('the headline sits on a chip in the winning side\'s colour', (tester) async {
    final race = _cases.first;
    await _openResults(tester, const Size(640, 360), race);

    final look = ToyLookScope.of(tester.element(find.byKey(_cardKey)));
    expect(tester.widget<Text>(find.byKey(_titleKey)).data, 'Left wins!');
    final chip = tester.widget<Container>(find.byKey(_chipKey));
    expect((chip.decoration! as BoxDecoration).color, look.colors.player(1), reason: 'the winner\'s colour heads it');
    expect(tester.widget<Text>(find.byKey(_titleKey)).style?.color, look.colors.ink, reason: 'ink on the chip');
  });

  testWidgets("a night's round heads its card in the good colour, as a finished one-board round does", (tester) async {
    final night = _cases[2];
    await _openResults(tester, const Size(640, 360), night);

    final look = ToyLookScope.of(tester.element(find.byKey(_cardKey)));
    expect(tester.widget<Text>(find.byKey(_titleKey)).data, 'Done!');
    final chip = tester.widget<Container>(find.byKey(_chipKey));
    expect((chip.decoration! as BoxDecoration).color, look.colors.good);
  });

  testWidgets('the way on keeps the focus as the card comes up, and the header\'s arrow pops the round', (
    tester,
  ) async {
    final series = _cases.last;
    await _openResults(tester, const Size(640, 360), series);

    expect(focused(tester, 'nextPuzzle'), isTrue, reason: 'the phone\'s A and the remote\'s OK work at once');
    expect(find.byKey(const Key('hostTitleBarBack')), findsOneWidget, reason: 'the route can pop, so the arrow shows');
    await tester.tap(find.byKey(const Key('hostTitleBarBack')));
    await navigated(tester);
    expect(find.byType(PuzzleScreen), findsNothing, reason: 'the arrow pops the round, as Back does');
  });
}
