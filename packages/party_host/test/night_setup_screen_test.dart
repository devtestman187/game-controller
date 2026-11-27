import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:party_host/src/night/night_pick_provider.dart';
import 'package:party_host/src/night/night_played_store.dart';
import 'package:party_host/src/night/night_settings.dart';
import 'package:party_host/src/night/night_setup_options.dart';
import 'package:party_host/src/night/variant.dart';
import 'package:party_host/src/ui/night_setup_widgets.dart';
import 'package:puzzle_game/puzzle_game.dart' show Level;

import 'support/all_looks.dart';
import 'support/host_harness.dart';
import 'support/night_harness.dart';
import 'support/toy_fonts.dart';

/// The owner's rule: every touch target is at least this many logical pixels on a side.
const _minTargetDp = 48.0;

/// The smallest text a chip shows on a phone, in logical pixels.
const _minTextDp = 14.0;

/// How far under a size the floating-point noise of the frame's scale may measure and still count as that size.
const _toleranceDp = 0.01;

/// How far one drag of the list scrolls, in frame px.
const _dragPx = 300.0;

/// The phones the screen must fit, as portrait phones: 360x640 and the narrowest, 320x640.
const _phones = {'360x640': Size(360, 640), '320x640': Size(320, 640)};

/// A screen so tall that the whole list is built, to look at every row at once.
const _tallScreen = Size(960, 4000);

/// The prefs key the settings are saved under.
const _prefsKey = 'party_night_settings_v1';

/// The list's own scrollable.
Finder _list() => find.descendant(of: find.byKey(const Key('nightSetupList')), matching: find.byType(Scrollable));

/// Every chip's key, one per option the screen offers.
List<Key> _chipKeys() => [
  const Key('setupKids'),
  for (final length in NightSetupOptions.offeredLengths) Key('setupLength-${length.name}'),
  for (final game in NightSetupOptions.offeredGames) Key('setupGame-${game.name}'),
  for (final level in Level.values) Key('setupEasiest-${level.name}'),
  for (final level in Level.values) Key('setupHardest-${level.name}'),
  for (final picker in NightSetupOptions.offeredPickers) Key('setupPicker-${picker.name}'),
];

/// What [finder] measures on the device, in logical pixels: the frame scales its layout, so the corners go through the
/// transforms.
Size _onScreen(WidgetTester tester, Finder finder) {
  final box = tester.renderObject<RenderBox>(finder);
  final topLeft = box.localToGlobal(Offset.zero);
  final bottomRight = box.localToGlobal(box.size.bottomRight(Offset.zero));
  return Size(bottomRight.dx - topLeft.dx, bottomRight.dy - topLeft.dy);
}

/// The screen alone in the frame at [size] in [look].
Future<void> _pumpSetup(WidgetTester tester, HostLook look, Size size) =>
    pumpHostLook(tester, look, screen: const NightSetupScreen(), size: size, framed: true);

/// Scrolls the list until the chip [key] shows.
Future<Finder> _reach(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  await tester.scrollUntilVisible(finder, _dragPx, scrollable: _list());
  return finder;
}

NightSettings _settings(WidgetTester tester) => appContainer(tester).read(nightSettingsProvider);

void main() {
  setUpAll(loadLookFonts);

  for (final phone in _phones.entries) {
    for (final look in HostLook.values) {
      final label = '${phone.key}/${look.name}';
      testWidgets('at $label the screen has no overflow, every row is reached by scrolling and every chip is at '
          'least 48 dp with text of at least 14 dp', (tester) async {
        await _pumpSetup(tester, look, phone.value);
        expect(tester.takeException(), isNull, reason: 'nothing overflows at $label');
        for (final key in _chipKeys()) {
          final finder = await _reach(tester, key);
          final size = _onScreen(tester, finder);
          expect(size.width, greaterThanOrEqualTo(_minTargetDp - _toleranceDp), reason: '$key is wide enough');
          expect(size.height, greaterThanOrEqualTo(_minTargetDp - _toleranceDp), reason: '$key is tall enough');
          final text = tester.widget<Text>(find.descendant(of: finder, matching: find.byType(Text)));
          final scale = phone.value.width / 960;
          expect(text.style?.fontSize, isNotNull, reason: '$key has a text size');
          expect((text.style?.fontSize ?? 0) * scale, greaterThanOrEqualTo(_minTextDp - _toleranceDp));
        }
        expect(tester.takeException(), isNull, reason: 'scrolling overflows nothing at $label');
      });

      testWidgets('at $label the Done button is on screen with the list scrolled to its end, and the last row can be '
          'tapped', (tester) async {
        await _pumpSetup(tester, look, phone.value);
        await tester.fling(_list(), const Offset(0, -4000), 4000);
        await tester.pumpAndSettle();
        final done = find.byKey(const Key('setupDone'));
        expect(done, findsOneWidget);
        final rect = tester.getRect(done);
        final screen = Offset.zero & phone.value;
        final corners = [tester.getTopLeft(done), tester.getBottomRight(done), tester.getCenter(done)];
        expect(corners.every(screen.contains), isTrue, reason: 'Done is inside the screen, rect $rect');

        final playlist = await _reach(tester, const Key('setupPicker-playlist'));
        await tester.tap(playlist);
        await tester.pumpAndSettle();
        expect(_settings(tester).picker, NightPicker.playlist, reason: 'the last row was tapped');
      });
    }
  }

  testWidgets('every chip of every row is drawn, and no row offers Rotating, Vote, Arena Race, 8 rounds or the cat', (
    tester,
  ) async {
    await _pumpSetup(tester, HostLook.menu, _tallScreen);
    for (final key in _chipKeys()) {
      expect(find.byKey(key), findsOneWidget, reason: '$key is a chip of the screen');
    }
    for (final word in ['Rotating', 'Vote', 'Arena Race', '8 rounds', 'Cat', 'Chaos']) {
      expect(find.text(word), findsNothing, reason: 'no chip says $word');
    }
    expect(find.text(NightSetupText.catNote), findsOneWidget, reason: 'the cat is only a note');
    expect(find.byType(NightSetupChip), findsNWidgets(_chipKeys().length));
  });

  testWidgets('a tap changes the setting and the saved prefs, and a refused toggle changes nothing', (tester) async {
    await _pumpSetup(tester, HostLook.menu, _tallScreen);
    final prefs = appContainer(tester).read(prefsProvider);

    await tester.tap(find.byKey(const Key('setupLength-five')));
    await tester.pumpAndSettle();
    expect(_settings(tester).length, NightLength.five);
    expect(prefs.getString(_prefsKey), contains('"length":"five"'), reason: 'the change is saved');

    await tester.tap(find.byKey(const Key('setupGame-shapeRace')));
    await tester.pumpAndSettle();
    expect(_settings(tester).pool, {'bumperRound'}, reason: 'Shape Race is off, the Bumper Round stays');

    final before = _settings(tester);
    await tester.tap(find.byKey(const Key('setupGame-bumperRound')));
    await tester.pumpAndSettle();
    expect(_settings(tester), before, reason: 'the last game cannot be turned off');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Hardest Medium keeps Block Castle out and Easiest above Hardest moves Hardest up', (tester) async {
    await _pumpSetup(tester, HostLook.menu, _tallScreen);
    await tester.tap(find.byKey(const Key('setupHardest-medium')));
    await tester.pumpAndSettle();
    expect(_settings(tester).difficultyMax, Level.medium);
    await tester.tap(find.byKey(const Key('setupEasiest-medium')));
    await tester.pumpAndSettle();
    expect(_settings(tester).difficultyMin, Level.medium);
    expect(_settings(tester).difficultyMax, Level.medium);
  });

  testWidgets('"Kids night" gives the Kids preset and then reads chosen', (tester) async {
    await _pumpSetup(tester, HostLook.menu, _tallScreen);
    await tester.tap(find.byKey(const Key('setupKids')));
    await tester.pumpAndSettle();
    expect(_settings(tester), NightSettings.kids);
    expect(_settings(tester).isKids, isTrue);
    final chip = tester.widget<NightSetupChip>(find.byKey(const Key('setupKids')));
    expect(chip.isSelected, isTrue, reason: 'the Kids chip reads chosen while the preset is on');
  });

  testWidgets('a running night shows the settings read-only: every chip is disabled', (tester) async {
    await _pumpSetup(tester, HostLook.menu, _tallScreen);
    appContainer(tester).read(partyNightProvider.notifier).start(length: NightLength.three, awards: threeAwards);
    await tester.pumpAndSettle();
    for (final key in _chipKeys()) {
      expect(tester.widget<NightSetupChip>(find.byKey(key)).onPressed, isNull, reason: '$key is disabled');
    }
    final before = _settings(tester);
    await tester.tap(find.byKey(const Key('setupLength-five')), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(_settings(tester), before, reason: 'a tap on a disabled chip changes nothing');
  });

  testWidgets('Done leaves the screen', (tester) async {
    await pumpHostLook(tester, HostLook.menu, screen: const StubHome(), framed: true);
    Navigator.of(tester.element(find.byType(StubHome)))
        .push(MaterialPageRoute<void>(builder: (_) => const NightSetupScreen()));
    await tester.pumpAndSettle();
    expect(find.byType(NightSetupScreen), findsOneWidget);
    await tester.tap(find.byKey(const Key('setupDone')));
    await tester.pumpAndSettle();
    expect(find.byType(NightSetupScreen), findsNothing);
  });

  group('the start card', () {
    Future<void> pumpStart(WidgetTester tester, HostLook look, NightSettings settings) async {
      final fake = await pumpHostLook(tester, look, screen: const NightStartScreen(seed: 7));
      fake.removeController('p2');
      fake.emit();
      appContainer(tester).read(nightSettingsProvider.notifier).update(settings);
      await tester.pumpAndSettle();
    }

    testWidgets('with the host picking it has the two game buttons and the Set up button', (tester) async {
      await forEachLook(tester, (look) async {
        await pumpStart(tester, look, const NightSettings());
        expect(find.byKey(const Key('nightShapeRace')), findsOneWidget);
        expect(find.byKey(const Key('nightBumper')), findsOneWidget);
        expect(find.byKey(const Key('nightStartPick')), findsNothing);
        expect(find.text(NightText.pickRound(1)), findsOneWidget);
        await tester.tap(find.byKey(const Key('nightSetup')));
        await tester.pumpAndSettle();
        expect(find.byType(NightSetupScreen), findsOneWidget, reason: 'Set up opens the setup screen');
      });
    });

    testWidgets('the header segment writes the length to the settings', (tester) async {
      await pumpStart(tester, HostLook.menu, const NightSettings());
      await tester.tap(find.text(NightText.fiveRounds));
      await tester.pumpAndSettle();
      expect(_settings(tester).length, NightLength.five);
    });

    testWidgets('with the director picking it has one start button and says the games are picked', (tester) async {
      await forEachLook(tester, (look) async {
        await pumpStart(tester, look, const NightSettings(picker: NightPicker.director));
        expect(find.byKey(const Key('nightStartPick')), findsOneWidget);
        expect(find.byKey(const Key('nightShapeRace')), findsNothing);
        expect(find.byKey(const Key('nightBumper')), findsNothing);
        expect(find.text(NightSetupText.gamesPickedForYou), findsOneWidget);
        expect(find.text(NightText.pickRound(1)), findsNothing);
      });
    });

    testWidgets('the start button with a Bumper Round pool opens the Arena waiting card, one variant played', (
      tester,
    ) async {
      await pumpStart(tester, HostLook.menu, const NightSettings(picker: NightPicker.director, pool: {'bumperRound'}));
      await tester.tap(find.byKey(const Key('nightStartPick')));
      await tester.pumpAndSettle();
      expect(find.byType(GameScreen), findsOneWidget);
      final pick = appContainer(tester).read(nightPickProvider);
      expect(pick?.variant.game, VariantGame.bumperRound);
      expect(NightPlayedStore(appContainer(tester).read(prefsProvider)).load(), [pick?.variant.id]);
    });

    testWidgets('the start button with a Shape Race pool and one player opens the puzzle', (tester) async {
      await pumpStart(tester, HostLook.menu, const NightSettings(picker: NightPicker.director, pool: {'shapeRace'}));
      await tester.tap(find.byKey(const Key('nightStartPick')));
      // The puzzle's clock keeps running, so the route is let in with a few frames instead of settling.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(PuzzleScreen), findsOneWidget);
      final pick = appContainer(tester).read(nightPickProvider);
      expect(NightPlayedStore(appContainer(tester).read(prefsProvider)).load(), [pick?.variant.id]);
    });
  });
}
