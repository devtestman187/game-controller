import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/game_kit.dart';
import 'package:party_host/party_host.dart';
import 'package:party_host/testing.dart';
import 'package:test_game/test_game.dart' show roboPlayerId;

import 'support/all_looks.dart';
import 'support/host_harness.dart';
import 'support/night_harness.dart';
import 'support/toy_fonts.dart';

/// The owner's rule (PRD acceptance): every touch target is at least this many logical pixels on a side.
const minTargetDp = 48.0;

/// How far under [minTargetDp] a side may measure and still count as 48: the frame scales its layout, and the
/// scaled corners of a 48 px box leave floating-point noise in the last digits.
const roundingToleranceDp = 0.01;

/// The phone sizes the targets are measured at, as the controller app's touch-target test has them.
const targetSizes = {'568x320': Size(568, 320), '640x360': Size(640, 360), '375x667': Size(375, 667)};

/// The screens a phone host shows, one per way a button reaches the player.
enum HostScreen {
  /// The game picker: its cards and the footer's settings button.
  games,

  /// The Shape Race join screen (the lobby).
  lobby,

  /// The pause card over a running round.
  pause,

  /// The Bumper Round's results in a night: the footer's buttons.
  results,

  /// One award's tile with its "i", then the explanation the "i" opens.
  award,
}

/// Today's offenders, measured on the base: `'<screen>@<size>/<look> <key, tooltip, text or type>'` to the size found
/// on screen, in dp. The case is part of the key so that every entry is checked in the very case it was measured in:
/// the test needs every target outside this map to be at least [minTargetDp] and every entry here to still be
/// below it in its case, so whoever fixes a target removes its entries.
/// The sizes are rounded to a tenth of a dp. The frame draws a 48 px control at 48 x scale dp (scale .667 at 640x360,
/// .592 at 568x320, .391 at 375x667), so every footer button, back arrow, award "i" and pause button is below 48 on a
/// phone; the TV look's taller buttons are still below.
const knownBelow48Host = <String, Size>{
  'award@375x667/menu HostButton awardExplanationClose': Size(33.4, 18.8),
  'award@375x667/menu IconButton awardInfo-comeback': Size(18.8, 18.8),
  'award@375x667/tv HostButton awardExplanationClose': Size(33.4, 25.0),
  'award@375x667/tv IconButton awardInfo-comeback': Size(18.8, 18.8),
  'award@568x320/menu HostButton awardExplanationClose': Size(50.6, 28.4),
  'award@568x320/menu IconButton awardInfo-comeback': Size(28.4, 28.4),
  'award@568x320/tv HostButton awardExplanationClose': Size(50.6, 37.9),
  'award@568x320/tv IconButton awardInfo-comeback': Size(28.4, 28.4),
  'award@640x360/menu HostButton awardExplanationClose': Size(57.0, 32.0),
  'award@640x360/menu IconButton awardInfo-comeback': Size(32.0, 32.0),
  'award@640x360/tv HostButton awardExplanationClose': Size(57.0, 42.7),
  'award@640x360/tv IconButton awardInfo-comeback': Size(32.0, 32.0),
  'games@375x667/menu HostButton openPuzzleSettings': Size(110.2, 18.8),
  'games@375x667/tv HostButton openPuzzleSettings': Size(110.2, 25.0),
  'games@568x320/menu HostButton openPuzzleSettings': Size(166.9, 28.4),
  'games@568x320/tv HostButton openPuzzleSettings': Size(166.9, 37.9),
  'games@640x360/menu HostButton openPuzzleSettings': Size(188.0, 32.0),
  'games@640x360/tv HostButton openPuzzleSettings': Size(188.0, 42.7),
  'lobby@375x667/menu HostButton joinBack': Size(57.1, 18.8),
  'lobby@375x667/menu HostButton joinStart': Size(58.8, 18.8),
  'lobby@375x667/menu IconButton hostTitleBarBack': Size(18.8, 18.8),
  'lobby@375x667/tv HostButton joinBack': Size(57.1, 25.0),
  'lobby@375x667/tv HostButton joinStart': Size(58.8, 25.0),
  'lobby@375x667/tv IconButton hostTitleBarBack': Size(18.8, 18.8),
  'lobby@568x320/menu HostButton joinBack': Size(86.5, 28.4),
  'lobby@568x320/menu HostButton joinStart': Size(89.0, 28.4),
  'lobby@568x320/menu IconButton hostTitleBarBack': Size(28.4, 28.4),
  'lobby@568x320/tv HostButton joinBack': Size(86.5, 37.9),
  'lobby@568x320/tv HostButton joinStart': Size(89.0, 37.9),
  'lobby@568x320/tv IconButton hostTitleBarBack': Size(28.4, 28.4),
  'lobby@640x360/menu HostButton joinBack': Size(97.5, 32.0),
  'lobby@640x360/menu HostButton joinStart': Size(100.3, 32.0),
  'lobby@640x360/menu IconButton hostTitleBarBack': Size(32.0, 32.0),
  'lobby@640x360/tv HostButton joinBack': Size(97.5, 42.7),
  'lobby@640x360/tv HostButton joinStart': Size(100.3, 42.7),
  'lobby@640x360/tv IconButton hostTitleBarBack': Size(32.0, 32.0),
  'pause@375x667/menu HostButton pauseQuit': Size(54.7, 18.8),
  'pause@375x667/menu HostButton pauseResume': Size(71.5, 18.8),
  'pause@375x667/tv HostButton pauseQuit': Size(54.7, 25.0),
  'pause@375x667/tv HostButton pauseResume': Size(71.5, 25.0),
  'pause@568x320/menu HostButton pauseQuit': Size(82.9, 28.4),
  'pause@568x320/menu HostButton pauseResume': Size(108.3, 28.4),
  'pause@568x320/tv HostButton pauseQuit': Size(82.9, 37.9),
  'pause@568x320/tv HostButton pauseResume': Size(108.3, 37.9),
  'pause@640x360/menu HostButton pauseQuit': Size(93.4, 32.0),
  'pause@640x360/menu HostButton pauseResume': Size(122.1, 32.0),
  'pause@640x360/tv HostButton pauseQuit': Size(93.4, 42.7),
  'pause@640x360/tv HostButton pauseResume': Size(122.1, 42.7),
  'results@375x667/menu HostButton endNight': Size(80.7, 18.8),
  'results@375x667/menu HostButton next': Size(56.7, 18.8),
  'results@375x667/tv HostButton endNight': Size(80.7, 25.0),
  'results@375x667/tv HostButton next': Size(56.7, 25.0),
  'results@568x320/menu HostButton endNight': Size(122.2, 28.4),
  'results@568x320/menu HostButton next': Size(85.9, 28.4),
  'results@568x320/tv HostButton endNight': Size(122.2, 37.9),
  'results@568x320/tv HostButton next': Size(85.9, 37.9),
  'results@640x360/menu HostButton endNight': Size(137.7, 32.0),
  'results@640x360/menu HostButton next': Size(96.8, 32.0),
  'results@640x360/tv HostButton endNight': Size(137.7, 42.7),
  'results@640x360/tv HostButton next': Size(96.8, 42.7),
};

/// The tappables whose hit area is measured; a button's own [InkWell] is not counted twice.
bool _isTappable(Widget w) => w is HostButton || w is ToyButton || w is IconButton || w is InkWell;

/// True when [w] is a tappable that has its own hit area (an [InkWell] inside it is not counted again).
bool _isOuterTappable(Widget w) => w is HostButton || w is ToyButton || w is IconButton;

/// The case's label in [knownBelow48Host]: screen, size and look.
String _caseLabel(HostScreen screen, String size, HostLook look) => '${screen.name}@$size/${look.name}';

void main() {
  setUpAll(loadLookFonts);

  for (final screen in HostScreen.values) {
    for (final size in targetSizes.entries) {
      for (final look in HostLook.values) {
        final label = _caseLabel(screen, size.key, look);
        testWidgets('every touch target on $label is at least 48 dp or listed in knownBelow48Host, and every '
            'listed one is still below', (tester) async {
          final found = await _measureScreen(tester, screen, size.value, look, label);
          expect(found, isNotEmpty, reason: 'no touch target found on $label');
          final below = {
            for (final e in found.entries)
              if (_isBelow(e.value)) e.key: e.value,
          };
          final unlisted = [
            for (final e in below.entries)
              if (!knownBelow48Host.containsKey(e.key)) '${e.key}: ${e.value}',
          ];
          expect(unlisted, isEmpty, reason: 'touch targets below 48 dp that knownBelow48Host does not list');
          final fixed = [
            for (final key in knownBelow48Host.keys)
              if (key.startsWith('$label ') && !below.containsKey(key)) key,
          ];
          expect(fixed, isEmpty, reason: 'these are 48 dp or more now: remove them from knownBelow48Host');
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}

bool _isBelow(Size size) =>
    size.width < minTargetDp - roundingToleranceDp || size.height < minTargetDp - roundingToleranceDp;

/// Mounts [screen] at [size] in [look] and measures what is on it (the award screen twice: tile, then explanation).
Future<Map<String, Size>> _measureScreen(
  WidgetTester tester,
  HostScreen screen,
  Size size,
  HostLook look,
  String label,
) async {
  switch (screen) {
    case HostScreen.games:
      await pumpHostLook(
        tester,
        look,
        screen: const _InFrame(child: GamesScreen()),
        size: size,
      );
    case HostScreen.lobby:
      final fake = await _pumpHome(tester, look, size);
      await openJoin(tester);
      await neutral(tester, fake, ['p1']);
      await press(tester, fake, 'p1', GamepadButton.a);
      expect(find.byType(JoinScreen), findsOneWidget);
    case HostScreen.pause:
      final fake = await _pumpHome(tester, look, size);
      fake.state = withController(fake.state, phoneInfo('p2', 2));
      fake.emit();
      await neutral(tester, fake, ['p1', 'p2']);
      await openJoin(tester);
      await startRace(tester, fake);
      await press(tester, fake, 'p1', GamepadButton.start);
      await navigated(tester);
      expect(find.byKey(const Key('pauseMenu')), findsOneWidget);
    case HostScreen.results:
      await _pumpResults(tester, look, size);
    case HostScreen.award:
      await pumpHostLook(
        tester,
        look,
        framed: true,
        size: size,
        screen: const _TileScreen(award: NightAward.comeback),
      );
      final tile = _measure(tester, label);
      await tester.tap(find.byKey(Key('awardInfo-${NightAward.comeback.name}')));
      await tester.pumpAndSettle();
      return {...tile, ..._measure(tester, label)};
  }
  return _measure(tester, label);
}

/// The host at [size] in [look], in the frame, on [StubHome].
Future<FakeHostService> _pumpHome(WidgetTester tester, HostLook look, Size size) =>
    pumpHostLook(tester, look, screen: const StubHome(), size: size, framed: true);

/// The Bumper Round's results in a night, in the frame, with two phones on the roster.
Future<void> _pumpResults(WidgetTester tester, HostLook look, Size size) async {
  final again = FocusNode(debugLabel: 'arenaAgain');
  addTearDown(again.dispose);
  await pumpHostLook(
    tester,
    look,
    screen: _InFrame(
      child: ArenaResults(
        result: RoundResult(
          game: 'arena',
          winners: const {'p1'},
          points: const {'p1': 9, 'p2': 5},
          lines: {
            'p1': const RoundLine(outcome: RoundOutcome.loss, count: 9, countOf: RoundCount.coins),
            'p2': const RoundLine(outcome: RoundOutcome.loss, count: 5, countOf: RoundCount.coins),
            roboPlayerId: const RoundLine(outcome: RoundOutcome.loss, count: 1, countOf: RoundCount.coins),
          },
        ),
        night: true,
        lastRound: false,
        againFocus: again,
        onAgain: () {},
        onChangeMode: () {},
        onNext: () {},
        onEndNight: () {},
      ),
    ),
    size: size,
    overrides: [gamePlayersProvider.overrideWith(TestRoster.new)],
  );
  final roster = appContainer(tester).read(gamePlayersProvider.notifier) as TestRoster;
  roster.put([nightPlayer('p1', 1, 'Maxi'), nightPlayer('p2', 2, 'Alexandria')]);
  await tester.pumpAndSettle();
}

/// [child] drawn in the host's frame, as the app draws every screen (DESIGN section 5).
class _InFrame extends StatelessWidget {
  const _InFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => hostFrameBuilder(context, child);
}

/// One award's tile alone on a screen, so its "i" can be measured and opened.
class _TileScreen extends StatelessWidget {
  const _TileScreen({required this.award});

  final NightAward award;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: SizedBox(
        width: _tileWidthDp,
        child: AwardTile(award: award, colour: ToyLookScope.of(context).colors.player(1)),
      ),
    ),
  );
}

/// The width a start card's tile has room for in the frame's row (as `award_explanation_tv_test.dart` has it).
const _tileWidthDp = 320.0;

/// Every tappable on screen as `'<label> <name>'` to the smallest on-screen size found for that name.
Map<String, Size> _measure(WidgetTester tester, String label) {
  final sizes = <String, Size>{};
  final counted = <Element>{};
  for (final element in find.byWidgetPredicate(_isTappable).evaluate()) {
    if (!counted.add(element) || _insideTappable(element)) continue;
    final box = element.renderObject;
    if (box is! RenderBox || !box.hasSize) continue;
    // The frame scales its layout, so the corners go through the transforms to give the size the player sees.
    final onScreen = Size(
      box.localToGlobal(box.size.bottomRight(Offset.zero)).dx - box.localToGlobal(Offset.zero).dx,
      box.localToGlobal(box.size.bottomRight(Offset.zero)).dy - box.localToGlobal(Offset.zero).dy,
    );
    final key = '$label ${_nameOf(element)}';
    final old = sizes[key];
    if (old == null || onScreen.width * onScreen.height < old.width * old.height) sizes[key] = onScreen;
  }
  return sizes;
}

/// True when [element] sits inside another tappable that has its own hit area.
bool _insideTappable(Element element) {
  var inside = false;
  element.visitAncestorElements((ancestor) {
    if (_isOuterTappable(ancestor.widget)) {
      inside = true;
      return false;
    }
    return true;
  });
  return inside;
}

/// The widget's key, else its tooltip, else its first text, else its type.
String _nameOf(Element element) {
  final w = element.widget;
  final type = w.runtimeType.toString();
  final key = w.key;
  if (key is ValueKey) return '$type ${key.value}';
  if (w is IconButton && w.tooltip != null) return '$type ${w.tooltip}';
  String? text;
  void visit(Element child) {
    if (text != null) return;
    final cw = child.widget;
    if (cw is Text && cw.data != null) {
      text = cw.data;
      return;
    }
    child.visitChildren(visit);
  }

  element.visitChildren(visit);
  return text == null ? type : '$type $text';
}
