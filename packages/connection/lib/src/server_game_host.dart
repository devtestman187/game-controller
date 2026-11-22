import 'dart:async';

import 'package:protocol/protocol.dart';

import 'away_slots.dart';
import 'game_host.dart';
import 'game_types.dart';
import 'gamepad.dart';
import 'host_server.dart';
import 'host_types.dart';
import 'local_player.dart';
import 'rtt.dart';

part 'server_game_frames.dart';

/// The [GameHost] of the TV and Windows apps: the phones connected to a
/// [HostServer], plus local players.
class ServerGameHost implements GameHost {
  ServerGameHost(this.server, {this.awayGrace = defaultAwayGrace}) {
    _away = AwaySlots(
      server: server,
      grace: awayGrace,
      nowMs: () => nowMs,
      hasView: () => _view.isOn,
      onEnded: _checkPlayers,
    );
    _view = RoundView(
      server: server,
      away: _away,
      nowMs: () => nowMs,
      characters: () => _characters,
      onEnded: _checkPlayers,
    );
    _serverSub = server.changes.listen((_) => _checkPlayers());
    _messagesSub = server.messages.listen((m) {
      final message = m.message;
      if (message is InputStateMessage) {
        _notePresses(m.controllerId, message, m.receivedAtMs);
        final delay = m.delayMs;
        if (delay != null) reportStage(m.controllerId, LatencyStage.sentToReceived, delay);
      } else if (message is MetricsMessage) {
        _reportStages(m.controllerId, message.stages);
      }
    });
  }

  /// A button press counts as held for at least this long: games read the
  /// latest input once a frame, so a tap that arrives between two is not lost.
  static const minPressMs = 50;

  /// How many seconds a player whose phone dropped keeps their slot (m12 bug
  /// 1107d, `hostGraceS`): the round waits for them this long, then goes on
  /// without them.
  static const hostGraceS = 30;

  /// The default [awayGrace]: [hostGraceS].
  static const defaultAwayGrace = Duration(seconds: hostGraceS);

  /// How long a dropped player keeps their slot (a test runs with less).
  final Duration awayGrace;

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

  /// The dropped players who still hold their slot (m12 bug 1107d).
  late final AwaySlots _away;

  /// The view a game shows on the phones, kept for viewers that pair mid-game
  /// (m12 §2).
  late final RoundView _view;

  /// The character each player wears right now, by player ID (M16 identity):
  /// the roster's, refreshed at every change, so each frame's `chars` costs no
  /// more than the frame's own roster.
  Map<String, PlayerCharacter> _characters = const {};

  /// Whether phones show this host's game at all (m12-joined-view §0.1): a
  /// change applies from the next [startView].
  bool get shareView => _view.shareView;

  set shareView(bool value) => _view.shareView = value;

  /// The rate of the view a game is running, in frames a second (m12 §0.4):
  /// the rate viewers were told. Null between games, and when not shared.
  int? get viewRateHz => _view.rateHz;

  /// Everything games report, for the analytics collector.
  Stream<GameRecord> get records => _records.stream;

  /// Every away player's slot ending, with the reason (m12 bug 1108g).
  Stream<AwayEnded> get awayEnded => _away.ends;

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
            nickname: nicknameOf(c.name),
            character: c.character,
            mode: InputMode.of(c.input),
            simulated: c.platform == 'sim',
            ownPlayer: c.isLocal,
          ),
      for (final l in _locals.values)
        GamePlayer(id: l.id, number: l.number, nickname: l.nickname, local: true, mode: InputMode.keyboard),
      ..._away.players,
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
  int? inputSeq(String playerId) => _info(playerId)?.input?.seq;

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
  bool get hasViewers => _view.hasViewers;

  @override
  void startView(ViewStartMessage start) => _view.start(start);

  @override
  void publishFrame(FrameMessage frame) => _view.publish(frame);

  @override
  void showResults(Map<String, ViewResult> results) => _view.results(results);

  @override
  void endView(ViewEndMessage end, {ViewStartMessage? of}) => _view.end(end, of: of);

  @override
  void hostAway(int? secondsLeft) => _view.hostAway(secondsLeft);

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

  /// A viewer's own samples (m12 §1) become the host's, so they reach
  /// [stages], [stageSummary] and the session summary like the host's own.
  void _reportStages(String controllerId, Map<String, List<int>> stages) {
    for (final MapEntry(key: stage, value: samples) in stages.entries) {
      for (final ms in samples) {
        reportStage(controllerId, stage, ms);
      }
    }
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
    _away.noteRoster(players);
    final now = players;
    _characters = {for (final p in now) p.id: ?p.character};
    if (_samePlayers(now, _lastPlayers)) return;
    // A phone that (re)joined gets the game's controls and panel again; one
    // that came back from a drop counts as rejoined, not as already here.
    final before = {
      for (final p in _lastPlayers)
        if (!p.away) p.id,
    };
    for (final p in now) {
      if (p.local || p.away || before.contains(p.id)) continue;
      if (_layouts[p.id] case final layout?) server.send(p.id, layout);
      if (_statuses[p.id] case final status?) _sendStatus(p.id, status);
      _view.sendTo(p.id);
    }
    _lastPlayers = now;
    if (!_playersChanged.isClosed) _playersChanged.add(now);
  }

  @override
  void goOnWithout(String playerId) {
    if (_away.end(playerId, AwayEnd.wentOnWithout)) _checkPlayers();
  }

  Future<void> dispose() async {
    for (final t in _statusTimers.values) {
      t.cancel();
    }
    _away.dispose();
    await _serverSub.cancel();
    await _messagesSub.cancel();
    await _playersChanged.close();
    await _records.close();
    await _stages.close();
    await _sounds.close();
  }
}

bool _samePlayers(List<GamePlayer> a, List<GamePlayer> b) =>
    a.length == b.length && Iterable<int>.generate(a.length).every((i) => a[i] == b[i]);
