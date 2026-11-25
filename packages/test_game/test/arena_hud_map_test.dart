import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_game/src/arena_map_names.dart';
import 'package:test_game/test_game.dart';
import 'package:toy_look/toy_look.dart';

import 'support/look.dart';
import 'support/map_files.dart';

/// The players these tests draw: two phones, numbered in the order they joined.
const two = {'a': (number: 1, name: 'Ada'), 'b': (number: 2, name: 'Bo')};

/// The TV's look: Sunny drawn for the big screen, beside the phone's [sunny].
final tvLook = ToyLook.build(palette: ToyPalette.sunny, tv: true);

/// A Bumper Round's frame on the map [mapId]: the snapshot carries the map's id, not its name.
ArenaSnapshot frameOn(String mapId) => ArenaSnapshot(
  round: 1,
  roundTimeS: 12.4,
  phase: ArenaPhase.playing,
  walls: const [],
  goal: Rect.zero,
  hazards: const [],
  players: [
    for (final MapEntry(key: id, value: player) in two.entries)
      ArenaPlayerView(id: id, x: 0.15 + 0.15 * player.number, y: 0.5),
  ],
  mapId: mapId,
  mode: ArenaMode.bumper,
  timeLeftMs: 30000,
);

/// The HUD of the map [mapId] drawn in [look] in a box of [size], one-line or two-line.
Future<void> pumpMapHud(
  WidgetTester tester,
  String mapId, {
  required ToyLook look,
  required Size size,
  required bool oneLine,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: withLook(
        Scaffold(
          body: ArenaHud(snapshot: frameOn(mapId), roster: two, oneLine: oneLine, round: 1, rounds: 3),
        ),
        look: look,
      ),
    ),
  );
}

/// The TV's box and a portrait phone's are two-line; a landscape phone's is one-line, as the bar folds below 480 px.
const boxes = [
  (size: Size(960, 540), oneLine: false),
  (size: Size(812, 375), oneLine: true),
  (size: Size(390, 844), oneLine: false),
];

void main() {
  testWidgets('a bundled map shows its name beside the round, on both looks and in every bar', (tester) async {
    for (final look in [sunny, tvLook]) {
      for (final box in boxes) {
        for (final id in mapIndexIds()) {
          await pumpMapHud(tester, id, look: look, size: box.size, oneLine: box.oneLine);
          expect(
            find.text(arenaMapNames[id]!),
            findsOneWidget,
            reason: '$id names its map in a ${box.size} box (oneLine: ${box.oneLine})',
          );
          expect(find.byKey(const Key('mapName')), findsOneWidget);
        }
      }
    }
  });

  testWidgets('an id the names do not list shows no name, keeps the round, and does not crash', (tester) async {
    for (final look in [sunny, tvLook]) {
      for (final box in boxes) {
        await pumpMapHud(tester, 'no-such-map', look: look, size: box.size, oneLine: box.oneLine);
        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('mapName')), findsNothing);
        expect(find.text('Round 1 of 3'), findsOneWidget);
      }
    }
  });

  test('the names are the bundled maps\' names from their files, so they cannot drift', () {
    expect(arenaMapNames, {for (final id in mapIndexIds()) id: loadMap(id).name});
  });
}
