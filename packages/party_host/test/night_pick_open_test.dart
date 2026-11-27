import 'dart:math';

import 'package:connection/connection.dart' show GamePlayer;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:party_host/src/night/night_flow.dart';
import 'package:party_host/src/night/night_flow_controller.dart';
import 'package:party_host/src/night/night_flow_provider.dart';
import 'package:party_host/src/night/night_pick.dart';
import 'package:party_host/src/night/night_pick_provider.dart';
import 'package:party_host/src/night/night_played_store.dart';
import 'package:party_host/src/night/night_settings.dart';
import 'package:party_host/src/night/night_variant.dart';
import 'package:party_host/src/night/variant.dart';
import 'package:puzzle_game/puzzle_game.dart' show Level;
import 'package:test_game/test_game.dart' show ArenaMode;

import 'support/all_looks.dart';
import 'support/host_harness.dart';
import 'support/night_harness.dart';

/// Milliseconds for every card but the how-to card, which keeps its minimum so a player can read it.
const _shortPacing = NightPacing(
  setup: Duration(milliseconds: 1),
  howTo: NightPacing.minHowTo,
  results: Duration(milliseconds: 1),
  scoreboard: Duration(milliseconds: 1),
);

/// A director that picks from the Bumper Round only, so round 2 is a Bumper Round on one of its maps.
const _bumperOnly = NightSettings(picker: NightPicker.director, pool: {'bumperRound'});

/// A director that picks from Shape Race only.
const _shapeRaceOnly = NightSettings(picker: NightPicker.director, pool: {'shapeRace'});

/// A roster of [players], as the joined phones report it.
final class _Roster extends GamePlayersNotifier {
  _Roster(this._players);

  final List<GamePlayer> _players;

  @override
  List<GamePlayer> build() => _players;
}

/// Mounts the home screen at [look] with [settings] and [players], records round 1 and pushes its scoreboard on top, as
/// the game's Next does. The night's random source is seeded, so a director pick is the same on every run.
Future<void> _openRoundOneScoreboard(
  WidgetTester tester,
  HostLook look, {
  required NightSettings settings,
  List<GamePlayer> players = const [],
  List<Override> overrides = const [],
  Size size = const Size(960, 540),
}) async {
  await pumpHostLook(
    tester,
    look,
    screen: const StubHome(),
    size: size,
    overrides: [
      nightPacingProvider.overrideWithValue(_shortPacing),
      nightRandomProvider.overrideWithValue(Random(1)),
      gamePlayersProvider.overrideWith(() => _Roster(players)),
      ...overrides,
    ],
  );
  final container = appContainer(tester);
  container.read(nightSettingsProvider.notifier).update(settings);
  container.read(partyNightProvider.notifier)
    ..start(length: NightLength.three, awards: threeAwards)
    ..recordRound(roundResult(points: {'p1': 5}, winners: {'p1'}));
  Navigator.of(tester.element(find.byType(StubHome)))
      .push(MaterialPageRoute<void>(builder: (_) => const NightScoreboardScreen()));
  await tester.pumpAndSettle();
}

/// The how-to timer ends: the controller starts round 2 with the pick it has.
Future<void> _endHowTo(WidgetTester tester) async {
  await tester.pump(NightPacing.maxHowTo);
  await tester.pump(const Duration(milliseconds: 500));
}

NightFlowController _controller(WidgetTester tester) {
  final controller = appContainer(tester).read(nightFlowControllerProvider);
  if (controller == null) fail('the night has no flow controller');
  return controller;
}

/// The pick the night made for round 2, or null when the host picks.
NightPick? _pick(WidgetTester tester) => appContainer(tester).read(nightPickProvider);

void main() {
  testWidgets('a director pick of the Bumper Round opens it on the pick\'s map when the how-to card ends', (
    tester,
  ) async {
    await forEachLook(tester, (look) async {
      await _openRoundOneScoreboard(tester, look, settings: _bumperOnly);
      await _endHowTo(tester);

      final pick = _pick(tester);
      final arena = appContainer(tester).read(arenaSettingsProvider);
      expect(find.byType(GameScreen), findsOneWidget, reason: 'the picked Bumper Round opens by itself');
      expect(pick?.variant.game, VariantGame.bumperRound, reason: 'the director picked from the pool');
      expect(arena.mapId, pick?.variant.mapId, reason: 'the Arena is set to the pick\'s map');
      expect(arena.mode, ArenaMode.bumper, reason: 'the Arena is set to the Bumper Round');
      expect(_controller(tester).flow.stage, NightStage.round);
      expect(_controller(tester).flow.round, 2);
    });
  });

  testWidgets('a director pick of Shape Race with two joined players opens the join screen', (tester) async {
    await forEachLook(tester, (look) async {
      // At the default size the join screen's player card overflows by 9 px (existing layout, not this job's), so the
      // two-player join is drawn at the TV's size.
      await _openRoundOneScoreboard(
        tester,
        look,
        settings: _shapeRaceOnly,
        players: [nightPlayer('p1', 1), nightPlayer('p2', 2)],
        size: const Size(1920, 1080),
      );
      await _endHowTo(tester);

      expect(_pick(tester)?.variant.game, VariantGame.shapeRace, reason: 'the director picked from the pool');
      expect(find.byType(JoinScreen), findsOneWidget, reason: 'two joined players share the join screen');
      expect(find.byType(PuzzleScreen), findsNothing, reason: 'the round does not start solo');
    });
  });

  testWidgets('a director pick of Shape Race with one joined player opens the puzzle solo', (tester) async {
    await forEachLook(tester, (look) async {
      await _openRoundOneScoreboard(tester, look, settings: _shapeRaceOnly, players: [nightPlayer('p1', 1)]);
      await _endHowTo(tester);

      expect(find.byType(PuzzleScreen), findsOneWidget, reason: 'a night\'s only player plays the puzzle solo');
      expect(find.byType(JoinScreen), findsNothing, reason: 'no join screen for one player');
    });
  });

  testWidgets('with the host picking, nothing opens by itself and the Shape Race button still opens its game', (
    tester,
  ) async {
    await forEachLook(tester, (look) async {
      await _openRoundOneScoreboard(tester, look, settings: const NightSettings());
      await _endHowTo(tester);

      expect(_pick(tester), isNull, reason: 'the host picks, so the night makes no pick');
      expect(find.byType(ShapeRaceScreen), findsNothing, reason: 'no game opens by itself');
      expect(_controller(tester).flow.stage, NightStage.howTo, reason: 'the card waits for the host');

      await tapVisible(tester, find.byKey(const Key('nightShapeRace')));
      await tester.pumpAndSettle();

      expect(find.byType(ShapeRaceScreen), findsOneWidget, reason: 'the button opens Shape Race as before');
      expect(_controller(tester).flow.round, 2);
    });
  });

  testWidgets('a started round keeps its one variant in the played list', (tester) async {
    await forEachLook(tester, (look) async {
      await _openRoundOneScoreboard(tester, look, settings: _bumperOnly);
      await _endHowTo(tester);

      final played = NightPlayedStore(appContainer(tester).read(prefsProvider)).load();
      expect(played, [_pick(tester)?.variant.id], reason: 'round 2 is the one variant played so far');
    });
  });

  testWidgets('an Arena Race pick opens nothing, since a night never plays it', (tester) async {
    await forEachLook(tester, (look) async {
      const arenaRace = NightPick(
        round: 2,
        variant: Variant(game: VariantGame.arenaRace, tier: Level.easy, mapId: 'playroom'),
      );
      await _openRoundOneScoreboard(
        tester,
        look,
        settings: _bumperOnly,
        overrides: [nightNextVariantProvider.overrideWithValue(arenaRace)],
      );
      await _endHowTo(tester);

      expect(find.byType(GameScreen), findsNothing, reason: 'no Arena game opens for an Arena Race pick');
      expect(find.byType(ShapeRaceScreen), findsNothing, reason: 'no Shape Race opens for it either');
      expect(find.byType(NightScoreboardScreen), findsOneWidget, reason: 'the scoreboard stays on top');
      expect(_controller(tester).flow.stage, NightStage.howTo, reason: 'startRound was false, so the card waits');
    });
  });
}
