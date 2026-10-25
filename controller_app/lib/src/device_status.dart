import 'dart:async';

import 'package:flutter/services.dart';

/// Battery, heat and this app's CPU time, for the long-session check (PRD
/// M6: "a battery and CPU sanity check of a long gyro-streaming session").
final class DeviceStatus {
  const DeviceStatus({
    this.battery,
    this.charging = false,
    this.thermal = 'unknown',
    this.cpuMs,
    this.lowPower = false,
  });

  factory DeviceStatus.fromMap(Map<Object?, Object?> map) {
    final battery = (map['battery'] as num?)?.toDouble();
    return DeviceStatus(
      battery: battery == null || battery < 0 ? null : battery.clamp(0.0, 1.0),
      charging: map['charging'] == true,
      thermal: map['thermal'] as String? ?? 'unknown',
      cpuMs: (map['cpuMs'] as num?)?.toDouble(),
      lowPower: map['lowPower'] == true,
    );
  }

  /// 0 to 1, or null if the phone doesn't say.
  final double? battery;
  final bool charging;

  /// How warm the phone is: nominal, fair, serious or critical.
  final String thermal;

  /// CPU time this app has used since it started (all threads), in ms.
  final double? cpuMs;

  /// Low Power Mode (iOS) or Battery Saver (Android).
  final bool lowPower;
}

/// Reads [DeviceStatus] from the native side. A fake replaces it in tests.
abstract class DeviceStatusSource {
  Future<DeviceStatus?> read();
}

/// Uses the same small native channel as the haptics (AppDelegate.swift,
/// MainActivity.kt).
class PlatformDeviceStatus implements DeviceStatusSource {
  static const _channel = MethodChannel('com.gamecontrollerdev.controller/haptics');

  @override
  Future<DeviceStatus?> read() async {
    try {
      final map = await _channel.invokeMapMethod<Object?, Object?>('deviceStatus');
      return map == null ? null : DeviceStatus.fromMap(map);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null; // An older native build without this method.
    }
  }
}

/// One sample: when, the status, and how many input states had been sent.
typedef DeviceSample = ({DateTime at, DeviceStatus status, int inputsSent});

/// What Diagnostics shows about a session: CPU use, battery drain and the
/// send rate, since the app started and over the last minute.
final class SessionStats {
  const SessionStats({required this.first, required this.latest, this.recent});

  final DeviceSample first;
  final DeviceSample latest;

  /// The sample about a minute before [latest], for the recent rates.
  final DeviceSample? recent;

  Duration get length => latest.at.difference(first.at);

  /// CPU use in % of one core, over the session and over the last minute.
  double? get cpuPercent => _cpu(first, latest);
  double? get recentCpuPercent => recent == null ? null : _cpu(recent!, latest);

  /// Battery used per hour (in % of a full charge), over the session. Null
  /// while charging, without a battery reading, or in the first 5 minutes.
  double? get batteryPerHour {
    final a = first.status.battery;
    final b = latest.status.battery;
    if (a == null || b == null || latest.status.charging || first.status.charging) return null;
    if (length < const Duration(minutes: 5)) return null;
    return (a - b) * 100 / (length.inSeconds / 3600);
  }

  /// Input states sent per second over the last minute (or the session).
  double get sendRate {
    final from = recent ?? first;
    final s = latest.at.difference(from.at).inMilliseconds / 1000;
    return s <= 0 ? 0 : (latest.inputsSent - from.inputsSent) / s;
  }

  static double? _cpu(DeviceSample a, DeviceSample b) {
    final cpuA = a.status.cpuMs;
    final cpuB = b.status.cpuMs;
    final wall = b.at.difference(a.at).inMilliseconds;
    if (cpuA == null || cpuB == null || wall <= 0) return null;
    return (cpuB - cpuA) * 100 / wall;
  }
}

/// Samples the device status every [period] and keeps the first sample, the
/// latest and about a minute's worth in between.
class SessionMonitor {
  SessionMonitor(
    this._source, {
    required this._inputsSent,
    this.period = const Duration(seconds: 10),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final DeviceStatusSource _source;
  final int Function() _inputsSent;
  final Duration period;
  final DateTime Function() _clock;
  final _samples = <DeviceSample>[];
  DeviceSample? _first;
  Timer? _timer;
  final _changes = StreamController<SessionStats?>.broadcast();

  Stream<SessionStats?> get changes => _changes.stream;

  SessionStats? get stats {
    final first = _first;
    if (first == null || _samples.isEmpty) return null;
    final latest = _samples.last;
    final cutoff = latest.at.subtract(const Duration(minutes: 1));
    final recent =
        _samples.where((s) => !s.at.isAfter(cutoff)).lastOrNull ?? (_samples.length > 1 ? _samples.first : null);
    return SessionStats(first: first, latest: latest, recent: recent);
  }

  void start() {
    _timer ??= Timer.periodic(period, (_) => sample());
    unawaited(sample());
  }

  /// Takes one sample now.
  Future<void> sample() async {
    final status = await _source.read();
    if (status == null) return;
    final s = (at: _clock(), status: status, inputsSent: _inputsSent());
    _first ??= s;
    _samples.add(s);
    // Keep a little over a minute, enough for the recent rates.
    final cutoff = s.at.subtract(const Duration(seconds: 90));
    while (_samples.length > 2 && _samples.first.at.isBefore(cutoff)) {
      _samples.removeAt(0);
    }
    if (!_changes.isClosed) _changes.add(stats);
  }

  Future<void> dispose() async {
    _timer?.cancel();
    await _changes.close();
  }
}
