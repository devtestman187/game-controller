import 'dart:async';

import 'package:connection/connection.dart';
import 'package:metrics/metrics.dart';

import 'host_device_monitor.dart';

/// How often the host reads its own battery while a session runs (m12 §0.8):
/// often enough for the thermal seconds to mean something, rarely enough that
/// a play session costs nothing.
const deviceSampleInterval = Duration(seconds: 30);

/// Takes the host device's battery and heat for the session summary (m12
/// §0.8): one reading every [period] while a session runs, and one at each
/// round's start and end so the round keeps its own battery.
///
/// It listens to [host]'s records beside the session recorder, so a round's
/// records stay in step while the readings, which are slow, arrive later.
class HostDeviceSampler {
  /// [session] returns the session to record into, or null between sessions,
  /// so a reading that arrives after one ended finds nothing to write.
  /// [period] is the time between readings, injected so a test doesn't wait
  /// 30 s; [log] gets a short line when a reading fails.
  HostDeviceSampler({
    required this.host,
    required this.monitor,
    required this.session,
    this.period = deviceSampleInterval,
    LogSink? log,
  }) : _log = log ?? ((_) {}) {
    _records = host.records.listen(_onRecord);
    _timer = Timer.periodic(period, (_) => unawaited(_tick()));
  }

  /// The game host whose rounds it follows.
  final ServerGameHost host;

  /// Where its readings come from.
  final HostDeviceMonitor monitor;

  /// The session being recorded, or null between sessions.
  final SessionCollector? Function() session;

  /// How often it reads the device while a session runs.
  final Duration period;

  final LogSink _log;
  late final StreamSubscription<GameRecord> _records;
  late final Timer _timer;

  /// The round being played, counted from 1 so 0 means none started yet.
  int _round = 0;

  /// The reading of the running round's start level, or null when the round
  /// hasn't started one.
  Future<double?>? _start;
  bool _reading = false;
  bool _disposed = false;

  /// Stops the timer and the round hooks: a reading in flight writes nothing.
  Future<void> dispose() async {
    _disposed = true;
    _timer.cancel();
    await _records.cancel();
  }

  void _onRecord(GameRecord record) {
    switch (record.name) {
      case 'round_start':
        final round = ++_round;
        _start = _readStart(round);
      case 'round_end':
        final start = _start;
        _start = null;
        // A round this sampler saw no start of has no level to pair with.
        if (start != null) unawaited(_readEnd(_round, start));
    }
  }

  /// The level at the start of the round that just began, which its end reads
  /// again: a reading that lands after a newer round began is not kept.
  Future<double?> _readStart(int round) async {
    final sample = await _sample();
    return round == _round ? sample?.battery : null;
  }

  /// Gives the round that ended its battery, from the start it read and from
  /// one taken now, and the device's heat at that moment.
  Future<void> _readEnd(int round, Future<double?> start) async {
    final startLevel = await start;
    final sample = await _sample();
    if (round != _round) return; // a newer round began while it read
    session()?.roundBattery(
      start: startLevel,
      end: sample?.battery,
      thermal: sample?.thermal,
      charging: sample?.charging ?? false,
    );
  }

  /// The timer's reading: [period] seconds have passed in the state it finds,
  /// so they are counted for that state's thermal seconds.
  Future<void> _tick() async {
    if (_reading) return; // a slow reading isn't counted twice
    _reading = true;
    try {
      final sample = await _sample();
      if (!_disposed) session()?.deviceSample(sample, forS: period.inSeconds);
    } finally {
      _reading = false;
    }
  }

  /// One reading, or null when the device can't be read: the adapter's
  /// failure is logged and costs that reading only.
  Future<HostDeviceSample?> _sample() async {
    if (_disposed) return null;
    try {
      return await monitor.sample();
    } catch (e) {
      _log('Could not read the battery: $e');
      return null;
    }
  }
}
