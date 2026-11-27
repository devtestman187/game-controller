import 'dart:async';
import 'dart:math';

import 'package:connection/connection.dart' show ChoiceOutcome, ChoiceRoundSetup, GamePlayer;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:party_host/src/night/night_flow_controller.dart';
import 'package:party_host/src/night/night_flow_provider.dart';
import 'package:party_host/src/night/night_pick_provider.dart';
import 'package:party_host/src/night/night_settings.dart';
import 'package:party_host/src/night/night_vote.dart';
import 'package:party_host/src/ui/night_vote_screen.dart';
import 'package:party_host/src/ui/night_vote_strip.dart';

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

/// The vote as picker, over the Bumper Round's maps only, so the won game opens the Arena's screen.
const _voteSettings = NightSettings(picker: NightPicker.vote, pool: {'bumperRound'});

/// A phone-sized menu screen, as 360x640 is on a phone.
const _phoneSize = Size(360, 640);

/// The seed of the night's random source in the tests.
const _seed = 1;

/// How long the winner stays up, plus a frame, so the screen has popped.
const _afterResult = Duration(seconds: nightVoteShowResultS + 1);

/// A vote round the test finishes by hand.
final class _FakeHandle implements VoteHandle {
  final _done = Completer<Map<String, ChoiceOutcome>>();
  bool isDisposed = false;

  @override
  Future<Map<String, ChoiceOutcome>> get done => _done.future;

  void finish(Map<String, ChoiceOutcome> outcomes) => _done.complete(outcomes);

  @override
  Map<String, ChoiceOutcome> closeNow() {
    if (!_done.isCompleted) _done.complete(const {});
    return const {};
  }

  @override
  void dispose() => isDisposed = true;
}

/// What the fake starter was asked and the rounds it handed out.
final class _Started {
  final setups = <ChoiceRoundSetup>[];
  final durations = <Duration>[];
  final handles = <_FakeHandle>[];
}

/// A roster of [players], as the joined phones report it.
final class _Roster extends GamePlayersNotifier {
  _Roster(this._players);

  final List<GamePlayer> _players;

  @override
  List<GamePlayer> build() => _players;
}

ChoiceOutcome _vote(String id) => ChoiceOutcome(cardId: id, count: 1, byDefault: false);

/// Overrides with a vote starter that hands out a fake round into [started], or none when [phones] is false.
List<Override> _overrides(_Started started, {bool phones = true}) => [
  nightPacingProvider.overrideWithValue(_shortPacing),
  nightRandomProvider.overrideWithValue(Random(_seed)),
  gamePlayersProvider.overrideWith(() => _Roster(const [])),
  voteStarterProvider.overrideWithValue((setup, duration) {
    if (!phones) return null;
    started.setups.add(setup);
    started.durations.add(duration);
    final handle = _FakeHandle();
    started.handles.add(handle);
    return handle;
  }),
];

/// The ids of the games the open vote offers.
List<String> _offered(WidgetTester tester) => [
  for (final variant in appContainer(tester).read(nightVoteProvider)!.offered) variant.id,
];

/// Mounts the home screen with [settings], then the night's start card on top of it.
Future<void> _openStartCard(
  WidgetTester tester,
  HostLook look,
  _Started started, {
  NightSettings settings = _voteSettings,
  bool phones = true,
  Size size = const Size(960, 540),
}) async {
  await pumpHostLook(
    tester,
    look,
    screen: const StubHome(),
    size: size,
    overrides: _overrides(started, phones: phones),
  );
  appContainer(tester).read(nightSettingsProvider.notifier).update(settings);
  Navigator.of(tester.element(find.byType(StubHome)))
      .push(MaterialPageRoute<void>(builder: (_) => const NightStartScreen(seed: _seed)));
  await tester.pumpAndSettle();
}

/// Mounts the home screen, records round 1 of [rounds] and pushes its scoreboard on top, as the game's Next does.
Future<void> _openScoreboard(
  WidgetTester tester,
  HostLook look,
  _Started started, {
  required NightLength length,
  required int roundsPlayed,
  NightSettings settings = _voteSettings,
  Size size = const Size(960, 540),
}) async {
  await pumpHostLook(tester, look, screen: const StubHome(), size: size, overrides: _overrides(started));
  final container = appContainer(tester);
  container.read(nightSettingsProvider.notifier).update(settings);
  final night = container.read(partyNightProvider.notifier)..start(length: length, awards: threeAwards);
  for (var i = 0; i < roundsPlayed; i++) {
    night.recordRound(roundResult(points: {'p1': 5}, winners: {'p1'}));
  }
  Navigator.of(tester.element(find.byType(StubHome)))
      .push(MaterialPageRoute<void>(builder: (_) => const NightScoreboardScreen()));
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('the start card with the vote as picker opens the vote screen with the 5 s vote', (tester) async {
    await forEachLook(tester, (look) async {
      final started = _Started();
      await _openStartCard(tester, look, started);
      await tapVisible(tester, find.byKey(const Key('nightStartPick')));
      await tester.pump();
      await tester.pump();

      expect(find.byType(NightVoteScreen), findsOneWidget);
      expect(find.text('Vote for the first game'), findsOneWidget);
      expect(find.text('Vote on your phones!'), findsOneWidget);
      expect(started.durations.last, const Duration(seconds: 5), reason: 'the default vote lasts 5 s');
      expect(started.setups.last.round, 1);
      expect(appContainer(tester).read(partyNightProvider), isNull, reason: 'the night starts after the vote');
      appContainer(tester).read(nightVoteProvider.notifier).cancel();
      await tester.pumpAndSettle();
    });
  });

  testWidgets('the game the vote won opens after the winner has shown for 2 s', (tester) async {
    await forEachLook(tester, (look) async {
      final started = _Started();
      await _openStartCard(tester, look, started);
      await tapVisible(tester, find.byKey(const Key('nightStartPick')));
      await tester.pump();
      await tester.pump();
      final ids = _offered(tester);

      started.handles.last.finish({'a': _vote(ids[1]), 'b': _vote(ids[1]), 'c': _vote(ids[0])});
      await tester.pump();
      expect(find.byKey(const Key('nightVoteStrip')), findsOneWidget);
      expect(find.textContaining('wins!'), findsOneWidget, reason: 'the winner is named first');
      expect(find.byType(GameScreen), findsNothing, reason: 'the winner shows before the game opens');

      await tester.pump(_afterResult);
      await tester.pumpAndSettle();

      final pick = appContainer(tester).read(nightPickProvider);
      expect(pick?.variant.id, ids[1], reason: 'the game with two votes is the round 1 pick');
      expect(find.byType(GameScreen), findsOneWidget, reason: 'the picked Bumper Round opens');
      expect(appContainer(tester).read(partyNightProvider), isNotNull);
    });
  });

  testWidgets('Back on the vote screen cancels the vote and starts no night', (tester) async {
    await forEachLook(tester, (look) async {
      final started = _Started();
      await _openStartCard(tester, look, started);
      await tapVisible(tester, find.byKey(const Key('nightStartPick')));
      await tester.pump();
      await tester.pump();

      await tapVisible(tester, find.byKey(const Key('voteBack')));
      await tester.pumpAndSettle();

      expect(find.byType(NightStartScreen), findsOneWidget);
      expect(find.byType(NightVoteScreen), findsNothing);
      expect(appContainer(tester).read(partyNightProvider), isNull, reason: 'Back starts no night');
      expect(appContainer(tester).read(nightVoteProvider), isNull, reason: 'Back cancels the vote');
      expect(started.handles.last.isDisposed, isTrue);
    });
  });

  testWidgets('with no phone to vote a random game is settled and the night starts, no hang', (tester) async {
    await forEachLook(tester, (look) async {
      await _openStartCard(tester, look, _Started(), phones: false);
      await tapVisible(tester, find.byKey(const Key('nightStartPick')));
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('by luck!'), findsOneWidget, reason: 'nobody voting is settled by chance');
      await tester.pump(_afterResult);
      await tester.pumpAndSettle();

      expect(find.byType(GameScreen), findsOneWidget);
    });
  });

  testWidgets('the scoreboard of round 1 of 3 starts one vote for round 2 and shows the strip', (tester) async {
    await forEachLook(tester, (look) async {
      final started = _Started();
      await _openScoreboard(tester, look, started, length: NightLength.three, roundsPlayed: 1);

      expect(started.setups, hasLength(1));
      expect(started.setups.single.round, 2);
      expect(started.durations.single, const Duration(seconds: 5));
      expect(find.byKey(const Key('nightVoteStrip')), findsOneWidget);
      expect(find.text('Vote on your phones!'), findsOneWidget);
    });
  });

  testWidgets('the how-to card after a vote on the scoreboard plays the voted game', (tester) async {
    await forEachLook(tester, (look) async {
      final started = _Started();
      await _openScoreboard(tester, look, started, length: NightLength.three, roundsPlayed: 1);
      final ids = _offered(tester);

      started.handles.single.finish({'a': _vote(ids[2])});
      await tester.pump();
      await tester.pump(NightPacing.maxHowTo);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(appContainer(tester).read(nightPickProvider)?.variant.id, ids[2]);
      expect(find.byType(GameScreen), findsOneWidget);
    });
  });

  testWidgets('the scoreboard of the last round starts no vote', (tester) async {
    await forEachLook(tester, (look) async {
      final started = _Started();
      await _openScoreboard(tester, look, started, length: NightLength.three, roundsPlayed: 3);

      expect(started.setups, isEmpty);
      expect(appContainer(tester).read(nightVoteProvider), isNull);
      expect(find.byKey(const Key('nightVoteStrip')), findsNothing);
    });
  });

  testWidgets('a settled vote of round 2 does not stay on the scoreboard of the last round', (tester) async {
    final started = _Started();
    await _openScoreboard(tester, HostLook.menu, started, length: NightLength.three, roundsPlayed: 1);
    started.handles.single.finish({'a': _vote(_offered(tester)[0])});
    await tester.pump();
    expect(find.byKey(const Key('nightVoteStrip')), findsOneWidget);

    final container = appContainer(tester);
    final night = container.read(partyNightProvider.notifier);
    night.recordRound(roundResult(points: {'p1': 5}, winners: {'p1'}));
    night.recordRound(roundResult(points: {'p1': 5}, winners: {'p1'}));
    Navigator.of(tester.element(find.byType(NightScoreboardScreen)))
        .push(MaterialPageRoute<void>(builder: (_) => const NightScoreboardScreen()));
    await tester.pump();
    await tester.pump();

    expect(container.read(nightVoteProvider), isNull);
    expect(find.byKey(const Key('nightVoteStrip')), findsNothing);
  });

  testWidgets('with the director as picker the scoreboard starts no vote', (tester) async {
    await forEachLook(tester, (look) async {
      final started = _Started();
      await _openScoreboard(
        tester,
        look,
        started,
        length: NightLength.three,
        roundsPlayed: 1,
        settings: const NightSettings(pool: {'bumperRound'}),
      );

      expect(started.setups, isEmpty);
      expect(find.byKey(const Key('nightVoteStrip')), findsNothing);
    });
  });

  testWidgets('the strip fits 360x640 and the TV size in every look, open and settled', (tester) async {
    for (final size in const [_phoneSize, Size(960, 540)]) {
      // The tree of the last size is taken down first: a scope keeps its number of overrides.
      await tester.pumpWidget(const SizedBox.shrink());
      await forEachLook(tester, (look) async {
        final started = _Started();
        await _openScoreboard(tester, look, started, length: NightLength.five, roundsPlayed: 1, size: size);
        expect(find.byType(NightVoteStrip), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'the open strip does not overflow at $size in $look');

        started.handles.single.finish(const {});
        await tester.pump();
        expect(find.textContaining('by luck!'), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'the settled strip does not overflow at $size in $look');
      });
    }
  });
}
