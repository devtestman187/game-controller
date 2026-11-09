import 'dart:async';

import 'package:connection/connection.dart';
import 'package:protocol/protocol.dart';

import '../host_service.dart';
import '../host_view_state.dart';
import 'fake_stats.dart';

/// The fake host service (was `FakeHostController`): the test sets [state]
/// and calls [emit]; its [gameHost] reads the players from that state.
class FakeHostService implements HostService {
  /// [consent] is what the fake stats start with: true (already answered),
  /// false, or null (the first-launch prompt shows).
  FakeHostService(this.state, {bool? consent = true}) : stats = FakeStats(consent: consent) {
    gameHost = FakeGameHost(this);
  }

  /// The game host over [state]; see [FakeGameHost].
  @override
  late final FakeGameHost gameHost;

  @override
  final FakeStats stats;

  @override
  Stream<String> get gameSounds => gameHost.soundStream;

  @override
  Stream<AwayEnded> get awayEnded => gameHost.awayEnded;

  /// What the screens show; the test replaces it and calls [emit].
  @override
  HostViewState state;

  final _changes = StreamController<HostViewState>.broadcast();

  /// How many times [newPairingCode] was called.
  int newCodes = 0;

  /// How many simulated controllers were added.
  int simAdds = 0;

  /// How many times the simulated controllers were stopped.
  int simStops = 0;

  /// How many times every connection was dropped.
  int drops = 0;

  /// How many times the pairings were forgotten.
  int forgets = 0;

  /// How many times the log was exported.
  int exports = 0;

  /// How many times [resume] was called.
  int resumes = 0;

  /// Whether the phones that join show the game: set by the test.
  @override
  bool shareView = false;

  /// Haptic events the game host sent: (event, player ID).
  final haptics = <(HapticEventMessage, String?)>[];

  @override
  Stream<HostViewState> get changes => _changes.stream;

  /// Tells the listeners that [state] changed.
  void emit() => _changes.add(state);

  /// [state] without [id]'s phone, told to the listeners: the host reports a
  /// dropped phone that way, and an away player's slot ending too (m12 bug
  /// 1107d).
  void removeController(String id) {
    final host = state.host;
    state = HostViewState(
      hostName: state.hostName,
      host: HostSnapshot(
        running: host.running,
        port: host.port,
        pairingCode: host.pairingCode,
        controllers: [
          for (final c in host.controllers)
            if (c.controllerId != id) c,
        ],
      ),
      addresses: state.addresses,
      advertise: state.advertise,
      advertisedName: state.advertisedName,
      advertiseError: state.advertiseError,
      serverError: state.serverError,
      sims: state.sims,
    );
    emit();
  }

  @override
  void newPairingCode() => newCodes++;

  @override
  void addSimulatedController() => simAdds++;

  @override
  void stopSimulatedControllers() => simStops++;

  @override
  void dropAllConnections() => drops++;

  @override
  int forgetPairings() {
    forgets++;
    return 1;
  }

  @override
  Future<String> exportLog() async {
    exports++;
    return 'D:/logs/controller-test-log.txt';
  }

  @override
  Future<void> resume() async => resumes++;

  @override
  Future<void> dispose() => _changes.close();
}

/// The game host over the fake host state: its connected controllers are the
/// players, plus any local ones. Records, stages, haptics and rating asks are
/// kept for the test to check.
class FakeGameHost implements GameHost {
  FakeGameHost(this.fake) {
    fake._changes.stream.listen((_) => _changes.add(players));
  }

  /// The host whose state is the source of the players.
  final FakeHostService fake;

  /// The local players added through [addLocalPlayer], by ID.
  final locals = <String, LocalPlayer>{};

  /// Every record the game made.
  final records = <GameRecord>[];

  /// Every delay stage the game reported.
  final stages = <StageSample>[];

  /// The view, as the game sent it: every start, frame and end, in order.
  final viewStarts = <ViewStartMessage>[];
  final frames = <FrameMessage>[];
  final viewEnds = <ViewEndMessage>[];

  /// Every [hostAway] call, in order: the seconds left, or null for "back".
  final hostAways = <int?>[];

  /// Every [goOnWithout] call, in order: the player the round went on
  /// without.
  final goOnWithouts = <String>[];

  /// Whether anyone would get a frame: the test sets it.
  @override
  bool hasViewers = false;

  /// Each controller's last applied input seq, for [inputSeq], set by hand.
  final inputSeqs = <String, int>{};

  /// Every rating prompt asked: (player ID, prompt ID).
  final asks = <(String, String)>[];

  /// Each player's buttons, set by the test.
  final pads = <String, GamepadState>{};

  /// The controls whose phone has dropped and whose slot the round holds
  /// (the game host's away players): the test sets them with [setAway].
  final away = <String>{};

  /// A clock the test sets, in ms, or null to read the fake's own stopwatch: a
  /// countdown test moves the clock on instead of waiting.
  int? clockMs;

  /// Each player's layout and status panel, as the game set them.
  final layouts = <String, GameLayoutMessage>{};
  final statuses = <String, StatusMessage>{};

  final _changes = StreamController<List<GamePlayer>>.broadcast();
  final _sounds = StreamController<String>.broadcast();
  final _awayEnds = StreamController<AwayEnded>.broadcast();
  final _clock = Stopwatch()..start();

  /// Every away player's slot ending, as the host reports it (m12 bug 1108g).
  Stream<AwayEnded> get awayEnded => _awayEnds.stream;

  /// The grace the fake's host holds a slot for
  /// ([ServerGameHost.defaultAwayGrace]): what its ends say.
  static const grace = ServerGameHost.defaultAwayGrace;

  /// The names passed to [playSound], in order.
  Stream<String> get soundStream => _sounds.stream;

  ControllerInfo? _info(String id) => fake.state.players.where((c) => c.controllerId == id).firstOrNull;

  @override
  int get nowMs => clockMs ?? _clock.elapsedMilliseconds;

  @override
  List<GamePlayer> get players => [
    for (final (i, c) in fake.state.players.indexed)
      GamePlayer(
        id: c.controllerId,
        number: c.player ?? i + 1,
        nickname: c.name,
        mode: InputMode.of(c.input),
        simulated: c.platform == 'sim',
        away: away.contains(c.controllerId),
      ),
    for (final l in locals.values)
      GamePlayer(id: l.id, number: l.number, nickname: l.nickname, local: true, mode: InputMode.keyboard),
  ]..sort((a, b) => a.number.compareTo(b.number));

  @override
  Stream<List<GamePlayer>> get playersChanged => _changes.stream;

  /// Sets a phone's buttons, as its input message would.
  void setGamepad(String id, GamepadState state) => pads[id] = state;

  @override
  GamepadState gamepad(String playerId) =>
      locals[playerId]?.state ?? pads[playerId] ?? GamepadState.fromInput(_info(playerId)?.input);

  @override
  int? inputArrivedAtMs(String playerId) => null;

  @override
  int? inputSeq(String playerId) => inputSeqs[playerId];

  @override
  void startView(ViewStartMessage start) => viewStarts.add(start);

  @override
  void publishFrame(FrameMessage frame) => frames.add(frame);

  @override
  void endView(ViewEndMessage end, {ViewStartMessage? of}) {
    // An end for a view a newer start replaced is ignored, as the real host does.
    if (of == null || identical(of, viewStarts.lastOrNull)) viewEnds.add(end);
  }

  @override
  void hostAway(int? secondsLeft) => hostAways.add(secondsLeft);

  @override
  void goOnWithout(String playerId) {
    goOnWithouts.add(playerId);
    // The round goes on without them: the phone leaves the roster.
    if (away.contains(playerId)) _end(playerId, AwayEnd.wentOnWithout);
  }

  /// The host's grace running out for [id]'s phone (m12 bug 1108g): the slot
  /// ends, so the round goes on without the player and the phone leaves the
  /// roster.
  void graceOver(String id) {
    if (away.contains(id)) _end(id, AwayEnd.graceOver);
  }

  /// Puts [id]'s phone away or back, as the host holds its slot for a while
  /// when the phone drops (m12 bug 1107d): the players change, so the screens
  /// hear it.
  void setAway(String id, {required bool isAway}) {
    final changed = isAway ? away.add(id) : away.remove(id);
    if (changed) _changes.add(players);
  }

  /// Tells the away-ended listeners that [id]'s slot ended, then drops the
  /// phone: the host reports the end of the slot it held, before the roster
  /// without it.
  void _end(String id, AwayEnd reason) {
    _report(id, reason);
    away.remove(id);
    fake.removeController(id);
  }

  /// Reports [id]'s slot ending for [reason], with the player as the slot holds
  /// them (away).
  void _report(String id, AwayEnd reason) {
    final player = players.where((p) => p.id == id).firstOrNull;
    if (player != null) _awayEnds.add((player: player, reason: reason, grace: grace));
  }

  @override
  bool haptic(String playerId, HapticEventMessage event) {
    if (_info(playerId) == null) return false;
    fake.haptics.add((event, playerId));
    return true;
  }

  @override
  bool askRating(String playerId, {required String id, required String game}) {
    asks.add((playerId, id));
    return true;
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
  RttSummary? stageSummary(String playerId, String stage) =>
      stage == LatencyStage.sentToReceived ? _info(playerId)?.inputLatency : null;

  @override
  void record(GameRecord record) => records.add(record);

  @override
  void reportStage(String playerId, String stage, int ms) => stages.add((playerId: playerId, stage: stage, ms: ms));

  @override
  void playSound(String name) => _sounds.add(name);

  @override
  void setLayout(String playerId, GameLayoutMessage layout) => layouts[playerId] = layout;

  @override
  void setStatus(String playerId, StatusMessage status) => statuses[playerId] = status;

  @override
  LocalPlayer addLocalPlayer({String? nickname}) {
    final n = players.fold(0, (a, p) => p.number > a ? p.number : a) + 1;
    final p = LocalPlayer(
      'local-$n',
      n,
      nickname: nickname,
      onRemove: (p) {
        locals.remove(p.id);
        _changes.add(players);
      },
    );
    locals[p.id] = p;
    _changes.add(players);
    return p;
  }
}
