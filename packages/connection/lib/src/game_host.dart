import 'package:protocol/protocol.dart';

import 'game_types.dart';
import 'gamepad.dart';
import 'local_player.dart';
import 'rtt.dart';

/// Everything a game or a TV test screen uses from the host (PRD v2 P3):
/// players joining and leaving, each player's gamepad, haptics and latency.
/// Games use nothing else, so this interface is the template for future
/// engine kits, and the same game runs unchanged on a TV, a PC or a phone
/// (S1). Pure Dart.
abstract interface class GameHost {
  /// The host's clock in ms (monotonic).
  int get nowMs;

  /// The players in the game right now, by number, including a player who is
  /// [GamePlayer.away] while their phone has dropped.
  List<GamePlayer> get players;

  /// Fires when a player joins or leaves, or changes mode.
  Stream<List<GamePlayer>> get playersChanged;

  /// The player's controls, neutral if they're gone.
  GamepadState gamepad(String playerId);

  /// When the player's current input arrived, on [nowMs], or null for a
  /// local player or before any input.
  int? inputArrivedAtMs(String playerId);

  /// Plays a haptic event on the player's controller. Returns false if it
  /// couldn't (a local player, or not connected).
  bool haptic(String playerId, HapticEventMessage event);

  /// Asks the player's phone how the controls felt (PRD v2 C19). Returns
  /// false if the phone can't show the prompt.
  bool askRating(String playerId, {required String id, required String game});

  /// Heartbeat round trip and input delay over the last 30 s (and the input
  /// delay over the whole connection), or null for a local player.
  PlayerLatency? latency(String playerId);

  /// A delay stage (S7) over the last 30 s, or null before any samples.
  RttSummary? stageSummary(String playerId, String stage);

  /// Adds a player whose input comes from this device (S2), with the lowest
  /// free number. The game sets its controls with [LocalPlayer.set].
  LocalPlayer addLocalPlayer({String? nickname});

  /// Reports something for analytics.
  void record(GameRecord record);

  /// Reports a delay stage (S7), e.g. [LatencyStage.receivedToDrawn] when a
  /// frame with a player's new input was built.
  void reportStage(String playerId, String stage, int ms);

  /// Plays a sound by event name, e.g. `snap` (PRD v2 S5). Games never play
  /// audio themselves, so a future host can stream it or have the receiver
  /// play its own copy. An unknown name plays nothing.
  void playSound(String name);

  /// What the game does with the player's buttons (P5): labels, hidden
  /// buttons, allowed modes. [GameLayoutMessage.standard] when the game
  /// ends. Kept and sent again if the phone reconnects.
  void setLayout(String playerId, GameLayoutMessage layout);

  /// The player's status panel (P6), or [StatusMessage.hidden]. Sent at most
  /// [StatusMessage.maxPerSecond] times a second; the newest always gets
  /// there.
  void setStatus(String playerId, StatusMessage status);

  /// True while at least one paired controller listed [Capability.view]. A
  /// session skips building frames when nobody would get them.
  bool get hasViewers;

  /// The seq of the input [gamepad] returns for [playerId] now: the last
  /// applied InputStateMessage.seq. Null for a local player or before any
  /// input.
  int? inputSeq(String playerId);

  /// A game starts being shown on viewers. Sent to every viewer now, and to
  /// any viewer that pairs later until [endView], followed by the latest frame.
  void startView(ViewStartMessage start);

  /// One frame, to every viewer. Encoded once, the same text to each.
  /// Ignored before startView or after endView.
  void publishFrame(FrameMessage frame);

  /// The game stopped being shown. Sent to every viewer; forgets the start
  /// and the latest frame. With [of], the start this end is for: an end for a
  /// view a newer start has replaced is ignored, so a rematch's new view, which
  /// starts before the old round's screen is gone, runs on (owner's test of
  /// m13.3).
  void endView(ViewEndMessage end, {ViewStartMessage? of});

  /// Each viewer whose id is in [results] gets its own result of the round
  /// that just ended (M14 design section 9), as a `view_end` carrying it. The
  /// view stays on, so the phone keeps the last frame and draws its card over
  /// it; the round's later [endView] takes the card away. Ignored when no view
  /// is running.
  void showResults(Map<String, ViewResult> results);

  /// This host is away for a while, so the viewers it shows the game to can
  /// say "Waiting for the host" and count down (m12 §2.10). [secondsLeft] is
  /// how long the round still runs; null says the host is back. Ignored when
  /// no view is running, and by a host whose screen is the one everybody
  /// watches.
  void hostAway(int? secondsLeft);

  /// Ends the grace of an away player now: the round goes on without them,
  /// and they leave the game (m12 bug 1107d). Does nothing for a player who
  /// is here or already gone.
  void goOnWithout(String playerId);
}

/// A player's heartbeat round trip and input delay.
typedef PlayerLatency = ({
  RttSummary? ping,
  int? pingNowMs,
  RttSummary? inputDelay,
  RttSummary? inputDelaySession,
  int? errorMs,
});
