import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:party_host/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/night_harness.dart';
import 'support/toy_fonts.dart';

/// The room allowed before a width, a height or a type size counts as wrong: a
/// frame's scale leaves noise in the last digits (DESIGN section 2's math).
const _tolerance = 1e-6;

/// The reveal's sizes in frame px (DESIGN section 4, the awards reveal): the
/// card's big badge, and the award name, winner name and reason beside it.
const _badgePx = 190.0;
const _awardNamePx = 52.0;
const _winnerNamePx = 40.0;
const _reasonPx = 26.0;

/// The design's text floor under the frame (DESIGN section 1, rule 3).
const _textFloorPx = 20.0;

/// One device, with the scale and the frame the design's math gives it (DESIGN
/// section 2; the numbers are `host_frame_screen_test.dart`'s).
class _Case {
  const _Case({required this.label, required this.device, required this.frame});

  /// The device in the brief's words, for the test's name.
  final String label;

  /// The device's logical size: its physical size at a device pixel ratio of 1.
  final Size device;

  /// The size the host lays out in, in frame px: the card fills it but for the
  /// frame's gutters.
  final Size frame;
}

/// The five devices every slice of the phone-host layout is checked at
/// (`host_frame_screen_test.dart`).
const _cases = [
  _Case(label: '640x360, a small phone', device: Size(640, 360), frame: Size(960, 540)),
  _Case(label: '852x393, a phone in landscape', device: Size(852, 393), frame: Size(1170.6870229007634, 540)),
  _Case(label: '1024x768, a tablet', device: Size(1024, 768), frame: Size(960, 720)),
  _Case(label: '1280x800, a laptop', device: Size(1280, 800), frame: Size(960, 600)),
  _Case(label: '1920x1080, the TV', device: Size(1920, 1080), frame: Size(960, 540)),
];

/// One award as the reveal meets it: the stats the night's first round
/// reported, who won it and the reason it names, or none when nobody did.
class _AwardCase {
  const _AwardCase({
    required this.label,
    required this.award,
    this.stats = const {},
    this.winners = const [],
    this.reason,
  });

  final String label;
  final NightAward award;
  final Map<String, Map<String, int>> stats;

  /// The winners' nicknames, as their lines read.
  final List<String> winners;

  /// What the reason line says (the award's own line when nobody won it).
  final String? reason;
}

/// The reveal's three cases: an award P1 won, one two players share, and one
/// nobody qualified for. The counters are the night's own sum over its rounds,
/// so only the first round reports them (`night_reveal_test.dart`).
const _awards = [
  _AwardCase(
    label: 'a won award',
    award: NightAward.bestHelper,
    stats: {
      'p1': {'carries': 3},
      'p2': {'carries': 1},
    },
    winners: ['Alexandria'],
    reason: 'Most carries home together: 3',
  ),
  _AwardCase(
    label: 'a tied award',
    award: NightAward.bestHelper,
    stats: {
      'p1': {'carries': 2},
      'p2': {'carries': 2},
    },
    winners: ['Alexandria', 'Nightshade'],
    reason: 'Most carries home together: 2',
  ),
  _AwardCase(label: 'an award nobody won', award: NightAward.catCatcher, reason: 'Most cats shooed'),
];

/// A night's three awards with [first] revealed first: a night always plays
/// for three (`night_state.dart`), and the reveal shows them in their order.
List<NightAward> _nightAwards(NightAward first) => [
  first,
  for (final award in threeAwards)
    if (award != first) award,
].take(3).toList();

/// The look the frame's screens are drawn in: the TV's sizes, which the frame
/// hands its screens as `ToyType.frame` (`host_frame_screen_test.dart`).
ToyLook _look() => ToyLook.build(palette: ToyPalette.sunny, tv: true);

/// Mounts [home] the way a host app does (DESIGN section 5): the app's
/// [ProviderScope], the look and its theme, and the frame above the navigator
/// at [device]'s size with a device pixel ratio of 1, so logical and physical
/// pixels are the same (`host_frame_screen_test.dart`). [key] makes a second
/// mount of the same test a fresh app: without it Flutter keeps the first
/// one's tree, its route and its night.
Future<void> _pumpFrame(WidgetTester tester, Size device, {required Widget home, Key? key}) async {
  final look = _look();
  tester.view.physicalSize = device;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      key: key,
      overrides: [
        prefsProvider.overrideWithValue(prefs),
        soundPlayerProvider.overrideWithValue(FakeSoundPlayer()),
        gamePlayersProvider.overrideWith(TestRoster.new),
      ],
      // The sky drifts for as long as a menu is open, so every test that
      // settles puts the still one above the app (`host_harness.dart`).
      child: ToyStillSky(
        child: ToyLookScope(
          look: look,
          child: MaterialApp(theme: toyTheme(look), builder: hostFrameBuilder, home: home),
        ),
      ),
    ),
  );
}

/// A host app's home screen, standing in for one the test is not about: the
/// reveal is pushed over it, so its header can go back (`night_reveal_test`'s
/// Back case).
class _StubHome extends StatelessWidget {
  const _StubHome();

  @override
  Widget build(BuildContext context) => const Scaffold(key: Key('home'), body: SizedBox.shrink());
}

/// Puts the night's two players on the roster: a ten-letter nickname for the
/// winner's line and a second name for a tie (DESIGN section 6's name length).
void _putPlayers(ProviderContainer container) {
  (container.read(gamePlayersProvider.notifier) as TestRoster).put([
    nightPlayer('p1', 1, 'Alexandria'),
    nightPlayer('p2', 2, 'Nightshade'),
  ]);
}

void main() {
  // The look's own fonts: text measured in the test font has a box for every
  // letter, so a card would come out wider than a device's (`toy_fonts.dart`).
  setUpAll(loadLookFonts);

  /// The reveal open over a night already played, its three rounds in, with
  /// the two players this test puts on the roster.
  Future<void> openReveal(WidgetTester tester, _Case device, _AwardCase award) async {
    await _pumpFrame(
      tester,
      device.device,
      key: ValueKey('${device.label}/${award.label}'),
      home: const NightRevealScreen(),
    );
    final container = ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
    _putPlayers(container);
    final night = container.read(partyNightProvider.notifier)
      ..start(length: NightLength.three, awards: _nightAwards(award.award));
    for (var i = 0; i < 3; i++) {
      night.recordRound(roundResult(points: {'p1': 5, 'p2': 4}, stats: i == 0 ? award.stats : const {}));
    }
    await tester.pump();
  }

  /// A text on the reveal, drawn in [size] frame px.
  void expectLine(WidgetTester tester, String text, double size) {
    final finder = find.text(text);
    expect(finder, findsOneWidget, reason: '"$text" is on the reveal');
    expect(tester.widget<Text>(finder).style?.fontSize, closeTo(size, _tolerance), reason: '"$text" at $size');
  }

  for (final device in _cases) {
    testWidgets('the reveal fills the frame at ${device.label}', (tester) async {
      for (final award in _awards) {
        await openReveal(tester, device, award);

        // The card fills the stage: the frame less a gutter at each side, with
        // nothing scrolling (DESIGN section 1, rules 4 and 6).
        expect(
          find.descendant(of: find.byType(NightRevealScreen), matching: find.byType(Scrollable)),
          findsNothing,
          reason: '${award.label} does not scroll',
        );
        final card = tester.getSize(find.byKey(const Key('nightReveal')));
        expect(
          card.width,
          closeTo(device.frame.width - 2 * hostFrameGutterPx, _tolerance),
          reason: '${award.label} fills the stage',
        );

        // The big badge on the left: the winner's own with the crown, or the
        // award's disc when nobody won it.
        if (award.winners.isEmpty) {
          expect(tester.getSize(find.byType(NightDisc)).width, closeTo(_badgePx, _tolerance));
          expect(find.byType(NightCrown), findsNothing, reason: 'nobody won it');
          expect(find.byKey(const Key('nightAwardMissed')), findsOneWidget);
        } else {
          expect(tester.getSize(find.byType(PlayerBadge)).width, closeTo(_badgePx, _tolerance));
          expect(find.byType(NightCrown), findsOneWidget, reason: 'the winner wears the crown');
        }

        // The award's name, its winner(s) and the reason beside it, in the
        // design's sizes.
        expectLine(tester, award.award.title, _awardNamePx);
        for (final name in award.winners) {
          expectLine(tester, name, _winnerNamePx);
        }
        expectLine(tester, award.reason ?? award.award.line, _reasonPx);

        // Nothing under the frame is smaller than the design's 20 px floor.
        final texts = tester.widgetList<Text>(
          find.descendant(of: find.byType(NightRevealScreen), matching: find.byType(Text)),
        );
        expect(texts, isNotEmpty);
        for (final text in texts) {
          final size = text.style?.fontSize;
          expect(size, isNotNull, reason: '"${text.data}" is drawn at a size the frame names');
          expect(size! >= _textFloorPx, isTrue, reason: '"${text.data}" at $size frame px');
        }

        // The header says the screen's name and nothing else; the footer keeps
        // its paper band and its room, and is empty (the owner: no Skip and no
        // dots until M17).
        final header = find.byKey(const Key('hostFrameHeader'));
        expect(find.descendant(of: header, matching: find.byType(Text)), findsOneWidget);
        expect(
          tester.widget<Text>(find.descendant(of: header, matching: find.byType(Text))).data,
          NightText.partyNight,
        );
        final footer = find.byKey(const Key('hostFrameFooter'));
        expect(tester.getSize(footer).height, closeTo(hostFrameFooterHeightPx, _tolerance));
        expect(find.descendant(of: footer, matching: find.byType(ToyButton)), findsNothing);
        expect(find.descendant(of: footer, matching: find.byType(Text)), findsNothing);

        // The awards' timers take the final scores' place, as they always
        // have: three awards, one moment each.
        for (var i = 0; i < 3; i++) {
          await tester.pump(const Duration(milliseconds: nightAwardRevealMs));
        }
        await tester.pumpAndSettle();
        expect(find.text('Final scores'), findsOneWidget);
      }
    });
  }

  testWidgets('the back arrow finishes the reveal, opening the final scores', (tester) async {
    await _pumpFrame(tester, _cases.first.device, home: const _StubHome());
    final home = tester.element(find.byKey(const Key('home')));
    final container = ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
    _putPlayers(container);
    Navigator.of(home).push(MaterialPageRoute<void>(builder: (_) => const NightRevealScreen()));
    await tester.pumpAndSettle();
    final night = container.read(partyNightProvider.notifier)
      ..start(length: NightLength.three, awards: _nightAwards(NightAward.bestHelper));
    for (var i = 0; i < 3; i++) {
      night.recordRound(roundResult(points: {'p1': 5, 'p2': 4}));
    }
    await tester.pump();
    expect(find.text('Best Helper'), findsOneWidget);

    await tester.tap(find.byKey(const Key('hostTitleBarBack')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('nightReveal')), findsNothing, reason: 'Back skips the rest, as Escape does');
    expect(find.text('Final scores'), findsOneWidget);
  });
}
