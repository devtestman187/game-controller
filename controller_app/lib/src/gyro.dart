import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'motion.dart';
import 'providers.dart';
import 'tilt.dart';

enum PadMode { dpad, gyro }

enum GyroAvailability { unknown, checking, available, unavailable }

/// Everything the gyro screen and Diagnostics show.
final class GyroState {
  const GyroState({
    this.mode = PadMode.dpad,
    this.availability = GyroAvailability.unknown,
    this.problem,
    this.side,
    this.calibrated = false,
    this.x = 0,
    this.y = 0,
    this.up,
    this.updates = 0,
  });

  final PadMode mode;
  final GyroAvailability availability;

  /// Why gyro mode isn't available, for the user.
  final String? problem;

  /// The landscape side the screen is locked to while in gyro mode.
  final LandscapeSide? side;
  final bool calibrated;

  /// The stick values being sent.
  final double x;
  final double y;

  /// The estimated up direction, for Diagnostics.
  final Vec3? up;

  /// Output steps since gyro mode started.
  final int updates;

  GyroState copyWith({
    PadMode? mode,
    GyroAvailability? availability,
    Object? problem = _keep,
    Object? side = _keep,
    bool? calibrated,
    double? x,
    double? y,
    Object? up = _keep,
    int? updates,
  }) => GyroState(
    mode: mode ?? this.mode,
    availability: availability ?? this.availability,
    problem: identical(problem, _keep) ? this.problem : problem as String?,
    side: identical(side, _keep) ? this.side : side as LandscapeSide?,
    calibrated: calibrated ?? this.calibrated,
    x: x ?? this.x,
    y: y ?? this.y,
    up: identical(up, _keep) ? this.up : up as Vec3?,
    updates: updates ?? this.updates,
  );
}

const Object _keep = Object();

/// Overridden in tests with fake sensors.
final motionSensorsProvider = Provider<MotionSensors>((ref) => PlatformMotionSensors());

final gyroSettingsProvider = NotifierProvider<GyroSettingsNotifier, GyroSettings>(GyroSettingsNotifier.new);

/// Sensitivity, dead zone and smoothing, saved between launches.
class GyroSettingsNotifier extends Notifier<GyroSettings> {
  @override
  GyroSettings build() => GyroSettings.load(ref.watch(prefsProvider));

  void update(GyroSettings settings) {
    state = settings;
    unawaited(settings.save(ref.read(prefsProvider)));
  }
}

final gyroProvider = NotifierProvider<GyroNotifier, GyroState>(GyroNotifier.new);

/// Gyro mode: reads both motion sensors, turns tilt into stick values and
/// sends them (with the buttons) about 60 times a second.
class GyroNotifier extends Notifier<GyroState> {
  static const sensorPeriod = Duration(milliseconds: 10);
  static const outputPeriod = Duration(microseconds: 16667); // ~60 Hz.

  /// How long to wait for the first gyroscope sample before deciding the
  /// phone has none.
  static Duration gyroTimeout = const Duration(milliseconds: 1500);

  final _estimator = UpEstimator();
  final _processor = TiltProcessor();
  StreamSubscription<Vec3>? _accelSub;
  StreamSubscription<(Vec3, DateTime)>? _gyroSub;
  Timer? _output;
  LandscapeSide _lastSide = LandscapeSide.left;
  bool _paused = false;

  @override
  GyroState build() {
    _processor.settings = ref.read(gyroSettingsProvider);
    ref.listen(gyroSettingsProvider, (_, s) => _processor.settings = s);
    ref.onDispose(_stopSensors);
    return const GyroState();
  }

  /// Switches between the D-pad and gyro mode without reconnecting.
  /// Returns false (staying on the D-pad) if the phone has no usable
  /// gyroscope.
  Future<bool> setMode(PadMode mode) async {
    if (mode == state.mode) return true;
    final log = ref.read(logProvider).sink('gyro');
    if (mode == PadMode.dpad) {
      log('Gyro mode off');
      _stopSensors();
      state = state.copyWith(mode: PadMode.dpad, x: 0, y: 0);
      ref.read(padProvider.notifier).tilt(null, null);
      unawaited(_unlockOrientation());
      return true;
    }

    state = state.copyWith(availability: GyroAvailability.checking);
    final ok = await _startSensors();
    if (!ok) {
      log('Gyro mode unavailable: ${state.problem}');
      _stopSensors();
      return false;
    }
    final side = _estimator.up == null ? null : landscapeSideOf(_estimator.up!);
    _lastSide = side ?? _lastSide;
    // Lock the screen: tilting to steer must not rotate the UI. If the
    // guess is wrong the UI turns over once, the user turns the phone, and
    // the axes then match.
    unawaited(
      SystemChrome.setPreferredOrientations([
        _lastSide == LandscapeSide.left ? DeviceOrientation.landscapeLeft : DeviceOrientation.landscapeRight,
      ]),
    );
    _processor.neutral = null; // Calibrate on the first reading.
    state = state.copyWith(mode: PadMode.gyro, side: _lastSide, calibrated: false, updates: 0);
    log('Gyro mode on (landscape ${_lastSide.name}), sensors every ${sensorPeriod.inMilliseconds} ms');
    _startOutput();
    return true;
  }

  /// Makes the way the phone is held right now the center.
  void calibrate() {
    final up = _estimator.up;
    final side = state.side;
    if (up == null || side == null) return;
    _processor.calibrate(tiltOf(up, side));
    state = state.copyWith(calibrated: true, x: 0, y: 0);
    ref.read(logProvider).add('gyro', 'Calibrated at ${tiltOf(up, side)}');
  }

  /// The app left the foreground: stop the sensors and center the stick.
  void pause() {
    if (state.mode != PadMode.gyro || _paused) return;
    _paused = true;
    _stopSensors();
    state = state.copyWith(x: 0, y: 0);
  }

  /// Back in the foreground: start again, keeping the calibration.
  Future<void> resume() async {
    if (state.mode != PadMode.gyro || !_paused) return;
    _paused = false;
    if (await _startSensors()) _startOutput();
  }

  Future<bool> _startSensors() async {
    final sensors = ref.read(motionSensorsProvider);
    final firstGyro = Completer<bool>();
    _accelSub = sensors
        .accelerometer(sensorPeriod)
        .listen(
          _estimator.accelerometer,
          onError: (Object e) => _fail('The accelerometer isn\'t working ($e).', firstGyro),
        );
    _gyroSub = sensors.gyroscope(sensorPeriod).listen((sample) {
      _estimator.gyroscope(sample.$1, sample.$2);
      if (!firstGyro.isCompleted) firstGyro.complete(true);
    }, onError: (Object e) => _fail('This phone has no usable gyroscope, so gyro mode is off ($e).', firstGyro));
    final ok = await firstGyro.future.timeout(
      gyroTimeout,
      onTimeout: () {
        _fail('No gyroscope readings, so gyro mode is off. This phone may not have a gyroscope.', null);
        return false;
      },
    );
    if (ok) state = state.copyWith(availability: GyroAvailability.available, problem: null);
    return ok;
  }

  void _fail(String problem, Completer<bool>? waiting) {
    state = state.copyWith(availability: GyroAvailability.unavailable, problem: problem);
    if (waiting != null && !waiting.isCompleted) waiting.complete(false);
  }

  void _startOutput() {
    _output?.cancel();
    _output = Timer.periodic(outputPeriod, (_) {
      final up = _estimator.up;
      final side = state.side;
      if (up == null || side == null) return;
      final out = _processor.process(tiltOf(up, side));
      ref.read(padProvider.notifier).tilt(out.x, out.y);
      state = state.copyWith(x: out.x, y: out.y, up: up, calibrated: true, updates: state.updates + 1);
    });
  }

  /// Stops at once: no samples arrive after this, so there is nothing to wait
  /// for (and the platform side may answer the cancel late).
  void _stopSensors() {
    _output?.cancel();
    _output = null;
    unawaited(_accelSub?.cancel());
    unawaited(_gyroSub?.cancel());
    _accelSub = null;
    _gyroSub = null;
  }

  Future<void> _unlockOrientation() =>
      SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
}
