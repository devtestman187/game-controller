import 'dart:async';

import 'package:protocol/protocol.dart';

import 'game_host.dart';
import 'game_types.dart';
import 'gamepad.dart';
import 'local_player.dart';
import 'rtt.dart';

/// A [GameHost] kept in memory, with players and controls set by hand: for
/// tests, demos and as the smallest example of the interface.
class MemoryGameHost implements GameHost {
  MemoryGameHost({int Function()? now}) : _now = now ?? _stopwatch();

  final int Function() _now;
  final _players = <String, GamePlayer>{};
  final _pads = <String, GamepadState>{};
  final _arrived = <String, int>{};
  final _locals = <String, LocalPlayer>{};
  final _changes = StreamController<List<GamePlayer>>.broadcast();

  /// Everything the game sent, for tests to check.
  final haptics = <(String, HapticEventMessage)>[];
  final ratingAsks = <(String, String, String)>[];
  final records = <GameRecord>[];
  final stages = <StageSample>[];
  final sounds = <String>[];

  /// Each player's current layout and status panel.
  final layouts = <String, GameLayoutMessage>{};
  final statuses = <String, StatusMessage>{};
  int _nextLocal = 1;

  static int Function() _stopwatch() {
    final clock = Stopwatch()..start();
    return () => clock.elapsedMilliseconds;
  }

  /// Adds or updates a player.
  void setPlayer(GamePlayer player) {
    _players[player.id] = player;
    _changes.add(players);
  }

  void removePlayer(String id) {
    _players.remove(id);
    _pads.remove(id);
    _changes.add(players);
  }

  /// Sets a player's controls, as if new input arrived now.
  void setGamepad(String id, GamepadState state) {
    _pads[id] = state;
    _arrived[id] = nowMs;
  }

  @override
  int get nowMs => _now();

  @override
  List<GamePlayer> get players => _players.values.toList()..sort((a, b) => a.number.compareTo(b.number));

  @override
  Stream<List<GamePlayer>> get playersChanged => _changes.stream;

  @override
  GamepadState gamepad(String playerId) => _locals[playerId]?.state ?? _pads[playerId] ?? GamepadState.neutral;

  @override
  int? inputArrivedAtMs(String playerId) => _arrived[playerId];

  @override
  bool haptic(String playerId, HapticEventMessage event) {
    if (!_players.containsKey(playerId) || _players[playerId]!.local) return false;
    haptics.add((playerId, event));
    return true;
  }

  @override
  bool askRating(String playerId, {required String id, required String game}) {
    if (!_players.containsKey(playerId) || _players[playerId]!.local) return false;
    ratingAsks.add((playerId, id, game));
    return true;
  }

  @override
  PlayerLatency? latency(String playerId) => null;

  @override
  RttSummary? stageSummary(String playerId, String stage) => null;

  @override
  void record(GameRecord record) => records.add(record);

  @override
  void reportStage(String playerId, String stage, int ms) => stages.add((playerId: playerId, stage: stage, ms: ms));

  @override
  void playSound(String name) => sounds.add(name);

  @override
  void setLayout(String playerId, GameLayoutMessage layout) => layouts[playerId] = layout;

  @override
  void setStatus(String playerId, StatusMessage status) => statuses[playerId] = status;

  @override
  LocalPlayer addLocalPlayer({String? nickname}) {
    final used = {for (final p in _players.values) p.number};
    var n = 1;
    while (used.contains(n)) {
      n++;
    }
    final player = LocalPlayer(
      'local-${_nextLocal++}',
      n,
      nickname: nickname,
      onRemove: (p) {
        _locals.remove(p.id);
        removePlayer(p.id);
      },
    );
    _locals[player.id] = player;
    setPlayer(GamePlayer(id: player.id, number: n, nickname: nickname, local: true, mode: InputMode.keyboard));
    return player;
  }
}
