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

/// The orientation to lock to so the screen stays on the physical [side].
///
/// Flutter's landscape names follow Android ([LandscapeSide.left] = top of
/// the phone on the left is `landscapeLeft`). On iOS they reach UIKit's
/// interface orientations, whose left and right are the other way round, so
/// the same physical side needs the opposite name. Seen on the iPhone in M3:
/// with the Android names the screen turned 180° on every mode switch.
DeviceOrientation orientationFor(LandscapeSide side, {required bool isIOS}) {
  final topOnLeft = side == LandscapeSide.left;
  return topOnLeft != isIOS ? DeviceOrientation.landscapeLeft : DeviceOrientation.landscapeRight;
}

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
  StreamSubscription<Vec3>? _sideSub;
  int _otherSideReadings = 0;
  bool _paused = false;

  @override
  GyroState build() {
    _processor.settings = ref.read(gyroSettingsProvider);
    ref.listen(gyroSettingsProvider, (_, s) => _processor.settings = s);
    ref.onDispose(() {
      _stopSensors();
      _stopSideTracking();
    });
    _startSideTracking();
    return const GyroState();
  }

  /// Keeps track of which landscape side the phone is held in, even in D-pad
  /// mode, with a light accelerometer reading 10 times a second. iOS turns
  /// the screen on the same cue, so this is the side the screen shows. It
  /// matters when gyro mode starts with the phone lying flat, where the side
  /// can't be read at that moment.
  void _startSideTracking() {
    _sideSub ??= ref.read(motionSensorsProvider).accelerometer(const Duration(milliseconds: 100)).listen(
      (a) {
        // Like iOS, only change sides once the new side has held for a
        // moment (3 readings, about 0.3 s), so a brief wobble can't flip it.
        final side = landscapeSideOf(a);
        if (side == null || side == _lastSide) {
          _otherSideReadings = 0;
        } else if (++_otherSideReadings >= 3) {
          _lastSide = side;
          _otherSideReadings = 0;
        }
      },
      onError: (Object _) {}, // Gyro mode reports sensor problems itself.
    );
  }

  void _stopSideTracking() {
    unawaited(_sideSub?.cancel());
    _sideSub = null;
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
    // The side comes from the tracker, which has been following the phone
    // all along (and is what the screen shows), never from a single reading.
    // Lock the screen to the side it already shows: tilting to steer must
    // not rotate the UI (and with it the axes).
    unawaited(SystemChrome.setPreferredOrientations([orientationFor(_lastSide, isIOS: ref.read(isIOSProvider))]));
    _processor.neutral = null; // Calibrate on the first reading.
    state = state.copyWith(mode: PadMode.gyro, side: _lastSide, calibrated: false, updates: 0);
    log(
      'Gyro mode on (landscape ${_lastSide.name}, up ${_estimator.up}), sensors every ${sensorPeriod.inMilliseconds} ms',
    );
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
    _stopSideTracking();
    if (state.mode != PadMode.gyro || _paused) return;
    _paused = true;
    _stopSensors();
    state = state.copyWith(x: 0, y: 0);
  }

  /// Back in the foreground: start again, keeping the calibration.
  Future<void> resume() async {
    _startSideTracking();
    if (state.mode != PadMode.gyro || !_paused) return;
    _paused = false;
    if (await _startSensors()) _startOutput();
  }

  Future<bool> _startSensors() async {
    final sensors = ref.read(motionSensorsProvider);
    // The phone may have moved since the sensors last ran: start fresh, or
    // the old estimate would drift towards the real position.
    _estimator.reset();
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
      if (!_estimator.settled) {
        // Settling (about 0.3 s): hold the stick centered, calibrate after.
        ref.read(padProvider.notifier).tilt(0, 0);
        return;
      }
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
