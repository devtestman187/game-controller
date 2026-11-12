import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_kit/game_kit.dart';

import '../providers.dart';
import 'automation_game_start.dart';
import 'automation_server.dart';
import 'automation_settings.dart';
import 'host_automation.dart';
import 'screen_frames.dart';

/// How the automation interface is switched on (M15 a2): the launch's
/// settings, from the shell that reads its environment or its build define.
/// Off by default, and inert until a launch says otherwise, so a store build
/// carries the code and never runs it.
final automationSettingsProvider = Provider<AutomationSettings>((ref) => const AutomationSettings());

/// The host's own frame, for `GET screenshot` (M15 a2): the shell wraps its
/// app in [ScreenFrames.boundary], and the automation reads the picture here.
final screenFramesProvider = Provider<ScreenFrames>((ref) => ScreenFrames());

/// The round a script asked for, or null when the host is home (M15 a2). The
/// automation gate watches it: a value opens the round, as the menus would,
/// and clearing it comes home.
final automationLaunchProvider = NotifierProvider<AutomationLaunchNotifier, AutomationGameStart?>(
  AutomationLaunchNotifier.new,
);

/// Keeps [automationLaunchProvider]: set by `POST game/start`, cleared by
/// `POST game/stop` or by the round's own way out.
class AutomationLaunchNotifier extends Notifier<AutomationGameStart?> {
  @override
  AutomationGameStart? build() => null;

  /// Sends the host to [start]'s round.
  void start(AutomationGameStart start) => state = start;

  /// Brings the host home.
  void stop() {
    if (state != null) state = null;
  }
}

/// Whether the latency test card covers the screen (M15 a2): `POST
/// probe/flash` shows it, and a press times from its next flip.
final automationProbeProvider = NotifierProvider<AutomationProbeNotifier, bool>(AutomationProbeNotifier.new);

/// Keeps [automationProbeProvider]: off until a script flashes the card.
class AutomationProbeNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  /// Shows the card, or hides it.
  void show({required bool on}) {
    if (state != on) state = on;
  }
}

/// How many times `POST probe/press` asked the latency card to flip (M15 c2):
/// a press is a flip the viewer can time, so `press_to_screen` is measured
/// from the host's clock at the press to the frame that shows the new colour.
final automationProbeFlipProvider = NotifierProvider<AutomationProbeFlipNotifier, int>(AutomationProbeFlipNotifier.new);

/// Keeps [automationProbeFlipProvider]: counts up once per press.
class AutomationProbeFlipNotifier extends Notifier<int> {
  @override
  int build() => 0;

  /// Asks the card for one more flip.
  void flip() => state = state + 1;
}

/// The host app's own drawn frames (M15 c2): the sampler reads the count
/// twice and tells the game's frame rate from it. A session with no phone
/// watching never publishes game frames (a frame goes out only to a viewer),
/// so the app's own drawing is what says how fast the game runs.
final automationDrawnProvider = Provider<AutomationDrawn>((ref) {
  final drawn = AutomationDrawn();
  SchedulerBinding.instance.addPersistentFrameCallback((_) => drawn.count());
  ref.onDispose(drawn.stop);
  return drawn;
});

/// A count of the frames the host app drew since it started.
final class AutomationDrawn {
  /// The frames drawn so far; one is added each time the app draws.
  int frames = 0;

  bool _stopped = false;

  /// Adds one frame, unless the counter was let go (its callback outlives it).
  void count() {
    if (!_stopped) frames++;
  }

  /// Stops counting.
  void stop() => _stopped = true;
}

/// The result of the round that ended last, as `GET state` reports it (M15
/// a2). The games record it here when their result card comes up; it clears
/// when the next round starts.
final automationResultProvider = NotifierProvider<AutomationResultNotifier, RoundResult?>(AutomationResultNotifier.new);

/// Keeps [automationResultProvider]: the last round's result, or null.
class AutomationResultNotifier extends Notifier<RoundResult?> {
  @override
  RoundResult? build() => null;

  /// Records the round that just ended.
  void record(RoundResult result) => state = result;

  /// Forgets the last round's result as a new round starts.
  void clear() {
    if (state != null) state = null;
  }
}

/// Answers the first-run stats question when the launch did (M15 a2): a run
/// with `THUMBPARTY_STATS_CONSENT=no` has no prompt over its screen, and the
/// session is still recorded on the host. Nothing here answers yes: sharing
/// stays a person's choice, so a launch only ever says no.
final automationConsentProvider = Provider<void>((ref) {
  final answer = ref.watch(automationSettingsProvider).statsConsent;
  if (answer == null) return;
  // After the frame that reads this: the answer is a change to another
  // provider, and the shell is built inside a build.
  Future.microtask(() => ref.read(statsServiceProvider).setConsent(answer));
});

/// Why the automation interface couldn't start (M15 f1, g1), or null: a bind
/// that failed while the host keeps hosting. The shared `StatsScreen` shows it
/// as one line, so a run that can't reach the interface says why instead of
/// waiting for a timeout; it clears once an interface listens again, or stops.
final automationStartErrorProvider = NotifierProvider<AutomationStartErrorNotifier, String?>(
  AutomationStartErrorNotifier.new,
);

/// Keeps [automationStartErrorProvider]: the reason the server's bind failed.
class AutomationStartErrorNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  /// Records the reason the interface couldn't listen; it stays until a start
  /// succeeds, the server stops, or a rebuilt server replaces it (M15 g1).
  void failed(String reason) => state = reason;

  /// Forgets the reason: the interface listens now, or nothing is left to say.
  void clear() {
    if (state != null) state = null;
  }
}

/// The automation interface's server (M15 a2). It listens while the app shows
/// anything, since the automation gate watches this, and stops with the
/// container; switched off ([AutomationSettings.enabled] false) it does
/// nothing at all. A bind that fails is reported to
/// [automationStartErrorProvider] as well as the log, and so is a bind that
/// works afterwards, so the one line never outlives its failure (M15 f1, g1).
final automationServerProvider = Provider<AutomationServer>((ref) {
  var disposed = false;
  void report(String? reason) {
    // A stop during the provider's own disposal must not touch providers.
    if (disposed) return;
    final errors = ref.read(automationStartErrorProvider.notifier);
    if (reason == null) {
      errors.clear();
    } else {
      errors.failed(reason);
    }
  }

  final server = AutomationServer(
    settings: ref.watch(automationSettingsProvider),
    api: HostAutomation(ref),
    log: ref.watch(logProvider).sink('automation'),
    onStartState: report,
  );
  // A rebuilt server starts from no failure: the line says what the interface
  // does now, not what a server before it could not do. Deferred, because this
  // is read inside a build.
  Future.microtask(() => report(null));
  ref.onDispose(() {
    disposed = true;
    unawaited(server.stop());
  });
  unawaited(server.start());
  return server;
});
