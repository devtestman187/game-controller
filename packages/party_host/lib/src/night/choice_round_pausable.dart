import 'dart:async';

import 'package:connection/connection.dart';

import 'night_flow_controller.dart';

/// Joins a choice round to the night's pause: the night's pause and resume freeze and carry on the round.
final class ChoiceRoundPausable implements NightPausable {
  /// Adds itself to [controller]; a night already paused pauses [round] now when it is started.
  ChoiceRoundPausable({required this.round, required this.controller}) {
    controller.addPausable(this);
    _closeSub = round.changes.listen((_) {
      if (round.isClosed) detach();
    });
    if (controller.isPaused) round.pause();
  }

  /// The round the night pauses and resumes.
  final ChoiceRound round;

  /// The night that owns the pause.
  final NightFlowController controller;
  StreamSubscription<void>? _closeSub;

  @override
  void pause() => round.pause();

  @override
  void resume() => round.resume();

  /// Takes this out of the night's pausables and stops listening to the round; safe to call twice.
  void detach() {
    controller.removePausable(this);
    unawaited(_closeSub?.cancel());
    _closeSub = null;
  }
}
