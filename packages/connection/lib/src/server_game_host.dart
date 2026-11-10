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

/// The [GameHost] of the TV and Windows apps: the phones connected to a
/// [HostServer], plus local players.
class ServerGameHost implements GameHost {
  ServerGameHost(this.server, {this.awayGrace = defaultAwayGrace}) {
    _away = AwaySlots(
      server: server,
      grace: awayGrace,
      nowMs: () => nowMs,
      hasView: () => _viewStart != null,
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

  /// Whether a round runs, [startView] to [endView] (m12 bug 1107d).
  bool _roundRunning = false;

  /// The view a game asked for, kept for viewers that pair mid-game (m12 §2).
  ViewStartMessage? _viewStart;
  ViewStartMessage? _latestStart;
  FrameMessage? _viewFrame;

  /// When the host's away grace runs out, on its clock (m12 R1 finding 9).
  int? _hostAwayEndsAtMs;

  /// Whether phones show this host's game at all (m12-joined-view §0.1): a
  /// change applies from the next [startView].
  bool shareView = true;

  /// The rate of the view a game is running, in frames a second (m12 §0.4):
  /// the rate viewers were told. Null between games, and when not shared.
  int? get viewRateHz => _viewStart?.hz;

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
  bool get hasViewers => shareView && server.snapshot.connected.any(_isViewer);

  /// A controller that gets frames: it listed [Capability.view].
  static bool _isViewer(ControllerInfo info) => info.supports(Capability.view);

  @override
  void startView(ViewStartMessage start) {
    _latestStart = start;
    _roundRunning = true;
    _hostAwayEndsAtMs = null;
    // A view that isn't shared is no view here: no start is kept, so no frame
    // or end can follow, and a viewer that pairs later gets nothing.
    _viewStart = shareView ? start : null;
    // A viewer that pairs from now on gets this start and the frames after it,
    // never a frame of a game that has ended or a previous one.
    _viewFrame = null;
    if (_viewStart == null) return;
    server.sendToAll(start);
  }

  @override
  void publishFrame(FrameMessage frame) {
    if (_viewStart == null) return;
    _viewFrame = frame;
    server.sendToAll(frame);
  }

  @override
  void showResults(Map<String, ViewResult> results) {
    // The view stays on: each phone keeps the last frame and draws its result
    // over it, until the round's own end (M14 design section 9).
    if (_viewStart == null) return;
    for (final MapEntry(key: playerId, value: result) in results.entries) {
      server.send(playerId, ViewEndMessage(reason: ViewEndReason.finished, result: result));
    }
  }

  @override
  void endView(ViewEndMessage end, {ViewStartMessage? of}) {
    if (of != null && !identical(of, _latestStart)) return;
    _roundRunning = false;
    final wasRunning = _viewStart != null;
    _viewStart = null;
    _viewFrame = null;
    _hostAwayEndsAtMs = null;
    if (wasRunning) server.sendToAll(end);
    // A slot ends with the round (m12 bug 1107d): when it is over, the
    // players away lose it at once, so a rematch never waits for someone
    // who left. The game has already stopped, so no step sees them go.
    if (_away.isEmpty) return;
    _away.endAll();
    _checkPlayers();
  }

  @override
  void hostAway(int? secondsLeft) {
    // Only a running view sends: a host that isn't sharing has no viewer to
    // tell (m12 §2.10).
    if (_viewStart == null) return;
    _hostAwayEndsAtMs = secondsLeft == null ? null : nowMs + secondsLeft * Duration.millisecondsPerSecond;
    final message = secondsLeft == null ? const HostBackMessage() : HostAwayMessage(secondsLeft: secondsLeft);
    server.sendToAll(message);
  }

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
    _away.noteRoster(players, roundRunning: _roundRunning);
    final now = players;
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
      _sendView(p.id);
    }
    _lastPlayers = now;
    if (!_playersChanged.isClosed) _playersChanged.add(now);
  }

  @override
  void goOnWithout(String playerId) {
    if (_away.end(playerId, AwayEnd.wentOnWithout)) _checkPlayers();
  }

  /// A viewer that just (re)paired mid-game gets the view's start, its latest
  /// frame and the aways before any later frame (m12 §2).
  void _sendView(String controllerId) {
    final start = _viewStart;
    if (start == null) return;
    server.send(controllerId, start);
    if (_viewFrame case final frame?) server.send(controllerId, frame);
    _away.sendTo(controllerId);
    if (_hostAwayEndsAtMs case final endsAt?) {
      server.send(controllerId, HostAwayMessage(secondsLeft: _secondsToGo(endsAt)));
    }
  }

  /// The whole seconds left of the host's away grace at [endsAtMs], rounded up
  /// like the wait's own count, and 0 once it is over.
  int _secondsToGo(int endsAtMs) {
    final ms = endsAtMs - nowMs;
    return ms <= 0 ? 0 : (ms / Duration.millisecondsPerSecond).ceil();
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
    a.length == b.length && Iterable.generate(a.length).every((i) => a[i] == b[i]);
