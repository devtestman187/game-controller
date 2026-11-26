import 'package:controller/src/home/home_contract.dart';
import 'package:controller/src/home/home_text.dart';
import 'package:controller/src/home/home_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart' as party;
import 'package:protocol/protocol.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The phone sizes Home must fit: two landscape, two portrait.
const screens = {
  '568x320': Size(568, 320),
  '640x360': Size(640, 360),
  '375x667': Size(375, 667),
  '320x640': Size(320, 640),
};

/// The text scale a user who asks for bigger text gets.
const largeTextScale = 1.3;

/// The least a tappable may be on each side, in logical pixels.
const minTapPx = 48.0;

const character = PlayerCharacter(colourSlot: 2, accessory: PlayerAccessory.antenna);

/// What a test counts: how often each callback fired.
class Taps {
  int join = 0;
  int play = 0;
  int display = 0;
  int settings = 0;
  int editName = 0;
  int searchAgain = 0;
}

/// Mounts Home in a look at a size and a text scale.
Future<(Taps, HomeAnchors)> pumpHome(
  WidgetTester tester, {
  HomeFind find = HomeFind.found,
  String? nickname = 'Sam',
  Size screen = const Size(568, 320),
  bool tv = false,
  double textScale = 1,
}) async {
  tester.view.physicalSize = screen;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final taps = Taps();
  final anchors = HomeAnchors();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        party.lookPrefsProvider.overrideWithValue(prefs),
        party.lookClockProvider.overrideWithValue(() => DateTime(2026, 11, 8, 12)),
        if (tv) party.toyTvProvider.overrideWithValue(true),
      ],
      child: Consumer(
        builder: (context, ref, _) {
          final look = ref.watch(party.toyLookProvider);
          return party.ToyLookScope(
            look: look,
            child: MaterialApp(
              theme: party.toyTheme(look),
              home: Scaffold(
                body: HomeView(
                  find: find,
                  nickname: nickname,
                  character: character,
                  anchors: anchors,
                  onJoin: () => taps.join++,
                  onPlay: () => taps.play++,
                  onDisplay: () => taps.display++,
                  onSettings: () => taps.settings++,
                  onEditName: () => taps.editName++,
                  onSearchAgain: () => taps.searchAgain++,
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
  await tester.pump();
  return (taps, anchors);
}

/// The fill a role button paints.
Color fillOf(WidgetTester tester, GlobalKey key) {
  final paint = find.descendant(of: find.byKey(key), matching: find.byType(CustomPaint));
  final painters = tester.widgetList<CustomPaint>(paint).map((p) => p.painter).whereType<party.ToyButtonPainter>();
  return painters.single.fill;
}

Finder buttonLabelled(String label) => find.ancestor(of: find.text(label), matching: find.byType(party.ToyButton));

void main() {
  group('Home lays out the three roles and fires each callback once', () {
    testWidgets('the three roles sit left to right as Join, Play, Display', (tester) async {
      final (_, anchors) = await pumpHome(tester);
      final join = tester.getCenter(find.byKey(anchors.join)).dx;
      final play = tester.getCenter(find.byKey(anchors.play)).dx;
      final display = tester.getCenter(find.byKey(anchors.display)).dx;
      expect(join < play && play < display, isTrue);
    });

    testWidgets('each tap fires its own callback once', (tester) async {
      final (taps, anchors) = await pumpHome(tester, find: HomeFind.none);
      await tester.tap(find.byKey(anchors.join));
      await tester.tap(find.byKey(anchors.play));
      await tester.tap(find.byKey(anchors.display));
      await tester.tap(buttonLabelled(HomeText.settings));
      await tester.tap(find.text('Sam'));
      await tester.tap(buttonLabelled(HomeText.searchAgain));
      expect([taps.join, taps.play, taps.display, taps.settings, taps.editName, taps.searchAgain], everyElement(1));
    });
  });

  group('the highlight follows HomeFind', () {
    for (final (mode, expected) in [
      (HomeFind.found, [true, false, false]),
      (HomeFind.none, [false, true, false]),
      (HomeFind.searching, [false, false, false]),
    ]) {
      testWidgets('$mode paints green on exactly $expected (join, play, display)', (tester) async {
        final (_, anchors) = await pumpHome(tester, find: mode);
        final good = party.ToyLookScope.of(tester.element(find.byKey(anchors.join))).colors.good;
        final fills = [anchors.join, anchors.play, anchors.display].map((k) => fillOf(tester, k) == good).toList();
        expect(fills, expected);
      });
    }
  });

  group('the chip and Search again follow HomeFind', () {
    testWidgets('found shows Found nearby and no Search again', (tester) async {
      await pumpHome(tester);
      expect(find.text(HomeText.foundNearby), findsOneWidget);
      expect(find.text(HomeText.noScreenFound), findsNothing);
      expect(find.text(HomeText.searchAgain), findsNothing);
    });

    testWidgets('none shows No screen found and Search again', (tester) async {
      await pumpHome(tester, find: HomeFind.none);
      expect(find.text(HomeText.noScreenFound), findsOneWidget);
      expect(find.text(HomeText.searchAgain), findsOneWidget);
    });

    testWidgets('searching shows Looking for a screen and no Search again', (tester) async {
      await pumpHome(tester, find: HomeFind.searching);
      expect(find.text(HomeText.lookingForScreen), findsOneWidget);
      expect(find.text(HomeText.foundNearby), findsNothing);
      expect(find.text(HomeText.noScreenFound), findsNothing);
      expect(find.text(HomeText.searchAgain), findsNothing);
    });
  });

  group('the nickname row', () {
    testWidgets('an empty nickname shows the hint', (tester) async {
      await pumpHome(tester, nickname: '');
      expect(find.text(HomeText.tapToAddName), findsOneWidget);
    });

    testWidgets('a null nickname shows the hint', (tester) async {
      await pumpHome(tester, nickname: null);
      expect(find.text(HomeText.tapToAddName), findsOneWidget);
    });

    testWidgets('a nickname shows instead of the hint', (tester) async {
      await pumpHome(tester);
      expect(find.text('Sam'), findsOneWidget);
      expect(find.text(HomeText.tapToAddName), findsNothing);
    });
  });

  group('Home fits and every tappable is at least 48x48', () {
    for (final tv in [false, true]) {
      for (final entry in screens.entries) {
        for (final scale in [1.0, if (entry.key == '320x640') largeTextScale]) {
          for (final mode in HomeFind.values) {
            testWidgets('${tv ? 'TV' : 'menu'} look, ${entry.key}, text x$scale, $mode: no overflow, 48 dp', (
              tester,
            ) async {
              final (_, anchors) = await pumpHome(
                tester,
                find: mode,
                nickname: '',
                screen: entry.value,
                tv: tv,
                textScale: scale,
              );
              expect(tester.takeException(), isNull);
              final tappables = [
                find.byKey(anchors.join),
                find.byKey(anchors.play),
                find.byKey(anchors.display),
                buttonLabelled(HomeText.settings),
                if (mode == HomeFind.none) buttonLabelled(HomeText.searchAgain),
                find.byType(InkWell),
              ];
              for (final finder in tappables) {
                final size = tester.getSize(finder);
                expect(size.width, greaterThanOrEqualTo(minTapPx), reason: '$finder width');
                expect(size.height, greaterThanOrEqualTo(minTapPx), reason: '$finder height');
              }
            });
          }
        }
      }
    }
  });
}
