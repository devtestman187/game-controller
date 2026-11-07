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
      other.simulated == simulated;

  @override
  int get hashCode => Object.hash(id, number, nickname, local, mode, simulated);
}

/// Named delay stages (PRD v2 S7). Later hosts add their own (snapshot
/// received, frame drawn on a joined phone, encode, decode, …), and results
/// stay comparable.
abstract final class LatencyStage {
  /// Input sent on the phone → received by the host (estimated one way).
  static const sentToReceived = 'sent_to_received';

  /// Input received by the host → the first frame built with it.
  static const receivedToDrawn = 'received_to_drawn';
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
