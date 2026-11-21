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

/// How far the footer band's room above its buttons may be from the room below
/// them, in frame px (brief fB: within 0.5).
const _bandSlackPx = 0.5;

/// The design's text floor under the frame (DESIGN section 1, rule 3).
const _textFloorPx = 20.0;

/// A winner's name in frame px, per size tier (brief fB): the design's 40 for
/// one or two winners, 32 for three and 24 for four or more.
const _designWinnerPx = 40.0;
const _tieWinnerPx = 32.0;
const _manyWinnerPx = 24.0;

/// The most names a five- or six-way tie puts in one column: three, so six
/// names make three rows (brief fB).
const _tieColumnMaxNames = 3;

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

/// The five devices every slice of the phone-host layout is checked at
/// (`host_frame_screen_test.dart`).
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

/// The roster a tie is drawn for: six players, the first with the design's
/// ten-character name (DESIGN section 6).
const _playerNames = ['Alexandria', 'Nightshade', 'Bright Fox', 'Milo', 'Jo', 'Ziggy'];

/// One tie as the reveal meets it: how many of the roster's players carry the
/// same, so all of them win, and the shape their lines take (brief fB).
class _TieCase {
  const _TieCase({required this.label, required this.winners, required this.namePx, this.columns = 1});

  /// The tie in the test's name: "a three-way tie".
  final String label;

  /// How many players share the award.
  final int winners;

  /// The size each winner's name is drawn at, in frame px.
  final double namePx;

  /// How many columns the names sit in: one for up to four winners, two for
  /// five or six (brief fB).
  final int columns;
}

const _ties = [
  _TieCase(label: 'a two-way tie', winners: 2, namePx: _designWinnerPx),
  _TieCase(label: 'a three-way tie', winners: 3, namePx: _tieWinnerPx),
  _TieCase(label: 'a four-way tie', winners: 4, namePx: _manyWinnerPx),
  _TieCase(label: 'a five-way tie', winners: 5, namePx: _manyWinnerPx, columns: 2),
  _TieCase(label: 'a six-way tie', winners: 6, namePx: _manyWinnerPx, columns: 2),
];

/// The look the frame's screens are drawn in: the TV's sizes, which the frame
/// hands its screens as `ToyType.frame` (`host_frame_screen_test.dart`).
ToyLook _look() => ToyLook.build(palette: ToyPalette.sunny, tv: true);

/// Mounts [home] the way a host app does (DESIGN section 5): the app's
/// [ProviderScope], the look and its theme, and the frame above the navigator
/// at [device]'s size with a device pixel ratio of 1, so logical and physical
/// pixels are the same (`night_reveal_frame_test.dart`). [key] makes a second
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

/// A night's three awards with [first] revealed first: a night always plays
/// for three (`night_state.dart`), and the reveal shows them in their order.
List<NightAward> _nightAwards(NightAward first) => [
  first,
  for (final award in threeAwards)
    if (award != first) award,
].take(3).toList();

/// The night's first round counters: the first [winners] players carry two
/// each and the rest one, so Best Helper is a tie of exactly [winners].
Map<String, Map<String, int>> _tieStats(int winners) => {
  for (var i = 0; i < _playerNames.length; i++) 'p${i + 1}': {'carries': i < winners ? 2 : 1},
};

/// A screen whose footer holds two way-on buttons, at the right end: the
/// buttons the band's padding is measured around (brief fB).
class _BandScreen extends StatelessWidget {
  const _BandScreen();

  @override
  Widget build(BuildContext context) => HostFrameScreen(
    title: 'Party night',
    body: const SizedBox.shrink(),
    footer: [
      ToyButton(key: const Key('bandFirst'), label: 'Shape Race', onPressed: () {}),
      ToyButton(key: const Key('bandSecond'), label: 'Bumper Round', onPressed: () {}),
    ],
  );
}

/// The names' left edges, one per column, in the order they read left to
/// right: two names share a column when their left edges agree.
List<double> _columnLefts(List<Rect> names) {
  final lefts = <double>[];
  for (final name in names) {
    if (!lefts.any((left) => (left - name.left).abs() <= _tolerance)) lefts.add(name.left);
  }
  lefts.sort();
  return lefts;
}

void main() {
  // The look's own fonts: text measured in the test font has a box for every
  // letter, so a card would come out wider than a device's (`toy_fonts.dart`).
  setUpAll(loadLookFonts);

  /// The reveal open over a night already played, its three rounds in, the
  /// roster of six and Best Helper shared by [tie]'s players.
  Future<void> openReveal(WidgetTester tester, _Case device, _TieCase tie) async {
    await _pumpFrame(
      tester,
      device.device,
      key: ValueKey('${device.label}/${tie.label}'),
      home: const NightRevealScreen(),
    );
    final container = ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
    (container.read(gamePlayersProvider.notifier) as TestRoster).put([
      for (var i = 0; i < _playerNames.length; i++) nightPlayer('p${i + 1}', i + 1, _playerNames[i]),
    ]);
    final night = container.read(partyNightProvider.notifier)
      ..start(length: NightLength.three, awards: _nightAwards(NightAward.bestHelper));
    // The counters are the night's own sum over its rounds, so only the first
    // round reports them (`night_reveal_test.dart`).
    for (var i = 0; i < 3; i++) {
      night.recordRound(roundResult(points: {'p1': 5, 'p2': 4}, stats: i == 0 ? _tieStats(tie.winners) : const {}));
    }
    await tester.pump();
  }

  /// The card's names sit in [tie]'s columns, each holding at most three, so a
  /// full tie makes three rows rather than six (brief fB).
  void expectColumns(WidgetTester tester, _TieCase tie) {
    final names = [for (var i = 0; i < tie.winners; i++) tester.getRect(find.text(_playerNames[i]))];
    final lefts = _columnLefts(names);
    expect(lefts, hasLength(tie.columns), reason: '${tie.label}: the names sit in ${tie.columns} column(s)');
    for (final left in lefts) {
      final column = names.where((name) => (name.left - left).abs() <= _tolerance).toList();
      // Only a tie that splits its names bounds a column; one column holds
      // them all.
      if (tie.columns > 1) {
        expect(
          column.length,
          lessThanOrEqualTo(_tieColumnMaxNames),
          reason: '${tie.label}: no column holds more than $_tieColumnMaxNames names',
        );
      }
      for (var i = 1; i < column.length; i++) {
        expect(
          column[i].top,
          greaterThan(column[i - 1].top),
          reason: '${tie.label}: each name in a column has a row of its own',
        );
      }
    }
  }

  for (final device in _cases) {
    testWidgets('${device.label}: a tie keeps the reveal inside its card', (tester) async {
      for (final tie in _ties) {
        await openReveal(tester, device, tie);

        // Nothing scrolls and nothing overflows: the names, the reason and the
        // points fit the card, and the card fits the body between the header
        // and the footer (DESIGN section 1, rule 6; brief fB).
        expect(tester.takeException(), isNull, reason: '${tie.label}: nothing overflows');
        expect(
          find.descendant(of: find.byType(NightRevealScreen), matching: find.byType(Scrollable)),
          findsNothing,
          reason: '${tie.label} does not scroll',
        );
        final body = tester.getRect(find.byKey(const Key('hostFrameBody')));
        final card = tester.getRect(find.byKey(const Key('nightReveal')));
        expect(
          card.top,
          greaterThanOrEqualTo(body.top - _tolerance),
          reason: '${tie.label}: the card starts inside the body',
        );
        expect(
          card.bottom,
          lessThanOrEqualTo(body.bottom + _tolerance),
          reason: '${tie.label}: the card\'s bottom is inside the body',
        );

        // Each winner gets a line of their own, one line long and ellipsised,
        // in the size its tier takes (brief fB).
        for (var i = 0; i < tie.winners; i++) {
          final name = find.text(_playerNames[i]);
          expect(name, findsOneWidget, reason: '${tie.label}: "${_playerNames[i]}" is on the reveal');
          final line = tester.widget<Text>(name);
          expect(
            line.style?.fontSize,
            closeTo(tie.namePx, _tolerance),
            reason: '${tie.label}: "${_playerNames[i]}" at ${tie.namePx} frame px',
          );
          expect(line.maxLines, 1, reason: '${tie.label}: a name is one line');
          expect(line.overflow, TextOverflow.ellipsis, reason: '${tie.label}: a long name ellipsises');
        }
        if (tie.winners < _playerNames.length) {
          expect(
            find.text(_playerNames[tie.winners]),
            findsNothing,
            reason: '${tie.label}: only the players who tied get a line',
          );
        }
        expectColumns(tester, tie);

        // Nothing under the frame is smaller than the design's 20 px floor.
        final texts = tester.widgetList<Text>(
          find.descendant(of: find.byType(NightRevealScreen), matching: find.byType(Text)),
        );
        for (final text in texts) {
          final size = text.style?.fontSize;
          expect(size, isNotNull, reason: '"${text.data}" is drawn at a size the frame names');
          expect(size! >= _textFloorPx, isTrue, reason: '"${text.data}" at $size frame px');
        }

        // The awards' timers take the final scores' place, so no timer is left
        // running when the next tie mounts.
        for (var i = 0; i < 3; i++) {
          await tester.pump(const Duration(milliseconds: nightAwardRevealMs));
        }
        await tester.pumpAndSettle();
      }
    });
  }

  testWidgets('the footer band pads its buttons evenly at every size', (tester) async {
    final inkWidth = _look().sizes.outlineWidth;
    for (final device in _cases) {
      await _pumpFrame(tester, device.device, key: ValueKey(device.label), home: const _BandScreen());
      final band = tester.getRect(find.byKey(const Key('hostFrameFooterBand')));
      final button = tester.getRect(find.byKey(const Key('bandFirst')));
      // The ink line paints the band's first inkWidth frame px, and the buttons
      // stand centred in the room under it, so the room above them (the ink
      // line and the band's top padding) equals the room below (brief fB).
      final above = button.top - band.top;
      final below = band.bottom - button.bottom;
      expect(
        above,
        closeTo(below, _bandSlackPx * device.scale),
        reason: '${device.label}: ${above / device.scale} px above the buttons, ${below / device.scale} below',
      );
      expect(
        above,
        greaterThanOrEqualTo(inkWidth * device.scale),
        reason: '${device.label}: the ink line is inside the band, above the buttons',
      );
    }
  });
}
