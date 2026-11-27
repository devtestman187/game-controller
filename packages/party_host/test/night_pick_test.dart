import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:party_host/src/night/night_director.dart';
import 'package:party_host/src/night/night_pick.dart';
import 'package:party_host/src/night/night_pick_provider.dart';
import 'package:party_host/src/night/night_settings.dart';
import 'package:party_host/src/night/night_vote.dart';
import 'package:puzzle_game/puzzle_game.dart';
import 'package:test_game/test_game.dart';

import 'support/fake_prefs.dart';
import 'support/host_harness.dart';
import 'support/night_harness.dart';

/// The prefs key the played list is saved under.
const _playedKey = 'party_night_played_v1';

/// The ids of the default pool, in launch order: the seven games a night plays by default (Arena Race is left out).
const _defaultPoolIds = [
  'shapeRace:easy',
  'shapeRace:medium',
  'shapeRace:hard',
  'bumperRound:pinball',
  'bumperRound:block-castle',
  'bumperRound:toy-factory',
  'bumperRound:spinning-tops',
];

/// A container whose prefs are [prefs], with the maps read from the data files and [random] as the night's random
/// source; the maps are loaded before it is returned, so a pick reads their tiers.
Future<ProviderContainer> _loaded({FakePrefs? prefs, Random? random, List<Override> overrides = const []}) async {
  final container = ProviderContainer(
    overrides: [
      ...overrides,
      prefsProvider.overrideWithValue(prefs ?? FakePrefs()),
      gamePlayersProvider.overrideWith(TestRoster.new),
      arenaMapLibraryProvider.overrideWith((ref) => testMaps()),
      nightRandomProvider.overrideWithValue(random ?? Random(1)),
    ],
  );
  addTearDown(container.dispose);
  await container.read(arenaMapLibraryProvider.future);
  return container;
}

/// Sets the night's settings to [settings] in [container].
void _useSettings(ProviderContainer container, NightSettings settings) {
  container.read(nightSettingsProvider.notifier).update(settings);
}

/// The picks for rounds 1 to [rounds], in order, each asked for once.
List<NightPick?> _picksFor(ProviderContainer container, int rounds) {
  final notifier = container.read(nightPickProvider.notifier);
  return [for (var round = 1; round <= rounds; round++) notifier.pickFor(round)];
}

/// The variant ids of [picks], which must all be picks.
List<String> _idsOf(List<NightPick?> picks) => [for (final pick in picks) pick!.variant.id];

void main() {
  test('a map plays at the tier its file gives: pinball easy, toy-factory medium, block-castle hard', () async {
    final library = testMaps();
    expect(mapTierLevel(library, 'pinball'), Level.easy);
    expect(mapTierLevel(library, 'toy-factory'), Level.medium);
    expect(mapTierLevel(library, 'block-castle'), Level.hard);
  });

  test('no library, no such map, or a map with no tier yet gives medium', () {
    final unrated = ArenaMap.parse(
      File('$mapDataDir/playroom.json').readAsStringSync().replaceFirst(RegExp(r'\s*"tier": "\w+",'), ''),
    );
    expect(mapTierLevel(null, 'pinball'), Level.medium, reason: 'no library yet');
    expect(mapTierLevel(testMaps(), 'no-such-map'), Level.medium, reason: 'no such map');
    expect(mapTierLevel(ArenaMapLibrary([unrated]), 'playroom'), Level.medium, reason: 'unrated');
  });

  test('the host picks: pickFor gives null and records nothing', () async {
    final prefs = FakePrefs();
    final container = await _loaded(prefs: prefs);
    expect(container.read(nightPickProvider.notifier).pickFor(1), isNull);
    expect(container.read(nightPickProvider), isNull);
    await pumpEventQueue();
    expect(prefs.containsKey(_playedKey), isFalse, reason: 'the host picked, so nothing was played');
  });

  test('the director opens a night at the easiest tier when round 1 is asked for', () async {
    final container = await _loaded();
    _useSettings(container, const NightSettings(picker: NightPicker.director));
    final pick = container.read(nightPickProvider.notifier).pickFor(1);
    expect(pick?.reason, DirectorReason.opening);
    expect(pick?.variant.tier, Level.easy);
    expect(pick?.round, 1);
  });

  test('a Kids night is easy only and never plays Arena Race or a map rated above easy', () async {
    final container = await _loaded();
    _useSettings(container, NightSettings.kids.copyWith(picker: NightPicker.director));
    final picks = _picksFor(container, 5);
    for (final pick in picks) {
      expect(pick, isNotNull);
      expect(pick!.variant.tier, Level.easy);
      expect(['shapeRace:easy', 'bumperRound:pinball'], contains(pick.variant.id));
    }
  });

  test('the director opens at medium when the night starts at medium, with no easier game', () async {
    final container = await _loaded();
    _useSettings(container, const NightSettings(picker: NightPicker.director, difficultyMin: Level.medium));
    final pick = container.read(nightPickProvider.notifier).pickFor(1);
    expect(pick?.reason, DirectorReason.opening);
    expect(pick?.variant.tier, Level.medium);
  });

  test('the director never picks the variant played last while another is left, for seeds 0 to 19', () async {
    for (var seed = 0; seed < 20; seed++) {
      final container = await _loaded(random: Random(seed));
      _useSettings(container, const NightSettings(picker: NightPicker.director));
      final notifier = container.read(nightPickProvider.notifier);
      final first = notifier.pickFor(1);
      final second = notifier.pickFor(2);
      expect(first, isNotNull, reason: 'seed $seed');
      expect(second?.variant, isNot(first?.variant), reason: 'seed $seed: the played list is used');
    }
  });

  test('pickFor for the same round twice gives the same pick and records it once', () async {
    final prefs = FakePrefs();
    final container = await _loaded(prefs: prefs);
    _useSettings(container, const NightSettings(picker: NightPicker.director));
    final notifier = container.read(nightPickProvider.notifier);
    final first = notifier.pickFor(1);
    final again = notifier.pickFor(1);
    expect(again, first);
    await pumpEventQueue();
    expect(jsonDecode(prefs.getString(_playedKey) ?? '[]') as List, hasLength(1));
  });

  test('the Shuffle plays every pool variant once before any repeat, with no reason', () async {
    final container = await _loaded();
    _useSettings(container, const NightSettings(picker: NightPicker.shuffle));
    final picks = _picksFor(container, _defaultPoolIds.length);
    expect(_idsOf(picks).toSet(), _defaultPoolIds.toSet());
    expect(picks.every((pick) => pick?.reason == null), isTrue, reason: 'the Shuffle gives no reason');
  });

  test('the Playlist plays the pool in its order, with no reason', () async {
    final container = await _loaded();
    _useSettings(container, const NightSettings(picker: NightPicker.playlist));
    final picks = _picksFor(container, _defaultPoolIds.length);
    expect(_idsOf(picks), _defaultPoolIds);
    expect(picks.every((pick) => pick?.reason == null), isTrue, reason: 'the Playlist gives no reason');
  });

  test('a pool of bumper rounds only never yields a Shape Race', () async {
    final container = await _loaded();
    _useSettings(container, const NightSettings(picker: NightPicker.director, pool: {'bumperRound'}));
    final ids = _idsOf(_picksFor(container, 10));
    expect(ids.every((id) => id.startsWith('bumperRound:')), isTrue, reason: '$ids');
  });

  test('with no pool set, Arena Race is never picked', () async {
    final container = await _loaded();
    _useSettings(container, const NightSettings(picker: NightPicker.director));
    final ids = _idsOf(_picksFor(container, 10));
    expect(ids.every((id) => !id.startsWith('arenaRace:')), isTrue, reason: '$ids');
  });

  test('a pool of only Arena Race gives no pick, and records nothing', () async {
    final prefs = FakePrefs();
    final container = await _loaded(prefs: prefs);
    _useSettings(container, const NightSettings(picker: NightPicker.director, pool: {'arenaRace'}));
    expect(container.read(nightPickProvider.notifier).pickFor(1), isNull);
    await pumpEventQueue();
    expect(prefs.containsKey(_playedKey), isFalse);
  });

  test('the played list survives a new container on the same prefs', () async {
    final prefs = FakePrefs();
    final first = await _loaded(prefs: prefs);
    _useSettings(first, const NightSettings(picker: NightPicker.shuffle));
    first.read(partyNightProvider.notifier).start(length: NightLength.three, awards: threeAwards);
    // A night saved before any round is played is dropped on a restart, so the night has a played round.
    first.read(partyNightProvider.notifier).recordRound(roundResult(points: {'p1': 5}, winners: {'p1'}));
    final firstPick = first.read(nightPickProvider.notifier).pickFor(1);
    expect(firstPick, isNotNull);
    await pumpEventQueue();

    final second = await _loaded(prefs: prefs);
    final secondPick = second.read(nightPickProvider.notifier).pickFor(2);
    expect(secondPick?.variant, isNot(firstPick?.variant), reason: 'the first round is still played');
  });

  test('the played list is cleared when the night ends', () async {
    final prefs = FakePrefs();
    final container = await _loaded(prefs: prefs);
    _useSettings(container, const NightSettings(picker: NightPicker.shuffle));
    container.read(partyNightProvider.notifier).start(length: NightLength.three, awards: threeAwards);
    container.read(nightPickProvider.notifier).pickFor(1);
    await pumpEventQueue();
    expect(prefs.containsKey(_playedKey), isTrue);

    container.read(partyNightProvider.notifier).end();
    await pumpEventQueue();
    expect(prefs.containsKey(_playedKey), isFalse, reason: 'the night ended');
    expect(container.read(nightPickProvider), isNull);
  });

  test(
    'the vote picker plays the game its settled vote chose, and the same round asked twice gives that pick',
    () async {
      final container = await _loaded(overrides: [voteStarterProvider.overrideWithValue((_, _) => null)]);
      _useSettings(container, const NightSettings(picker: NightPicker.vote));
      await container.read(nightVoteProvider.notifier).run(1);
      final voted = container.read(nightVoteProvider)!.result!.variant;

      final notifier = container.read(nightPickProvider.notifier);
      final pick = notifier.pickFor(1);

      expect(pick!.variant, voted);
      expect(notifier.pickFor(1), same(pick), reason: 'asked again, the same pick');
      expect(container.read(nightPickProvider)!.round, 1);
    },
  );

  test('the vote picker with no vote run plays a random variant of the pool', () async {
    final container = await _loaded();
    _useSettings(container, const NightSettings(picker: NightPicker.vote));

    final pick = container.read(nightPickProvider.notifier).pickFor(1);

    expect(_defaultPoolIds, contains(pick!.variant.id));
  });

  test('the vote picker with an empty pool gives null', () async {
    final container = await _loaded();
    _useSettings(container, const NightSettings(picker: NightPicker.vote, pool: {'arenaRace'}));

    expect(container.read(nightPickProvider.notifier).pickFor(1), isNull);
  });

  test('with no night running, the first read clears a saved played list and the next pick starts a new one', () async {
    final prefs = FakePrefs();
    await prefs.setString(_playedKey, jsonEncode(['shapeRace:easy']));
    final container = await _loaded(prefs: prefs);
    expect(container.read(nightPickProvider), isNull);
    await pumpEventQueue();
    expect(prefs.containsKey(_playedKey), isFalse, reason: 'no night runs, so the saved list is removed');

    _useSettings(container, const NightSettings(picker: NightPicker.shuffle));
    expect(container.read(nightPickProvider.notifier).pickFor(1), isNotNull);
    await pumpEventQueue();
    expect(
      jsonDecode(prefs.getString(_playedKey) ?? '[]') as List,
      hasLength(1),
      reason: 'the old list was not loaded',
    );
  });
}
