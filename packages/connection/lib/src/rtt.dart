import 'dart:collection';

/// Lowest, average and highest round-trip time (or any delay) over a recent
/// window.
final class RttSummary {
  const RttSummary({required this.minMs, required this.avgMs, required this.maxMs, required this.samples, this.p95Ms});

  final int minMs;
  final int avgMs;
  final int maxMs;
  final int samples;

  /// 95 % of the samples were at or below this. Null when not computed.
  final int? p95Ms;

  @override
  String toString() => 'min $minMs · avg $avgMs · max $maxMs ms';
}

/// Keeps samples (in milliseconds) from the last [window] and summarizes
/// them. Used for the heartbeat round trip and for the input delay.
class RttWindow {
  RttWindow({this.window = const Duration(seconds: 30)});

  final Duration window;
  final _samples = ListQueue<(int, int)>(); // (time ms, value ms)

  void add(int nowMs, int rttMs) {
    _samples.addLast((nowMs, rttMs));
    _trim(nowMs);
  }

  void clear() => _samples.clear();

  RttSummary? summary(int nowMs) {
    _trim(nowMs);
    if (_samples.isEmpty) return null;
    final values = [for (final (_, v) in _samples) v]..sort();
    final total = values.fold(0, (a, b) => a + b);
    return RttSummary(
      minMs: values.first,
      avgMs: (total / values.length).round(),
      maxMs: values.last,
      samples: values.length,
      p95Ms: values[((values.length - 1) * 0.95).round()],
    );
  }

  void _trim(int nowMs) {
    final cutoff = nowMs - window.inMilliseconds;
    while (_samples.isNotEmpty && _samples.first.$1 < cutoff) {
      _samples.removeFirst();
    }
  }
}

/// Running totals for a whole session (no window), for the log export.
final class RunningStats {
  int count = 0;
  int _total = 0;
  int? minMs;
  int? maxMs;

  void add(int ms) {
    count++;
    _total += ms;
    minMs = minMs == null || ms < minMs! ? ms : minMs;
    maxMs = maxMs == null || ms > maxMs! ? ms : maxMs;
  }

  int? get avgMs => count == 0 ? null : (_total / count).round();

  @override
  String toString() => count == 0 ? 'no samples' : 'min $minMs · avg $avgMs · max $maxMs ms ($count samples)';
}
