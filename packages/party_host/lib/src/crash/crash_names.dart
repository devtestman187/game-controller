import 'package:connection/connection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'crash_reporter.dart';

/// The players whose names a crash report must hide, or null when this app has
/// no lobby to take them from (design sentry-consent.md): a phone that only
/// pairs a TV has none, and so has a host before it starts.
///
/// Each app overrides it from the players of its own host, and the default is
/// no lobby, so no app reads a host it does not run.
final crashLobbyProvider = Provider<List<GamePlayer>?>((ref) => null);

/// Keeps the lobby's names where a report can scrub them (design
/// sentry-consent.md; the run's review found nothing ever set them): every
/// non-blank nickname is a name that must go out as `[name]` instead, and the
/// set is empty while nobody is in the lobby. Both apps keep it running at
/// their root, and a container that goes leaves no name behind (the run's
/// review, f1): the set is a static, so it outlived the lobby without this.
final crashNamesProvider = Provider<void>((ref) {
  ref.onDispose(() => CrashReports.playerNames = const {});
  final players = ref.watch(crashLobbyProvider);
  CrashReports.playerNames = players == null ? const {} : _namesOf(players);
});

/// The players' nicknames, leaving out the blanks.
Set<String> _namesOf(List<GamePlayer> players) {
  final names = <String>{};
  for (final player in players) {
    final name = player.nickname?.trim();
    if (name != null && name.isNotEmpty) names.add(name);
  }
  return names;
}
