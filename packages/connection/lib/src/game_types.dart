import 'package:protocol/protocol.dart';

import 'gamepad.dart';

/// One player in a game: a phone, or a local player on the host itself.
final class GamePlayer {
  const GamePlayer({
    required this.id,
    required this.number,
    this.nickname,
    this.local = false,
    this.mode = InputMode.none,
    this.simulated = false,
    this.away = false,
    this.ownPlayer = false,
  });

  /// The controller ID (or a local player's own ID).
  final String id;

  /// 1, 2, …, shown on the phone and next to the sprite.
  final int number;

  /// A name to show, kept on the host only. Never recorded in analytics.
  final String? nickname;

  /// True for a player whose input comes from this device (PRD v2 S2).
  final bool local;

  final InputMode mode;

  /// A simulated controller (the TV's test tool or `sim_controller`): its demo
  /// input presses every button, so menus and pausing ignore it.
  final bool simulated;

  /// True while this phone has dropped and the round still holds its slot
  /// (m12 bug 1107d): the rules keep its place and its held piece, but no
  /// input comes and the round waits for it for the host's grace. A player
  /// who is here is never away.
  final bool away;

  /// True when this player came in on the host's own in-process link: the
  /// host phone's own player (D1). It is a controller like any other, but its
  /// link going is the host's own business, so the round never waits for it
  /// and it is never [away] (m12 code health N5).
  final bool ownPlayer;

  /// This player's colour as 0xAARRGGBB.
  int get color => playerColor(number);

  String get label => 'P$number${nickname == null ? '' : ' $nickname'}';

  @override
  bool operator ==(Object other) =>
      other is GamePlayer &&
      other.id == id &&
      other.number == number &&
      other.nickname == nickname &&
      other.local == local &&
      other.mode == mode &&
      other.simulated == simulated &&
      other.away == away &&
      other.ownPlayer == ownPlayer;

  @override
  int get hashCode => Object.hash(id, number, nickname, local, mode, simulated, away, ownPlayer);
}

/// Why a player's away slot ended (m12 bug 1108g): the round stopped waiting
/// for a phone that dropped (m12 bug 1107d).
enum AwayEnd {
  /// The phone is back within the grace, so the round goes on with it.
  back,

  /// The host's grace ran out and the phone never came back: the round goes on
  /// without the player.
  graceOver,

  /// Someone chose Go on without them: the round goes on without the player.
  wentOnWithout,

  /// The round is over: every slot ends with it.
  roundOver,
}

/// One away player's slot ending (m12 bug 1108g): who, why, and the grace the
/// host holds a dropped player's slot for. The host's log says the grace's real
/// seconds from it.
typedef AwayEnded = ({GamePlayer player, AwayEnd reason, Duration grace});

/// Named delay stages (PRD v2 S7). Later hosts add their own (snapshot
/// received, encode, decode, …), and results stay comparable.
abstract final class LatencyStage {
  /// Input sent on the phone → received by the host (estimated one way).
  static const sentToReceived = 'sent_to_received';

  /// Input received by the host → the first frame built with it.
  static const receivedToDrawn = 'received_to_drawn';

  /// A touch on the phone → the drawn frame that first acknowledges it
  /// (PRD v2 D3, M12). Measured on the phone's own clock: the time from when
  /// the input was sent to the post-frame callback of the frame whose `acks`
  /// covered it.
  static const touchToFrame = 'touch_to_frame';

  /// How much later a frame arrived than the fastest frame of the last 2 s
  /// (m12 §4). One sample per frame, measured on the phone's clock; it is
  /// what sizes the viewer's playout delay.
  static const frameJitter = 'frame_jitter';
}

/// One delay measurement.
typedef StageSample = ({String playerId, String stage, int ms});

/// Something a game reports for analytics: a round result, a wall hit, a
/// goal. [data] holds numbers and short strings only.
final class GameRecord {
  const GameRecord({required this.game, required this.name, this.playerId, this.data = const {}});

  /// The game, e.g. `arena`.
  final String game;

  /// What happened, e.g. `round_end`, `wall_hit`, `goal`.
  final String name;

  /// Who it happened to, if anyone.
  final String? playerId;

  final Map<String, Object?> data;

  @override
  String toString() => '$game.$name${playerId == null ? '' : ' ($playerId)'} $data';
}
