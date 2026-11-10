import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:party_host/testing.dart';

import 'support/host_harness.dart';
import 'support/pixels.dart';

/// How wide a band round a focused widget's own box counts as its edge, in
/// logical pixels: the focus ring and a pixel either side of it.
const _edgeBand = 6.0;

/// Whether the primary focus is inside the widget keyed [key].
bool _inside(String key) {
  final context = FocusManager.instance.primaryFocus?.context;
  if (context is! Element) return false;
  var found = false;
  context.visitAncestorElements((ancestor) {
    if (ancestor.widget.key == Key(key)) {
      found = true;
      return false;
    }
    return true;
  });
  return found;
}

/// The box of the widget that has the focus, in the test screen's pixels.
Rect _focusedRect(WidgetTester tester) {
  final box = FocusManager.instance.primaryFocus!.context!.findRenderObject()! as RenderBox;
  return box.localToGlobal(Offset.zero) & box.size;
}

/// How many pixels of [ink] are painted in the band round [box]'s edge: what
/// the focus look adds to the edge of the thing that has the focus.
int edgeInk(Pixels pixels, Rect box, int ink) {
  var count = 0;
  for (var y = box.top.floor(); y < box.bottom.ceil(); y++) {
    for (var x = box.left.floor(); x < box.right.ceil(); x++) {
      final near =
          x - box.left < _edgeBand ||
          box.right - x <= _edgeBand ||
          y - box.top < _edgeBand ||
          box.bottom - y <= _edgeBand;
      if (near && pixels.at(x, y) == ink) count++;
    }
  }
  return count;
}

/// Walks the pad's focus to the control keyed [key], one press at a time, at
/// most [tries], and says whether it got there.
Future<bool> _walkTo(
  WidgetTester tester,
  FakeHostService fake,
  String key, {
  GamepadButton direction = GamepadButton.dpadDown,
  int tries = 40,
}) async {
  for (var i = 0; i < tries; i++) {
    if (_inside(key)) return true;
    await press(tester, fake, 'p1', direction);
  }
  return _inside(key);
}

void main() {
  testWidgets('the picker rings the card that has the focus', (tester) async {
    final fake = await pumpHost(tester, screen: const StubHome());
    await neutral(tester, fake, ['p1']);
    await tapVisible(tester, find.byKey(const Key('openPlay')));
    await tester.pumpAndSettle();

    final card = tester.getRect(find.byKey(const Key('pickPartyNight')));
    final focus = argb(ToyLookScope.of(tester.element(find.byKey(const Key('pickPartyNight')))).colors.focus);
    final pixels = await screenPixels(tester);
    expect(edgeInk(pixels, card, focus), greaterThan(0), reason: 'the card has the focus, so its ring must paint');

    // The ring moves with the focus: the night's card is the picker's last, so
    // left walks to the Arena.
    await press(tester, fake, 'p1', GamepadButton.dpadLeft);
    expect(_inside('pickArena'), isTrue);
    final arena = tester.getRect(find.byKey(const Key('pickArena')));
    final after = await screenPixels(tester);
    expect(edgeInk(after, arena, focus), greaterThan(0), reason: 'the ring follows the focus to the Arena card');
    expect(edgeInk(after, card, focus), 0, reason: 'and the card it left has none');
  });

  // The controls that aren't toy buttons or cards: a switch, a slider, a
  // segment and the title bar's back arrow are Material's, and their focus
  // look is the theme's wash. Each has to show the toy ring instead (m13 s21).
  final surfaces = <({String name, Widget screen, String key})>[
    (name: 'the puzzle settings switch', screen: const PuzzleSettingsScreen(), key: 'setting-dropReadyHighlight'),
    (name: 'the effects switch', screen: const LookAndSoundScreen(), key: 'lookEffects'),
    (name: 'the mute switch', screen: const LookAndSoundScreen(), key: 'soundMute'),
    (name: 'a volume slider', screen: const LookAndSoundScreen(), key: 'soundVolume'),
    (name: 'the palette segments', screen: const LookAndSoundScreen(), key: 'lookChoice'),
    // The toy buttons on the settings and the Shape Race screens, for the
    // screens whose buttons the pad walks: a row's step buttons, and a level's
    // play buttons.
    (name: "a puzzle setting's step buttons", screen: const PuzzleSettingsScreen(), key: 'setting-angleToleranceDeg'),
  ];
  for (final surface in surfaces) {
    testWidgets('${surface.name} shows the ring when the pad reaches it', (tester) async {
      final fake = await pumpHost(tester, screen: surface.screen);
      await neutral(tester, fake, ['p1']);
      expect(await _walkTo(tester, fake, surface.key), isTrue, reason: 'the pad reaches ${surface.key}');
      // A Material overlay fades in; the ring is there with it.
      await tester.pump(const Duration(milliseconds: 400));

      final box = _focusedRect(tester);
      final focus = argb(ToyLookScope.of(tester.element(find.byKey(Key(surface.key)))).colors.focus);
      final pixels = await screenPixels(tester);
      expect(edgeInk(pixels, box, focus), greaterThan(0), reason: 'the focus look is an outline a thumb can see');
    });
  }

  testWidgets('a touch hides the ring, and the next pad press brings it back', (tester) async {
    final fake = await pumpHost(
      tester,
      screen: const StubHome(),
      overrides: [hostTouchFirstProvider.overrideWithValue(true)],
    );
    await neutral(tester, fake, ['p1']);
    await tapVisible(tester, find.byKey(const Key('openPlay')));
    await tester.pumpAndSettle();

    final focus = argb(ToyLookScope.of(tester.element(find.byKey(const Key('pickShapeRace')))).colors.focus);
    final card = tester.getRect(find.byKey(const Key('pickShapeRace')));
    expect(
      edgeInk(await screenPixels(tester), card, focus),
      0,
      reason: 'a touch-first host shows no ring until a pad moves the focus',
    );

    // The pad moves the focus, and the ring shows.
    await press(tester, fake, 'p1', GamepadButton.dpadRight);
    final arena = tester.getRect(find.byKey(const Key('pickArena')));
    expect(edgeInk(await screenPixels(tester), arena, focus), greaterThan(0));

    // A thumb on the screen takes it away, and it stays away.
    await tester.tapAt(tester.getCenter(find.text('Play')));
    await tester.pump();
    expect(edgeInk(await screenPixels(tester), arena, focus), 0, reason: 'a thumb takes the ring away');

    // The next pad press brings it back, and the menus are still the ones that
    // were there before the thumb (m13 s21: a swap of the wrapper's own
    // widgets remounted them, and they lost that press).
    final menus = tester.state<State>(find.byType(ControllerMenus));
    await press(tester, fake, 'p1', GamepadButton.dpadDown);
    expect(edgeInk(await screenPixels(tester), _focusedRect(tester), focus), greaterThan(0));
    expect(tester.state<State>(find.byType(ControllerMenus)), same(menus), reason: 'the menus kept their state');
  });

  testWidgets('a TV shows the ring from the start, and a pointer does not take it away', (tester) async {
    // No override: this is the TV's and the Windows app's host.
    final fake = await pumpHost(tester, screen: const StubHome());
    await neutral(tester, fake, ['p1']);
    await tapVisible(tester, find.byKey(const Key('openPlay')));
    await tester.pumpAndSettle();

    final focus = argb(ToyLookScope.of(tester.element(find.byKey(const Key('pickPartyNight')))).colors.focus);
    final card = tester.getRect(find.byKey(const Key('pickPartyNight')));
    expect(
      edgeInk(await screenPixels(tester), card, focus),
      greaterThan(0),
      reason: 'a TV rings its first screen at once, on the party night card',
    );

    // A pointer on a TV's screen is a mouse, not a thumb: the ring stays.
    await tester.tapAt(tester.getCenter(find.text('Play')));
    await tester.pump();
    expect(edgeInk(await screenPixels(tester), card, focus), greaterThan(0));
  });

  testWidgets('Shape Race\'s level and puzzle buttons show the ring', (tester) async {
    final fake = await pumpHost(tester, screen: const ShapeRaceScreen());
    await neutral(tester, fake, ['p1']);
    await tester.pumpAndSettle();

    // The first level's "any puzzle" button takes the focus as the list opens.
    final focus = argb(ToyLookScope.of(tester.element(find.byType(ShapeRaceScreen))).colors.focus);
    final first = await screenPixels(tester);
    expect(edgeInk(first, _focusedRect(tester), focus), greaterThan(0), reason: 'the first play button is ringed');

    // Right moves along the level's puzzles, and the ring goes with it.
    await press(tester, fake, 'p1', GamepadButton.dpadRight);
    final next = await screenPixels(tester);
    expect(edgeInk(next, _focusedRect(tester), focus), greaterThan(0), reason: 'the next puzzle\'s button is ringed');
  });

  testWidgets('the join screen\'s buttons show the ring when the pad reaches them', (tester) async {
    final fake = await pumpHost(tester, screen: const StubHome());
    await neutral(tester, fake, ['p1', 'p2']);
    await openJoin(tester);

    expect(await _walkTo(tester, fake, 'joinStart'), isTrue, reason: 'the pad reaches Start');
    final focus = argb(ToyLookScope.of(tester.element(find.byKey(const Key('joinStart')))).colors.focus);
    expect(edgeInk(await screenPixels(tester), _focusedRect(tester), focus), greaterThan(0));
  });

  testWidgets('the pause menu\'s buttons show the ring when the pad reaches them', (tester) async {
    final fake = await pumpHost(tester, screen: const StubHome());
    await neutral(tester, fake, ['p1']);
    await openArena(tester);
    await press(tester, fake, 'p1', GamepadButton.start);
    await navigated(tester);
    expect(find.byKey(const Key('pauseMenu')), findsOneWidget);

    final focus = argb(ToyLookScope.of(tester.element(find.byKey(const Key('pauseResume')))).colors.focus);
    expect(
      edgeInk(await screenPixels(tester), _focusedRect(tester), focus),
      greaterThan(0),
      reason: 'Resume is ringed',
    );
    await press(tester, fake, 'p1', GamepadButton.dpadLeft);
    expect(edgeInk(await screenPixels(tester), _focusedRect(tester), focus), greaterThan(0), reason: 'Quit is ringed');
  });

  testWidgets('the results\' buttons show the ring as the pad moves across them', (tester) async {
    final fake = await openRace(tester);
    lockEveryPiece(tester);
    await endRound(tester);
    await navigated(tester);
    expect(find.byKey(const Key('puzzleResults')), findsOneWidget);

    final focus = argb(ToyLookScope.of(tester.element(find.byKey(const Key('puzzleResults')))).colors.focus);
    expect(
      edgeInk(await screenPixels(tester), _focusedRect(tester), focus),
      greaterThan(0),
      reason: 'Play again is ringed',
    );
    for (final key in ['changeTeams', 'resultsBack']) {
      await press(tester, fake, 'p1', GamepadButton.dpadRight);
      expect(_inside(key), isTrue, reason: 'right reaches $key');
      expect(
        edgeInk(await screenPixels(tester), _focusedRect(tester), focus),
        greaterThan(0),
        reason: '$key is ringed',
      );
    }
  });

  testWidgets('the title bar\'s back arrow shows the ring when the pad reaches it', (tester) async {
    final fake = await pumpHost(tester, screen: const StubHome());
    await neutral(tester, fake, ['p1']);
    await tapVisible(tester, find.byKey(const Key('openPlay')));
    await tester.pumpAndSettle();
    expect(
      await _walkTo(tester, fake, 'hostTitleBarBack', direction: GamepadButton.dpadUp),
      isTrue,
      reason: 'up from the first card reaches the back arrow',
    );

    final box = _focusedRect(tester);
    final focus = argb(ToyLookScope.of(tester.element(find.byKey(const Key('hostTitleBarBack')))).colors.focus);
    final pixels = await screenPixels(tester);
    expect(edgeInk(pixels, box, focus), greaterThan(0));
  });
}
