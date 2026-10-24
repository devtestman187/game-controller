import 'dart:collection';

/// Lowest, average and highest round-trip time over a recent window.
final class RttSummary {
  const RttSummary({required this.minMs, required this.avgMs, required this.maxMs, required this.samples});

  final int minMs;
  final int avgMs;
  final int maxMs;
  final int samples;

  @override
  String toString() => 'min $minMs · avg $avgMs · max $maxMs ms';
}

/// Keeps round-trip samples from the last [window] and summarizes them.
class RttWindow {
  RttWindow({this.window = const Duration(seconds: 30)});

  final Duration window;
  final _samples = ListQueue<(int, int)>(); // (time ms, rtt ms)

  void add(int nowMs, int rttMs) {
    _samples.addLast((nowMs, rttMs));
    _trim(nowMs);
  }

  void clear() => _samples.clear();

  RttSummary? summary(int nowMs) {
    _trim(nowMs);
    if (_samples.isEmpty) return null;
    var min = _samples.first.$2;
    var max = min;
    var total = 0;
    for (final (_, rtt) in _samples) {
      if (rtt < min) min = rtt;
      if (rtt > max) max = rtt;
      total += rtt;
    }
    return RttSummary(minMs: min, avgMs: (total / _samples.length).round(), maxMs: max, samples: _samples.length);
  }

  void _trim(int nowMs) {
    final cutoff = nowMs - window.inMilliseconds;
    while (_samples.isNotEmpty && _samples.first.$1 < cutoff) {
      _samples.removeFirst();
    }
  }
}
