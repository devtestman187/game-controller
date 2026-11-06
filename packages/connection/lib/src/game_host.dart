import 'dart:async';

import 'package:protocol/protocol.dart';

import 'gamepad.dart';
import 'host_server.dart';
import 'host_types.dart';
import 'rtt.dart';

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

/// Everything a game or a TV test screen uses from the host (PRD v2 P3):
/// players joining and leaving, each player's gamepad, haptics and latency.
/// Games use nothing else, so this interface is the template for future
/// engine kits, and the same game runs unchanged on a TV, a PC or a phone
/// (S1). Pure Dart.
abstract interface class GameHost {
  /// The host's clock in ms (monotonic).
  int get nowMs;

  /// The players in the game right now, by number.
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
}

/// A player's heartbeat round trip and input delay.
typedef PlayerLatency = ({
  RttSummary? ping,
  int? pingNowMs,
  RttSummary? inputDelay,
  RttSummary? inputDelaySession,
  int? errorMs,
});

/// A player on the host device itself, e.g. a keyboard on Windows (S2).
final class LocalPlayer {
  LocalPlayer(this.id, this.number, {this.nickname, required this._onRemove});

  final void Function(LocalPlayer) _onRemove;
  final String id;
  final int number;
  final String? nickname;
  GamepadState _state = const GamepadState(mode: InputMode.keyboard);
  bool _removed = false;

  GamepadState get state => _state;

  /// Sets what the player is pressing.
  void set(GamepadState state) {
    if (_removed) return;
    _state = state;
  }

  /// Takes the player out of the game and frees its number.
  void remove() {
    if (_removed) return;
    _removed = true;
    _onRemove(this);
  }
}

/// The [GameHost] of the TV and Windows apps: the phones connected to a
/// [HostServer], plus local players.
class ServerGameHost implements GameHost {
  ServerGameHost(this.server) {
    _serverSub = server.changes.listen((_) => _checkPlayers());
    _messagesSub = server.messages.listen((m) {
      final message = m.message;
      if (message is! InputStateMessage) return;
      _notePresses(m.controllerId, message, m.receivedAtMs);
      final delay = m.delayMs;
      if (delay != null) reportStage(m.controllerId, LatencyStage.sentToReceived, delay);
    });
  }

  /// A button press counts as held for at least this long. Games read the
  /// latest input once a frame, so a quick tap whose press and release
  /// arrive between two frames (Wi-Fi often bunches them) would be lost.
  static const minPressMs = 50;

  final _buttonsBefore = <String, Set<ControllerButton>>{};
  final _pressedAtMs = <String, Map<ControllerButton, int>>{};

  void _notePresses(String id, InputStateMessage input, int atMs) {
    final before = _buttonsBefore[id] ?? const {};
    for (final b in input.buttons) {
      if (!before.contains(b)) (_pressedAtMs[id] ??= {})[b] = atMs;
    }
    _buttonsBefore[id] = input.buttons.toSet();
  }

  final HostServer server;
  late final StreamSubscription<HostSnapshot> _serverSub;
  late final StreamSubscription<ControllerMessage> _messagesSub;
  final _locals = <String, LocalPlayer>{};
  final _playersChanged = StreamController<List<GamePlayer>>.broadcast();
  final _records = StreamController<GameRecord>.broadcast();
  final _stages = StreamController<StageSample>.broadcast();
  final _stageWindows = <(String, String), RttWindow>{};
  final _sounds = StreamController<String>.broadcast();
  final _layouts = <String, GameLayoutMessage>{};
  final _statuses = <String, StatusMessage>{};
  final _statusSentMs = <String, int>{};
  final _statusTimers = <String, Timer>{};
  List<GamePlayer> _lastPlayers = const [];
  int _nextLocal = 1;

  /// Everything games report, for the analytics collector.
  Stream<GameRecord> get records => _records.stream;

  /// Sounds the games ask for, by event name (S5): the app plays them.
  Stream<String> get sounds => _sounds.stream;

  /// The layout a player was last given (standard if none).
  GameLayoutMessage layoutOf(String playerId) => _layouts[playerId] ?? GameLayoutMessage.standard();

  @override
  void playSound(String name) {
    if (!_sounds.isClosed) _sounds.add(name);
  }

  @override
  void setLayout(String playerId, GameLayoutMessage layout) {
    if (_locals.containsKey(playerId)) return;
    if (layout.isStandard) {
      _layouts.remove(playerId);
    } else {
      _layouts[playerId] = layout;
    }
    server.send(playerId, layout);
  }

  @override
  void setStatus(String playerId, StatusMessage status) {
    if (_locals.containsKey(playerId)) return;
    if (status.isHidden) {
      _statuses.remove(playerId);
    } else {
      _statuses[playerId] = status;
    }
    final gap = 1000 ~/ StatusMessage.maxPerSecond;
    final since = nowMs - (_statusSentMs[playerId] ?? -gap);
    if (since >= gap) {
      _sendStatus(playerId, status);
    } else {
      // Too soon: the newest one goes when the gap is up.
      _statusTimers[playerId] ??= Timer(Duration(milliseconds: gap - since), () {
        _statusTimers.remove(playerId);
        _sendStatus(playerId, _statuses[playerId] ?? StatusMessage.hidden());
      });
    }
  }

  void _sendStatus(String playerId, StatusMessage status) {
    _statusSentMs[playerId] = nowMs;
    server.send(playerId, status);
  }

  /// Every delay sample, for the analytics collector.
  Stream<StageSample> get stages => _stages.stream;

  @override
  int get nowMs => server.nowMs;

  @override
  List<GamePlayer> get players {
    final list = <GamePlayer>[
      for (final c in server.snapshot.connected)
        if (c.player != null)
          GamePlayer(
            id: c.controllerId,
            number: c.player!,
            nickname: c.name,
            mode: InputMode.of(c.input),
            simulated: c.platform == 'sim',
          ),
      for (final l in _locals.values)
        GamePlayer(id: l.id, number: l.number, nickname: l.nickname, local: true, mode: InputMode.keyboard),
    ]..sort((a, b) => a.number.compareTo(b.number));
    return list;
  }

  @override
  Stream<List<GamePlayer>> get playersChanged => _playersChanged.stream;

  @override
  GamepadState gamepad(String playerId) {
    final local = _locals[playerId];
    if (local != null) return local.state;
    final state = GamepadState.fromInput(_info(playerId)?.input);
    final presses = _pressedAtMs[playerId];
    if (presses == null || presses.isEmpty) return state;
    final now = server.nowMs;
    presses.removeWhere((_, at) => now - at >= minPressMs);
    return state.withButtons({for (final b in presses.keys) GamepadState.buttonOf(b)});
  }

  @override
  int? inputArrivedAtMs(String playerId) => _info(playerId)?.inputAtMs;

  @override
  bool haptic(String playerId, HapticEventMessage event) {
    if (_locals.containsKey(playerId)) return false;
    return server.send(playerId, event);
  }

  @override
  bool askRating(String playerId, {required String id, required String game}) {
    if (_locals.containsKey(playerId)) return false;
    return server.send(playerId, RatingAskMessage(id: id, game: game));
  }

  @override
  PlayerLatency? latency(String playerId) {
    final c = _info(playerId);
    if (c == null) return null;
    return (
      ping: c.rttStats,
      pingNowMs: c.rttMs,
      inputDelay: c.inputLatency,
      inputDelaySession: c.inputLatencySession,
      errorMs: c.latencyErrorMs,
    );
  }

  @override
  RttSummary? stageSummary(String playerId, String stage) => switch (stage) {
    LatencyStage.sentToReceived => _info(playerId)?.inputLatency,
    _ => _stageWindows[(playerId, stage)]?.summary(nowMs),
  };

  @override
  void record(GameRecord record) {
    if (!_records.isClosed) _records.add(record);
  }

  @override
  void reportStage(String playerId, String stage, int ms) {
    if (ms < 0) return;
    if (stage != LatencyStage.sentToReceived) (_stageWindows[(playerId, stage)] ??= RttWindow()).add(nowMs, ms);
    if (!_stages.isClosed) _stages.add((playerId: playerId, stage: stage, ms: ms));
  }

  @override
  LocalPlayer addLocalPlayer({String? nickname}) {
    final number = server.reserveLocalPlayer();
    final player = LocalPlayer('local-${_nextLocal++}', number, nickname: nickname, onRemove: _removeLocal);
    _locals[player.id] = player;
    _checkPlayers();
    return player;
  }

  void _removeLocal(LocalPlayer player) {
    _locals.remove(player.id);
    server.releaseLocalPlayer(player.number);
    _checkPlayers();
  }

  ControllerInfo? _info(String id) => server.snapshot.connected.where((c) => c.controllerId == id).firstOrNull;

  void _checkPlayers() {
    final now = players;
    if (_samePlayers(now, _lastPlayers)) return;
    // A phone that (re)joined gets the game's controls and panel again.
    final before = {for (final p in _lastPlayers) p.id};
    for (final p in now) {
      if (p.local || before.contains(p.id)) continue;
      if (_layouts[p.id] case final layout?) server.send(p.id, layout);
      if (_statuses[p.id] case final status?) _sendStatus(p.id, status);
    }
    _lastPlayers = now;
    if (!_playersChanged.isClosed) _playersChanged.add(now);
  }

  Future<void> dispose() async {
    for (final t in _statusTimers.values) {
      t.cancel();
    }
    await _serverSub.cancel();
    await _messagesSub.cancel();
    await _playersChanged.close();
    await _records.close();
    await _stages.close();
    await _sounds.close();
  }
}

bool _samePlayers(List<GamePlayer> a, List<GamePlayer> b) =>
    a.length == b.length && Iterable.generate(a.length).every((i) => a[i] == b[i]);

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
