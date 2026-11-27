import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import 'night_director.dart';
import 'night_flow_controller.dart';
import 'night_pick_provider.dart';
import 'party_night.dart';

/// How long each night card stays; a test overrides it.
final nightPacingProvider = Provider<NightPacing>((ref) => const NightPacing());

/// The scheduler the night's timers use; null is real time, a test overrides it with a fake clock.
final nightScheduleProvider = Provider<NightSchedule?>((ref) => null);

/// The controller of the night running now, or null when none runs. It stays the same while the night changes and is
/// built again only when a night starts or ends early or is cleared; a night loaded after rounds were played resumes
/// at their scoreboard, and a night loaded after its last round has no controller.
/// It never begins by itself: the screen that shows the night calls begin.
final nightFlowControllerProvider = Provider<NightFlowController?>((ref) {
  // The last round's end is not a change here: its ceremony and end still run on this controller.
  final length = ref.watch(
    partyNightProvider.select((night) => night == null || night.isEndedEarly ? null : night.length),
  );
  if (length == null) return null;
  final played = ref.read(partyNightProvider)?.round ?? 0;
  if (played >= length.rounds) return null;
  final pacing = ref.watch(nightPacingProvider);
  final schedule = ref.watch(nightScheduleProvider);
  // The director's rule for a round's game comes from the pick the night made for it; a host pick has none.
  DirectorReason? reasonFor(int round) => ref.read(nightPickProvider.notifier).pickFor(round)?.reason;
  final controller = played > 0
      ? NightFlowController.resumed(rounds: length.rounds, playedRounds: played, pacing: pacing, schedule: schedule)
      : NightFlowController(rounds: length.rounds, pacing: pacing, schedule: schedule);
  controller.reasonFor = reasonFor;
  ref.onDispose(controller.dispose);
  // The roster is read, not watched: a phone joining or leaving must not build the night again.
  controller.rosterChanged(ref.read(gamePlayersProvider));
  ref.listen(gamePlayersProvider, (_, players) => controller.rosterChanged(players));
  return controller;
});
