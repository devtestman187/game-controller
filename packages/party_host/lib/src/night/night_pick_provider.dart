import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../arena_settings_provider.dart';
import '../prefs.dart';
import 'director_input.dart';
import 'night_director.dart';
import 'night_pick.dart';
import 'night_played_store.dart';
import 'night_settings.dart';
import 'party_night.dart';
import 'playlist_picker.dart';
import 'shuffle_picker.dart';
import 'variant.dart';

/// The random source the night picks with; a test overrides it with a seeded one.
final nightRandomProvider = Provider<Random>((ref) => Random());

/// The night's pick for the round it is on, or null when the host picks (M17 plan 1.2): see [NightPickNotifier].
final nightPickProvider = NotifierProvider<NightPickNotifier, NightPick?>(NightPickNotifier.new);

/// Picks each round's game from the night's settings: the director, the Shuffle or the Playlist. Each pick is kept
/// with the variants played so far, which are saved on the host's prefs.
class NightPickNotifier extends Notifier<NightPick?> {
  /// The ids of the variants played this night, oldest first.
  List<String> _playedIds = const [];

  @override
  NightPick? build() {
    _playedIds = NightPlayedStore(ref.watch(prefsProvider)).load();
    // A night that ends, or is dropped, takes its played list and its pick with it.
    ref.listen(partyNightProvider, (_, night) {
      if (night == null) _forgetNight();
    });
    return null;
  }

  /// The pick for [round] (counting from 1). Asked again for the round it is on, it gives the same pick. Null when the
  /// host picks the game, or when the pool has no game to play.
  NightPick? pickFor(int round) {
    final current = state;
    if (current?.round == round) return current;
    final settings = ref.read(nightSettingsProvider);
    final pick = switch (settings.picker) {
      NightPicker.host || NightPicker.rotating || NightPicker.vote => null,
      NightPicker.director => _directorPick(round, settings),
      NightPicker.shuffle => _shufflePick(round, settings),
      NightPicker.playlist => _playlistPick(round, settings),
    };
    state = pick;
    if (pick != null) _record(pick);
    return pick;
  }

  /// The director's pick for [round], from the pool and the night's totals so far.
  NightPick? _directorPick(int round, NightSettings settings) {
    final night = ref.read(partyNightProvider);
    final input = DirectorInput(
      pool: _pool(settings),
      played: _played(),
      totals: night?.totals.values.toList() ?? const [],
      min: settings.difficultyMin,
      max: settings.difficultyMax,
    );
    final pick = const NightDirector().pick(input, random: ref.read(nightRandomProvider));
    return pick == null ? null : NightPick(round: round, variant: pick.variant, reason: pick.reason);
  }

  /// The Shuffle's pick for [round]: a variant from the pool, with no repeats until every one has been played.
  NightPick? _shufflePick(int round, NightSettings settings) {
    final variant = const ShufflePicker().next(
      pool: _pool(settings),
      played: _played(),
      random: ref.read(nightRandomProvider),
    );
    return variant == null ? null : NightPick(round: round, variant: variant);
  }

  /// The Playlist's pick for [round]: the pool in its order, from the first round.
  NightPick? _playlistPick(int round, NightSettings settings) {
    final variant = PlaylistPicker(order: _pool(settings)).next(_playedIds.length);
    return variant == null ? null : NightPick(round: round, variant: variant);
  }

  /// Every launch variant, with each map's tier from the library as far as it has loaded.
  List<Variant> _launch() {
    final library = ref.read(arenaMapLibraryProvider).value;
    return launchVariants((mapId) => mapTierLevel(library, mapId));
  }

  /// The variants this night may play: the settings' pool and difficulty, in the games a night plays.
  List<Variant> _pool(NightSettings settings) => [
    for (final variant in variantPool(_launch(), settings))
      if (nightPlayableGames.contains(variant.game)) variant,
  ];

  /// The variants played so far, as the pool's own variant objects, oldest first.
  List<Variant> _played() {
    final byId = {for (final variant in _launch()) variant.id: variant};
    return [for (final id in _playedIds) ?byId[id]];
  }

  /// Notes [pick] as played: its id is appended, saved, and the list is kept for the next round.
  void _record(NightPick pick) {
    _playedIds = [..._playedIds, pick.variant.id];
    unawaited(NightPlayedStore(ref.read(prefsProvider)).save(_playedIds));
  }

  /// Clears the played list and the pick when the night ends.
  void _forgetNight() {
    _playedIds = const [];
    state = null;
    unawaited(NightPlayedStore(ref.read(prefsProvider)).clear());
  }
}
