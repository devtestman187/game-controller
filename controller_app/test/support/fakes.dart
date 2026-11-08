import 'dart:async';

import 'package:connection/connection.dart';
import 'package:controller/src/device_status.dart';
import 'package:controller/src/discovery.dart';
import 'package:controller/src/haptics.dart';
import 'package:controller/src/motion.dart';
import 'package:controller/src/tilt.dart';
import 'package:flutter/services.dart';
import 'package:protocol/protocol.dart';

class FakeClient extends ControllerClient {
  FakeClient({this.savedTokens = const {}})
    : super(
        identity: const ControllerIdentity(controllerId: 'test', name: 'Test', platform: 'test', appVersion: 't'),
        connector: WebSocketConnector(),
      );

  final Map<String, String> savedTokens;
  final calls = <String>[];

  /// Every input state the pad sent, as "A+B dx,dy".
  final inputs = <String>[];
  ClientSnapshot _snap = const ClientSnapshot(status: ClientStatus.idle);
  final _changes = StreamController<ClientSnapshot>.broadcast();
  final _haptic = StreamController<HapticEventMessage>.broadcast();
  int _hapticCount = 0;

  /// A haptic event arriving from the TV.
  void fromTv(HapticEventMessage m) {
    _hapticCount++;
    _haptic.add(m);
  }

  @override
  Stream<HapticEventMessage> get hapticEvents => _haptic.stream;

  @override
  int get hapticsReceived => _hapticCount;

  void emit(ClientSnapshot s) {
    _snap = s;
    _changes.add(s);
  }

  @override
  ClientSnapshot get snapshot => _snap;

  @override
  Stream<ClientSnapshot> get changes => _changes.stream;

  @override
  Map<String, String> get tokens => savedTokens;

  @override
  void connect(HostAddress target, {String? code}) =>
      calls.add('connect ${target.display}${code == null ? '' : ' $code'}');

  @override
  void submitCode(String code) => calls.add('code $code');

  @override
  void disconnect() => calls.add('disconnect');

  @override
  void updateAddress(HostAddress found) {}

  @override
  void resume() => calls.add('resume');

  int sent = 0;

  @override
  int get inputsSent => sent;

  @override
  void sendInput(
    Set<ControllerButton> buttons, {
    int dx = 0,
    int dy = 0,
    double? ax,
    double? ay,
    ({double x, double y})? left,
    ({double x, double y})? right,
  }) {
    final names = [
      for (final b in ControllerButton.values)
        if (buttons.contains(b)) b.name.toUpperCase(),
    ];
    final tilt = ax == null ? '' : ' tilt $ax,$ay';
    final sticks = left == null ? '' : ' L ${left.x},${left.y} R ${right!.x},${right.y}';
    inputs.add('${names.join('+')} $dx,$dy$tilt$sticks'.trim());
    sent++;
  }

  /// Metrics batches and ratings the phone sent (M9).
  final metrics = <MetricsMessage>[];
  final ratings = <RatingMessage>[];
  final _asks = StreamController<RatingAskMessage>.broadcast();

  /// A rating prompt arriving from the TV.
  void ask(RatingAskMessage m) => _asks.add(m);

  @override
  Stream<RatingAskMessage> get ratingAsks => _asks.stream;

  @override
  void sendMetrics(MetricsMessage batch) => metrics.add(batch);

  @override
  void sendRating(RatingMessage rating) => ratings.add(rating);

  /// The game's controls and status panel arriving from the TV (M10).
  GameLayoutMessage _layout = GameLayoutMessage.standard();
  StatusMessage _status = StatusMessage.hidden();
  final _layouts = StreamController<GameLayoutMessage>.broadcast();
  final _statuses = StreamController<StatusMessage>.broadcast();

  void setLayout(GameLayoutMessage l) => _layouts.add(_layout = l);

  void setStatus(StatusMessage s) => _statuses.add(_status = s);

  @override
  GameLayoutMessage get layout => _layout;

  @override
  Stream<GameLayoutMessage> get layouts => _layouts.stream;

  @override
  StatusMessage get status => _status;

  @override
  Stream<StatusMessage> get statuses => _statuses.stream;

  /// The game a host shows this phone (m12 §5): the test adds its events to
  /// this stream, as the client's handler would.
  final _view = StreamController<ViewEvent>.broadcast();

  @override
  Stream<ViewEvent> get view => _view.stream;

  /// What the phone measures while it shows a game: a real one, as the client
  /// makes for a phone that listed view (m12 §4).
  @override
  final ViewerStats viewerStats = ViewerStats(hz: ViewerStats.simStepHz);

  /// This phone's clock in ms, which a frame's arrival and its draw are
  /// measured on (m12 §4): the test moves it, as it moves a real client's
  /// stopwatch.
  @override
  int nowMs = 0;

  /// The host starts showing [start].
  void viewStart(ViewStartMessage start) => _view.add(ViewStarted(start));

  /// The frame [frame] of the shown game, arriving now on this phone's clock.
  void viewFrame(FrameMessage frame) => _view.add(ViewFrame(frame, nowMs));

  /// The host stops showing its game.
  void viewEnd(ViewEndMessage end) => _view.add(ViewEnded(end));

  /// The host is away for [secondsLeft], arriving now on this phone's clock
  /// (m12-joined-view §0.3).
  void hostAway(int secondsLeft) => _view.add(HostAway(secondsLeft, nowMs));

  /// The host is back, so the game goes on.
  void hostBack() => _view.add(const HostBack());

  /// The player [playerId], number [number] in the round, is away and the game
  /// waits [secondsLeft] for it, arriving now on this phone's clock (m12 bug
  /// 1107d).
  void playerAway(String playerId, int number, int secondsLeft) =>
      _view.add(PlayerAway(playerId, number, secondsLeft, nowMs));

  /// The player [playerId] is back, so its card line goes.
  void playerBack(String playerId) => _view.add(PlayerBack(playerId));

  @override
  Future<void> dispose() async {
    await _view.close();
    await _changes.close();
  }
}

class FakeDiscovery implements HostDiscovery {
  FakeDiscovery([this._state = const DiscoveryState(running: true)]);

  DiscoveryState _state;
  final _changes = StreamController<DiscoveryState>.broadcast();
  int restarts = 0;

  /// How many times the search was stopped: a hosting phone stops it.
  int stops = 0;

  void emit(DiscoveryState s) {
    _state = s;
    _changes.add(s);
  }

  @override
  DiscoveryState get state => _state;

  @override
  Stream<DiscoveryState> get changes => _changes.stream;

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async => stops++;

  @override
  Future<void> restart() async => restarts++;

  @override
  Future<void> dispose() => _changes.close();
}

/// Haptics whose capability check finishes only when the test completes [caps].
class SlowCapsHaptics extends FakeHaptics {
  SlowCapsHaptics() : super(caps: HapticsCapabilities.none);

  final ready = Completer<HapticsCapabilities>();

  @override
  Future<HapticsCapabilities> capabilities() => ready.future;
}

/// Motion sensors driven by the test.
class FakeMotionSensors implements MotionSensors {
  final _accel = StreamController<Vec3>.broadcast();
  final _gyro = StreamController<(Vec3, DateTime)>.broadcast();
  var _time = DateTime(2026);

  /// Makes the gyroscope stream fail, like a phone without one.
  bool noGyroscope = false;

  bool get listening => _gyro.hasListener;

  @override
  Stream<Vec3> accelerometer(Duration period) => _accel.stream;

  @override
  Stream<(Vec3, DateTime)> gyroscope(Duration period) =>
      noGyroscope ? Stream.error(PlatformException(code: 'NO_SENSOR', message: 'No gyroscope')) : _gyro.stream;

  /// Holds the phone still with "up" along [up] for [samples] readings
  /// (10 ms apart), so the filter settles on it.
  void hold(Vec3 up, {int samples = 400}) {
    for (var i = 0; i < samples; i++) {
      _accel.add(up.normalized * standardGravity);
      _time = _time.add(const Duration(milliseconds: 10));
      _gyro.add((const Vec3(0, 0, 0), _time));
    }
  }
}

/// Battery and CPU readings from the test.
class FakeDeviceStatus implements DeviceStatusSource {
  DeviceStatus? next = const DeviceStatus(battery: 0.8, thermal: 'nominal', cpuMs: 0);

  @override
  Future<DeviceStatus?> read() async => next;
}
