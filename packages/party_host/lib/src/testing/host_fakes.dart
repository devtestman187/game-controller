import 'dart:async';

import 'package:connection/connection.dart';
import 'package:protocol/protocol.dart';

import '../host_service.dart';
import '../host_view_state.dart';
import '../session_uploader.dart';
import '../stats_service.dart';
import '../stats_state.dart';

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

  /// Haptic events the game host sent: (event, player ID).
  final haptics = <(HapticEventMessage, String?)>[];

  @override
  Stream<HostViewState> get changes => _changes.stream;

  /// Tells the listeners that [state] changed.
  void emit() => _changes.add(state);

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

  /// Whether anyone would get a frame: the test sets it.
  @override
  bool hasViewers = false;

  /// Each controller's last applied input seq, for [inputSeq], set by hand.
  final inputSeqs = <String, int>{};

  /// Every rating prompt asked: (player ID, prompt ID).
  final asks = <(String, String)>[];

  /// Each player's buttons, set by the test.
  final pads = <String, GamepadState>{};

  /// Each player's layout and status panel, as the game set them.
  final layouts = <String, GameLayoutMessage>{};
  final statuses = <String, StatusMessage>{};

  final _changes = StreamController<List<GamePlayer>>.broadcast();
  final _sounds = StreamController<String>.broadcast();
  final _clock = Stopwatch()..start();

  /// The names passed to [playSound], in order.
  Stream<String> get soundStream => _sounds.stream;

  ControllerInfo? _info(String id) => fake.state.players.where((c) => c.controllerId == id).firstOrNull;

  @override
  int get nowMs => _clock.elapsedMilliseconds;

  @override
  List<GamePlayer> get players => [
    for (final (i, c) in fake.state.players.indexed)
      GamePlayer(
        id: c.controllerId,
        number: c.player ?? i + 1,
        nickname: c.name,
        mode: InputMode.of(c.input),
        simulated: c.platform == 'sim',
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
  void endView(ViewEndMessage end) => viewEnds.add(end);

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

/// Analytics for the tests: [summaries] are the saved sessions, [consents]
/// every answer to the consent prompt.
class FakeStats implements StatsService {
  FakeStats({bool? consent}) : _state = StatsState(consent: consent, uploadConfigured: true);

  StatsState _state;
  final _changes = StreamController<StatsState>.broadcast();

  /// The saved sessions, as [sessions] reports them.
  final summaries = <Map<String, Object?>>[];

  /// Every answer given to the consent prompt.
  final consents = <bool>[];

  /// How many times the sessions were exported.
  int exports = 0;

  /// Replaces the state and tells the listeners.
  void emit(StatsState s) {
    _state = s;
    _changes.add(s);
  }

  @override
  StatsState get state => _state;

  @override
  Stream<StatsState> get changes => _changes.stream;

  @override
  Future<List<SessionFile>> sessions() async => [
    for (final (i, s) in summaries.indexed) SessionFile('/sessions/s$i.json', s),
  ];

  @override
  Future<String> exportAll() async {
    exports++;
    return 'D:/Downloads/thumb-party-sessions';
  }

  @override
  void setConsent(bool share) {
    consents.add(share);
    emit(_state.copyWith(consent: share));
  }

  @override
  Future<void> uploadNow() async {}
}

/// An uploader that keeps what it was given and can be told to fail.
class FakeUploader implements SessionUploader {
  /// Every summary uploaded successfully, in order.
  final uploaded = <Map<String, Object?>>[];

  /// While set, every upload fails with this message.
  String? failWith;

  @override
  Future<String?> upload(Map<String, Object?> summary) async {
    if (failWith != null) return failWith;
    uploaded.add(summary);
    return null;
  }
}
